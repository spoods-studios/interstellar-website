# M0.8 Phase 47 — Findings + Fixes: Technical Deep-Dive

> Retroactive technical devlog. **Closing phase of M0.8 Perturbation
> Refinements.** A review pass ran 2026-07-13; the resulting fixes and
> the milestone close landed the same day.

## The review pass

A review pass ran 2026-07-13 against the post-Phase-46.1 tree.

## What it found

**1 Critical, 8 High, 17 Medium, 12 Low.** The perturbation math itself
came back clean: the J2 kernel and the ST94 split were independently
re-derived and checked against a primary source, and determinism stayed
spotless — the locked kernel byte-identical, libm-free, zero findings on
either correctness pass. Every blocker that did land clusters at the
**contract seams** the perturbation work cut through, not the physics: what
the warp tier publishes, which convention the production force law uses
versus what the validation harness assumed, what a malformed config is
allowed to do, and whether any of it is visible at runtime.

### The Critical: warp peek ships pseudo-velocities as real ones

`warp_enter_session()` converts live orbital velocities to ST94 pseudo-
velocities on the way into the HJS warp tier; `warp_exit_session()`
converts them back on the way out. `warp_synchronize_peek()` — the call
that lets the render/telemetry side read state *without* leaving the warp
session — was never given the same treatment. It exported `vj_warp_`
straight through `hjs_warp_export`/`g2b`, and `publish_snapshot()` read the
result as real coordinates. In the shipped config (1PN on, HJS warp
active), every peek while warping published the pseudo-velocity, not the
true one — positions were unaffected, but velocity and any KE-derived
telemetry were wrong for the duration of the warp.

It was reproduced two different ways: a static reproducer built directly
against the export chain, and a live reproduction driven through the
production worker. Both measured the same gap — snapshot velocity equal
to the raw pseudo export, differing from the true export by
0.0028–0.0043 m/s, with energy computed from the pseudo values off by a
relative 1.6e-8. The same code path surfaced independently from two more
review passes — once flagged out-of-lane during a concurrency check, once
traced during a separate practitioner pass — before any fix work began.

## The other eight Highs

- **Production PN omits the back-reaction the validation harness
  assumes.** The shipped direct-force callback exempted the dominant body
  (the Sun) from the 1PN back-reaction; a DE441 validation harness added a
  momentum-conserving Sun reaction of its own and used it to validate the
  DE441 barycenter lock. The lock therefore validated a force law
  production didn't run — an independent probe found the production
  convention drifts the Sun-Earth barycenter ~657 m over 50 years that the
  harness convention doesn't.
- **Four config-validation gaps in the same family:** a
  `has_j2=true, mass=0` body passes construction and then NaNs the
  back-reaction; a PN-enabled config never checks whether the system has a
  clear dominant mass, so an equal-mass binary silently gets a Schwarzschild
  correction around a tie-broken slot; a short, non-empty `OblatenessTable`
  is assert-only, so Release quietly drops J2 sources or reads past the
  end of the span depending on the tier; and the public `PnParams{true,
  0.0}` constructor plus the raw-double `c2` primitives emit `Inf` with no
  guard.
- **Perturbation state is invisible in production telemetry.**
  Neither the `[telemetry]` line, `FrameMeta`/`SnapshotView`, the startup
  banner, nor any log reports whether J2 or 1PN is active, how many rows,
  which axis, or which body is dominant. A dropped enable or an empty table
  ships byte-identical-looking logs; the energy monitor is Newtonian-only
  and structurally can't catch a perturbation-side error.
- **The production HJS-warp seam with hierarchy + J2 + PN together
  was never under test.** No fixture built a `PhysicsWorker` with all
  three at once. A mutation test dropped the oblateness table (or the PN
  params) from the production warp call, and the focused M0.8 suite stayed
  green at 90/90 — the shipped warp force model was unlocked.
- **Reclassified High→Medium: `C_LIGHT` has no portable value
  pin.** A drifted `c` is only caught by the same-family byte goldens,
  which are skipped on MSVC/non-x86_64; every portable PN test cancels `c`
  through shared references, so a 2.7e-8 drift in the constant escapes all
  of them.
