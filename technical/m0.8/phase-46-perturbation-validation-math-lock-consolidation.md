# M0.8 Phase 46 — Perturbation Validation + Math-Lock Consolidation: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-12**; a
> drift section covers what happened to this phase's surfaces afterward.

## Starting point

Phases 44 and 45 had landed the force physics — a J2 zonal-harmonic catalog
and an ST94 explicit-split 1PN kernel, both wired additively into the WH,
HJS, and IAS15 tiers with the pre-M0.8 Newtonian path preserved as a
structural off-switch. Neither phase proved the numbers were right against
an external reference, and the shipped live seed still had 9 bodies with
perturbations wired but disabled. Phase 46 closed that gap: recover Mercury's
known perihelion-precession rate from the 1PN kernel in isolation, show the
combined 1PN+J2 path beats pure Newtonian gravity against DE441 for the
inner planets, prove the on/off switch is bit-exact in the OFF position on
every force path, confirm the M0.7 nested-seed machinery tolerates
perturbations with no regression, and grow the live seed from 9 to 14 bodies
as the substrate the next phase would flip ON.

The work breaks into six additive stages: the DE441 data foundation, the
Mercury precession harness, the seed growth, the twin-run accuracy gate,
the on/off matrix, and the final consolidation exit gate.

## What was built

### DE441 data foundation

Five new GM pins in `constants.hpp` — `MU_MERCURY_DE440` (22031.868551
km³/s²) and `MU_VENUS_DE440` (324858.592000 km³/s²) as body GMs, plus lumped
system GMs for `MU_SATURN_SYSTEM_DE440` (37940584.841800), `MU_URANUS_SYSTEM_DE440`
(5794556.400000), and `MU_NEPTUNE_SYSTEM_DE440` (6836527.100580) — each with
a by-construction `M_X = MU_X / G` mass and a `within_one_ulp(G·M_X, MU_X)`
math-lock row, re-verified against JPL SSD's `astro_par` DE440 table (Park
2021) the same session. The Jupiter-system row in that table
(126712764.100000 km³/s²) matches the already-pinned `MU_JUPITER_SYSTEM_DE440`
exactly, and the Earth/Mars rows match the existing pins too — three
independent confirmations the new pins are drawn from the same table the
old ones were.

`tests/data/horizons_planets_epochs.hpp` fetched 56 state vectors live from
JPL Horizons — 14 bodies × 4 epochs, base epoch JD 2451546.0 (J2000+1d, the
same base the M0.7 fixture uses) plus a whole-day ladder at
{0, +365, +3653, +18263} days, every point landing on both an outer-KDK
boundary (τ=86400 s) and a 300 s flat-step boundary. Target-name and source
labels were asserted at fetch time — Mercury `'1'`→"Mercury Barycenter (199)"
and Venus `'2'`→"Venus Barycenter (299)" are body==barycenter (no moons),
while Saturn/Uranus/Neptune (`'6'`/`'7'`/`'8'`) are true system barycenters
paired with the lumped system GMs above. The base-epoch column for the 9
bodies shared with the M0.7 fixture was mechanically byte-verified identical
to `horizons_full_seed_epochs.hpp`'s own base column, across all 6 components
× 9 bodies — one fetch, one frame, every downstream consumer inherits it.
Full suite stayed at 620/620 (constants + fixture only, nothing consumed
yet); `constants.hpp`'s diff was 38 insertions, 0 deletions; the locked
kernel's diff stayed empty.

### Mercury precession, the milestone's headline number

The measurement machinery already existed: `test_hjs_precession_guard.cpp`
(M0.7 Phase 40) implemented the Laplace-Runge-Lenz eccentricity-vector +
unwrapped-apsidal-angle + least-squares-slope core for measuring secular
precession. That core was extracted verbatim into
`tests/unit/test_helpers/apsidal_fit.hpp` — the same Phase-16 `pcg.hpp`
extraction precedent, include-plumbing only, all three existing cases
unchanged after the move.

It was then pointed at Sun+Mercury on the flat WH tier: DE441-seeded
from `pl_sun_epochs[0]`/`pl_mercury_epochs[0]`, `steps_per_orbit=44` giving
h≈1.9993 days (the orbitN `gr-mercury` reference shape — verified from
`orbitN-1.0.1/sim/gr-mercury/sim.c`: `#define PN` on, J2 off, `in_dt=2.0`
days, 1000 yr, header-commented "42.98 arcsec per century"), run 1000 years,
apsidal angle sampled once per orbit (4152 orbits) and LSQ-fit. Four cells:

