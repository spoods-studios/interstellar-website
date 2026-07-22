# M0.8 Phase 46.1 — All-Planet Validation Seeds: Technical Deep-Dive

> Retroactive technical devlog. **Inserted phase**: added 2026-07-10
> between Phase 46 and Phase 47. Code shown **as built on 2026-07-12**; a
> drift section traces `engine/src/main.cpp` and `engine/src/pn_force.cpp`
> through today's stack.

## Starting point

Phase 44 landed the J2 oblateness catalog with nine rows (Sun, Mercury, Venus,
Earth, Mars, Jupiter, Saturn, Uranus, Neptune), but the live seed only ever
turned four of them on — Sun/Earth/Jupiter/Mars. Jupiter's row gets exercised
dynamically by Phase 46's Galilean-clump run; Mercury/Venus/Mars/Earth get
exercised by DE441 deltas and the Earth-Moon clump. Saturn, Uranus, and
Neptune's catalog rows had no satellite dynamics anywhere in the test suite to
prove them against — nothing in the tree would catch a wrong J2 coefficient,
a wrong reference radius, or a wrong spin axis for those three planets. This
gap was named and the fix locked as its own inserted phase rather than
folding it into 44 or 46.

Two validation efforts formalized 2026-07-12 carry the scope: per-system
satellite seeds for Saturn/Uranus/Neptune, two-pronged against analytic
secular rates and Horizons ephemerides, and a DE441 multi-epoch barycenter
ladder extended from Phase 46's inner-planet set to the full nine-body
planetary set. DE441 itself carries planet barycenters only, not satellites,
so the two efforts split cleanly: one validates the outer moons against
analytic rates and Horizons satellite ephemerides, the other validates the
planets against DE441. The work breaks into six stages, all test-side except
the last, which lands the milestone's shipped-config flip.

## The shared J2 secular-rate helper

This phase builds the machinery all three per-system suites consume:
`tests/unit/test_helpers/j2_secular.hpp`. Three pieces:

- `j2_secular_rates(n, j2, r_ref, a, e, i)` — the MIT OCW 16.346 Lec 30
  averaged forms, `p = a(1-e²)`, `f = J2·(r_ref/p)²`, `dΩ/dt = -1.5·n·f·cos i`,
  `dω/dt = 0.75·n·f·(5cos²i-1)` — the exact arrangement used to compute
  each moon's anchor, so switching to an algebraically
  equivalent form later would silently break independence between the
  formula and the anchors it's checked against.
- `pole_frame_elements(rel_r, rel_v, mu, s_hat)` — rotates a body-centered
  relative state into a frame whose z-axis is the catalog spin axis, then
  hands off to the engine's own `extract_kepler_elements`. The pole-frame
  basis picks the global axis least parallel to `s_hat` as its reference,
  which makes the global-z case (`s_hat = (0,0,1)`) reduce to an exact
  identity — no round-off noise on the one input this helper will be run
  against most often in regression.
- `unwrap_angles` + `secular_slope` — sequential 2π unwrap plus a closed-form
  least-squares slope. Osculating Ω/ω carry short-period J2 oscillation on
  top of the secular drift; endpoint-differencing two raw samples aliases
  that oscillation into the measured rate, so every per-system suite fits a
  slope across many samples instead.

This is test-side-only code — libm (`std::cos`, `std::atan2`, …) is fine here
and explicitly barred from ever migrating into the engine's deterministic
`det_` path. The Earth sun-synchronous anchor (+0.9856°/day at 700 km /
98.19° inclination) checks the formula itself against a textbook target
independent of any planetary seed, landing within 0.1% (measured 0.03% off).
Full suite: 635/635, `engine/` diff empty.

## Saturn: Mimas + Tethys

A four-body seed is pinned — Sun, Saturn (body GM, not the system GM the
four-body seed would double-count against), Mimas, Tethys — from five
Horizons epochs (base, +1d, +5d, +30d, +100d, `sat441l` ephemeris), and adds
`OuterPlanetSeed` plus `saturn_j2_seed()` to a shared fixture header the
Uranus and Neptune plans append to.

The suite runs the seed through its natural HJS nested-clump routing and
checks two independent things. Prong (a) recomputes the analytic anchor
in-test from `OBLATENESS_SATURN` itself (J2 = 1.6290573e-2 at
R_ref = 6.0330e7 m, spin axis {0.0855, 0.0732, 0.9936}) rather than an
independently-typed constant — an engine-vs-analytic self-consistency check,
not two copies of the same number that could drift together:

