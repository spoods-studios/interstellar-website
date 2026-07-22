# M0.4 Phase 21.5 — Time-Warp + Energy Observability: Technical Deep-Dive

> Retroactive technical devlog. Both items here were identified 2026-06-04
> during Phase 15.5's validation work and carried out 2026-06-09, inserted
> between Phase 21 (Multi-Body Enablement, closed 2026-06-08) and Phase
> 21.7 (Expanded Multi-Body Validation).

## Starting point

Two items surfaced during Phase 15.5's validation work, both explicitly
**not correctness** — `test_energy_conservation.cpp` had already proven
the |ΔE/E| bound: raise `time_scale_max` past its locked 1024× geometric
cap, because even maxed out the Moon demo ran ~38 minutes of wall-clock
per orbit; and give the on-screen HUD a min/max ΔE/E envelope so the
bounded symplectic oscillation is visible without watching a full period.

Phase 21 closed 2026-06-08 with the second gravitating body live —
Sun-Earth-Moon integrating and rendering — but visual testing surfaced two
complaints: "only 2 bodies visible" (the Moon overlaps Earth at 1 AU zoom)
and "HUD garbled." Both trace to one root cause: a fixed-pixel debug HUD
can't separate Moon from Earth at real solar-system scale, and text
rendering at that scale is a camera/UX problem, not a physics problem. The
2026-06-09 resolution drew the line: the engine owes physics correctness
and at most a legible debug overlay, not game-quality visualization;
camera zoom-to-body, labels, navball, and art are `setare-game` scope. That
closed Phase 21's verification without gating on HUD polish, and gave this
phase's telemetry item a landing spot: replace the on-screen envelope idea
with an authoritative **stderr** telemetry stream, since logs are
parseable, deterministic, and don't depend on a fragile in-engine text
renderer. The same day's reconciliation reopened the locked 1024× bound:
the roadmap's own acceptance criteria committed to real solar-system scale
AND a ≤1000× warp ceiling without reconciling that together they make the
dominant orbit unwatchable (3.156e7 s / 1024 ≈ 8.5 h). Phase 21.5 was
inserted the same day to carry both, ahead of Phase 21.7 — whose 100-yr
stability run needed the ceiling raised first to be watchable at all.

## What was built

### Stderr physics telemetry

`orbit_demo.cpp`'s render loop already held the live `SnapshotView` every
frame. The addition is a frame-cadence counter and a fixed-format line:

```cpp
if (telemetry_frame_counter_ % kTelemetryFrameCadence == 0) {
    std::fprintf(stderr, "[telemetry] t=%.6e dE/E=%.3e",
                 snap.sim_time, snap.rel_energy_error);
    for (std::size_t k = 0; k < snap.count; ++k) {
        const double specific_ke = 0.5 * snap.vel_at(k).dot(snap.vel_at(k));
        std::fprintf(stderr, " body%zu_E=%.6e", k, specific_ke);
    }
    std::fputc('\n', stderr);
}
++telemetry_frame_counter_;
```

`kTelemetryFrameCadence = 120` (`orbit_demo.hpp`), chosen as ~1 line per 2
wall-seconds at 60 fps — frequent enough to track drift, sparse enough to
stay readable. The per-body term is **specific** kinetic energy (½‖v‖²,
units J/kg), not full kinetic energy: the SoA render snapshot carries
position/velocity only, no per-body mass, so a true per-body energy isn't
reconstructible on this path. The whole-system `dE/E` field already folds
in the mass-weighted potential and kinetic terms, so the two fields
together cover the "per-body kinetic + system energy" intent without
threading mass through the render handoff. Output is space-delimited,
`%.<n>e` scientific, `key=value` — a downstream parser splits on
whitespace. This stderr stream, not the on-screen HUD, is designated the
authoritative physics-validation channel: no engine gate depends on the
rendered HUD from this point forward.

### Raising the warp ceiling

```cpp
inline constexpr double time_scale_min = 1.0 / 1024.0;
inline constexpr double time_scale_max = 1048576.0;  // 2²⁰
```

