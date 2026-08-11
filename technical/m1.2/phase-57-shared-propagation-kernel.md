# M1.2 Phase 57 — Shared Propagation Kernel Extraction: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-31**; M1.2 is
> still open, so the drift section covers what has touched the kernel since,
> not a milestone close.

## Starting point

Phase 55 gave the craft its own substep, splitting it off the 300 s step
every planetary body shares. At that shared step a 400 km LEO orbit had
accumulated 546 km of position error and a spurious eccentricity over a
single orbit — coarse enough that the craft needed its own finer,
symplectically-derived integrator rather than a smaller global step. Phase 55
built that integrator already shaped for a second caller: a pure, `noexcept`
free function, `craft_substep`, taking position, velocity and mass as
explicit parameters, a context struct the caller assembles once per coarse
window, and a thrust sample the caller supplies per substep — with a
worker call site reduced to one line.

Phase 57's job was not to build that extraction. It was to prove it. Three
things had to hold for a future trajectory predictor to share the kernel with
the live flight worker and inherit predicted-vs-flown parity by construction
rather than by a convergence test after the fact: the kernel's shape had to
genuinely satisfy its own contract, the flown trajectory had to be frozen as
a byte-exact reference so nothing done to the kernel afterward could move it
silently, and — the strongest claim — a binary that never sees the flight
worker at all had to reproduce that trajectory bit for bit. Checking the
first assumption changed the shape of the other two: the extraction had
already landed, so the phase's proof burden moved onto the golden and the
isolation binary.

## Three parameters, not one struct

The kernel signature resists the obvious refactor. Position, velocity and
mass do not travel together in an aggregate:

```cpp
[[nodiscard]] CraftSubstepResult craft_substep(const coords::Vec3f64& r,
                                               const coords::Vec3f64& v,
                                               double m_kg,
                                               int sub_index,
                                               const CraftSubstepCtx& ctx,
                                               const CraftThrust& thrust,
                                               CraftBoundaryCache* cache = nullptr) noexcept;
```