| Cell | Slope | Reference | Locked |
|------|-------|-----------|--------|
| Newtonian control | −8.755e-08 ″/cy | numerical floor (~0) | < 0.05 |
| **PN-only** | **42.9807 ″/cy** | Genova et al. 2018, 42.98 (0.0016%) | **42.98 ± 0.30 ″/cy** |
| solar-J2-only | 0.0284019 ″/cy | closed-form 0.0286 (0.7%) | 0.0284 ± 0.008 |
| PN+J2 | 43.0091 ″/cy | excess = J2 slope | directional > PN-only |

N=2 makes this the cleanest possible isolation — the Newtonian WH
interaction term vanishes for a two-body pair, so the enabled 1PN kick is
the *only* thing moving the apsidal angle. A mismatch here would be a
force-law or frame bug in the Phase-45 ST94 implementation, not a timestep
problem — the harness never shrinks dt to chase a wrong number.

This exact 1000-year harness was designed to confirm Phase 45's per-step
true↔pseudo-velocity conversion (rather than per-session) introduces no
secular drift artifact. It didn't: the PN-only ΔE/E channel (stroboscopic,
182,688 steps) measured amplitude 7.68e-12 and LSQ drift 1.42e-11, both at
the round-off floor and ~3 orders below any physical secular red flag.
That energy check needed a small design correction: the inherited "drift
≪ amplitude" idiom from `test_full_seed_de441.cpp` assumes a physical
oscillation amplitude much larger than round-off, but
once-per-orbit sampling here removes the in-orbit wobble entirely — leaving
both amplitude and drift at the same ~1e-11 noise floor, where their ratio
is meaningless. Realized instead as two absolute ceilings (amp < 1e-9,
drift < 1e-9), ~100× the measured floor — same "bounded, no secular growth"
intent, calibrated honestly rather than reusing an idiom that didn't
fit the sampling regime. Full suite: 622/622; the locked kernel's diff
stayed empty (element extraction is entirely test-side).

### Live seed growth, 9 → 14 bodies, perturbations OFF