| Quantity | Measured | Analytic | rel err | Locked |
|---|---|---|---|---|
| Mimas node dΩ/dt | -0.983574°/day | -0.977109 | 0.66% | 0.015 |
| Mimas apse dω/dt | +1.942891°/day | +1.953118 | 0.52% | 0.012 |
| Tethys node dΩ/dt | -0.194907°/day | -0.194492 | 0.21% | 0.006 |

The residuals are the J2² term plus osculating-extraction noise plus
Mimas/Tethys's mutual secular coupling — exactly as predicted, not slack
padding.

Prong (b) checks Horizons satellite-position residuals per epoch, split
planetocentric (isolates J2 alone) and SSB (also carries the seed's 4-body-cut
frame drift, since this Sun+Saturn+2-moons system feels no Jupiter or other
planet):

| Epoch | planetocentric (km) | bound | SSB (km) | bound |
|---|---|---|---|---|
| +1d | 43.6 | 90 | 53.3 | 110 |
| +5d | 240.8 | 500 | 738.4 | 1500 |
| +30d | 1453.7 | 3000 | 4465.9 | 9000 |
| +100d | 4783.2 | 9600 | 21833.5 | 44000 |

Bounds are locked at roughly 2× the measured residual — calibrate-then-lock,
not an aspirational target. Full suite: 637/637, `engine/` diff still empty.

## Uranus: the axis kill

This is the phase's sharpest test. Uranus's ~98° obliquity is the one
system where a spin-axis bug — say, an engine that silently used global-z
instead of the catalog's arbitrary pole — would still pass Jupiter and
Saturn (whose poles are close to their orbital normals) and only fail here.
The suite falsifies that bug three independent ways rather than asserting
one number and hoping it's sensitive enough:

| Kill | Measured | Locked | Falsifies |
|---|---|---|---|
| Static axis sanity | `\|s_hat.z\|` = 0.2618 (= sin 15.175°) | `\|·-0.262\|` < 0.01 | global-z, which would read 1.0, no run required |
| Miranda node-rate ratio | catalog-axis / global-z rate = **104.9×** | > 10 | a global-z engine collapses this ratio toward 1 |
| Ariel orbit-normal lock | axis-line angle, max **0.0035°** | < 0.05° | global-z drifts this ~0.18°/100d |

The catalog stores the IAU pole, which is the antipode of the angular-momentum
pole (IAU 257.311°/-15.175° vs angular-momentum 77.312°/+15.171°) — about the
IAU pole, Miranda's inclination measures 175.57° (retrograde), so `cos i < 0`
and its node *advances* at +0.05452°/day, the same sign a global-z bug would
also produce. The suite therefore never hard-asserts a bare negative rate; it
uses an antipode-safe rule, `sign(measured) == sign(-cos i_measured)`, plus
the 104.9× magnitude gap, so it can't be fooled by the pole-convention
ambiguity into passing a broken axis.

Prong (a)'s rate anchor:

| Quantity | Measured | Analytic | rel err | Locked |
|---|---|---|---|---|
| Miranda node dΩ/dt | +0.05452°/day | +0.05177 | 5.3% | 0.11 |
| Miranda apse dω/dt | +0.10783°/day | +0.10308 | — | INFO only |

The apse row is INFO-only rather than locked — Miranda's eccentricity
(~0.001) is too small to condition a periapsis fit reliably. The 5.3%
node residual, wider than Saturn's or Neptune's, is dominated by Ariel's
second-moon secular coupling onto Miranda — real two-moon physics the
single-moon analytic anchor doesn't carry, not a formula error. Position
bounds (per-epoch, measured × ~2): planetocentric {22.6, 334.3, 1596.6,
19445.3} km against {50, 700, 3200, 40000}; SSB {29.2, 468.2, 2298.7,
118535.3} km against {60, 1000, 4600, 240000} at {+1d, +5d, +30d, +366d}. Full
suite: 639/639.

## Neptune: the sharpest anchor

This closes the third system — Sun, Neptune, Naiad, Proteus (`nep098`
ephemeris) — and completes the phase's Saturn + Uranus + Neptune set. The
anchor recomputes from `OBLATENESS_NEPTUNE`'s textbook (J2, R_ref) pair
(3.4084e-3 at 2.5225e7 m), which happens to be algebraically equivalent to
a different (J2, R_ref) pairing found in some sources (3536.297e-6 at
2.4764e7 m) — only the product J2·R_ref² is physical, so recomputing from
the engine's own catalog values rather than an independently-typed literal
sidesteps that renormalization trap entirely.

