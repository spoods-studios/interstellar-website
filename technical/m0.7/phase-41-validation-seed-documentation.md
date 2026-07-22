# M0.7 Phase 41 — Validation Seed + Documentation: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on
> 2026-07-09**; the drift section traces `engine/src/main.cpp` and the
> design documentation's §4.4 tier table through today's stack.

## Starting point

Phases 36–40 built the Hierarchical Jacobi Symplectic (HJS) nested map: the
coordinate core, the KDK step, SyMBA-style recursive sub-stepping, the
warp↔flown handoff, and the summation-order lock Phase 40 pinned. All of it
ran on minimal fixtures — a two-clump toy tree with a handful of bodies,
enough to prove the math but not the seed the game will ship. Phase 41's
mandate: validate the full nine-body hierarchy — Sun / Earth-Moon / Jupiter
plus the four Galilean moons / Mars — against JPL HORIZONS DE441, wire it up
as the demo's live rendered worker, and document the tier in the project's
design documentation. Any
failure found here gets fixed in-phase, not by loosening a bound; M0.6
backlog reconciliation and the closing review are separate phases (42, 43).

## Pinning the reference data

Three early commits fetch and commit the reference
data everything downstream depends on: nine bodies × five epochs from
HORIZONS, fetched live via `curl -G` against the DE441/jup365 ephemerides
(`EPHEM_TYPE=VECTORS`, `CENTER=@0`, `REF_SYSTEM=ICRF`), committed offline in
`tests/data/horizons_full_seed_epochs.hpp` with re-runnable query parameters
and response-header provenance (`Center-site name: BODY CENTER`).

Jupiter is fetched as body `599`, not the `5` system barycenter the M0.6
five-body seed used — once the four Galileans are resolved as separate
gravitating bodies, mixing the system GM with the body-only mass would
double-count their contribution (a pitfall named in the M0.7 research and
avoided here by construction). `constants.hpp` gains
`MU_JUPITER_BODY_JUP365` (126,686,531.900 km³/s²) plus the four Galilean GMs
(Io 5,959.9155, Europa 3,202.7121, Ganymede 9,887.8328, Callisto 7,179.2834
km³/s²), each math-locked with a bit-exact literal pin and a 1-ULP `G·M`
composition check against `test_constants.cpp`. The system-vs-body GM
residual (the Amalthea group and other small moons) — 2.4562e9 m³/s²,
~1.94e-8 relative — is checked and documented rather than silently absorbed.

The epoch ladder itself had to move. At J2000 the Europa-Ganymede jovicentric
separation is 7.46°, below the ~10° floor treated as a near-conjunction
that ill-conditions position error as a diagnostic. An early assertion
catches this and slides the whole ladder forward one day; at JD
2451546.0 (J2000+1d) the minimum pairwise Galilean separation is 44.89°.
The slide preserves whole-day offsets so every epoch still lands on a
synchronized outer KDK boundary (needed for the warp handoff below). The
identical fetch pipeline was byte-verified against the existing
J2000 fixture first — Sun/Earth/Moon/Mars rows matched
`horizons_multibody_epochs.hpp` exactly — before trusting it on the slid
ladder.

`tests/unit/physics/data/hjs_full_seed.hpp` transcribes the nine-body base
epoch into a valid HJS tree: two clumps (Earth-Moon, Jovian) under one root,
eight declared orbits, masses from the by-construction constants (Jupiter's
slot uses `M_JUPITER_BODY`, not the system mass).

## The calibrate-then-lock DE441 gate

Two commits build `test_full_seed_de441.cpp`: one
365-day integration of the nine-body seed under the nested map at
`tau_outer = 86400 s`, checked against the pinned HORIZONS rows at four
epochs. The first commit runs the gate with deliberately generous
placeholder bounds and prints the measured residuals; the second replaces
them with locked bounds at roughly twice the measured value, tagged
`[math-lock]`. The two-commit split is the audit trail — no bound in this
phase was declared before it was measured.

Measured Moon geocentric residual against DE441: 5.74 km at +1 day, rising to
24.34 km at +30 days — inside the "tens of kilometers" floor the M0.7
research assigns to omitted Venus/Earth-J2 perturbations plus the Moon's own
~1.4 km/month secular drift (Williams & Dickey 2002). Locked bounds:
{12, 40, 42, 50} km at {+1d, +5d, +7d, +30d}. The four Galilean jovicentric
residuals come out monotone — Io > Europa > Ganymede > Callisto at every
epoch, the along-track signature of Jupiter's J2 (1.4697e-2, Iess et al.
2018), roughly twice the pure-J2 estimate once eccentricity phasing and solar
tide are folded in.