- **Reclassified High→Medium: the fixed-8 pseudo-velocity solve
  has no domain guard.** `pn_true_to_pseudo`'s fixed-iteration sweep only
  converges in the weak-field regime; past v≈0.5c it returns finite-but-
  wrong values (round-trip error 1.8e-4 at 0.5c, divergent by 0.7c). Every
  solar-system velocity sits deep inside the convergent domain, which is
  why this surface was otherwise rated clean — the finding is about a
  missing guard for inputs the shipped seed never produces, not a live bug.
- **Discussed at High, closed as Medium: the HJS warp tier and the flown
  tiers use different PN source-mass conventions.** Direct/WH use one
  global dominant μ; HJS uses per-orbit enclosed mass. On the shipped
  ladder the two diverge by up to 1.34e-3 (relative, at Neptune's orbit),
  and satellite edges (Earth-Moon, the Galileans) get a two-body PN term in
  HJS the flown tier doesn't carry at all. The gap was undocumented and the
  cross-tier consistency lock never covered the HJS arm.
- **Discussed at High, closed as Medium: the Mercury and WH test harnesses
  bypass the boundary they claim to lock.** `test_mercury_precession.cpp`
  and related suites call `wh_step` directly on true velocities, so the
  worker's actual true↔pseudo wrapping around that call was never
  math-locked by the headline Mercury-precession evidence.

## The fixes

All nine blockers were fixed in-milestone (2026-07-13), across six fix
rounds that folded in all 17 Mediums and the 12 Lows along the way.

### Convert-on-copy at the warp peek

A shared `export_warp_session(std::span<State> out,
bool convert_pn)` helper is extracted. When PN is enabled it copies
`vj_warp_` into a pre-reserved scratch buffer and runs `pn_pseudo_to_true`
per real orbit (k=2..N; the COM orbit at k=1 is exempt) using that orbit's
own `gm_k`, then exports from the copy — the live warp session is never
mutated, so integration resumes from it exactly as before (zero-alloc).
`warp_synchronize_peek()` now calls the helper with `convert_pn =
pn_params_.enabled`; PN disabled still takes the raw-export path,
byte-identical to before. The fix adds a regression: a 9-body
nested seed with PN enabled, driven into warp, pins `latest_snapshot().vel
== true export` and `!= raw pseudo export` for every convention-differing
body, with an anti-vacuity check that the two conventions differ by a
finite, sub-m/s amount. Reverting to the pre-fix `convert_pn=false`
fails the regression — published pseudo `9.3273640244` versus true
`9.3273639682` — a genuine fail-before/pass-after. `nbody_force.cpp` stays
byte-untouched. Release 645/645, Debug 641/641.

### PN contract alignment

A new `apply_pn_dominant_accelerations(states, props, dom,
mu_dom, c2, accel)` function is added to `pn_force.cpp` as the single
shipped-direct-tier 1PN definition: each non-dominant body i gets its usual
`pn_direct_accel` term, and the dominant body gets `−Σ_i a1_i·(m_i/m_dom)`
accumulated in a pinned ascending-i order (an extension of the same
determinism contract). The production worker callback and the DE441
validation harness both now call this one function — the harness's
separate reimplementation is deleted. The fix re-locks
`test_pn_worker_boundary` to assert the back-reaction is present (previously
it asserted the dominant body was exempt) and regenerates `test_pn_det`'s
`GOLDEN_DIRECT` from 6 to 9 doubles (the added Sun back-reaction row, the
Venus/Earth rows unchanged). The convention choice: production now
matches the harness, not the other way around.

For the source-mass convention gap, the HJS arm is added to the cross-tier
consistency lock and quantifies the flown↔warp handoff gap: on the shipped
14-body seed's eight Sun-anchored planetary orbits, enclosed-mass vs.
dominant-mass μ differs by at most 0.00134 (Neptune), now locked at 2e-3;
the five satellite orbits are a distinct local-mass PN class, asserted
present rather than folded into the same bound. The same fix corrects a
misattributed "Zeebe convention" citation in `hjs_map.cpp` (orbitN uses
solar GM, not enclosed mass). A follow-up commit documents the
two-convention contract: flown tiers keep one global dominant μ, HJS keeps
per-orbit enclosed mass, by design — a deliberate higher-fidelity warp
model, not a bug that needs unifying.

The constraint here was that relative dynamics must not move — a change
would signal a bug, not a fix. They didn't: Mercury precession held
at 42.98″/cy, DE441 SSB validation stayed green (now via the shared
helper), and the full perturbation on/off matrix stayed green.
`nbody_force.cpp` untouched; `pn_force.cpp.o` stayed libm-clean (verified
by `nm` symbol scan — only `det_sqrt`). Release 647/647, Debug 643/643.

### Config-validation hardening

One hardening pass closes the four config-validation gaps: the worker
config constructor now rejects a `has_j2=true` row without a finite,
positive mass/mu (`std::invalid_argument`), and rejects a PN-enabled
config whose table has no clear dominant body (`select_dominant().dominated`
must hold). `apply_j2_accelerations`, `oblateness_kick`, and the HJS
`interaction_kick_masked` Step-2b all gain a Release guard that skips a
short, non-empty `OblatenessTable` outright instead of partially applying
it or reading past the span — Debug keeps the original loud coverage
assert, so the assert/guard duality holds in both build modes. The six
noexcept PN kernel primitives gain a Debug assert on `c2 > 0`; the
production seam (the worker ctor) is throw-validated, and the kernels stay
noexcept rather than moving to a `detail` namespace, which would have been
disproportionate churn for the actual gap.

The same pass adds `pn_true_to_pseudo_checked` for the domain-guard gap:
it runs the existing fixed-8 solve, then a closed-form pseudo→true
round-trip, and flags `ok=false` past a `kPnRoundTripMaxUlp=64` ULP band (a
squared check, still libm-free). It's wired at `warp_enter_session` per
real orbit, with a hard stop through the worker's existing `catch(...)` if
a solve ever leaves the weak-field domain. The kernel itself is unchanged,
so PN-on trajectories stay byte-identical. The fix adds the regressions:
massless-J2 reject, undominated-PN reject, the short-table Release-only
skip path, and the domain flag (in-domain `ok` at Mercury perihelion,
`!ok` at v≈0.7c). `nbody_force.cpp` untouched; 163 broad Release cases plus
the full suite stayed green after the change — no valid config broke.
Release 651/651, Debug 647/647.

### Perturbation observability

A value-bearing startup line is added at the worker constructor:
`perturb j2=on j2_active=N/total j2_axis_hash=0x… pn=on pn_c2=…
pn_dom_slot=… pn_mu_dom=…` (or the Newtonian-point-mass line when both are
off). The hash is an FNV-1a fold over each J2 row's `j2`/`r_eq`/spin-axis
bits — a wrong-but-unit spin axis flips the hash, which is exactly the
class of silent error a prior finding named. `FrameMeta`/`SnapshotView`
gain three per-frame fields — `perturb_j2_active`, `perturb_pn_on`,
`perturb_pn_dom_slot` — computed once at construction and stamped at every
publish site; both structs stay trivially copyable, so the seqlock
static_assert still holds. The `[telemetry]` line gets an appended
`perturb=j2:N,pn:on/off,pndom:S` field after the clump data and before the
per-body trailers — append-only, so the locked `t=/dE/E=/regime=/method=`
prefix every existing UAT grep depends on is untouched. A follow-up commit
pins the new field in `test_telemetry_format`'s three shape cases plus a
new perturbations-on case, and adds a worker-construction diagnostic proving
the fingerprint reaches the snapshot end-to-end. Read-only diagnostic;
nothing here feeds back into the integrator. Release 653/653, Debug
649/649.

### Warp perturbation seam locks

Test-only fix round. `test_worker_warp_seam.cpp`
is the first fixture to build a `PhysicsWorker` with hierarchy, oblateness,
and PN all present at once and drive it into the warp tier. It runs an
anti-wiring check: J2-only, PN-only, both, and off, all driven to the same
warp point, must pairwise-differ. Mutating the production warp call to
drop the oblateness table now fails this test — the exact mutation an
earlier finding proved got through before. The same fixture also
re-asserts the warp-peek fix in context (published warp velocity equals the
true export, not the pseudo one) and exercises a shipped-config-equivalent
assembly helper that fails if any enable is dropped from the flip.

The on/off regression matrix gains the missing single-force cells — HJS
PN-only, direct J2-only, direct PN-only — so a live perturbation can no
longer mask a dead one; the HJS PN-only cell specifically locks the
map-step 1PN β-kick as load-bearing through the real production chain. The
"oblateness kick leaves the dominant body's velocity byte-unchanged" guard
test replaces its old 2e34 sentinel (33 orders of magnitude above the
actual ~1e-12 m/s spurious signal it was supposed to catch) with a
realistic ~12 m/s value; the guard-drop mutation now genuinely fails.

The test-harness-bypass finding needed no code change once traced: the WH
flown tier keeps `states_` in true velocities — the ST94 pseudo bracketing
lives *inside* `wh_step` per Kepler drift, not in a worker-level wrapper —
so a harness calling `wh_step(true, pn)` directly already exercises the
real production boundary. The honest scoping note in this phase: PN enters
the warp tier through two seams (the session true↔pseudo transforms and the
map-step β-kick), and the worker-level anti-wiring fixture catches an
oblateness drop or a full PN disable, but not the narrow case of dropping
only the map-step argument while leaving the session transforms in place —
that narrower seam is covered instead at the chain level by the
strengthened HJS PN-only cell in the on/off regression matrix. Release
656/656, Debug 652/652.

### Trivial bundle

One commit pins `C_LIGHT`/`C2_LIGHT` as portable `REQUIRE`s in
`test_constants.cpp` (the hex literal for `C2_LIGHT` verified against the
compiler's own `%a` output), rewords the constants-header comment — `c²`
needs about 57 bits, so the stored product is correctly-rounded, not
exact — swaps `M_PI` for `std::numbers::pi` in the three new J2 seed tests
(MSVC portability), and rewrites `apsidal_fit::lsq_slope` to the centered
normal-equation form (the raw form was losing digits to cancellation
against ~1e9-second time offsets). A follow-up corrects a stale `main.cpp`
comment claiming rows below it were placeholder-only when they'd been
active since the 46.1-06 flip, updates the startup banner to name
"perturbations ON: J2 + 1PN," flips several header comments from "Phase 46
scope" / "not wired into the live worker" to their landed state, and
documents the frozen-J2000 spin-axis validity horizon (sub-1e-5 relative
J2-force error over ≤50 years; a precessing model is deferred to a
century-scale J2 milestone). Another adds the five new M0.8
determinism-extension rows to the Determinism Contract registry, pins the
reproducibility-relevant Horizons fetch parameters on the four new
fixtures so a refetch can't silently inherit a changed API default, and
closes out the warp-handoff corrector's known gap — its B operator
omitting both J2 and 1PN — as an accepted, documented limitation,
correcting prior wording that had named only J2. The only behavioral
(non-doc, non-test) change in this bundle is the centered LSQ; every
precession lock stayed green against it. Release 656/656, Debug 652/652.

## Close

Closed 2026-07-13 — Release 656/656, Debug 652/652, math-lock 182 cases /
1,759,263 assertions, the locked kernel byte-identical, Mercury 42.98″/cy
held. A post-completion audit caught two loose ends before merge:
unused-result warnings on two residue-clear calls in the Phase 45-era
`test_29fb_kepler_convergence.cpp` (`(void)`-cast fixed same day) and an
`M_PI` MSVC-portability miss in `j2_secular.hpp` that the trivial bundle's
sweep hadn't reached — both test-only, zero production effect. Merged the
same day, the release tag moved forward from the archive commit to include
both post-tag fixes so the release compiles clean on the Windows/MSVC CI
lane. Phase 0 exits here: Patreon, Discord, devblog cadence, and
conference-submission obligations go live.
