# M0.5 Phase 26 — Massless Test-Particle Tier: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-15**; the
> drift section traces the tier through Phase 27's benchmark and forward
> into M1.1's craft tier.

## Starting point

The test-particle *physics* already shipped by M0.4: the per-side
`gravitating` gate in `compute_accelerations` (`nbody_force.cpp:84-85`,
landed for an earlier fix) already lets a body feel gravity from
gravitating actives while sourcing none. The kernel's header even named the
future use case — "a non-gravitating / massless body is integrated and
FEELS force but exerts none — the deferred craft tier's test-particle
path" (`nbody_force.hpp:57-59`). What was missing was the *cost guarantee*.
The kernel still ran a single `i<j` loop over all N bodies and skipped
test-test pairs with `if (!gi && !gj) continue;` — correct, but still
O(N²): the outer loop visited every test-test pair and threw the result
away. The requirement this phase closes is that that work be structurally
absent, not branched away. Phase 26 is a **cost-and-contract** phase, not a
new-physics phase: partition the bodies so test-test pairs are never
visited, and make the partition (`N_active` / `testparticle_type`) an
explicit, validated contract on the worker.

## What was built

### The two-block force kernel

`compute_accelerations` gained an `n_active` parameter (placed after
`mu_central`, before `accel_out`) and split into two sequential blocks. The
first is the existing active-active `i<j` loop with its bound changed from
`n` to `n_active` — every other line, including the per-side `+=`/`-=` and
the locked `inv_r3 = 1.0 / (r2 * std::sqrt(r2))` form, is untouched. The
second is new — a test-particle block, locked structurally:

```cpp
// BLOCK 1 — active-active: bound changed n -> n_active, nothing else.
for (std::size_t i = 0; i < n_active; ++i) {
    for (std::size_t j = i + 1; j < n_active; ++j) {
        // ... byte-for-byte the existing kernel body ...
    }
}
// BLOCK 2 — test particles [n_active, n): feel gravitating actives only.
for (std::size_t t = n_active; t < n; ++t) {
    for (std::size_t j = 0; j < n_active; ++j) {        // actives only
        if (!props.gravitating(j)) continue;
        const auto dr = states[j].r - states[t].r;
        const double r2 = dr.dot(dr);
        const double inv_r3 = 1.0 / (r2 * std::sqrt(r2));
        accel_out[t] = accel_out[t] + (G * inv_r3 * props.mass(j)) * dr;
        // no write-back to accel_out[j]; no inner test-test loop
    }
}
```

The load-bearing property is structural, not incidental: when `n_active ==
n` (every existing M0.2/M0.3/M0.4/Phase-23/24 lock, all of which seed
all-active tables), Block 2's loop bound is empty and the output is
byte-identical to the pre-Phase-26 kernel. `test_testparticle_determinism.cpp`
pins this directly — a 5-active table run at `(n_active=5, n=5)` vs the
same table with 15 test particles appended run at `(n_active=5, n=20)`
asserts `accel_out[0..5)` bit-equal (`==`, not `Approx`) across both runs,
plus a partition-permutation guard (re-ordering the 15 test slots leaves
the active block unchanged) and a same-binary A==B rerun.
`test_testparticle_force.cpp` covers the two contract requirements: a test
particle in a known field reproduces the analytic acceleration and a
gravitating active feels nothing back from a test particle; and two test
particles' recorded accelerations are independent of each other's position
— a test-local pair counter, never in-kernel instrumentation, confirms the
visit count is `n_active·(n_active−1)/2 + n_active·(n−n_active)`, strictly
below the all-pairs `n·(n−1)/2` once `n > n_active`.

Every caller at this point still passes `n_active = states.size()` — the
kernel is partition-aware without any behavior change yet; threading
the real cut through the worker comes next.

### The worker contract