An aggregate looked like the natural next step going in — a single
`{r, v, m_kg}` value type is the shape most of the engine's other kernel
call sites use. It did not land, because everything else about the call is
already explicit: the coarse-window context (perturber positions, the
dominant's gravitational parameter, J2 terms, post-Newtonian parameters) and
the per-substep thrust command are both separate parameters, and folding
just the propagated state into a struct would have made that one input
implicit for no reason beyond convention. `r`, `v` and `m_kg` stay three
independent, equally explicit inputs and outputs, matching the discipline
the rest of the signature already keeps.

## A throttle command, not a precomputed delta-v

The more consequential shape decision is what `CraftThrust` carries. It is
not a velocity delta computed elsewhere and handed to the kernel — it is a
throttle in `[0, 1]` plus the same thrust properties the Phase 49 fuel
kernel takes, and `craft_substep` calls that fuel kernel itself, once per
substep, before touching velocity at all:

```cpp
double thrust_half = 0.0;
if (thrust.enabled) {
    const ThrustStep ts = thrust_step(thrust.props, m_kg, thrust.throttle, h);
    out.m_kg = ts.m_new_kg;
    out.dv_mps = ts.dv_mps;
    out.burned_out = ts.burned_out;
    thrust_half = 0.5 * ts.dv_mps;  // exact dyadic split
}
```

The returned delta-v splits into two exact halves that bracket the
gravity kick — mass commits first, then half the impulse, then the drift,
then the remaining half. This is what makes a future trajectory predictor's
job tractable: it needs to hand the kernel a *planned* burn — a throttle
profile over time — not a precomputed fuel schedule it would otherwise have
to derive by re-implementing the same analytic depletion curve. Feed the
same throttle sequence through the same kernel and the mass, delta-v and
burnout flag come out identical to what the flight worker would have
produced, because it is the same call.

## The golden table

Proving the extraction preserved behavior needs a frozen "before." The
reference (`tests/unit/physics/test_craft_extraction_golden.cpp`, data in
`tests/unit/physics/data/craft_extraction_golden.hpp`) drives the production
`PhysicsWorker` end to end — selector, window open, substep drain, seam,
recompose, publish — rather than calling the kernel directly, because the
claim under test is about the *flown* trajectory: a kernel-only capture
would stay green even if the worker had stopped calling the kernel
correctly.

Two scenarios cover different parts of the kernel. Scenario A puts Earth,
with its J2 term, alone and at rest at the origin, with a 400 km circular LEO
craft on a thrust-only track: 64 coarse windows, three-plus coasting orbits,
a four-window constant-throttle burn, a coasting tail. With Earth the only
gravitating body and at rest, its own Leapfrog step writes `r += 0` and
`v += 0` exactly, so the craft's dominant-relative state equals its absolute
state every window and the whole 64-window input sequence is a pure function
of window index — no worker state feeds it. Scenario B adds the Moon as a
second gravitating body: 24 windows, the same craft. Earth and Moon now move
under mutual gravity, so each window's perturber state depends on the
planetary integrator's own output — not reproducible in closed form, and
asserted only by the worker-driven golden.

The frozen values are the state's raw bits, captured with `std::bit_cast`
into `uint64_t`, at five checkpoint windows for A (one per orbit through the
coast, the burn's start and end, the final state) and three for B:

```cpp
struct Checkpoint {
    int window{0};
    std::array<std::uint64_t, 3> r_bits{};
    std::array<std::uint64_t, 3> v_bits{};
    std::uint64_t m_bits{0};
};
```

The comparison runs on two bands. Every build lane checks the recovered
state against a derived physical-distance ceiling — `1.0 m`, itself derived
from a per-substep round-off budget (`8 * 2^-52` per substep, compounded
linearly over 1,048,576 substeps against the LEO radius) rather than picked
by eye, and left with roughly 79x headroom over that derived floor. On the
same compiler family the check is stricter: exact equality on every stored
bit, since the whole craft path is addition, subtraction, multiplication,
division and a small deterministic set of roots — no platform-dependent
`libm` call anywhere on the trajectory — so a same-family divergence means an
operation-order regression to fix, not a tolerance to widen.

A hidden, always-skipped test case prints the table in paste-ready form for
regeneration; nothing regenerates the table silently.

## The isolation binary

The golden proves the worker still flies the same trajectory. It says
nothing about whether the kernel could be called from anywhere else — a
worker-linked test binary carries every worker symbol whether the kernel
needs one or not, so a numeric match inside it doesn't prove the kernel is
freestanding.

`craft-kernel-isolation-tests` is a second, separate executable with an
explicit nine-file source list — the kernel's own translation unit plus its
transitive pure-physics dependencies (root-finding, the universal Kepler
solver, oblateness, post-Newtonian terms, the thrust kernel, and the
rigid-body rotation the test harness itself needs to reproduce the thrust
direction) — and nothing else:

```cmake
add_executable(craft-kernel-isolation-tests
    unit/physics/test_craft_integrator_kernel.cpp
    ${PROJECT_SOURCE_DIR}/engine/src/physics_craft_integrator.cpp
    ${PROJECT_SOURCE_DIR}/engine/src/det_math.cpp
    ${PROJECT_SOURCE_DIR}/engine/src/kepler_universal.cpp
    ${PROJECT_SOURCE_DIR}/engine/src/encounter_detector.cpp
    ${PROJECT_SOURCE_DIR}/engine/src/oblateness_force.cpp
    ${PROJECT_SOURCE_DIR}/engine/src/pn_force.cpp
    ${PROJECT_SOURCE_DIR}/engine/src/thrust_force.cpp
    ${PROJECT_SOURCE_DIR}/engine/src/rigid_body.cpp
)
target_link_libraries(craft-kernel-isolation-tests
    PRIVATE
        Catch2::Catch2WithMain
        glm::glm
)
```

No `physics_worker_thread.cpp`, no `interstellar-engine` library link. If the
kernel ever picked up a worker dependency — a stray extern, an ambient clock
read, a helper that migrated into the worker's own translation unit — this
target fails to *link*, not to pass a test. That distinction is the whole
point: a link failure blocks the build before any test runs, where a
review-only convention could be missed.

The test inside this binary reproduces Scenario A's checkpoint bits by
driving `craft_substep` directly, one substep at a time, replaying the same
64-window input sequence the worker fixture runs — same seed state, same
scheduled throttle, same thrust direction resolved through the same rotation
call the worker uses. The compiled binary genuinely cannot construct a
`PhysicsWorker`; there is no such symbol in its object files. And yet the
checkpoint bits it produces match the table Scenario A's worker-driven golden
also asserts, exactly, on the same compiler family:

```
nm -C build/tests/craft-kernel-isolation-tests | grep -c PhysicsWorker
0
```

Worker path and kernel path are proven identical by transitivity through
that one shared, frozen table, rather than by running a worker and the bare
kernel side by side in the same binary. Building a worker into the isolation
target would put worker symbols back into the very binary whose absence is
the proof — the check would then only demonstrate that a worker and a kernel
called with the same inputs agree with each other, inside a binary that no
longer establishes anything about the kernel's independence. Two other
cases in the same file exercise properties the checkpoint replay alone
doesn't reach: repeated calls with identical inputs produce identical output
bits and mutate none of their arguments, and a hand-built three-perturber
context — never sourced from a worker — produces the same bits whether or
not the caller passes a scratch cache for the perturber-position memo.

## Zero allocation, proven rather than assumed

A caller that replays this kernel across a whole prediction horizon calls it
far more often than the flight worker does per frame, so a heap allocation
that would be invisible in live flight becomes a real cost there. A separate
executable, `craft-zero-alloc-tests`, replaces the global `operator new` and
`operator delete` for the duration of the binary, counts calls into a
translation-unit-local counter, and runs bursts of 2000 substeps each —
coasting, burning with the boundary cache attached, and the shared
perturber-position function on its own — snapshotting the counter into a
plain local before any assertion runs, so the test framework's own machinery
can't be counted. All three bursts allocate zero, and each carries its own
anti-vacuity check (mass genuinely drops while burning, position genuinely
moves while coasting) so a silently no-op kernel could not pass by doing
nothing.

Underneath that measurement, the header pins the same claim structurally.
Every kernel-facing type gets a `std::is_trivially_copyable_v` assertion —
the context, the perturber record, the boundary cache, the thrust sample,
the result — so an owning member (a `std::vector`, a `std::string`, a
snapshot type that copies rather than views) becomes a compile error instead
of a review finding the first time someone reaches for one. `noexcept` is
asserted the same way, on the call expressions rather than the declarations,
so a throwing helper introduced anywhere in the call chain fails the build
at this header instead of surfacing as a crash inside a caller that assumed
the kernel could never throw.

## Why it was built this way

- **Verification changed the deliverable, not the design.** Once the
  extraction turned out to already exist, the remaining work moved onto
  proving properties rather than creating them — the golden, the structural
  assertions, and the isolation binary are what a phase whose extraction
  already shipped is left to deliver.
- **A throttle command outlives the caller that first defines it.** Handing
  the kernel a burn schedule instead of a delta-v means whichever caller
  plans the burn — the flight worker today, a trajectory predictor later —
  gets the identical analytic depletion the fuel kernel already produces,
  with no second implementation of that curve to keep in sync.
- **Transitivity is cheaper and stronger than co-location.** Proving the
  worker path and the kernel path agree by replaying both against one frozen
  table is a stronger claim than running both in the same process, because
  the isolation binary's freedom from worker symbols is itself the evidence
  — putting a worker into that binary to compare live would destroy the
  property being demonstrated.
- **A link failure is a harder gate than a test failure.** Enumerating the
  isolation binary's source files explicitly, rather than linking the
  engine library and trusting the kernel not to reach outside itself, turns
  "the kernel grew a worker dependency" into something the build catches
  before any test executes.

## Where it is now

- The kernel's own selection-rule commentary for its fixed substep count
  originally claimed that running more substeps per window never makes the
  result less accurate. A later hardening pass this milestone measured that
  claim directly against a single analytic reference step and found it
  false — accuracy degrades slowly past a certain substep count because
  each additional call commits its own small systematic bias, even though
  the substep count still has to stay where it is for an unrelated
  responsiveness reason. The header's comment was corrected in place rather
  than left standing, and a new lock now grades the kernel's output against
  one analytic reference call instead of only against another kernel run,
  which is the only way the original overstatement was visible at all.
- The isolation test file picked up three more cases: an out-of-range
  perturber index now has an explicit release-build fallback to a zero
  vector rather than reading past its span, an out-of-range substep boundary
  index is pinned to return exactly the clamped-endpoint answer rather than
  left as an unstated assumption, and the golden-replay case gained a
  numeric bound on velocity and on ending mass — both previously checked
  only for finiteness on cross-compiler lanes, which meant either could have
  been wrong by any amount on those lanes without the test noticing.
  Position was already bounded; velocity and mass now carry bounds derived
  the same way, from the fixture's own scale.
  The zero-allocation binary gained a positive-control case that
  deliberately performs and counts one allocation, so a broken counter fails
  loudly instead of leaving every other case in the file passing for the
  wrong reason.
- Later in the milestone, the whole flight capture was re-run end to end —
  a fresh Release build, a fresh Debug build, and the original 2026-07-31
  bits — after a run of numeric fixes elsewhere in the propagation stack
  that were expected to move it. All three agreed on every one of the 56
  frozen checkpoint words. The kernel's own arithmetic had not changed; the
  fixes elsewhere left this particular chain untouched, which the
  re-capture confirmed rather than assumed.
- The kernel also grew an additive extrapolation mode for perturbers,
  `KeplerDriftPerDominant`, and a matching anchor type, used by the
  trajectory predictor that was always Phase 57's intended second caller.
  Every pre-existing mode is byte-identical to what this phase shipped —
  the addition is a new branch a caller opts into, not a change to the one
  the flight worker already uses.
