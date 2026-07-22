# M0.5 Phase 29 — Findings + Fixes: Technical Deep-Dive

> Retroactive technical devlog. **Closing phase of M0.5 Gravity
> Performance.** A review pass ran 2026-06-15 on the
> post-Phase-28 tree; a re-coverage pass plus dispositions landed 2026-06-16;
> fix phases landed 2026-06-16; the gate closed the same day; a
> post-gate MSVC-portability fix landed 2026-06-20; merged 2026-06-20.

## The review pass

A review pass ran 2026-06-15 against the post-Phase-28 tree. Five cells
covering the physics surface had drifted onto the M0.2 coordinate/Vulkan
layer instead, weakening coverage of the core physics — so a re-coverage
pass re-ran those five (anti-drift instructions) on 2026-06-16: 15
corroborations plus 4 new findings, no new Critical.

## What it found

**1 Critical, 15 High, 27 Medium, 9 Low — 52 findings total.** Agreement
across review cells landed on 11 items; the Critical was reproduced and
verified before disposition.

- **The WH silent-NaN bug [Critical]** — the WH integration arm in
  `run_due_steps` published `wh_step` output with **no finiteness check**,
  unlike the Leapfrog/Yoshida/IAS15 arms (the existing hard-stop contract
  every other integrator path already honored). A coincident non-dominant
  pair drives `1/inv_r3 = 1/0 = +Inf`, NaN-poisoning every body through COM
  reconstruction — published silently as `regime=REGULAR`, `dE/E=nan`, no
  alarm. Rebuilt and reproduced from HEAD with a throwaway repro: `wh_step
  threw=0`, all three bodies `finite=0`.
- **A related High** — two non-dominant bodies at identical positions made
  the predictive detector's periapsis arm return `q=NaN` and `t*=NaN`;
  every NaN-conservative gate fell through to REGULAR, routing the pair
  straight into the WH silent-NaN detonation above.
- **Two new Highs from the re-coverage pass** — `predicted_periapsis`/
  `predicted_apoapsis`'s `h² = r²v² − (r·v)²` Lagrange identity loses digits
  to catastrophic cancellation for near-radial pairs (worst relative error
  ~1e4 vs a long-double oracle); separately, the predictive `Config` knobs
  (`pred_k`/`pred_pad`/`pred_horizon_n`/`pred_n_min`) had no ctor
  validation — a NaN knob silently suppresses all switch-IN, routing close
  encounters back into the same silent-NaN path.
- **Another High** — `to_democratic_heliocentric`/`from_democratic_heliocentric`/
  `wh_step` read `states[dom]`/write `helio[i]` with zero bounds
  enforcement; an undersized span or out-of-range `dom` is a silent
  heap-buffer overflow in Release (ASan-confirmed).

The remaining Highs: hand-copied `det_sqrt` in three translation units with
divergent iteration budgets — bit-identical today, but with no shared ULP
lock an edit to one silently voids cross-site bit-identity; the locked
fixed-`N=8` Laguerre-Conway Kepler corrector has no convergence/residual
check by design — for e≥0.99 large steps or many revolutions per step, 8
iterations don't converge and a finite, physically-wrong state returns with
no signal (quantified at e=0.5, 12 rev/step: |dE/E| = 3.97); `assert_*_i64`
computed the overflow-checked result for the debug assert but **returned
the raw `a OP b`** — signed-overflow UB once `NDEBUG` strips the assert
(first flagged as a hypothesis at synthesis, later confirmed real in
Release via UBSan); and, found independently by multiple review cells, the
force kernel/encounter detector/`system_energy` are all O(N²) on actives —
fine at N=5, wrong complexity class for the roadmap's M1.0 (N≈100k) scope,
and the deferral hadn't been recorded with a named blocker. The remaining
test-adequacy findings: no property-based suite for `kepler_step`/`wh_step`,
no negative-control fixture, no energy/COM/L continuity assertion across
the WH↔IAS15 handoff, and a one-sided predictive-trigger horizon gate.

