# M0.7 Phase 42 — M0.6 Backlog Reconciliation: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on
> 2026-07-09**; the drift section traces `publish_snapshot` and
> `jump_drift` through today's stack.

## Starting point

M0.6's review pass closed with six residual findings that its closing
fixes hadn't folded into the M0.6 release: two Mediums and four Lows.
Debt closes in its own dedicated phase rather than riding a feature
closer, and no residual gets silently dropped — every one either
closes on a real commit or gets re-deferred against a named structural
blocker. Phase 42 is that phase, and it runs after Phase 41 (the
nested HJS map fully wired into the production worker, the M0.6 EMB
scaffolding worker removed), so the residuals are reconciled against
the shipped nested-WH state, not the M0.6 snapshot where they were
first logged.

All six residuals were dispositioned on 2026-07-06: five CLOSE, one NO
ACTION. The seqlock-writer finding (the only residual with a real perf
shape) got its own pass; the four trivial findings were bundled into
one per-finding-commit pass; a third pass wrote the reconciliation
ledger.

## The seqlock writer had an O(N²) passenger

`system_energy` (O(N²) potential scan), `active_amd` (O(N)·transcendental —
per-body Kepler-element extraction through `libm` `sqrt`/`cos`), and
`log_energy_drift_alarm` ran **inside** `publish_snapshot`'s `publish_with`
fill lambda — the seqlock's odd-generation write window. Any render or test
reader spinning on the seqlock stalled on that O(N²) work on every publish,
and the cost was only going to compound as the per-step O(N²) surface grew
into the dynamic-body milestone.

**The hoist.** All three calls read `states_`/`body_props_`/
`n_active_`/`dom_slot_` — never the page — so nothing stops them from running
before `publish_with` instead of inside it:

```cpp
const double energy = system_energy(
    src.first(n_active_),
    BodyTable{std::span<const BodyProps>{body_props_}.first(n_active_)},
    mu_central_);
const double rel_energy_error = (initial_energy_ != 0.0)
    ? (energy - initial_energy_) / std::fabs(initial_energy_)
    : 0.0;
const double amd = active_amd(
    src.first(n_active_),
    BodyTable{std::span<const BodyProps>{body_props_}.first(n_active_)},
    dom_slot_);
log_energy_drift_alarm(rel_energy_error, sim_time);

publish_with([this, warp_active, active, src, rel_energy_error, amd, sim_time](Page& page) {
    // ... fill lambda now only assigns rel_energy_error / amd into the page
```

Same inputs, same arithmetic, same relative order (energy → ratio → AMD →
alarm), same single writer thread — only earlier relative to the odd marker.
`sim_clock_.sim_time()` is read once into a local and reused by both the
alarm and the page, since the clock can't advance between the hoist and the
fill. `publish_with` itself — fences, generation stores, page rotation — is
untouched. This makes the commit provably bit-identical: every
`[math-lock]` exact-`==` pin (`sysenergy_n5_oracle_pin`,
`sysenergy_n1_byte_identity`) stays green because nothing about the
computation changed, only where it runs.

**The cadence.** The hoist alone still recomputes on every
publish. `Config::observability_cadence` (default `1`) throttles the refresh
to every Nth publish:

```cpp
std::size_t observability_cadence{1};
```

```cpp
const bool refresh = (publish_seq_ % config_.observability_cadence) == 0;
```

On refresh, energy/AMD/per-clump drift recompute into worker-thread-only
caches (`last_rel_energy_error_`, `last_amd_secular_`,
`last_clump_rel_energy_error_` — no atomics; single writer under the parked
threading contract) and the alarm fires on the fresh ratio. On skip, the
cached values re-publish and the alarm does **not** re-fire, which keeps
the existing "logged magnitude == published magnitude" pairing exact.
`publish_seq_`
increments after the modulo check, so sequence 0 — the first publish —
always refreshes. The ctor rejects `observability_cadence == 0` with
`std::invalid_argument` (a `0` would never refresh, which is a
modulo-by-zero-shaped config error).

