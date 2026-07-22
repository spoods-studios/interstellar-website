# M0.6 Phase 32 — Live Seed Flip + Time-Warp Tier Documentation: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-24**; the
> drift section traces `engine/src/main.cpp` and the Time Warp tier table
> through today's stack.

## Starting point

Phase 30 hoisted the Wisdom-Holman (WH) step to a zero-allocation path; Phase
31 wired the perturbation-ratio gate (`η = |Σa_ij|²/dominant²`, pure
`+−×÷`) into the `PhysicsWorker` constructor. Both landed with Yoshida4 still
the live seed. Phase 31's calibration run against the shipped
Sun/Earth/Moon/Mars/Jupiter table found it fails that gate: the Earth-Moon
pair gives η²≈0.16, three orders above `kPerturbationRatioSqMax` (1e-4).
Heliocentric WH treats every non-dominant body as a small perturbation on a
Kepler orbit about the Sun — the Moon's pull on Earth isn't small, so the
premise breaks and the gate correctly rejects it.

The finding recorded 2026-06-24 ("Heliocentric WH is invalid for
bound satellites") narrowed M0.6's scope to the heliocentric-valid regime and
split hierarchical WH for bound satellites into a new M0.7. Phase 32's
mandate: ship WH on a config where it's valid, without touching the
5-body default that still needs Yoshida4/IAS15 fidelity for the Moon.

## ADD-ALONGSIDE, not replace

This phase adds a second `PhysicsWorker` to `main.cpp`, constructed on a
Sun/EMB/Mars/Jupiter barycentric table — EMB (Earth-Moon Barycenter) is one
body at Earth's heliocentric position carrying mass `M_EARTH + M_MOON` (the
Moon's offset from that position is negligible for η at AU scale). The
assembly mirrors `test_wh_energy.cpp:601-612` verbatim — same four
`BodyProps`, same four `State` values, reused from the existing
`sun_state`/`earth_state`/`mars_state`/`jupiter_state` locals with no new IC
literals:

```cpp
std::vector<interstellar::physics::BodyProps> emb_body_props{
    {.id = 0, .mass = M_SUN,            .mu = MU_SUN,                  .gravitating = true},
    {.id = 1, .mass = M_EARTH + M_MOON, .mu = 0.0,                     .gravitating = true},  // EMB
    {.id = 2, .mass = M_MARS,           .mu = MU_MARS_SYSTEM_DE440,    .gravitating = true},
    {.id = 3, .mass = M_JUPITER,        .mu = MU_JUPITER_SYSTEM_DE440, .gravitating = true},
};
```

`.method = Wh{}`, `.step_dt = 1.0e5` (the Brouwer-validated warp step size
from M0.5, ~0.3% of a 1-year period), `.mu_central = 0.0` (pure mutual i<j
force).
The existing 5-body `worker_config` above it is untouched — `.method` stays
`Yoshida4{}`, `step_dt` stays `300.0`.

This table is star-dominated (mass ratio ≫ `kDominantMassRatio` 100.0) and
perturbation-eligible (η²≈1.4156e-8, pinned by `test_wh_energy.cpp`, far
below the 1e-4 threshold), so the perturbation-ratio ctor gate keeps
`Wh{}` instead of downgrading it. `PhysicsWorker::selected_method_index()`
exposes
`method_.index()` on the ctor's `std::variant<Leapfrog, Yoshida4, Wh>` —
indices 0/1/2 — so a genuinely-selected WH worker reads `2`.

## Proving WH runs

Shipping a request for `Wh{}` isn't the same as WH running: the
eligibility gate could silently downgrade it and nothing downstream would
notice. This phase adds an NDEBUG-stripped
`assert(emb_worker.selected_method_index() == 2)` directly after
construction. The canonical, test-runnable proof is a new `[s51]`
`TEST_CASE` in `test_wh_eligibility.cpp` ("s51 worker: WH-valid EMB
barycentric warp config selects WH (index 2) - the shipped path", ctest
#299) that builds the identical EMB assembly and asserts
`REQUIRE(worker.selected_method_index() == 2)`.

The file already had a generic 2-body `==2` pin (#298) proving the gate
*logic* works, and a bound-Moon `==1` pin (#301) proving the 5-body seed
still downgrades correctly. Neither proved WH runs on the exact table
`main.cpp` ships — #299 closes that gap. All three routing pins passed
together in the `s51` subset (9/9), confirming the dual guarantee: WH ships
and runs on the EMB config while the 5-body default is unchanged.

## What stayed untouched

`git diff --stat engine/src/nbody_force.cpp` was empty before and after —
the locked force kernel never enters the picture; this is a
`PhysicsWorker::Config` assembly change, nothing more. The EMB worker is
declared after the 5-body worker (so RAII teardown order matches existing
convention) and is not wired into `OrbitDemo`, the render loop, or any
warp-toggle path — `(void)emb_worker;` silences the NDEBUG unused-variable
warning on the otherwise-unconsumed object. The plan's own framing: this is
scaffolding for M0.7, which will consume a warp-exit state from a config
shaped like this one. Nothing in M0.6 reads it, and there is no
Moon-reattachment logic anywhere in the change.

Full-suite validation: Release 417/417, Debug 414/414 (the 3-test delta is
existing NDEBUG-gated Release-only cases, not new). `wh-energy` 3/3 (WH-02/
WH-03 Brouwer energy locks) and `wh-handoff` 3/3 (both switch directions)
green. The repo carries no separate `build-tsan` configure lane; the
TSan-instrumented cases run inside the main Debug/Release suites and stayed
green — this change touches only a Config-assembly site and an additive
test, neither of which introduces new concurrency surface.

## Seating WH in the time-warp tier documentation

This phase also edits the project's Time Warp tier table, which previously
jumped straight from Yoshida4 (Tier 2) to Yoshida6 + analytical Kepler
(Tier 3) with no mention of WH at all. The edit adds a row labeled `2→3`
— deliberately not a new integer tier, so the existing four-tier count
and its internal cross-references stay intact — plus a paragraph naming
the gap directly:

> Between the fine-step Yoshida 4th-order regime (Tier 2, interplanetary
> coasts) and the extreme analytical-Kepler tier (Tier 3 / §4.4.2) sits the
> symplectic large-step lever: Wisdom-Holman (WH) ... WH is the long-horizon
> warp lever, not a small-step speedup.

That last clause is load-bearing prose, not a hedge. Phase 27's benchmark
had already shown WH loses to Yoshida4 at the shipped small-step
config — its win is bounded-energy behavior under a *large* sustained step,
not raw speed. The paragraph also names WH's real eligibility condition
(the perturbation-ratio gate, heliocentrically-dominated tables only) and
the correct exclusion of bound satellites like the Moon, deferring
hierarchical WH to a later milestone rather than overstating current
coverage.

## Key decisions

- **ADD-ALONGSIDE over replace** (decided 2026-06-24): shipping WH is
  satisfied by a second worker on a valid config, not by forcing WH onto a
  table it fails on.
- **Reuse the exact validated assembly** — the EMB props/states/step come
  verbatim from `test_wh_energy.cpp`, so the shipped worker inherits an
  already-locked Brouwer energy bound instead of an unvalidated new
  configuration.
- **Two independent runtime proofs** (assert + test pin) that WH is
  genuinely selected, not gate-downgraded to a silent no-op — this
  phase's own threat-modeling pass had already named exactly that
  spoofing risk.
- **Tier-table edit confined to the existing four tiers, no invented tier
  names** — the `2→3` label and the naming paragraph work within the
  existing four-tier framing rather than renumbering around WH.

## Deviations

None from the plan. The one implementation-detail note: `main.cpp` writes
the EMB combined mass fully-qualified as
`interstellar::physics::M_EARTH + interstellar::physics::M_MOON` to match
the file's existing fully-qualified `body_props` idiom, while the test file
uses the bare `M_EARTH + M_MOON` form via its `using` declarations — both
express the same EMB assembly.

## Where it is now (drift since 2026-06-24)

- **The project's design documentation moved out of the engine repo**
  (2026-06-29, "scope-split + extract studio/game content") into the
  studio repo, where the devlog itself now lives.
- **The WH tier row was amended twice after the move.** One edit seated
  the Hierarchical Jacobi Symplectic (HJS) nested tier alongside the
  flat-WH row (M0.7); a later edit realigned the WH row's framing to a
  scope ruling. The current text reads WH as "available, gate-selected,
  validated, and monitored," noting that "as of M0.7 the shipped demo's live
  warp worker is the HJS nested tier, with flat WH remaining the routing
  target for flat heliocentrically-dominated seeds."
- **The EMB scaffolding worker itself is gone from `main.cpp`.** Phase 41
  (2026-07-09, "run full nested seed as the rendered worker + camera
  keybinds") replaced the live rendered worker with the full 9-body
  nested seed (Sun / Earth-Moon / Jupiter + four Galileans / Mars), routing
  to the HJS nested map at warp via a declared hierarchy; the flown tier
  stays Yoshida4 @ 300 s. The change is explicit about removing the
  superseded M0.6 EMB WH warp-seat scaffolding once the live HJS tier
  replaced it.
- **What didn't move: the perturbation-ratio gate itself.** The
  eligibility primitive this phase proved a runtime path for is the same
  primitive M0.7's HJS eligibility check builds on — `test_wh_eligibility.cpp`
  and its EMB `==2` pin remain live math-lock infrastructure, not superseded
  scaffolding.