**Shipped-relevance lens:** Yoshida4, not WH, seeds the default binary
(`main.cpp:146-147`), so the WH-path findings don't corrupt today's shipped
trajectory by the strict rubric. Weaknesses compound, though, so the
WH-safety class was fixed now anyway: WH is the milestone's headline
deliverable, one line from shipping, and the explicit time-warp lever for
M0.6+.

## The fixes

The disposition (2026-06-16) was **fix all now** before gate close, with
the O(N²)-scaling finding the sole defer-with-named-phase.

### WH safety

Debug 389/389, Release 392/392, TSan 3/3, `nbody_force.cpp` byte-unchanged.
One fix adds a finiteness guard immediately after `wh_step` so the
existing catch/hard-stop surfaces a triageable `runtime_error` naming the
first non-finite slot. Another adds a zero-separation guard to the
predictive pair loop, returning ENCOUNTER before the bound/horizon gates.
A third replaces the Lagrange identity with a fixed-order cross
product (`h = r×v; h² = h·h`) — sign-flip safe under `v→−v`; the
periapsis/apoapsis re-lock left all 443k lock assertions byte-green, no
golden changed. A fourth adds ctor validation for the predictive
knobs with a rejection-matrix test. A fifth adds debug-assert
preconditions on the WH frame transforms plus a Release no-op degrade.
Two findings in this cluster took a different disposition: an assert that
`mu_dom == G·mass(dom)` was **disputed** — the engine uses CODATA-precise
GM values that differ from `G·M` by ~1e-4 by design, and the WH map never
consumes `mass(dom)` for the dominant term. Per-step `wh_step` heap
allocation was **deferred**: dormant while Yoshida4 ships; fixing it needs
a locked-signature change — named home the M0.6 pre-WH perf cluster,
alongside the O(N²)-scaling item.

### det_math consolidation

Debug 394/394, Release 397/397, TSan 3/3, 680k+ lock assertions unchanged.
Single canonical `det_math.hpp`/`.cpp`: kepler and WH call `det_sqrt`
directly, the encounter-detector peri site delegates to it; a new
`test_det_sqrt.cpp` adds the ULP+anchor+specials lock the copies never
had. `det_stumpff`'s raw `double[4]` output buffer became a typed
`std::array<double,4>&` — behavior byte-identical.

### Kepler convergence

Debug 396/396, Release 399/399, TSan 3/3, N-raise byte-identical for
converged inputs. `kKeplerIterations` raised 8→12 against a dense (e,
dt/T, rev/step) grid. A production `kepler_consume_worst_residual()`
surfaces the per-step convergence residual with a throttled worker log
past 1e-6. An N−2 convergence-margin test pins seed quality across
the (e × sub-period dt) grid. The finding that WH eligibility is gated by
mass ratio, not perturbation size, folded into the doc-bundle as a
**deferred** design note, re-add-triggered when WH ships as the default
warp integrator.

### int64 overflow + coordinate hardening

Debug 397/397, Release 400/400, TSan 3/3, UBSan-clean. `assert_*_i64` now
returns the builtin-wrapped defined result instead of the raw UB'd
`a OP b` — byte-identical for every valid input (upgraded from
hypothesis to confirmed). One shared
`int64_range_bound` (largest double below 2^63, derived from `INT64_MAX`)
replaces the magic `9.22e18` ceiling. Inclination/RAAN extraction
now clamp their `acos` argument to `[-1,1]`, matching the existing
omega/nu clamps.

A post-gate follow-up (2026-06-20) made the overflow detectors
MSVC-portable: moving `__builtin_{add,sub,mul}_overflow` out of an
`assert()` meant MSVC's Windows CI lane hit `C3861` on the GCC/Clang-only
builtins. Per the same day's decision record, this did **not**
re-trigger the gate — the GCC path is provably byte-identical
(`#ifdef`-guarded portable `#else`), so re-running the full adversarial
pass against a provably unchanged lane would be waste. A companion fix
made the same argument for `M_PI` → `std::numbers::pi` across three test
files.