Default `1` is not a placeholder — it's required. `test_system_energy_
coherence.cpp`'s exact-`==` pins recompute the oracle energy from each
published page's own states, so any test that leaves the cadence above 1
would desync the page from the oracle by construction. Production opts into
`kObservabilityCadence = 8` in `main.cpp`, derived rather than picked:

- power of two, for a clean modulo;
- at the slowest plausible publish rate (~60 Hz, frame-locked), one cadence
  period at N=8 is ~8/60 ≈ 0.13 s — HUD staleness and alarm-detection latency
  stay far below the structural-collapse timescales the alarm exists for
  (the M0.5 phantom `1.578e-2`/yr drift class, which persists across many
  publishes, not one);
- 8 is the smallest power of two that meaningfully cuts the per-publish O(N²)
  cost while keeping that latency imperceptible — 2 or 4 barely help, 16+
  start pushing staleness toward visible HUD lag with no further
  structural-safety benefit.

This was originally scoped for two production workers (`worker_config` +
`emb_worker_config`); Phase 41 had already removed the M0.6 EMB WH
warp-seat scaffolding worker (the live HJS warp tier supersedes it), so
the opt-in landed on the one worker that remains — a scope correction,
not a change in what shipped.

The per-clump internal-energy drift (added by Phase 41's own snapshot
work) wasn't accounted for once the global energy moved outside the
write window. It was kept on the same cadence and hoisted too, rather
than leaving one telemetry field per-publish inside the window while its
siblings throttle — a single coherent staleness bound for the whole
observability line instead of two.

Three new cases in `test_observability_cadence.cpp` pin the semantics: ctor
rejects cadence 0; at N=3, sequence 0 and 3 refresh against the
per-snapshot oracle while sequence 1 and 2 carry bit-equal values with
`sim_time` still strictly advancing; at the N=1 default, every tick
refreshes. Release 536/536, Debug 532/532 (both +3 tests +1 ctest alias);
TSan seqlock/snapshot contention green; diff on `nbody_force.cpp`
empty; no new worker-TU `libm` symbol.

## The trivial bundle

Four residuals, one plan, one commit per finding — none of them touch
production numeric output.

**The undocumented-ctor-complexity finding (doc-only).** The
`PhysicsWorker` constructor runs four
O(N)-or-worse scans exactly once: `wh_perturbation_eligible` (a per-body
j-scan, WH-request path only), `initial_energy_ = system_energy` (O(N²)),
the seed-page `active_amd` (O(N)·transcendental), and `select_dominant`
(O(N)). The finding was that this complexity was undocumented. The fix adds
one comment block naming all four scans, stating the ctor-static invariant
— they run once, the body table is immutable mid-run, so this
cost never compounds with the per-step O(N²) surface — and naming the
dynamic-body milestone as the owner of re-amortizing them once bodies can be
added or removed mid-run. Code is otherwise unchanged.

**The dead-branch finding.** `jump_drift`'s dominant-mass reconstruction had
a dead branch:

```cpp
const double m0 = (G != 0.0) ? (mu_dom / G) : props.mass(dom);
```

Every caller passes `physics::G`, so the `else` arm never ran. The
survivor arm has to stay `mu_dom / G` rather than reading the mass slot
directly: the fixtures seed mass `1.0e30` with `mu = kMuSun`, so
`mu_dom / G ≈ 1.988e30` — reading `props.mass(dom)` instead would move
every multi-body determinism golden by roughly 2×. The fix keeps the survivor
expression and replaces the dead arm with an assert:

```cpp
assert(G != 0.0 && "jump_drift: G must be nonzero (every caller passes physics::G)");
const double m0 = mu_dom / G;
```

The assert compiles out under `NDEBUG`, so Release codegen is byte-identical
to before — no new `libm` call, no behavior change, only a removed
branch that could never execute. The NaN-conservative `!(m0 > 0.0)`
early-return stays as the Release-path defense.

**The alias-assert residue finding.** The alias-assert *code* half of this
finding was already closed by an M0.6 gate fix — the
`wh_step` aliasing guard had been un-gated from `INTERSTELLAR_TESTING` to a
plain Debug assert. What was left: a stale header comment that still
described the guard as testing-only-compiled (fixed to cite the commit that
closed it); the
`select_dominant` n==0 sentinel (`mu_dom = 0.0`) documented at its producer,
where the worker's `!(sel.mu_dom > 0.0)` reject is what refuses it
before `kepler_step` sees `k=0`; and a new `active_table()` helper on the
worker that factors the seven `n_active_`-bounded `BodyTable{span.first(n)}`
views that had been hand-repeated at each call site. The active-bounded
`wh_step` dispatch and the `states_.size()`-bounded accel callback keep their
own spans deliberately — the `active` vs `n_active_` distinction is real
(test particles ride the WH step and render but are excluded from
eligibility/energy/detector spans), so those two sites were left alone
rather than folded into the helper.

**The undocumented-tolerance finding.** Two tolerances — `kEnergyDriftAlarm = 1e-2` and the
Kepler-convergence residual `1e-6` — had no documented derivation basis.
Both get a margin-derived note at their definition site (the values
themselves are unchanged: `kEnergyDriftAlarm` sits one decade above the
widest locked bounded-drift band, `1e-6` sits roughly nine decades above the
converged Kepler residual and six below the broken-domain one). The finding
also asked for moving-COM coverage: every existing `wh_step` fixture ran
with the system center of mass at rest. The additive test applies a common
bulk velocity boost to a 3-body kick fixture so `v_com ≠ 0` and the
non-dominant momentum sum is nonzero (exercising the jump-drift dom-skip
path), then asserts one `wh_step` moves the system COM by exactly
`v_com * dt` — free-particle COM translation. Measured residual: x=0, y=0,
z=0.11 ULP at COM scale ~2.39e9 m, pinned with the file's existing
`axis_recovered` 4-ULP precedent rather than bit-`==` (the
democratic-heliocentric dom-slot rebuild is a mass-weighted sum/divide, not
a pure copy). Non-vacuity was verified empirically, not assumed: temporarily
flipping the COM-restore sign in `physics_integrator_wh.cpp` blew the
residual to ~3e15 ULP before the file was restored exactly from `HEAD`.

The remaining residual (the wall-clock→step-count coupling / `det_sqrt`
determinism swap) took **no action** — it's recorded as accepted design
in the ledger, not touched by this plan.

Release 537/537, Debug 533/533 (both +1, the moving-COM case); the
determinism goldens byte-green in both configs across all four commits; the WH
translation unit's `libm` baseline is unchanged (`kepler_step`, `det_sqrt`
in Release; Debug adds only the assert-failure handler, not a math symbol).

## The ledger

A single docs-only commit established the audit trail Phase 43's review
reads: six rows, each tracing its residual to the commit that closed it
or to the original finding it disposed of — no bare "done." **5 closed**,
**1 no-action**, **0 re-deferred**. Every cited pointer was independently
re-verified against `git log` while writing the ledger, not copy-pasted
from the sub-plan summaries.

The ledger also carries a note-only row, explicitly excluded from the
5/1/0 accounting: Phase 41's research turned up that the M0.3-era
"geocentric Moon" HORIZONS reference block
(`tests/data/horizons_earth_moon_j2000.hpp`) had been fetched with the
ambiguous `CENTER='399'`, which HORIZONS resolves to the Kushiro
observatory site rather than Earth's body center — a ~6,362 km position
offset and ~0.34 km/s velocity offset from the true geocenter. Zero
committed test integrates against that block today, so it's a
fix-on-touch candidate, logged as its own debt-ledger item rather than
fixed here (out of this phase's scope, which is the six named
residuals).

Phase-42 exit gate: Release 537/537, Debug 533/533, both configs;
a `git log`/`git diff` check against `engine/src/nbody_force.cpp` across
every phase-42 commit comes back empty — the locked force kernel
provably untouched.

## Where it is now (drift since 2026-07-09)

None of the four surfaces have moved. `Config::observability_cadence`
still defaults to `1` and `main.cpp` still opts the production worker into
`kObservabilityCadence = 8` with the same power-of-two derivation comment.
`jump_drift`'s `assert(G != 0.0)` and `m0 = mu_dom / G` are unchanged, and
`active_table()` is still the shared accessor for the seven
`n_active_`-bounded views.

The one place a later phase touches this surface is additive, not a
rewrite: M1.1 Phase 51 added a craft flight block to the published page
(present flag, wet mass, fuel, throttle, burn-active, attitude quaternion),
and its comment is explicit that this block is filled **unconditionally**
on every publish, never behind the cadence gate — craft state is O(1) to
copy, and a stale `burn-active` flag would lag the HUD by up to
`observability_cadence` publishes, which the craft telemetry can't afford.
The reconciliation ledger itself hasn't been touched since the single
commit that created it.