`time_scale_max` moves from 1024 (2¹⁰) to 1,048,576 (2²⁰); `time_scale_min`
is untouched. The target was picked backward from the dominant Earth orbit:
3.156e7 s / 2²⁰ ≈ 30 s of wall-clock at the ceiling, versus ~8.5 h at the
old cap. 2²⁰ was chosen over an arbitrary round number for two reasons
carried in the source comment. First, staying an exact power-of-two
preserves the long-horizon test's exact-double accumulator reasoning, which
was derived for power-of-two scales. Second, it keeps the worst-case
steps-per-iteration bounded: `scale · wall_dt_clamp / step_dt = 2²⁰ · 0.25 /
300 ≈ 873`, comfortably inside the Fiedler spiral-of-death guard
(`wall_dt_clamp_seconds = 0.25`, unchanged) that caps how many step() calls
a single accumulator iteration can burn through after a stall.

An existing invariant — `time_scale` never mutates `step_dt` — was the one
thing this change could not touch: raising the ceiling only changes how
many fixed 300 s Yoshida4 chunks run per wall-second, never the chunk size,
so the symplectic fixed-step energy bound stays exactly as proven. The new
test asserts that invariant directly, rather than resting on the comment
alone:

```cpp
worker.set_time_scale(1.0);
for (int i = 0; i < 5; ++i) worker.tick(kStepDt);
REQUIRE(sim_time_is_step_multiple(worker.latest_snapshot().sim_time));

worker.set_time_scale(time_scale_max);
worker.tick(wall_dt_clamp_seconds);
REQUIRE(sim_time_is_step_multiple(worker.latest_snapshot().sim_time));

const double max_steps_per_iter =
    time_scale_max * wall_dt_clamp_seconds / kStepDt;
REQUIRE(std::isfinite(max_steps_per_iter));
REQUIRE(max_steps_per_iter < 1000.0);  // 2^20·0.25/300 ≈ 873
```

`sim_time_is_step_multiple` checks that `sim_time / step_dt` lands on an
integer at both a low scale (one chunk per tick) and at the new ceiling (a
single clamped iteration advancing many chunks) — proof step_dt itself
never moved, only the chunk count per iteration. A second, existing test
was updated to assert against the named `time_scale_max`/`time_scale_min`
constants rather than literal `1024.0`/`2048.0`, so it stays pinned to
whichever bound is locked rather than silently drifting.

### Verification

Full suite green at Release 216/216, Debug 216/216 (+1 net-new case,
additive); the deterministic force kernel unaffected (`nbody_force.cpp`
untouched — this phase never touches force computation); TSan
contention/liveness suite green with the existing suppression
configuration. No M0.2/M0.3/P19/P20 math-lock tolerance moved.

## Why it was built this way

- **stderr over an on-screen envelope.** The original envelope idea (a HUD
  min/max ΔE/E readout) assumed the HUD was worth investing in; the
  2026-06-09 reframing made that assumption false. A parseable log line
  serves the actual need — physics-validation evidence — without a
  fragile in-engine text renderer.
- **Specific, not absolute, per-body energy.** Threading per-body mass
  through the render snapshot for true kinetic energy would touch the
  Phase 18 handoff contract for a validation-only feature; specific KE plus
  the existing system-level `dE/E` covers the same intent at zero
  snapshot-contract cost.
- **Power-of-two ceiling, not a round number.** 2²⁰ keeps the exact-double
  long-horizon accumulator reasoning valid and the Fiedler bound
  calculation clean, not because 2²⁰ ≈ 1.05e6 is a natural target.
- **Checked, not documented.** The new test drives `tick()` at a low scale
  and at the new ceiling and checks `sim_time` lands on exact `step_dt`
  multiples in both — the invariant that makes raising the ceiling
  physics-safe is checked directly.

## Where it is now

- **M0.6 (2026-06-25, Phase 32)**: Wisdom-Holman ships as a validated warp
  seat (Sun/EMB/Mars/Jupiter) — the symplectic large-step tier this
  phase's raised ceiling was ultimately aimed at reaching; M0.7
  (2026-07-09) replaces that EMB scaffolding worker with the live HJS
  nested-WH warp tier and a Chambers/Wisdom-2006 corrector on trivial
  recursion ladders.
- **Phase 51 (2026-07-20)**: a coasting craft test particle rides the warp
  tier on a per-step re-keyed Kepler-universal conic about its dominant
  body, with zero-thrust-in-warp asserted as a named invariant; Phase 52
  (2026-07-21) carries FRB attitude through warp steps with a hold-to-exit
  control — the warp ladder now carries orientation as well as
  position/velocity.
- The `[telemetry]` stderr line and its cadence constant are unchanged
  since this phase; `kEnergyDriftAlarm` and the per-clump variants (M0.6)
  extended the same observability channel into an automated tripwire, no
  longer only a human-read log line.
