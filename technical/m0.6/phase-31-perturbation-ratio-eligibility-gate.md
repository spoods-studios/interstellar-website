# M0.6 Phase 31 — Perturbation-Ratio Eligibility Gate: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-24**; the
> drift section traces `wh_perturbation_eligible` through today's stack.

## Starting point

M0.5 shipped Wisdom-Holman (WH) built, validated, and disabled — Yoshida4
stayed the production integrator because the honest benchmark found WH's
real lever is step size, not small-N speed. M0.6 Phase 30 made the WH step
zero-alloc; Phase 31 is the gate that decides when WH is even valid to
select. The existing ctor-time check, `kDominantMassRatio = 100.0`
(shipped in M0.5), asks one question: is a single body's mass enough to
call the table "star-dominated"? It says nothing about the *geometry* —
how close together the non-dominant bodies sit relative to each other. A
table can pass the mass-ratio gate (Sun ≫ every planet) and still contain
a pair whose mutual pull rivals what the "dominant" body exerts on either
of them. This phase adds a second, orthogonal gate for exactly that case.

## Why mass ratio alone misses it

Heliocentric WH splits the Hamiltonian as H = H_Kepler (each body drifts
around the dominant mass alone) + H_interaction (a kick from every other
body, treated as a perturbation). The split is only accurate when
H_interaction is small next to H_Kepler for every body. The Earth–Moon
pair breaks that: Earth's pull on the Moon is a sizeable fraction of the
Sun's pull on the Moon, because the Moon orbits Earth, not the Sun,
even though the whole system is Sun-dominated by mass. `kDominantMassRatio`
can't see this — it compares the dominant body's mass to the *next*
body's mass, not any pair's separation. Phase 31 adds
`wh_perturbation_eligible`, a per-body perturbation-ratio η measuring each
body's interaction acceleration against its dominant acceleration, ANDed
onto the existing mass gate — not a replacement, since
`kDominantMassRatio` is a math-locked quantity from M0.5 and stays
untouched.

## The η formulas, and a dimensional bug caught before calibration

η² is a ratio of squared accelerations, computed per non-dominant body i:

```
a_dom,i²  = mu_dom² / r_i⁴                          (dominant pull on i)
a_int,ij² = Σ_j (G·mass(j))² / r_ij⁴                (interaction pull on i)
```

`mu_dom` is `G·M_dom` — already a gravitational parameter. The original
draft wrote the dominant term as `(G·mu_dom)²/r⁴`, silently squaring in a
second factor of G, and the interaction denominator as `/(r²)³` (`r⁶`
instead of `r⁴`). Both were caught during implementation, not review, and
corrected directly: `a_dom,i² = mu_dom² / r⁴` (no double-G),
`a_int,ij² = (G·mass(j))² / r_ij⁴` (`r⁴ = (r²)²`, not `r⁶`). The final
diff proves it: `mu_dom * mu_dom` appears once, `G * mu_dom` appears zero
times, `r4_ij = r2_ij * r2_ij` appears with no triple product anywhere in
the function.

## Libm-free by construction

The decision is a per-body loop over ascending canonical slot order,
cross-multiplying instead of dividing:

```cpp
if (a_int_sq_i > kPerturbationRatioSqMax * a_dom_sq_i) {
    return false;
}
```

No `std::sqrt`, no division in the comparison itself — squaring both
sides kills the root that a plain-η computation would need, and
cross-multiplying kills the division. `nm -u` on
`physics_integrator_wh.cpp.o` shows only the engine's own `det_sqrt` and
`kepler_step` as undefined symbols (present because the same TU also
holds the drift step, not because the eligibility predicate calls them);
no `sqrt@GLIBC`, `cbrt@GLIBC`, or `pow@GLIBC` anywhere. `-ffp-contract=off`
reaches the TU (confirmed via `cmake --build --verbose`). Edge cases stay
inside the same arithmetic discipline: `n ≤ 1` or an invalid dominant slot
returns `true` (no interaction possible); a coincident or NaN pair
(`r² ≤ 0`, which also fails on NaN) returns `false` — conservatively
ineligible rather than propagating a bad value.

## Calibration — and the result that rescoped the milestone

The plan's original calibration target was the shipped 5-body seed
(Sun/Earth/Moon/Mars/Jupiter). Running the new predicate against it
produced η² ≈ 0.1601 (η ≈ 0.40) at the Moon's slot — the seed fails the
gate. That is not a calibration bug. Earth's pull on the Moon is about
40% of the Sun's pull on it; heliocentric WH's small-interaction
premise does not hold for a bound satellite, at any threshold that also
rejects genuinely invalid configs. The finding was recorded directly on
2026-06-24: "Heliocentric WH is invalid for bound satellites."
Calibration switched to the Sun/EMB/Mars/Jupiter
config instead — Earth and the Moon collapsed into their barycenter
(EMB), the regime heliocentric WH is built for. That config
measured η² = 1.4156e-08 (η ≈ 1.19e-4) and a Brouwer √t energy slope
under 0.5 at `dt=1e5 s, Nsteps=5000` — bounded, non-secular, genuinely
WH-valid.

`kPerturbationRatioSqMax` was pinned to 1.0e-4 (η_max = 0.01), the
literature eligibility anchor from Hernandez & Dehnen (2023) and
Rein & Tamayo's WHFast paper (2015, §2), which also names η > 0.1 as the
hard-fallback boundary two orders above:

| Quantity | Value |
|---|---|
| Pinned `kPerturbationRatioSqMax` | 1.0e-4 (η_max = 0.01) |
| Barycentric Sun/EMB/Mars/Jupiter, measured max η² | 1.4156e-08 |
| Margin above the barycentric config | ~3.85 orders of magnitude |
| Full 5-body Moon seed, measured η² | 0.1601 (η ≈ 0.40) |
| Margin below the bound-Moon seed | ~3.2 orders of magnitude |