| Quantity | Measured | Analytic | rel err | Locked |
|---|---|---|---|---|
| Naiad node dΩ/dt | -1.701018°/day | -1.695110 | **0.35%** | 0.007 |
| Proteus node dΩ/dt | -0.075369°/day | -0.075318 | **0.07%** | 0.0015 |

Naiad's 0.35% is the tightest rate residual of the three systems — flagged
in advance as the sharpest J2 anchor available. Both
moons have near-zero eccentricity, so — as with Miranda — only the node is
locked; periapsis rates are degenerate and excluded rather than force-fit.
Position bounds (per-epoch, measured × ~2): planetocentric {8.7, 41.8, 257.7,
936.6} km against {18, 90, 520, 1900}; SSB {41.1, 495.5, 2575.1, 8513.2} km
against {85, 1000, 5200, 17100} at {+1d, +5d, +30d, +100d}. Full suite:
641/641.

## The full-planet DE441 ladder

This extends Phase 46's inner-planet DE441 gate to all nine bodies — Sun
plus the eight planet-system barycenters — at the same
J2000/+1yr/+10yr/+50yr epoch ladder, run at Yoshida4 direct-force
`dt = 300 s` (the ladder's epochs are fractional-day multiples the
`tau = 86400 s` warp lane can't land on exactly). Perturbations run ON through
the flown-tier direct-force seams — `apply_j2_accelerations` plus
`pn_direct_accel` — rather than the warp HJS map, since a flat nine-barycenter
set has no bound clumps for HJS to nest.

| Body | +1yr (km) | +10yr (km) | +50yr (km) |
|---|---|---|---|
| Sun | 0.29 | 5.93 | 64.3 |
| Mercury | 2.59 | 405.9 | 9728.6 |
| Venus | 0.33 | 13.9 | 363.1 |
| EMB | 117.1 | 1174.4 | 5935.2 |
| Mars | 0.22 | 6.68 | 60.5 |
| Jupiter | 0.08 | 7.37 | 65.0 |
| Saturn | 0.03 | 3.46 | 67.3 |
| Uranus | 0.03 | 2.55 | 77.2 |
| Neptune | 0.06 | 5.76 | 158.3 |

Every bound here is far tighter than Phase 46/21.7's inner-planet-only
ladder (whose Jupiter +50yr bound sat at 1.5e7 km) — this set omits no major
planet. Against a Newtonian-only control at +1yr, the 1PN contribution drops
Mercury's residual 57.9→2.6 km and Venus's 98.7→0.33 km, the confirmation
that the perturbation terms are doing real physical work rather than being
wired in inert. The EMB residual is belt-perturbation-dominated (1PN
contributes nothing measurable for Earth); none of the bounds are fitted to
DE441 after the fact — measured once, locked, never re-tuned.

Calibration surfaced one bug, fixed the same day: the first cut of
the harness applied solar 1PN to each planet without giving the Sun the
matching back-reaction, injecting net momentum that drifts the SSB
barycenter. The fix adds `a_sun -= (m_body/m_sun)·a_1PN(body)` — momentum
conservation. The effect is numerically tiny at this seed's mass ratios
(~3e-6), but the fix confirmed the EMB residual above is honest asteroid-belt
model fidelity, not a barycenter drift artifact.

Exit check: `engine/` stayed diff-empty across all five test-side stages,
`nbody_force.cpp` byte-identical, Release 643/643, Debug 639/639, the
`[.long]` tier (including the +50yr rows) green.

## The shipped-config flip

The phase's one authorized engine-source change — 33 insertions, 26
deletions, `engine/src/main.cpp` only — landed only after both Phase 46's
exit gate and this phase's own green add-only proof. Two edits:

```cpp
-            interstellar::physics::OblatenessProps{},       // 9  = Mercury  (absent — flip is 46.1-06)
-            interstellar::physics::OblatenessProps{},       // 10 = Venus    (absent — flip is 46.1-06)
-            interstellar::physics::OblatenessProps{},       // 11 = Saturn   (absent — flip is 46.1-06)
-            interstellar::physics::OblatenessProps{},       // 12 = Uranus   (absent — flip is 46.1-06)
-            interstellar::physics::OblatenessProps{},       // 13 = Neptune  (absent — flip is 46.1-06)
+            interstellar::physics::OBLATENESS_MERCURY,      // 9  = Mercury  (ACTIVE — 46.1-06 flip)
+            interstellar::physics::OBLATENESS_VENUS,        // 10 = Venus    (ACTIVE — 46.1-06 flip)
+            interstellar::physics::OBLATENESS_SATURN,       // 11 = Saturn   (ACTIVE — 46.1-06 flip)
+            interstellar::physics::OBLATENESS_URANUS,       // 12 = Uranus   (ACTIVE — 46.1-06 flip)
+            interstellar::physics::OBLATENESS_NEPTUNE,      // 13 = Neptune  (ACTIVE — 46.1-06 flip)
```

plus `worker_config.pn = PnParams{true, C2_LIGHT}`, enabling the Phase 45 ST94
1PN across every tier. Both edits wire APIs Phase 44/45 already landed —
`OBLATENESS_MERCURY`/`_VENUS`/`_SATURN`/`_URANUS`/`_NEPTUNE` and `PnParams`
existed already, so there's no re-typed catalog constant for the
(J2, R_ref) pairing trap to bite. All nine catalog rows are now ACTIVE (the
Moon and four Galileans stay point-mass). Post-flip: Release 643/643,
Debug 639/639, `[math-lock]` tag 1,759,225 assertions across 180 cases,
`nbody_force.cpp` byte-untouched. A 25-second headless smoke of the rebuilt
`build-release` binary booted the 14-body seed clean — `dE/E = -9.198e-12`
(round-off floor), `regime=REGULAR method=Yoshida4`, zero NaN/Inf/validation-
layer lines.

## Key decisions

- **Test-side seeds, not live-seed additions.** The live seed's
  satellites stay Earth's Moon and the four Galileans; Saturn/Uranus/Neptune's
  moons exist only inside this phase's validation fixtures.
- **1-2 moons per system, picked by J2-signal strength.** Inner
  regular moons with the largest, best-documented J2 secular rates, not
  the marquee names (Titan, Triton) — a weaker-signal moon makes for a
  duller validation.
- **Anchors recomputed from the engine's own catalog constants, not
  independently-typed literals.** Saturn/Neptune's analytic cross-checks pull
  `(J2, R_ref, spin_axis)` straight from `OBLATENESS_SATURN`/`OBLATENESS_NEPTUNE`
  — an engine-vs-analytic self-consistency proof, and immune to the
  (J2, R_ref) renormalization trap that bit an alternate Neptune source.
- **Antipode-safe sign rule for Uranus, not a hard-coded negative
  assertion.** The catalog's IAU pole is the antipode of the angular-momentum
  pole, which flips Miranda's measured node sign from what a naive analytic
  comparison would expect; the suite asserts consistency with the actual
  pole convention in use plus a 104.9× magnitude gap, not a bare sign.
- **Momentum-conserving 1PN back-reaction, caught during calibration, not
  after.** The DE441 ladder's first cut omitted the Sun's back-reaction; the
  fix landed the same session rather than shipping a barycenter-drifting
  harness.

## Deviations

Two, both minor:

- **No `[.long]` tag on the Uranus/Neptune per-system suites.** `[.long]`
  is conditional on runtime; the 100d/366d rate-and-position runs on a
  4-body seed are instant, so neither needed it.
- **Prong (b) position bounds locked per-epoch rather than one worst-case
  bound (Saturn).** Keeps the tight early-epoch residuals from being
  masked by the loose +100d one.

## Where it is now (drift since 2026-07-12)

- **The momentum-conserving back-reaction is now shared, not harness-only.**
  A Phase 47 review finding caught that the DE441 ladder's harness had
  implemented the Sun's PN back-reaction but the shipped flown-tier direct
  callback hadn't — so the lock was validating a convention production
  didn't yet run, and the omission drifts the Sun-Earth barycenter ~657 m
  over 50 yr in the shipped path. The fix extracted
  `apply_pn_dominant_accelerations` in `pn_force.cpp` as the single
  shipped-direct-tier definition; both the production worker callback and
  the DE441 ladder's harness call it now, and the harness's local
  reimplementation is gone. Mercury's 42.98″/century, the DE441 ladder, and
  the on/off matrix all re-verified green against the corrected convention;
  `nbody_force.cpp` stayed byte-untouched throughout.
- **The nine active oblateness rows and the 1PN enable are unchanged.**
  `engine/src/main.cpp`'s `oblateness` vector and `worker_config.pn` still
  read exactly as this phase's shipped-config flip left them.
- **The three per-system test suites are unmoved.** `test_saturn_j2_seed.cpp`,
  `test_uranus_j2_seed.cpp`, and `test_neptune_j2_seed.cpp` still carry the
  seeds and bounds documented above.
