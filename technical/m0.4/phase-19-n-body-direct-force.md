# M0.4 Phase 19 — N-Body Direct Force + State Promotion: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-08**; the
> drift section traces `nbody_force.cpp` to its current status as the
> locked deterministic force kernel.

## Starting point

Phase 18 made the physics→render handoff N-capable: fixed-capacity SoA
snapshot pages plus a single shared immutable body-id table. Force
evaluation was still M0.3's: `bound_force_fn`, a per-body function pointer
`r → a` with μ pre-bound, one body, two-body point-mass. Phase 19 replaces
that seam with a whole-vector coupled force pass — direct O(N²) exact
Newtonian in float64, symmetric `i<j` accumulation over the shared table —
and promotes integrator state from size 1 to N, targeting same-binary
determinism. The architecture locked 2026-06-05, eight decisions ratified
2026-06-08, and all five task commits landed the same day.

A question raised before implementation amended the phase (2026-06-08):
the original plan read "a single self-less body coasts" — but M0.3's
canonical orbit is empirically a test particle in a fixed central μ-field:
Earth is implicit in μ, never a body in the state vector (`main.cpp:28-33`,
`test_long_horizon.cpp:105-108`). A literal self-less N=1 body feels zero
force, integrates a straight line, and fails every M0.3 math-lock. So the
kernel retains a configurable fixed central-μ source term evaluated through
the byte-identical `evaluate_force(mu, r)` expression; at N=1 that term is
the entire acceleration, and bit-identity is provable.

## What was built

### The force kernel

`engine/src/nbody_force.cpp`, a stateless free function:
`compute_accelerations(span<const State> states, const BodyTable& props,
double G, double mu_central, span<Vec3f64> accel_out) noexcept`. Two stages. First the central-source pre-fill: `accel_out[i] =
evaluate_force(mu_central, states[i].r)` when `mu_central != 0.0`, else zero —
the M0.3 expression reused verbatim; the exact `0.0` compare lets fixtures
request a pure-mutual system. Then the mutual loop (REBOUND BASIC
accelerate-direct form, verified against `src/gravity.c`, clean-room):

```cpp
for (std::size_t i = 0; i < n; ++i) {
    if (!props.gravitating(i)) {
        continue;
    }
    for (std::size_t j = i + 1; j < n; ++j) {
        const coords::Vec3f64 dr = states[j].r - states[i].r;
        const double r2 = dr.dot(dr);
        // inv_r3 mirrors physics_force.cpp:35 — r³ = r²·√r², NOT pow(r,3).
        const double inv_r3 = 1.0 / (r2 * std::sqrt(r2));
        const double prefact = G * inv_r3;
        accel_out[i] = accel_out[i] + (prefact * props.mass(j)) * dr;
        accel_out[j] = accel_out[j] - (prefact * props.mass(i)) * dr;
    }
}
```

The form accumulates acceleration directly — `G/r³` times the *other* body's
mass — not force-then-divide. That carries the massless tier for free: a
`mass = 0` body multiplies the other body's accumulator by zero (exerts
nothing) while its own accumulator is driven by the other bodies' masses
(feels everything). No `1/0`, no branch.

The loop shape is pinned for determinism. Float64 addition is not
associative — `(a + b) + c` and `a + (b + c)` round differently — so each
accumulator holds a sequence of roundings, one per pair visit, and the
final bits depend on visit order. Fixing `i` ascending from 0 and `j` from
`i+1`, in shared-table slot order, makes that rounding sequence identical
on every run. Plain `+=` is reproducible only because `-ffp-contract=off`
(CMakeLists.txt:24) forbids fusing `a*b + c` into an FMA — one rounding
instead of two, different bits — and `FE_TONEAREST` is pinned at startup
(main.cpp:42); both were re-verified before trusting the sum. No
superaccumulator — reproducible-summation machinery would *change* the M0.3
result and break the N=1 gate. This is the locked reference summation
order: changing the `dr` sign, the prefactor form, or the pair-visit order
changes locked behavior and requires re-verification against the full
math-lock suite.

The gravitating gate shipped wrong once inside the phase: an early version
gated both `i` and `j`, so a non-gravitating body skipped as `j` never
received `accel[j] -= prefact·mass(i)·dr` — zero force on a body that must
feel everything. The first test run caught it; a fix moved the exerts-side
gate to the outer `i` only — itself carrying a latent slot-order bug (drift
section).

The data model rode the same commit: `BodyProps { uint32_t id; double mass;
double mu; bool gravitating; }` plus `BodyTable`, a non-owning
`std::span<const BodyProps>` view — static per-body metadata extending Phase
18's shared immutable table, not the render-facing pos/vel-only `State`
SoA. Both `mass` and `mu` are carried (central/energy paths use published
μ, the mutual loop `G·mass`, neither reassociated); the span *is* the
canonical body order.

### The N=1 bit-identity gate

`test_nbody_n1_identity.cpp` asserts `compute_accelerations` at N=1 equals
`evaluate_force(MU_EARTH, r)` with `Vec3f64` `==` — exact per-component, not
`Approx` — across six radii from LEO altitude to lunar distance. The contract:
at N=1 the mutual loop visits zero pairs, the central term is the entire
output, and the central term is the byte-identical M0.3 expression, so
equality holds to the last ULP. The named test pins the contract; the full
`integrator/*` + `coordinates/*` math-lock suite, re-run unchanged, proves no
produced number moved. If the suite goes red, the fix belongs in the force
path — no M0.3 tolerance gets retuned.

