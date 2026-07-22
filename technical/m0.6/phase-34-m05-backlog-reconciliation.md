# M0.6 Phase 34 — M0.5 Backlog Reconciliation: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-24/25**;
> the drift section traces the observability and strong-type surfaces
> through today's stack.

## Starting point

M0.5 closed 2026-06-16 with the 1 Critical + 15 High findings resolved
in-phase; 15 Medium + 7 Low findings were deliberately left open, to close
in a dedicated phase rather than ride a feature phase. Phase 34 is that
phase: read every backlog finding, disposition it, and produce a ledger
with one row per finding, each pointing at a real commit (closed) or a
recorded blocker (re-deferred). It runs after Phase 32 (WH flipped live),
so each finding is reconciled against the shipped integrator, not the M0.5
state where WH was built but disabled.

The backlog turned out to total 30 findings once the reconciliation was
exhaustive, not 22: the 15 Medium + 7 Low batch, plus three Mediums that
M0.6 phases 30/31/33 had already closed as a side effect of unrelated
work, plus three that were accepted, disputed, or marked not-applicable
when M0.5 closed and needed re-verifying, not re-opening. Final tally: **3
already-closed, 19 closed here, 5 re-deferred with named blockers, 3
accepted/disputed/N-A** — zero rows without a disposition.

## 34.1 — test adequacy

Six findings named gaps in coverage rather than bugs in code.

**Snapshot-contention soak test** — the existing cases parked the
production worker and drove `publish_snapshot()` from the test thread itself,
so the real production-worker-writes/render-reads interleave was never
exercised. A new case starts `PhysicsWorker` live (no pause)
against an N=3 config with `time_scale_init = 1e5` (frequent publishes) and
spins a reader thread on `latest_snapshot(SnapshotView&)` — the render hot
path — for a soak window, asserting every observed frame is internally
coherent (`pos.size() == vel.size() == count`, `count <= capacity`, every
scalar finite) and `sim_time` never runs backwards across coherent reads.

**End-to-end shipped WH warp coverage** — the shipped Wisdom-Holman path
had energy locks and eligibility tests, but no single test drove the
exact shipped EMB warp config (Sun/EMB/Mars/Jupiter, SSB J2000/DE441
initial conditions copied verbatim from `main.cpp`) end-to-end through
`wh_step` over a long warp window. `test_wh_warp_scenario.cpp` fixes
that: 20,000 steps at `dt = 1e5` s (~63 years), confirming the production
worker genuinely selects WH (`selected_method_index() == 2`) on this
seed, then asserting whole-system energy stays under a 5e-3 ceiling
against the independent `total_energy` oracle. The ceiling is 5× the
M0.6 calibration's measured `max|dE/E| < 1e-3` at 5000 steps — a
documented envelope for the 4×-longer horizon, not an a-priori number.

**Cross-family tolerance and hysteresis-band coverage** — one fix derives
the cross-family determinism tolerance band from measurement instead of
a round number, and gives the S2 golden a non-vacuous z-channel; another
pair two-sided-brackets the WH perturbation-ratio eligibility knee and
the detector's chatter-vs-switch-rate threshold on a near-boundary pair,
closing the hysteresis-band gap at the test level (the hysteresis
*implementation* itself stays a named M1.x deferral against the
perturbation-ratio gate).

**Test-particle branch coverage** — adds coverage for two zero-covered
test-particle branches: a central-field force applied over a TP slot,
and the analytic TP branch under multiple simultaneous placements.

## 34.2 — observability

**A missing alarm on a silent telemetry signal** — the largest single
finding in the batch: `dE/E` was print-only telemetry with no alarm, and
the AMD (Angular Momentum Deficit) secular signal the 28.x math-lock
computes internally never reached a running binary. The fix adds a
**derived** alarm threshold:

```cpp
inline constexpr double kEnergyDriftAlarm = 1.0e-2;  // 10× the widest locked bounded-drift band (1e-3)
```

— one decade above the widest locked bounded-drift envelope across every
shipped tier (two-body WH < 1e-6, perturbed multi-body < 1e-4, the hybrid
reference envelope 1e-6). A genuinely bounded symplectic run never approaches
1e-2; the M0.5 frozen-Sun bug that published a phantom `1.578e-2` structural
collapse would have tripped it immediately. `active_amd()` mirrors the test
oracle's Laskar-Petit form op-for-op and is write-only with respect to
propagated state — it reads `pos`/`vel`, writes a telemetry field, and
never feeds the integrator, so the determinism invariants hold. Both
fields land on the existing `t=`/`dE/E=`/`regime=` telemetry line,
appended after the locked triplet so UAT greps against the old format
keep matching:

```
[telemetry] t=1.234500e+04 dE/E=-1.250e-12 regime=ENCOUNTER amd=6.500000e+30 body0_E=...
```