Energy over the full year: global nine-body barycentric `|dE/E|` sits at the
round-off floor, 6.39e-11, with no secular trend — the numerical-integrity
gate. The two clumps' *internal* energy is a different story: the Jovian
clump (tightly bound) holds at 6.84e-6, but the Earth-Moon clump drifts
1.099e-2 — the Moon is only weakly bound (η ≈ 0.40, the same ratio that
failed the M0.6 heliocentric-WH gate), so the Sun's pull measurably perturbs
the internal Earth-Moon energy. This isn't a leak: the signed drift stays in
[-1.099e-2, +9.75e-3], peaks at day 4, and a least-squares slope of
2.6e-4/year confirms no secular ramp — a bounded oscillation the lock
captures with a permanent no-secular-slope guard rather than a flat
tolerance. The ladder derivation (`n_k = next_pow2(ceil(|τ|·20/P_k))`) gives
Io 16 substeps, Europa 8, Ganymede 4, Callisto 2, everything else 1 — the
fast inner moons resolve at ≥20 substeps per orbit while the day-scale outer
edges fire once per outer step.

## Per-clump telemetry

A follow-up set of commits add a diagnostic the DE441 gate
needed a name for: per-clump internal-energy drift on the live `[telemetry]`
stderr line. `clump_internal_energy()` computes
`Σ ½mᵢ|vᵢ − V_com|² − Σ_{i<j} Gmᵢmⱼ/rᵢⱼ` over a clump's bodies — COM-frame
kinetic energy minus internal pairwise potential, read-only over the
published state. Clump membership is derived generically from the tree's
`oloc` array (any satellite set with ≥2 bodies), not hardcoded to this seed,
so it applies unchanged to whatever hierarchy a future seed declares. For the
nine-body tree this yields exactly two clumps in ascending order: `clump0`
(Earth-Moon) and `clump1` (Jovian).

The field lands append-only: `format_telemetry_line`'s locked `snprintf`
prefix string is byte-unedited, and the new `" clump%zu_dE=%.3e"` fields are
appended via `std::string` after `amd=` and before the per-body energy
trailers. A flat seed with zero clumps produces the identical byte string it
did before Phase 41 — pinned by a test that asserts `find("clump") ==
std::string::npos` on that path. `FrameMeta`/`SnapshotView` carry the new
fields as a fixed `std::array<double, 16>` plus a count, keeping the struct
trivially copyable under the existing seqlock read.

The same plan adds a throttled stderr line for the warp↔flown handoff itself:
`[physics-worker] warp-tier FLOWN->WARP t=...` (and the reverse), emitted
from the existing `warp_enter_session`/`warp_exit_session` boundary helpers
on their own `KeyedLogThrottle` key so it can't be evicted by an unrelated
regime or pause log. Phase 39 had wired the handoff mechanics but published
neither this line nor the clump fields — both are new here.

## The full seed becomes the rendered worker

Two commits replace the demo's live 5-body flat seed
with the full 9-body nested seed as the worker the render loop
consumes. `main.cpp`'s nine SSB initial conditions mirror the pinned
base-epoch column verbatim; the declared 8-orbit hierarchy is wired through
the Phase-39 `Config::hierarchy` mechanism, so the existing declarative
routing selects the HJS nested map at warp without any new dispatch logic.
The flown tier is unchanged — Yoshida4 at 300 s. Startup `time_scale_init`
is set to 256, below the `warp_in_scale` of 2048 set in Phase 39, so a user
pressing the warp-up keybind genuinely crosses the threshold rather than
starting inside it.

The M0.6 EMB scaffolding worker — the second `PhysicsWorker` Phase 32 added
as an unconsumed WH warp seat for a future milestone to pick up — is removed
in the same commit, along with the `PhysicsWorkerFleet` wrapper and its
`report_if_emb_warp_stopped` polling built to manage two workers' error
channels. Its purpose is superseded: the live HJS tier on the primary worker
is now the consumed warp path, so `main.cpp` drains a single worker directly.

The same commit adds the camera controls the staged-warp UAT needs to see any of
this: `cycle_focus()` recenters the view on the next body slot (TAB,
wrapping on the live body count, resetting the trail since camera-relative
trail points are meaningless across a center change), and `zoom_in()`/
`zoom_out()` (`]`/`[`) scale the effective world→NDC framing by powers of
two, clamped to `[2⁻⁸, 2¹⁶]` — a range chosen to cover both the ~180× zoom
needed to see the Moon's ~4×10⁸ m orbit around Earth and the ~36× needed for
the ~2×10⁹ m Callisto orbit around Jupiter, from the same ~1 AU startup fit.
Disk radii divide by the same effective scale so they hold constant screen
size while zooming.

