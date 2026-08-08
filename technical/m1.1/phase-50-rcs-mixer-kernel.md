# M1.1 Phase 50 — RCS Mixer Kernel: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-20**;
> M1.1 is still open (currently Phase 53, no gate yet) so the drift
> section traces the kernel only through Phase 52's additive wiring, not
> a milestone close.

## Starting point

Phase 48 landed the rigid-body attitude kernel and Phase 49 the
Tsiolkovsky thrust/fuel kernel — both standalone, both kernel-first, both
verified without a `PhysicsWorker` in sight. Phase 50 owes the piece that
turns attitude and thrust into something a player can fire: a
fixed-geometry RCS thruster set that maps a desired body-frame force and
torque to duties on individual thrusters, none of which can pull.

The requirement sounds like a controls problem — build something that
"mixes" axes without letting them bleed into each other. The tempting
test for that is a closed-loop one: command a rotation,
watch the craft's simulated attitude converge, call it done. That's
exactly the trap to avoid: a controller with a sign error or a wrong
mixing matrix can still converge, worse but still converge. A
convergence test doesn't catch the difference. The phase boundary is
drawn to make that anti-pattern structurally impossible — no closed-loop
controller exists this phase, only the allocation kernel and tests against
closed-form allocation algebra. Three plans, all landing 2026-07-20.

## The allocation math: an identity, not an empirical property

The zero-cross-coupling property this phase asks for is the linear-algebra
identity `B·B⁺ = I₆` of the right pseudo-inverse, true for *any*
full-row-rank control-effectiveness matrix `B`, independent of thruster
count or layout. Nothing here needs measuring or bounding — the identity
holds exactly:

```
B⁺ = Bᵀ·(B·Bᵀ)⁻¹
```