`Config` gained `n_active` (a `0` sentinel means "all bodies active",
preserving the M0.4 seed exactly) and a `TestParticleType` policy enum with
a single value, `FeelOnly = 0`. REBOUND's own test-particle example
distinguishes `testparticle_type=0` (feel-only) from `=1` (semiactive —
also perturbs the actives); Phase 26 ships only the former. Making type-1
*unrepresentable* in the enum, plus a `std::invalid_argument` throw on any
raw request for it, was the deliberate choice over silently ignoring it —
a future caller asking for semiactive back-reaction gets a loud "not
implemented" rather than quietly getting feel-only behavior it didn't ask
for. The ctor also validates seed consistency: every slot below `n_active`
must be gravitating, every slot at or above it must be non-gravitating
with `mass == 0.0`, or construction throws.

`detect_regime`, the dominant-mass scan, and `system_energy` all narrowed
to `.first(n_active_)` on both the state and body-props spans — a test
particle has `mass = 0` so it could never win the dominant-mass scan
anyway, but leaving it in the Hill-radius pair loop risked a stray probe
flyby dragging the whole system into an O(N) IAS15 window, and leaving it
in the energy sum risked distorting the conserved quantity Phase 25's gate
depends on. The snapshot's `FrameMeta.count`, by contrast, stays at the
total body count — the renderer wants to draw the probes even though the
physics gate doesn't count them.

Before any of that code changed, a read-only check confirmed whether
Phase 24's `wh_step` drift loop already iterates every slot in
`states_`, or only the active ones. It does — `step<M>`/`wh_step` advance
the full span unconditionally, so a massless test slot Keplers about the
dominant mass for free, with zero new integration code. A live end-to-end
lock then drove the worker: a test particle placed on a close flyby of an
active does not flip the regime out of REGULAR (the detector never sees
it), and running the same active seed with and without appended test
particles for K steps produces bit-identical active trajectories.

## Why it was built this way

- **Cost partition by loop bound, not by branch.** A `continue` inside a
  full `i<j` sweep still visits every pair; the guarantee needed is that
  test-test pairs never enter the loop at all. Bounding Block 1 by
  `n_active` and giving Block 2 its own restricted inner loop is the only
  shape where the cost guarantee is structural — enforced by the loop
  bound, not by branch prediction.
- **Contiguous partition over a scattered flag.** A per-body `is_test` flag
  anywhere in the slot range would force a filter *inside* the active
  block, changing its accumulation order — which breaks bit-identity even
  when the physical result is unchanged. `[0,n_active)` / `[n_active,n)`
  keeps the active block a textual superset-free copy of the existing
  kernel.
- **Type-1 deferred, not built.** A pure forward-compatible enhancement
  with no compounding-weakness risk can be deferred.
  Feel-only has zero back-reaction, so the active block's byte-identity
  can't be threatened by a test particle regardless of what a future type-1
  does; semiactive back-reaction is a genuinely new numeric surface (its
  own summation-order lock, its own review) that no M0.5 requirement
  needs.
- **Ride the existing integrator, not a bespoke one.** A massless body is
  symplectically integrable by the same WH map that integrates the actives
  — it Keplers about the dominant mass exactly and picks up the
  interaction kick from Block 2. Building a separate feel-only integrator
  would have duplicated that machinery for no benefit.

## Where it is now (drift since 2026-06-15)

- **2026-06-15, Phase 27:** the test-particle scaling benchmark
  measured the two-block visit count against the production kernel
  directly, confirming O(n_active·N) empirically against the exact pair
  formula this phase derived.
- **2026-06-16, Phase 29:** the review found that the *active-active* force
  loop (still O(N²) on actives, unrelated to this tier) was a deferred
  spatial-partition item for M1.0 scale — the test-particle tier itself
  was not a finding; its own requirements closed clean.
- **M1.1:** the bound-warp session loops (spacecraft warp enter/exit/export)
  iterate the HJS tree's body count rather than every slot — the same
  discipline this phase established (bound the loop to the set that
  matters, leave the rest as high slots) carried into the craft tier the
  Phase-26 header comment had named as the eventual consumer.
- As of 2026-07-21 the two-block kernel and the `n_active`/`testparticle_type`
  contract are unchanged; type-1 semiactive remains the one open,
  explicitly-logged deferral, gated on craft-tier gravity.