### Seam swap + state promotion

`bound_force_fn = Vec3f64 (*)(Vec3f64)` became `bound_accel_fn =
std::function<void(span<const State>, span<Vec3f64>)>`; `step<M>` takes the
state span, a caller-owned acceleration scratch, and the callback by
const-ref. `leapfrog_kdk_substep` now runs whole-vector: fill `a(r)`,
half-kick all, drift all, *refill* `a(r)` at post-drift positions, half-kick
all. The refill is the correctness requirement — KDK's second kick needs
accelerations at post-drift positions; a single pre-step fill feeds it stale
values, an O(dt²) operator-order error the bit-identity gate catches.

The worker integrates `span<State>{&state_, active}` through
`span{accel_}.first(active)`; `accel_` is sized to `body_capacity` at
construction and reused every substep — no hot-path allocation — and the
`std::function` is built once in the constructor, closing over `body_props_`,
`physics::G`, and `mu_central_`. Production config moved from
`.force = &earth_force` to `.mu_central = MU_EARTH`, with a `force_override`
seam keeping the harmonic/no-force/NaN worker tests alive after the signature
change broke seven Config-consuming test files. The energy diagnostic became
whole-system — `Σ½vᵢ² − Σ μ_central/rᵢ − Σ_{i<j} G·mᵢmⱼ/rᵢⱼ` — reducing
exactly to M0.3's `½v² − μ/r` at N=1; the NaN/Inf filter became N-aware,
naming the offending body slot. 23 files; 168/168 green, zero tolerance
changes.

### Determinism regression test

`test_nbody_determinism.cpp` runs the same N=2 seed twice in one binary and
asserts `==` across all six r/v components of every body after ~1000 Yoshida4
substeps — Earth and Moon masses at roughly lunar separation, `mu_central = 0`,
so the only force is the mutual write-back and the locked order fires every
substep; it also asserts the bodies moved (no vacuous pass on a frozen
state). A second case pins order-stability: the same two bodies fed in two
different input orders, each sorted into canonical id order before
integrating, produce bit-identical trajectories — pair-visit order belongs
to the table, not the caller. The harness drives `step<Yoshida4>` +
`compute_accelerations` directly through the worker's callback shape (the
worker hardcodes `active = 1`). Phase close-out: Release, Debug, and TSan
(`halt_on_error=1`, suppressions scoped to seqlock functions — the new
force path ran unsuppressed) each 170/170 with an identical 71-entry ctest
surface.

## Why it was built this way

- **Direct O(N²), no tree/FMM.** Barnes-Hut/FMM force error is θ-controlled
  and non-conservative — it injects artificial periastron precession and
  breaks the separable Hamiltonian the symplectic integrators depend on; at
  solar-system N the exact sum costs microseconds.
- **No Plummer softening.** Softening corrupts exactly the close-flyby
  dynamics players scrutinize; close approaches are an integrator problem
  (Phase 20's adaptive fallback), never faked in the force law.
- **Same-binary first.** Bit-identical reproduction is achievable with a
  fixed summation order under pinned rounding and no FMA contraction;
  cross-platform bit-identity is not (libm and codegen differ), so a
  separate physical-tolerance contract for cross-platform reproduction is
  deferred to Phase 21.
- **Symmetric `i<j` over per-`i` full inner sums.** Halves force evaluations
  via Newton's third law and leaves exactly one pair-visit order to pin.

## Where it is now (drift since 2026-06-08)

- **2026-06-10, M0.4 gate:** masses repinned as GM_DE440/G by construction
  so the kernel's `G·(GM/G)` product cancels G to ≤1 ULP — the shipped
  `M_SUN` had mixed DE441 GM with CODATA-1986 G, effectively 2.6e-4 too
  strong.
- **2026-06-10:** the outer-`i`-only gate was itself wrong — a
  non-gravitating body at slot 0 is never visited as `j` and silently
  received zero force (0 vs 8.13 m/s² by slot order); replaced with
  per-side gates, all-gravitating operation order byte-identical.
- **2026-06-10:** mutually non-gravitating pairs short-circuit before the
  distance math — removing `1/0 = +Inf` on coincident no-force pairs; the
  all-gravitating path untouched.
- **2026-06-15, M0.5 Phase 26:** kernel split into two blocks —
  active-active verbatim loop (bound `n → n_active` only) plus a
  test-particle block summing gravitating actives — determinism verified,
  file under byte-identity lock.
- **2026-06-24:** `GravConstant`/`CentralMu` strong types — a transposed
  G/μ call is now a compile error; byte-preserving.
- **2026-06-25, M0.6 gate:** fail-closed scratch/output size guards on the
  kernel entry.
- As of 2026-07-21, `engine/src/nbody_force.cpp` is the engine's locked
  deterministic force kernel; the WH (M0.6) and HJS (M0.7) tiers sit above
  it, and every determinism pin still resolves to the pair-visit order this
  phase fixed.