Three headless stderr scans (redirect → run 30 s → kill, no interaction)
covered Release `build/`, the rebuilt `build-release/` (stale since
Jun 29), and a Debug `build-debug/` lane specifically to exercise Vulkan
validation layers (both Release configs build with `NDEBUG`, so layers are
off there). All three show the telemetry line firing on schedule, both
`clump0_dE`/`clump1_dE` present, zero `ENERGY-DRIFT` alarms, and zero
`VUID-` matches in the layer-on lane. The one warning present in the
Debug-lane output is a benign `dzn` DirectX-on-Vulkan loader notice, not a
validation error.

## Documentation

This phase's documentation update lands in the project's design
documentation: §4.4's warp-tier table gets a
`2→3 (nested)` row, and a new §4.4.3 subsection covers hierarchy seed
declaration, eligibility (the η gate plus `hjs_map_eligible`/`valid`),
handoff semantics (synchronized boundaries, the corrector, the
keep-unsynchronized peek path), and the validated-behavior paragraph
quoting the locked DE441 bound table above. The section also names the
M1.x re-hierarchization deferral: the declared hierarchy is static for
a run, and dynamic re-hierarchization only matters once bodies can
change primaries at runtime — irrelevant to a fixed declared seed. A
same-day follow-up reconciles the existing WH row's framing against the
2026-06-25 scope ruling so the two rows read consistently.

The visual-validation requirement closes on the standing headless
evidence above — the three-lane stderr scans plus the locked DE441 bound
table — rather than an interactive run.

The reference-data work also surfaced an unrelated, pre-existing
data-quality issue: the M0.3 "geocentric Moon" fixture
(`horizons_earth_moon_j2000.hpp`) had been fetched topocentric
(`CENTER='399'` resolves to a specific observatory, not the body center).
Logged as a debt-ledger item and resolved the same day by
re-fetching from `CENTER='500@399'` with the response header verified as
`BODY CENTER` — the block has no consumer outside itself, so the fix is
reference-data-only.

## Key decisions

- **Calibrate-then-lock, not aspirational targets.** Every DE441
  bound in this phase is measured first, on the record, before it's locked —
  the two-commit split (placeholder bounds, then locked bounds) is the
  auditable proof.
- **Reference data fetched live, committed offline.** HORIZONS
  queries are re-runnable (documented URL + parameters); tests run
  deterministically against the pinned fixture, never fetching at test time.
- **Clump derivation stays generic.** `clump_internal_energy` and its
  membership compilation read the tree's `oloc` structure rather than
  hardcoding "Earth-Moon" and "Jovian" — the mechanism works for any declared
  hierarchy; this seed produces two clumps.
- **ADD-ALONGSIDE superseded by REPLACE, once the replacement earns it.** The
  M0.6 EMB scaffolding worker was deliberately unconsumed pending a future
  milestone; Phase 41 is that milestone, and the live HJS tier replacing it
  outright — rather than adding a third worker — was the disposition
  recorded against the original scaffolding note.

## Deviations

Two adjustments, both accepted:

- **Epoch base slid J2000 → J2000+1d.** An early degeneracy check catches
  a Galilean pair falling below the ~10° non-degeneracy floor at J2000
  (Europa-Ganymede measured 7.46°); the slide was anticipated, not ad hoc.
- **EMB scaffolding worker removed rather than left alongside.** Removing
  the M0.6 worker once the live nested tier superseded its purpose was
  the intended disposition all along.

## Where it is now (drift since 2026-07-09)

- **The seed has grown twice since.** Phase 44 (M0.8) added oblateness rows
  for Sun/Earth/Jupiter/Mars on top of this nine-body config; Phase 46 grew
  the live seed to 14 bodies and then turned planetary perturbations
  (J2 + 1PN) on. The Phase-41 nine-body core — the declared hierarchy,
  `M_JUPITER_BODY`, the camera slot-name table — is still there
  (`engine/src/main.cpp:34,169,256,266`); newer phases extended it rather
  than replacing it.
- **The camera controls are unchanged.** `cycle_focus()`/`zoom_in()`/
  `zoom_out()` and their keybinds are still exactly what this phase shipped
  (`engine/include/interstellar/render/orbit_demo.hpp:79-81`,
  `engine/src/main.cpp:612-625`).
- **The design documentation's §4.4.3 nested-tier section stands.** Later
  milestones added rows and rulings alongside it (the same-day WH-row
  reconciliation, and subsequent milestone work) but didn't revise the
  hierarchy-seed subsection this phase wrote.
- **The topocentric-fixture fix stayed resolved.** The re-pinned
  topocentric-vs-geocentric Moon fixture has no consumer and hasn't needed
  to move since.