**A matched pair of silent-degrade findings** — the `PhysicsWorker`
constructor clamped an out-of-band `time_scale_init` through
`sanitize_time_scale` with no log, while the runtime setter
`set_time_scale` rejected the same condition loudly; the fix brings the
ctor to log parity on the setter's own throttle keys without changing
the clamp behavior. The matching short-read case: `latest_snapshot(out&)`
degrading to a copy smaller than the live body count was silent in Release; the
fix adds a throttled warn at the worker's degrade site and, on the consumer
side, has `orbit_demo.cpp` capture the previously-discarded return count
and warn when the render buffer saturates below `body_capacity()`.

## 34.3 — source hardening

**Thread-safety on test-observation globals** — makes `kepler_step`'s
test-observation globals `thread_local` (they were plain statics with a
comment claiming the function was "pure") and corrects the comment.

**A silent NaN path at the worker boundary** — `kepler_step`'s `k = mu` argument hits a half-guard,
`k_eff = (k > 0) ? k : 0`, so a non-positive or non-finite dominant `mu_dom`
silently drives `1 / det_sqrt(0) = +Inf` into a NaN trajectory with no alarm.
`kepler_step` stays `noexcept` — the fix, per the user's 2026-06-24
disposition, is a loud reject at the caller boundary instead:

```cpp
if (!(sel.mu_dom > 0.0) || !std::isfinite(sel.mu_dom)) {
    throw std::invalid_argument(msg);  // PhysicsWorker ctor, S-33
}
```

mirroring the existing WH-safety ctor-validation pattern established
elsewhere. A new `test_kepler_k_boundary.cpp` pins both halves: valid
`k > 0` stays byte-identical (A/B determinism + a finite two-body
advance), and `k <= 0`/non-finite at the worker boundary throws.

**A per-step heap allocation in the detector's timescale arm** — the
dominant-timescale arm inside `detect_regime_predictive` heap-allocated a
fresh `std::vector<Vec3f64>(n)` every step. The fix hoists
it to a caller-owned `std::span<Vec3f64> pos_scratch` — the same idiom Phase
30 established for `wh_step`'s `helio_scratch` — with the worker reserving
`detector_pos_scratch_` once at `body_capacity()`. An undersized span degrades
safely (the timescale arm skips that step, warned; the pair gate still runs).
A no-scratch convenience overload keeps the ~19 existing test call sites
unchanged, byte-identical decision either form. The fix explicitly does
**not** co-hoist the sibling allocs in `detect_regime` (`:573`) and
`detect_regime_substepped` (`:637`) — those are different public functions
with locked signatures called from many test sites, so adding a scratch
parameter there would be the same kind of signature-break hazard already
seen once before. Both are logged as named micro-deferrals in the 34.6
ledger rather than silently dropped.

**Two undocumented `std::sqrt` calls in the detector** — two `std::sqrt`
calls in the detector regime path (`encounter_detector.cpp`'s eccentricity
arm and its `T_dyn` arm) contradicted the "+−×÷-only" claim on that
path; the periapsis root already routed through the canonical
`det_sqrt`. The fix converts both. `det_sqrt` is ULP-bounded
against `std::sqrt`, not bit-identical, so this is a value-changing numeric
path — the blocking checkpoint ran the full ctest suite plus every
M0.2–M0.5 math-lock (representative-point and property-based) after the swap:
434/434 green, zero golden shifted, no re-review triggered.

**The one sanctioned exception to the locked-kernel rule.**
`compute_accelerations` takes
`G` and `mu_central` as two same-typed positional `double`s — a transposed
call compiles clean and silently produces a wrong but finite trajectory.
The fix wraps both in explicit one-field strong types:

```cpp
struct GravConstant { double value; explicit constexpr GravConstant(double v) noexcept : value{v} {} };
struct CentralMu    { double value; explicit constexpr CentralMu(double v)    noexcept : value{v} {} };
```

with no implicit `double`→type conversion, so a transposed or unwrapped call
is now a compile error. Because a C++ definition's signature has to match its
declaration, this forces a 9-line edit to `engine/src/nbody_force.cpp` — the
locked force-kernel file — tripping the phase's automated "never touched"
check. The change was stopped and escalated rather than pushed through
silently. The edit is confined to the signature line and two unwrap locals
(`const double G = G_param.value;`); everything below is byte-identical.
Sign-off on the override was recorded 2026-06-25, after
verifying the full suite (436/436) and the math-lock/determinism subset
(118/118, including the bit-determinism cases) stayed green with zero
golden shifted. The determinism invariant — bit-reproducible
trajectories — holds; only the literal file-untouched form was
overridden, once, in writing.
34 call sites (the production worker plus 31 test translation units) picked up
the wrapper types.

## 34.4 — supply chain

