# M0.4 Phase 21.7 — Expanded Multi-Body Validation: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built 2026-06-09/10**; the
> drift section covers the gate-time re-diagnosis that relocked two of
> this phase's bound tables.

## Starting point

Phase 21 shipped three bodies; the master-roadmap M0.4 acceptance asked for
more — Mars and Jupiter integrated and validated, and long-baseline
stability proven. Phase 21.7 was inserted on 2026-06-09 to close that gap
under the unchanged force model: direct O(N²) mutual gravity, fixed-step
Yoshida4 with the IAS15 encounter fallback, celestials only. Scope came
from a research pass (synthesis diffed into locked vs grey — all five
grey items accepted at the recommended defaults). Executed 2026-06-09 with
the exit gate closing early 2026-06-10.

One research finding shaped everything downstream: the worker's
`system_energy` scalar is a specific-energy N=1 holdover, mass-inconsistent
for multi-body — so no 21.7 gate uses it. The true total energy
`E = Σ½mᵢvᵢ² − Σ_{i<j} Gmᵢmⱼ/rᵢⱼ` is computed in-test instead.

## What was built

### Five-body foundation

Mars and Jupiter entered as planet **barycenters** (HORIZONS `COMMAND='4'`/
`'5'` — planet + moons system mass, matching the system-mass constants
`M_MARS = 6.4171e23`, `M_JUPITER = 1.89818e27`), fetched live from the JPL
HORIZONS API with the DE441 source label confirmed at fetch and committed as
`tests/data/horizons_{mars,jupiter}_ssb_j2000.hpp` with full provenance.
`main.cpp` grew to five gravitating `BodyProps` rows in the shared SSB J2000
frame; `step_dt` (300 s), `mu_central` (0), and the method stayed untouched.
The true-energy, total-angular-momentum, barycenter, and AMD oracles were
promoted from per-test copies into `tests/unit/test_helpers/
multibody_energy.hpp` for every wave that follows.

### Orbital periods by phase crossing

Each of Earth/Mars/Jupiter gets its sidereal period measured from the live
5-body integration by interpolated phase-angle crossing of θ₀ + 2π in its
t₀ heliocentric orbital plane; the osculating period from
`extract_kepler_elements` is a secondary INFO cross-check, never the gated
assertion. Measured relative errors: Earth 5.20e-4, Mars 6.50e-4, Jupiter
1.47e-4 — all above the 0.01% roadmap target, so honest looser bounds were
locked (Earth/Mars 1.5e-3, Jupiter 4.0e-4, measured × ~2.3–2.9) with the
residual attributed at the time to the moving Sun: the phase is taken on
`r_body − r_sun`, and the Sun wobbles about the SSB at solar-radius scale,
so the crossing measures a synodic-flavoured closure rather than the
inertial sidereal period. The osculating cross-check landing at
~0.013–0.015% on all three bodies argued the orbits themselves were sound.
That attribution did not survive the milestone-close gate — see the drift
section.
Jupiter's ~11.86-year first orbit runs behind the `[.long]` tag.

### 100-year stability

The headline gate: 100 Julian years of the 5-body system — 10,519,200 steps
at dt = 300 s, ~3.7 s wall time in Release. Hard gates, calibrate-then-lock:

| Quantity | Measured | Locked |
|----------|----------|--------|
| max\|ΔE/E\| (true total energy) | 1.29e-12 | 1e-9 |
| AMD band / AMD₀ | 3.22e-5 | 1e-4 |
| max\|ΔL/L\| | 6.95e-13 | 5e-12 |

Energy and angular momentum sit at the float64 round-off floor over 1e7
steps — Yoshida4 shows zero secular trend. AMD is the secular sentinel:
the Angular Momentum Deficit is the gap between the system's total orbital
angular momentum and what the same bodies would carry on circular, coplanar
orbits with their current semi-major axes. It grows as eccentricities and
inclinations pump up, which is exactly the degradation mode a bounded-energy
symplectic integration can hide — the measured envelope is a bounded ~3e-5
libration, not growth. Per-body semi-major-axis bands are logged as INFO
(physical perturbation wobble, not asserted). A 300 s-vs-150 s convergence
check confirmed the production step: the halved-step error ratio of 2.23 is
pure round-off accumulation, meaning Yoshida4's (h/T)⁴ truncation sits below
the float64 floor at both steps.