The threshold sits with wide margin on both sides of the values that
matter, and matches a documented literature boundary.

## Wiring the gate as a ctor-only AND

Per-step hysteresis (an enter/exit band that could migrate a table
between integrators mid-run) was explicitly out of scope — a named M1.x
deferral, since it only matters once N grows enough for the dominant
regime to shift dynamically. The second half of the phase then
wires `wh_perturbation_eligible` as a third AND inside the existing
star-dominated branch of the `PhysicsWorker` constructor, evaluated once
against the already-seeded state:

```cpp
if (wh_perturbation_eligible(
        std::span<const State>{states_}.first(n_active_),
        active_table(), sel.slot, sel.mu_dom)) {
    dom_slot_ = sel.slot;
    mu_dom_ = sel.mu_dom;
    log_throttled("integrator-select",
        "integrator=WH (... star-dominated table, perturbation-ratio eligible)");
} else {
    method_ = Yoshida4{};
    log_throttled("integrator-select",
        "integrator=Yoshida4 (WH requested, table star-dominated but "
        "perturbation ratio too high — S-51 auto-fallback)");
}
```

The distinct fallback log line matters operationally: a table that fails
the mass-ratio gate and a table that fails the perturbation-ratio gate
both end up on Yoshida4, but for different physical reasons, and only one
of them is fixable by changing which bodies are in the table. `run_due_
steps()`'s REGULAR arm was verified byte-unchanged — the gate is a
one-time ctor decision, not a new hot-loop branch: ENCOUNTER-classified
pairs still route through IAS15 regardless of what the ctor decided.

## Migrating three fixtures the gate broke

Wiring the gate broke three pre-existing M0.5 tests on both lanes — each
asserted WH selection (`selected_method_index() == 2`) on a configuration
the new, physically correct gate downgrades to Yoshida4. The disposition,
settled 2026-06-24: migrate the fixtures to preserve their original
coverage, not weaken the assertions.

- `test_wh_determinism.cpp`'s worker-seam determinism fixture was two
  3×10²⁷ kg planets 0.02 AU apart (η² ≈ 72, a tightly-coupled
  comparable-mass pair the gate correctly rejects). Re-parameterized to
  two ~1×10⁻⁶ M_sun planets at 1.0/2.0 AU (η² ≈ 4×10⁻¹², WH selected) —
  the bit-identity check still runs on the WH arm it was written to cover.
- `test_29fa_wh_safety.cpp`'s coincident-pair NaN-safety case is now
  perturbation-ineligible (Yoshida4 selected); the safety hard-stop is
  integrator-agnostic so the assertion moved to index 1. A new case was
  added alongside it — well-separated positions that pass the gate (WH
  selected), then a NaN initial velocity, to keep the WH arm's own
  finiteness-scan coverage from being lost in the migration.

No numeric tolerance or magnitude changed in the process — only which
fixture exercises which selection path.

## Proving the gate doesn't touch encounter routing

A coincident pair is both perturbation-ineligible (by the `r² ≤ 0` guard)
and classified `ENCOUNTER` by the predictive detector — the negative
control proves the two systems are orthogonal: a table can fail the
perturbation-ratio gate and still be correctly routed to IAS15 by
encounter detection, not by the eligibility predicate. A second prong (an
eligible WH worker whose `step_dt` under-resolves a body's dynamical
timescale) confirms the same thing from the other direction: passing the
gate doesn't exempt a table from IAS15 if the detector fires for an
unrelated reason.

## Determinism and test counts

`nbody_force.cpp` stayed byte-unchanged across every commit in the phase.
`kDominantMassRatio == 100.0` is pinned by an `[s51]` test case
alongside the new `kPerturbationRatioSqMax == 1e-4`. At phase close: Release
416/416, Debug 413/413 (+10 each from the 406/403 baseline); the
new `wh_elig` ctest alias runs 8 cases / 36 assertions, including the
headline bound-Moon rejection with the real J2000 Earth–Moon geocentric
separation (~402,448 km) taken verbatim from `main.cpp`'s seed.

## Where it is now (drift since 2026-06-24)

- **Phase 32 (2026-06-24, same day):** the gate's outcome went live — WH
  enabled on the Sun/EMB/Mars/Jupiter warp config, the full 5-body seed
  staying on Yoshida4/IAS15 exactly as the gate decided.
- **Phase 34 (2026-06-24):** the ctor site gained a guard right
  after the eligibility check — a non-finite or non-positive `mu_dom`
  is now rejected loudly at the worker boundary before it can reach
  `kepler_step`, where it would otherwise silently NaN the trajectory
  through `det_sqrt(0) = +Inf`.
- **Phase 35 (2026-06-25):** the ctor site picked up
  a "ctor complexity" comment cataloguing every O(N²)-or-worse scan
  that now runs once at construction — `wh_perturbation_eligible` among
  them — clarifying that these costs are ctor-static and don't compound
  with the per-step force loop.
- **Later refactor (Phase 42):** the inline `BodyTable{...first(n_active_)}`
  construction at the call site became the `active_table()` helper: same
  span, same eligibility call, less repetition.
- **M0.7:** the nested (hierarchical) WH integrator for bound satellites
  is built directly on this phase's η primitive rather than inventing a
  new one.
- As of 2026-07-21, the ctor call site sits around line 1630 of
  `physics_worker_thread.cpp` — moved down from its original ~574 by the
  accumulated comments and guards above it, not by any change to the gate
  itself. `wh_perturbation_eligible`'s body, and `kPerturbationRatioSqMax
  = 1.0e-4`, are unchanged since this phase.