### Test-strengthening, additive

Debug 401/401, Release 404/404, TSan 3/3, **zero source change** — purely
additive math-lock. A `kepler_step` property suite (~5000 PCG
samples: time-reversal round-trip + energy bound) closes the missing
property-based coverage. A wh-energy coarse-vs-fine discrimination control
proves the energy metric isn't vacuous. A worker-driven WH↔IAS15
changeover test asserts energy/momentum/angular-momentum continuity
(<1e-3) across the seam in both directions. A predictive-horizon knee
bracket proves the trigger is predictive, not reactive, from both sides.

### Doc-bundle + decision record

Comment-only, behavior byte-identical. WH's public docs corrected DKD→KDK
across four header mentions — the shipped composition had been KDK
since Phase 24, but the banner still described the old plan. "Danby
quartic" comments corrected to Laguerre-Conway; the Mikkola seed
docstring's "all e incl. hyperbolic" claim narrowed to elliptic-only, e
clamped ≤0.999. Three findings were formally **deferred** with
named blockers and re-add triggers: the O(N²) ceiling (→ M1.0 Barnes-Hut),
the IAS15 fallback cost cliff (→ benchmark-then-MERCURIUS), and the WH
mass-ratio eligibility gate (→ perturbation-ratio gate, M0.6). The stale
status-docs finding routed to the milestone close-out step.

The remaining Medium/Low findings that didn't ride a fix phase were
grouped into the non-blocking M0.6 cleanup backlog — test-adequacy,
observability, design-smell/API, supply-chain, and off-M0.5-lane
(M0.2/Vulkan) clusters, none with shipped-correctness impact.

## Why it was fixed this way

- **Fix the WH-safety class even though it's dormant.** Weaknesses
  compound, and WH is the explicit M0.6+ warp lever. Fixing the silent-NaN
  cluster now is cheaper than inheriting it as M0.6 starting debt.
- **A legal deferral needs a named blocker and a re-add trigger, not a
  scope excuse.** The O(N²) ceiling needs a spatial-partition structure
  with its own determinism contract — machinery genuinely not built; the
  IAS15 cost cliff and the WH eligibility gate each name a concrete
  benchmark/gate they're waiting on. Contrast the disputed `mu_dom`
  finding, whose premise (mass-ratio == GM/G) was wrong against the
  engine's CODATA-precise-GM design.
- **Re-coverage over trusting an incomplete first pass.** Five cells
  missing the physics surface entirely was a coverage gap, not a "no
  findings" result — re-running them surfaced two new Highs the original
  pass never saw.

## Close

Closed 2026-06-16, suite at Debug 401 / Release 404 / TSan 3 with
`nbody_force.cpp` byte-unchanged across every fix commit. The post-gate
portability fixes did not re-trigger the review (byte-identical GCC path).
Merged 2026-06-20.

## Where it is now (drift since 2026-06-16)

- **2026-06-17**: M0.6 was scoped as the narrow "WH Shipped" closer — flip
  WH on as the default REGULAR-tier integrator and close this gate's three
  named deferrals (WH eligibility, dormant heap allocation, IAS15 cost
  cliff).
- **2026-06-24**: M0.6 Phase 31 calibration found the shipped
  Sun/Earth/Moon/Mars/Jupiter seed **fails** the eligibility gate's own
  perturbation-ratio test for the Moon (η≈0.40) — heliocentric WH cannot
  model a bound satellite, confirming the exact mechanism that finding had
  predicted. M0.6 shipped WH on an Earth-Moon-barycenter config instead; a
  new M0.7 (Hierarchical Symplectic Integrator) was opened for satellites.
  The same day, the O(N²)-scaling finding was formalized into an
  architecture split — exact deterministic core forever plus best-effort
  approximate shells — Barnes-Hut re-add still targeted at M1.0.
- The same review-pass format, plus the machine-readable status header
  this gate introduced, held through M0.6, M0.7, and M0.8 (2026-07-13).