`B` is 6×N — one column per thruster, force contribution over torque
contribution (`column_i = thrust_max_i · [d_i ; r_i × d_i]`, the
duty-fraction scaling that makes `u_i` mean "fraction of thruster i's own
max thrust"). Because `B` has 6 rows and N ≥ 6 columns, `B·Bᵀ` is a 6×6
matrix that inverts by a plain Gauss-Jordan solve — no SVD, no iterative
eigen-solve, and (Higham's forward-stability results for Gauss-Jordan
aside) no `libm` symbol beyond a single `det_sqrt` at the cold-path
unit-norm guard. Pei et al.'s NASA NTRS treatment of pseudo-inverse RCS
allocation gives the same closed form. The tests assert `B·B⁺ = I` and
its consequences directly. That's what makes them the analytic ground
truth this phase asks for rather than a controller checking itself.

Three things sit on top of that exact identity because real thrusters
can't pull and can't exceed full duty:

- **Non-negativity:** a negative unconstrained duty fires the
  *opposing* thruster instead. The opposing-pair table is built once, at
  allocation time, straight from `B`'s own columns — thruster `j` is
  thruster `i`'s partner iff its entire scaled 6-row column is the exact
  arithmetic negation of column `i` (`==`, all six rows), so the test
  checks direction, lever arm, and `thrust_max` in one comparison.
- **Saturation:** if any post-split duty exceeds 1, every duty
  scales down uniformly by `1/max(u)` — direction and the zero-coupling
  property are both scale-invariant, so this can't reintroduce coupling.
- **Rank deficiency:** a genuinely degenerate geometry (e.g. every
  thruster coplanar through the CoM, no roll authority) makes `B·Bᵀ`
  singular. Row-only partial pivoting (never column swaps) keeps each
  pivot's column tied to a fixed physical axis, so a pivot falling below
  threshold aborts construction naming the missing axis by name — `Fz`,
  not "row 2".

## What was built

### The kernel

`rcs_mixer.{hpp,cpp}` mirrors the `rigid_body`/`thrust_force`
props/free-function shape: `RcsProps` is data-only (N thrusters, each
`{r_body, d_body, thrust_max_n}`, `std::array`-backed to a compile-time
`kMaxRcsThrusters = 32` with a live `count` — zero heap by
construction). `validate_rcs_props` is the loud cold-path gate:
non-finite components, a non-unit `d_body` (checked via `det_sqrt` at 8
ULP of 1.0), or a non-positive `thrust_max_n` all throw naming the
offending thruster index.

`build_rcs_allocation` does the one-time work:

1. Build `B`.
2. Form `M = B·Bᵀ`.
3. Invert `M` via row-only partial-pivoting Gauss-Jordan on the augmented
   `[M | I₆]`.
4. Assemble `B⁺ = Bᵀ·M⁻¹`.
5. Build the exact-negation `opposing_pair` table.

`rcs_mix` is the hot path — one GEMV (`u_raw = B⁺·w`), the opposing-pair
split, uniform saturation, and a paired-order achieved-wrench readback
(`B·u`) so callers never have to recompute what was achieved:

```cpp
[[nodiscard]] RcsAllocation build_rcs_allocation(const RcsProps& props);

[[nodiscard]] RcsMixResult rcs_mix(const RcsAllocation& alloc,
                                   const Wrench& wrench) noexcept;
```

Non-finite input is a symmetric, structural no-op (the same convention
`thrust_step`'s non-finite handling established): any non-finite wrench
component skips the GEMV entirely and returns NaN duties, NaN achieved
wrench, and `non_finite_input` set — never a silent clamp.

The 10-case RED suite (`test_rcs_mixer_kernel.cpp`) landed against stubs
first. The implementation turned it GREEN with every dyadic equality on
the canonical 12-thruster cube bit-exact on the first attempt. That
cube (`thrust_max = 128 N`, face distance 2 m, in-face offset 0.5 m) is
a fixture, not baked into the kernel — but its geometry makes
`M = B·Bᵀ` come out **exactly diagonal**, `[65536, 65536, 65536, 16384,
16384, 16384]`, all powers of two, so the whole allocation for that
fixture is bit-exact dyadic arithmetic: every `B⁺` entry is `±2⁻⁹`
(force rows) or `±2⁻⁸` (torque rows). Full suite 713/713.

One early discrepancy surfaced: an initial test description gave a
saturating force of `2¹⁷ N` with an "unconstrained max duty 256" and a
stated `scale_factor == 1/256`, but saturation runs on **post-split**
duties — the pair split concentrates the pseudo-inverse's `±256` spread
across 4 thrusters into a `net = u_i − u_j = 512` on 2 thrusters, so the
correct uniform scale is `1/512 (2⁻⁹)`, not `1/256`. Post-split saturation
is the authoritative rule. The RED suite was written with the corrected
value from the start.

### Exactness locks

Test-only: zero production changes, every lock passing on the first
build because it freezes already-correct mixer behavior. Six new
`[math-lock]` cases in `test_rcs_mixer_lock.cpp`:

- Pure-translation commands (±64 N per axis) → achieved torque `== 0.0`
  on all axes.
- The complementary pure-rotation lane (±16 N·m per axis) → achieved
  force `== 0.0`.
- The saturated path locked separately for both translation
  (`2¹⁷ N`) and rotation (`2¹⁶ N·m`) — both produce `scale_factor ==
  2⁻⁹` and exact 0.0 coupling after the scale-down.
- The opposing-pair split path (three negative-axis commands) — every
  duty `≥ 0`, the idle pair sits at exactly `0.0`, achieved wrench
  matches exactly, coupling exactly `0.0`.
- A golden `==` table of all 72 cube `B⁺` entries.
- A build-determinism check — two independent `build_rcs_allocation` runs
  give bit-identical `b_plus` and `opposing_pair`.

A standalone `rcs-zero-alloc-tests` executable (its own binary, mirroring
the detector-zero-alloc precedent for ODR safety) proves
`build_rcs_allocation` plus 1000 `rcs_mix` calls across all three
allocation branches allocate zero heap, gated by a work-fired assertion
so the test can't pass vacuously. Full suite 715/715.

### General geometry + phase close

Two more lock cases extend the general-geometry lane the idealized cube
can't cover (an M0.5 lesson: symmetric-only fixtures mask structural
bugs). Case 7 uses an 8-thruster fixture with offset positions, tilted
directions, and eight *distinct* `thrust_max` values (80–150 N — the only
fixture class that catches a dropped thrust-max column scale), with
no exact-negation column pairs at all. It asserts both the pseudo-inverse
identity residual `max|B·B⁺ − I|` and achieved-wrench accuracy against an
analytic, N-aware ULP bound — `c_pivot·κ(M)·u + γ(N−1)·Σ|·|` — not a
picked-by-hand epsilon. Measured `κ(M) = 69.07` (locked `κ_M = 70`). The
identity residual came in at `1.98e-15` against a `3.34e-14` bound (~17×
headroom). Worst achieved-wrench error came in at `3.41e-13` against a
`9.4e-12` bound (~27× headroom). Commands for this fixture had to be
built as `w = B·u₀` for a strictly-positive in-row-space `u₀` rather than
pure unit axes — an 8-thruster fixture with no opposing pairs has a
6-dimensional row space that barely pierces the positive orthant
(Stiemke's lemma), so pure axis commands would have driven duties
negative and pulled the split/clamp paths into what was meant to be a
pure-rounding accuracy lane.

Case 8 calibrates the rank-rejection threshold with fixtures straddling
it from both sides: a genuinely coplanar 8-thruster geometry
(loses `Fz`/`Tx`/`Ty`, deficient pivot measured exactly `0.0`) rejects,
naming `Fz`. A near-degenerate cube (`delta = 1e-4 m` in-face offset,
smallest measured relative pivot `= delta² = 1.0e-8`) passes and returns
a finite, unflagged smoke result. `kRcsRankPivotRelTol = 1.0e-12` — the
provisional value the mixer landed with — turned out to already sit at the
log-midpoint between the `1.1e-16` unit-roundoff floor and the `1.0e-8`
side-B pivot (four orders of margin on each side), so it stayed
unchanged. Only its source comment moved from "provisional" to a locked
derivation.

This pins the summation-order convention: the opposing-pair table is the
single source of truth for both the non-negativity split and the
achieved-wrench readback. It visits thrusters in ascending index order
and sums each pair's contribution together *before* folding it into the
accumulator. The same table driving both paths is what keeps the split's
non-negativity transfer and the readback's cancellation grouping from
silently diverging. Phase-end two-lane gate: Release
722/722, Debug 718/718; `nm -u -C` libm scan on `rcs_mixer.cpp.o` clean
but for `det_sqrt`; `nbody_force.cpp` byte-untouched across the phase.

### Code review

One Warning, three Info findings, disposed same-day. The Warning was
real: `rcs_mix`'s non-finite gate only inspected the six *input* wrench
components, so a poorly-scaled-but-accepted geometry (`validate_rcs_props`
bounds `thrust_max_n` only as finite and positive, with no magnitude
cap) could inflate `B⁺` enough that a finite wrench overflows the GEMV to
`±Inf`. A subsequent `Inf − Inf` pair-split subtraction or
`Inf × 0.0` saturation scale silently folded to `NaN` — with
`non_finite_input` still reading `false`. Reproduced with a 12-cube built
at `thrust_max_n = 1e-100` (finite, passes validation) fed a `1e250 N`
wrench: `non_finite_input == false`, every duty `NaN`.

The fix adds a distinct `non_finite_output` flag rather than folding
the fix into `non_finite_input` — that flag's contract is specifically
"the GEMV never entered, every field is NaN," and overflowing partway
through the pipeline doesn't satisfy that. The new output sweep is one
more `O(n)` pass of `is_finite` checks, no `libm`, no allocation, so it
doesn't disturb the zero-alloc gate. The two Info fixes were smaller:
`kRcsUnitNormTol` now spells out `std::numeric_limits<double>::epsilon()`
instead of a hand-copied `2.220446049250313e-16` literal.
`axis_name`'s sixth case is now an explicit `case 5: return "Tz";`
instead of a silent `default:` fallthrough. The third
finding — `RcsAllocation` being a public aggregate a caller could
default-construct and pass straight to the validation-free `rcs_mix` —
was disposed `wontfix`: the kernel's whole design already trusts callers
to route `RcsAllocation` only through `build_rcs_allocation` (the same
hot-path-is-validation-free contract `rigid_body`/`thrust_force` already
carry).

## Why it was built this way

- **An identity, not a measurement.** The whole shape of this phase
  follows from treating `B·B⁺ = I₆` as something to invoke, not verify
  empirically. Once that's the frame, the exact-0.0 locks aren't
  optimistic tolerance-zero assertions — they're checking that the
  IEEE-754 arithmetic realizes an algebraic guarantee bit-for-bit for a
  fixture whose symmetry makes the cancellation exact.
- **Row-only pivoting for a naming contract.** The "reject and name
  the missing axis" requirement is why the Gauss-Jordan solve is
  constrained to row swaps only — column swaps would break the fixed
  column-to-physical-axis correspondence a caller needs to fix their
  geometry.
- **One pair table, not two.** The opposing-pair table doing double duty
  for both the non-negativity split and the achieved-wrench summation
  grouping isn't an optimization — it's what prevents the two paths from
  independently choosing different pairings and reintroducing the
  coupling the zero-tolerance locks exist to forbid.
- **Asymmetric fixtures alongside the symmetric one.** The 12-cube's
  power-of-two `B⁺` makes for a clean golden lock, but a kernel that only
  gets tested against a perfectly symmetric fixture can hide a bug an
  asymmetric one would catch (M0.5's lesson) — hence Case 7's eight
  distinct `thrust_max` values specifically targeting a dropped
  thrust-max scale bug that the cube's uniform 128 N could never expose.
- **Propagate, never scrub.** Both the input-side non-finite gate and
  the output-side overflow fix follow the same rule the `thrust_step`
  kernel already established: a non-finite result gets flagged and still
  rides through to the caller, rather than being silently clamped to
  something plausible-looking.

## Where it is now (drift since 2026-07-20)

M1.1 has not closed — no gate has landed yet — so this traces only what
has touched the kernel since, not a milestone-end reconciliation.

- **2026-07-20/21, Phase 51:** the kick seam consumes
  `RcsMixResult.achieved` to step the live Phase 48 attitude kernel and
  accumulate the achieved-force Δv — `rcs_mixer.{hpp,cpp}` themselves are
  untouched; Phase 51 only calls the locked public surface.
- **2026-07-21, Phase 52:** added a `w_max` field to
  `RcsAllocation` — a per-axis max-envelope (`w_max[k] = 1 /
  max_i(u_i)` for the post-split unit-wrench response on axis `k`)
  computed by six cold probes through the *existing* `rcs_mix` pipeline,
  so a full player input of `±1.0` maps to the largest pure-axis command
  that saturates no thruster. This is additive on the Phase 50 struct —
  every field the kernel itself locked (`b`, `b_plus`, `opposing_pair`,
  `count`) is byte-unchanged; `w_max` rides alongside as one more
  `build_rcs_allocation` output. Phase 52's
  `PhysicsWorker::attitude_tick` now builds its wrench request by scaling
  the ramped input axes by `craft_rcs_alloc_.w_max[...]` before calling
  `rcs_mix` — the mixer itself, and its lock stack, are unchanged from
  what the ramped-input work closed.
- As of this writing (engine HEAD, still Phase 53) `rcs_mixer.hpp` is
  256 lines and `rcs_mixer.cpp` is 452 — up from their initial
  landing by the overflow-guard output sweep and the two Info refactors,
  all three closed same-phase; no changes to either file have landed in
  Phase 51 or 52.