Three lower-severity findings about how the build resolves its own
dependencies. The project runs two dependency schemes — vcpkg
manifest mode on the Windows CI lane, FetchContent on Fedora — that already
resolved Catch2 3.5.4 and EnTT 3.13.2 identically but had no documented link
between them; the fix adds a per-lane source-of-truth block to
`CMakeLists.txt` plus a comment in `vcpkg.json` tying its overrides to the
FetchContent `GIT_TAG` SHAs, so the two lanes can't silently diverge on a
future bump. Three GitHub Actions were pinned by mutable `@vN` tags
that can move to different code without warning; the fix SHA-pins
`actions/checkout`, `humbletim/install-vulkan-sdk`, and `lukka/run-vcpkg` to
immutable commits, with the version kept in a naming comment beside each SHA.
And Catch2's default RNG seeds its test shuffle from the clock, so an
order-dependent failure wouldn't reproduce between runs; the fix wires a
fixed `--rng-seed 20260624` into `catch_discover_tests`' `EXTRA_ARGS`,
alongside the existing `FE_TONEAREST` FP-rounding pin.

## 34.5 — contract narrowing

**A docstring overpromise** — `kepler_step`'s docstring claimed a
"full-domain" guarantee that didn't hold at the extreme: a subnormal or
near-denormal `r0` overflows `inv_r0` and the mean-motion seed to
Inf/NaN. The fix narrows the domain paragraph to exclude subnormal `r0`
(already physically unreachable — the smallest real orbital radius is
metres, nowhere near the binary64 denormal floor) and pins the boundary
as deterministic UB-free NaN-out, not a crash.

**An implicit slot-vs-property contract** — the test-particle partition
treats storage position as physics: slots `[0, n_active)` source force,
slots `[n_active, n)` are test particles that source none, for the
identical body if you moved it across the boundary. That was true but
implicit. The fix adds a kernel-level contract test asserting exactly
that — same mass, same position, force behavior determined by slot, not
by any body property — rather than the heavier alternative (a
role-as-slot enum touching `nbody_force.{hpp,cpp}` and risking the
locked-kernel partition golden) the user's disposition explicitly rejected.

## 34.6 — the ledger, and five honest deferrals

The closing sub-phase is documentation only — `git diff --stat -- engine/
tests/` is empty at both its commits. It re-defers five findings
that don't belong on the M0.5 physics lane, each with a structural blocker and
a named future home, not a vague "acceptable for scope":

| Gap | Blocker | Future home |
|---|---|---|
| Cross-family determinism, no arm64 witness | no arm64 CI runner exists | M1.x cross-platform/portability pass |
| M0.2 `to_render`/`to_camera_relative` under-tested | off-lane coordinate/render layer, no such milestone in flight | next render/coordinate milestone |
| `to_absolute` process-wide atomic log flags | same off-lane coordinate surface as the item above | next render/coordinate milestone |
| `HostBuffer` raw `void* mapped`, no unmap before free | no render/Vulkan milestone scheduled | next render milestone |
| CI SDK lag, `glslc REQUIRED` blocks headless build, dead `render_frame()`, device-pick nondeterminism | render/Vulkan not on the M0.6 path; the `glslc`/headless facet already tracked separately | next Vulkan-touching pass |

The ledger then cross-checks every commit hash
against `git log` before publishing the table, and listing the full
already-resolved M0.5 set (the 1 Critical + 15 High + doc-bundle items)
alongside the backlog so the ledger is provably exhaustive — no finding
unaccounted for.

## Where it is now (drift since 2026-06-24/25)

- **Phase 42 (M0.7, 2026-07-09):** the observability path from 34.2 moved
  again. `active_amd()`, `system_energy`, per-clump drift, and the alarm were
  originally computed inline on every `publish_snapshot()` call, inside the
  seqlock write window; a later fix hoisted them out of that window, and
  gated the recompute behind a `Config::observability_cadence`
  (default 1 — every publish, for test coherence; a production opt-in
  `kObservabilityCadence = 8` documented as a power-of-two derivation).
  Between refreshes the worker republishes `last_amd_secular_` /
  `last_rel_energy_error_` carry state, seeded from the ctor's t0 values so no
  carry ever precedes a refresh.
- **The `GravConstant`/`CentralMu` wrappers** are unchanged at the current
  HEAD — the strong types and the 9-line `nbody_force.cpp` unwrap are still
  the live signature every caller uses.
- **`det_sqrt` still owns both regime-path arms** converted in 34.3; no arm
  has reverted to `std::sqrt`.
- As of 2026-07-21, `test_kepler_k_boundary.cpp` and
  `test_wh_warp_scenario.cpp` are still the only committed tests
  exercising, respectively, the WH worker-boundary reject and the shipped EMB
  warp config end-to-end — nothing since has replaced or weakened either.