### Multi-epoch DE441 position error

Twenty reference samples (5 bodies × 4 epochs: J2000, +1 yr, +10 yr, +50 yr)
fetched from HORIZONS and committed; one integration J2000 → +50 yr
(5,259,600 steps) asserts every body at every epoch boundary. The J2000
self-check measured 0 km exactly (km→m→km is exact at these magnitudes) and
is locked at 1e-6 km as a conversion sentinel. Forward cells locked at
measured × ~2 — Earth 497,445 km at +1 yr, Jupiter 80,644 km, Sun 7,958 km —
and framed explicitly as **model-fidelity** gates, not integrator gates: the
errors grow secularly with baseline because Venus and Saturn are not in the
system, while the 100-year stability gate independently pins the integrator
floor at 1e-12.

### Cost-vs-N benchmark + exit gate

`test_nbody_benchmark.cpp` times `compute_accelerations` and `step<Yoshida4>`
across N ∈ {2..100} with hand-rolled `std::chrono`, hidden behind
`[.benchmark]` with deliberately no `add_test` alias so hardware-variable
timings never enter the gated tier. `ns_per_pair` is flat at ~2.46–2.47 ns
from N ≥ 10 through N = 100 — force time grows linearly in pair count,
quadratically in N, the direct-summation cost this design committed to.
Exit gate: Release 218/218, Debug 218/218, TSan suppression-scoped gate
3/3 with zero un-suppressed warnings; a diff over every M0.2–P21 lock file
confirmed empty — the whole phase is additive.

## Why it was built this way

- **Barycenters, not planet centers**, for Mars and Jupiter: at
  solar-system scale the engine integrates each planet system's mass at its
  barycenter, which is what the DE ephemerides tabulate and what the system
  masses match.
- **The in-test true-energy oracle** rather than fixing the worker's scalar:
  the worker function is pinned by the N=1 bit-identity gate, so the phase
  computes the correct quantity beside it instead of moving a locked
  surface mid-phase.
- **Honest bounds over headline bounds.** The 0.01% target was not met by
  the gated metric, so the locked numbers say so, with the residual
  diagnosis documented inline rather than absorbed into slack.
- **[.long] and [.benchmark] tiers** keep 1e7-step runs and timing tables
  out of the default ctest path while `ctest -L long` and the phase gate
  still exercise them.

## Where it is now (drift since 2026-06-10)

- **2026-06-10, M0.4 gate:** the moving-Sun diagnosis was superseded. The
  dominant residual in the period test was a mass-table GM inconsistency —
  the mass constants and the published GMs disagreed at the 1e-4 level.
  The fix defines `M_X = GM_X_DE440 / G` by construction, and both the
  period and multi-epoch tests were recalibrated-then-relocked on
  consistent GMs: Earth's period bound tightened 1.5e-3 → 2e-5 (measured
  5.67e-6), Mars → 1.5e-4; Jupiter's loosened 4.0e-4 → 8e-4 because its old
  number had been a two-error cancellation. The multi-epoch +1 yr
  Earth/Moon case fell 497,445 km → measured 6,510 km (bound 1.4e4 km). The
  honest-bound discipline is what made the relock cheap: the measured
  values were real, only the attribution was wrong.
- **2026-06-13, gate fix:** the benchmark's `detect_regime` column was
  re-derived against a full-scan fixture — the original fixture
  short-circuited on the first pair, understating the detector's O(N²)
  cost ~940× at N = 100 (151 ns → 142,586 ns).
- **2026-06-15, M0.5 Phase 27:** the benchmark notes gained a
  WH-vs-Yoshida4 section — Wisdom-Holman did not beat Yoshida4 at the
  shipped config, and Yoshida4 stayed the production seed.
- **2026-07-12, M0.8 Phase 46:** the multi-epoch DE441 pattern scaled to a
  14-body × 4-epoch ladder covering the full planetary set, with
  per-system Saturn/Uranus/Neptune fixtures following in 46.1. The
  100-year stability gate and its AMD sentinel still run green under the
  four-tier integrator stack.