The shipped seed was locked at the full planetary set — Sun + 8 planets +
Moon + 4 Galileans. The twin fixture landed first
(`tests/unit/physics/data/full_planets_seed.hpp`, following the same
fixture-first-then-live-seed precedent established earlier): masses
by-construction, states transcribed by-symbol from the new DE441 ladder,
a 13-edge in-order Jacobi tree with the existing 9 bodies keeping slots
1–9 and the 5 new bodies appended diff-stably as 10=Mercury, 11=Venus,
12=Saturn, 13=Uranus, 14=Neptune — Mercury/Venus slot in below the
Earth-Moon barycenter, Saturn/Uranus/Neptune stack above Jupiter,
canonicalizing the trailing-satellite ordering artifact the M0.7 seed had
left informal. `engine/src/main.cpp` then grew to mirror the fixture
exactly: +5 `State`s, +5 `body_props`, +5 *absent* oblateness placeholder
rows (new bodies get no J2 yet), +5 name strings, the 8-edge hierarchy
replaced by the 13-edge ladder — perturbations OFF throughout (the ON flip
is owned by the next phase, once both phases' validations are green).

The `build_tree` probe on the grown structure reported `valid=1,
map_eligible=1, n_bodies=14` with every edge's η/μ physically sane. A
headless boot from the built binary ran the PhysicsWorker constructor
against the new 13-edge tree and the 14-row oblateness↔body_props pairing
with no invalid-tree throw. Because the growth touches only `main.cpp` (no
test config, no scalar physics parameter), every existing golden — including
the frozen full-state table — stayed byte-unmoved: full suite
622/622, unchanged from the precession harness's exit count. The locked
kernel's diff stayed empty.

### The twin-run DE441 accuracy gate

One seed, two runs. Run A takes the grown 14-body seed through the shipped
nested map with perturbations off (pure Newtonian — the pre-M0.8-identical
path). Run B takes the *same* seed through the *same* map with the full J2
catalog plus 1PN on, replicating the worker's warp session exactly:
`b2g` → per-orbit `pn_true_to_pseudo` at session entry → the nested Jacobi
ladder with oblateness and PN kicks → `pn_pseudo_to_true` + `g2b` at every
peek. That pseudo-velocity bookkeeping isn't cosmetic — the O(v²/c²) initial-condition
transform is worth thousands of kilometers for Mercury over 50 years, so
skipping it would corrupt the comparison. Positions need no such transform
(`g2b` depends only on Jacobi positions); only energy peeks convert
pseudo→true.

Both runs are compared against the DE441 whole-day ladder — one-directional,
engine → truth: nothing here is fitted to DE441, so an improvement is a
real physics claim, not a curve-fit artifact.

| Body | +1yr OFF→ON (km) | +10yr OFF→ON (km) | +50yr OFF→ON (km) |
|------|-------------------|---------------------|---------------------|
| **Mercury** | 60.33 → 0.70 | 1812.2 → 7.45 | **7963.0 → 56.66 (140×)** |
| Venus | 98.64 → 0.27 | 902.2 → 6.45 | 4543.4 → 65.57 (69×) |
| Earth | 62.04 → 4.97 | 556.2 → 62.86 | 2938.1 → 214.4 (14×) |
| Mars | 39.67 → 0.22 | 338.8 → 6.35 | 1746.3 → 45.94 (38×) |

The Galilean SSB errors collapse too (Ganymede +50yr 2.09e6 → 998 km — the
J2 signature reaching all the way to a jovicentric-adjacent moon system),
global ΔE/E stays bounded (amplitude 2.88e-9, ramp 2.33e-10), and the
anti-wiring check (ON must differ bitwise from OFF) fires before any
physical assertion runs.

Mars was the tightest call: the 1PN signal there (~50 km) sits closer to
the asteroid-belt noise floor (documented model gap — DE441 models
Ceres/Pallas/Vesta perturbations at a 2.5–7 km/decade budget; the engine
doesn't) than Mercury/Venus/Earth's margins do, so Mars was flagged for
directional-only reporting unless the measured margin came out comfortable.
It did — 38–53× (err_OFF/err_ON), unambiguous — so Mars was promoted to a
hard `err_ON ≤ err_OFF` gate alongside the other three. Full suite: 623/623;
tag-policy registered the new `[.long]` reason; the locked kernel's diff
stayed empty.

### The on/off regression matrix

The actual regression contract: perturbations OFF must
reproduce the pre-M0.8 engine to the bit on every force path, and every ON
cell must (a) differ bitwise from OFF before any tolerance is applied and
(b) stay energy-bounded. Three force paths × the OFF/J2/PN/BOTH grid:

| Path | Legacy shape | Capable-empty shape | OFF result |
|------|--------------|----------------------|------------|
| WH flat | `wh_step(...7-arg)` | `wh_step(..., OblatenessTable{}, ..., PnParams{})` | byte `==` |
| HJS nested | `hjs_map_step_jacobi(...ladder)` | `...(..., OblatenessTable{}, PnParams{})` | byte `==` |
| IAS15 direct | `compute_accelerations` | `+ apply_j2_accelerations(empty)` | byte `==` |

Each OFF cell drives one config through both the legacy (pre-M0.8) call
shape and the perturbation-capable-but-empty shape and asserts exact `==`
(hexfloat on failure) — no tolerance is permitted here, because a tolerance
would silently pass a partially-wired perturbation. That byte-identity
claim rests on three complementary proofs together: an empty diff on
`nbody_force.cpp`, the entire pre-M0.8 `[math-lock]` suite (including the
frozen golden) staying green *unmodified*, and these explicit cells.

ON cells, measured then locked with margin:

| Path | Cells | anti-wiring | ΔE/E measured → locked |
|------|-------|--------------|--------------------------|
| WH flat | J2/PN/BOTH | all differ from OFF | 2.53e-4 → 6e-4 |
| HJS nested | J2/BOTH | Jupiter/Io differ | 9.0e-10 → 2e-9 |
| IAS15 direct | BOTH smoke | differs from OFF | 5.80e-8 → 1.5e-7 |

Full suite: 629/629 (+6 for the six matrix cells); the locked kernel's diff
stayed empty.

### Consolidation and the exit gate

The last validation: does the M0.7 nested-seed machinery — the η-eligibility
gate, the warp↔flown handoff — still work with perturbations turned on? The
exact M0.7 9-body `hjs_full_seed()` seed, run on the nested map with the
full J2 catalog and 1PN enabled, `τ_outer=86400` s. `build_tree` takes no
perturbation input, so η/μ/reduced-mass invariance holds structurally by
construction — nothing to measure there. The physics payoff is the Galilean
jovicentric residual collapse once Jupiter's J2 turns on:

| Body | err_OFF (km) | err_ON (km) | Improvement |
|------|--------------|-------------|-------------|
| Io | 56774.1 | 85.11 | 667× |
| Europa | 17879.6 | 5.70 | 3137× |
| Ganymede | 5358.01 | 4.73 | 1134× |
| Callisto | 1457.09 | 1.23 | 1186× |

Energy over 365 days stays bounded (global 1.36e-9, EM-clump 1.1% — matching
the pre-existing solar-tide signature from the M0.7 seed's validation, Jovian
1.17e-5), and the warp-export/re-enter handoff arc's ΔE/E is 8.9e-12. The
existing DE441 validation file (`test_full_seed_de441.cpp`) stayed
byte-untouched throughout — its locked OFF bounds serve as the baseline this
file measures against, re-measured in-place rather than imported.

The final audit task was audit-only — no new fix surfaced. Full suite Release
630/630, Debug 626/626; `[math-lock]` 171 cases / 1,759,263 assertions
green; `[.long]` 25 cases green; TSan 3/3 green; the locked kernel's diff
stayed empty against the milestone base; and an additive-only audit
confirmed zero deletions in `constants.hpp` and byte-untouched scalar
config in `main.cpp` (step_dt, mu_central, method, time_scale,
observability cadence). The phase's sanctioned modified-file set:
`test_hjs_precession_guard.cpp` (include-plumbing only), `test_constants.cpp`
(additive ULP rows), `test_tag_policy.cpp` (additive reason),
`tests/CMakeLists.txt` (additive registrations), `constants.hpp` (additive
pins), `main.cpp` (additive seed growth). No test tolerance weakened
anywhere in the phase.

The shipped configuration — the grown 14-body seed with perturbations
flipped ON — stayed **locked-pending** at this phase's close: the
ON-flip commit was explicitly handed off to Phase 46.1, gated on
that phase's outer-planet validations also going green, rather than folded
in here.

## Why it was built this way

- **Calibrate-then-lock, every number.** Mercury's 42.9807 ″/cy, the solar-J2
  0.0284019 ″/cy secondary, every energy ceiling from the on/off matrix, and
  Mars's promotion to a hard accuracy gate are all measured values plus a
  documented margin — never an a-priori estimate locked in before the run
  existed.
- **Isolate before you combine.** The Mercury precession harness proves the
  1PN kernel in the cleanest possible two-body configuration before the
  twin-run gate asks it to hold up inside a 14-body nested integration — a
  force-law bug shows up as a wrong Mercury number long before it would be
  findable in a 50-year multi-body DE441 comparison.
- **Compare against truth, never fit to it.** The accuracy gate runs one
  direction only — engine states measured against the committed DE441
  fixture, with GM constants pinned by-construction from JPL SSD rather than
  tuned to match. An improvement claim built on constants fit to the same
  data it's validated against would be circular.
- **The OFF path gets a tolerance-free proof.** The on/off matrix's `==`
  cells exist specifically because a numeric tolerance on the OFF path would
  mask a perturbation kick that's wired but silently wrong — exactness is
  the only proof that rules that failure mode out.
- **A cross-phase handoff needs an explicit owner.** The production ON-flip
  was named to a specific phase, with an explicit gate (both phases'
  validations green), rather than leaving "who flips the switch" implicit
  between two phases landing in the same session.

## Where it is now (drift since 2026-07-12)

- **2026-07-13, Phase 46.1:** the shipped-configuration ON flip landed as
  its own commit against the same `main.cpp` this phase grew — J2 catalog
  rows and the 1PN worker path went live for the full 14-body seed, gated
  on Phase 46.1's outer-planet validations going green alongside this
  phase's. This was the planned next step, not an unplanned change.
- **Checked at engine HEAD (2026-07-21 session, branch
  `milestone/m1.1-spacecraft-control`):** every file this phase created or
  touched — `test_mercury_precession.cpp`, `apsidal_fit.hpp`,
  `test_perturbed_de441_epochs.cpp`, `test_perturbation_matrix.cpp`,
  `test_full_seed_perturbed.cpp`, `constants.hpp` — has taken no further
  commits since the M0.8 gate closed. `main.cpp` shows one hit since —
  Phase 52's kill-rot + SDL input producer, a pure 110-line append for
  spacecraft attitude control that never touches the perturbation seed rows
  this phase and 46.1 landed. No drift beyond the planned ON flip above.
