# M0.8 Phase 44 — J2 Zonal-Harmonic Oblateness: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-12**; a
> drift section at the end tracks what changed since and why.

## Starting point

Two perturbation corrections were owed to the engine's locked Newtonian
kernel: 1PN relativistic terms and J2 oblateness. Phase 44 is the first of
the two — an oblate primary's equatorial bulge pulls a satellite off a pure
Kepler ellipse, and nine bodies in the catalog (Sun, Mercury through
Neptune) are oblate enough for it to matter. The perturbation has to enter
additively on `nbody_force.cpp` — the locked deterministic force kernel —
through the existing perturbation paths (the WH flat kick, the HJS nested
kick, the IAS15 force evaluation) and leave every point-mass body
byte-identical off-path.

## A parallel table, not a field on the locked struct

`OblatenessProps` is slot-indexed 1:1 with `BodyProps`, but it's a separate
struct in a separate table (`engine/include/interstellar/physics/
oblateness.hpp`) — `nbody_force.hpp`'s locked types gain nothing:

```cpp
struct OblatenessProps {
    bool has_j2{false};
    double j2{0.0};
    double r_eq{0.0};
    coords::Vec3f64 spin_axis{0.0, 0.0, 1.0};
};
```

`has_j2` is a presence flag, not a `j2 = 0.0` sentinel. A point-mass body
never enters the J2 loop at all — `apply_j2_accelerations` and
`oblateness_kick` both iterate `obl.size()` rows and skip any row where
`has_j2` is false, so an all-absent table runs zero floating-point
operations. That's the whole bit-identity proof: it's a property of
control flow, not of the arithmetic evaluating to zero. A compute-anyway
`j2=0.0` path would still execute the kernel's `+`, `*`, and `det_sqrt` calls
— and `x + (-0.0)` flips a sign bit under IEEE-754, so "zero" and "absent"
aren't provably the same bytes unless the zero case never runs.

Also missing: an `id` field. An early shape sketch had one, but `BodyProps`
already owns the slot identity and the span index *is* the canonical order
— a second id column would be a second source of truth for the same slot,
dropped as a deliberate design choice.

## One kernel, every tier

`j2_pair_accel` is defined exactly once, out-of-line in
`oblateness_force.cpp`, and every tier — WH, HJS, the worker's direct-force
callback — calls the same compiled definition rather than three hand-copies
that could drift apart (the precedent: `det_sqrt`'s single-definition rule
from M0.5). Its arithmetic is locked the same way — changing the `dr` sign,
the prefactor grouping, or the operation order requires re-verification
against the lock:

```cpp
coords::Vec3f64 j2_pair_accel(coords::Vec3f64 dr, coords::Vec3f64 s_hat,
                              double g_m_o, double j2, double r_eq) noexcept {
    const double r2 = dr.dot(dr);
    const double r = det_sqrt(r2);
    const double inv_r5 = 1.0 / (r2 * r2 * r);
    const double z = dr.dot(s_hat);
    const double f1 = 1.5 * g_m_o * j2 * (r_eq * r_eq) * inv_r5;
    const double c2 = (z * z) / r2;
    const double f2 = 5.0 * c2 - 1.0;
    return (f1 * f2) * dr - (f1 * (2.0 * z)) * s_hat;
}
```

This is the ŝ-projection form: REBOUNDx's `gravitational_harmonics.c`
computes the same acceleration over a rotated triad (û, v̂, ŵ), where the û
and v̂ components share one coefficient and only the ŵ=ŝ component differs
by exactly `-2z·ŝ` — so the triad collapses to a basis-free projection onto
the spin axis, no rotation matrix built at all, one `det_sqrt`, no libm. `dr
= r_target - r_source` is the locked sign convention; `g_m_o` is `G·mass`
formed from the source's row each call. The catalog stores no precomputed
column for it, keeping the catalog pure measured data and mass
single-sourced in `BodyTable`.

There's no softening, mirroring the existing Newtonian kernel's convention —
a coincident pair produces `inv_r5 = +Inf`, which propagates to the caller's
finiteness check rather than being swallowed by an epsilon offset.

## Catalog: two ways to get the constant right and still be wrong

The catalog carries nine rows — Sun plus Mercury through Neptune — each
transcribed from a primary source with citation and epoch in a trailing
comment. Two pairing mistakes are called out by name as guardrails, both
present in the catalog's own comments:

- **The reference radius has to match the solution it came from.** Saturn's
  Cassini-derived J2 (`1.6290573e-2`, Iess et al. 2019 Science) is normalized
  to `R_ref = 6.0330e7` m — the 60,330 km solution radius, not the 60,268 km
  IAU shape radius. Neptune's is worse: Jacobson's J2 pairs with 25,225 km,
  3.7% off the 24,764 km IAU value, enough to move `J2·R_ref²` by 3.7% if
  swapped.
- **Mission gravity products publish normalized `C̄20`, not J2.** Mercury,
  Venus, and Mars ship `C̄20` from their gravity solutions; the catalog
  stores `J2 = -√5·C̄20` — a sign flip combined with a √5 factor — with both
  the normalized and unnormalized values in the comment for cross-check.

Spin axes are frozen J2000 unit vectors in the engine's ICRF equatorial
frame, derived from each body's pole right ascension/declination
(`ŝ = (cosδ·cosα, cosδ·sinα, sinδ)`) computed offline in IEEE double and
pasted as twelve-digit literals — no trigonometry runs on the engine's
locked path. Earth's pole is the frame pole by construction, so its `ŝ` is
exactly `(0, 0, 1)`, no derived literal needed.

## The WH tier: the dominant body is a source and a target

`wh_step` gains an 8-argument overload taking an `OblatenessTable`; the
original 7-argument function now forwards to it with an empty table, so
every existing caller stays byte-for-byte unchanged. The new overload calls
`oblateness_kick` immediately after `interaction_kick` at *both* half-kick
sites — position-only kicks commute, so appending J2 there preserves the
KDK's time symmetry without touching the locked interaction-kick loop.

The subtlety is the dominant (Sun) slot. In democratic-heliocentric
coordinates the dominant body's position and velocity don't store real
state — they store the barycenter and total momentum — so it can't be
naively included or naively excluded from the J2 loop. `oblateness_kick`
resolves it with three rules: the dominant's J2 *position* is exactly the
origin (heliocentric coordinates already center it there); the dominant
slot participates as both source (solar J2 acts on every planet) and target
(every planet's J2 reacts back on the Sun) — because Kepler drift is
point-mass only, so J2 has nowhere else to enter; and only non-dominant
slots receive an explicit velocity kick, because the dominant's compensating
velocity change is carried automatically by the existing COM-anchored
reconstruction on exit from heliocentric coordinates. Skip the dominant as
a J2 source and solar oblateness — the dominant physical effect in the
catalog — silently vanishes from the WH tier, which is why the dominant is
deliberately *not* treated like the Newtonian kick's dominant-skip.

## The HJS tier: inertial-first, gated by the same edge mask

The nested tier's `interaction_kick_masked` gets a Step-2b, inserted after
the locked Newtonian barycentric fold completes and before the existing
Step-3 matrix fold that carries barycentric accelerations into Jacobi rows:

```cpp
if (obl.size() != 0) {
    for (int o = 1; o <= N; ++o) {
        const std::size_t orow = static_cast<std::size_t>(o - 1);
        if (!obl.has_j2(orow)) continue;
        ...
        for (int t = 1; t <= N; ++t) {
            if (t == o) continue;
            if (!edge_selected(edge_mask, tree.sep[o][t])) continue;
            const Vec3f64 a =
                j2_pair_accel(xb_scratch[t] - xb_scratch[o], s_hat, g_m_o, j2, r_eq);
            a_bary[t] = a_bary[t] + a;
            a_bary[o] = a_bary[o] - (tree.m[t] / m_o) * a;
        }
    }
}
```

J2 is computed on the reconstructed barycentric positions (`xb_scratch`),
never directly on Jacobi vectors — applying it in the Jacobi frame yields a
subtly wrong precession rate, since HJS's Jacobi coordinates aren't a simple
linear rescaling of a two-body separation the way the point-mass kick is.
Computing it inertial-first and letting the same matrix fold that already
carries the Newtonian term into Jacobi rows carry J2 too keeps the transform
single-sourced. Each pair is gated by `edge_selected(edge_mask,
tree.sep[o][t])` — the exact same V_k bit its Newtonian pair uses, so a J2
pair and its Newtonian counterpart are never split across a DLL98
multiple-timestep partition boundary; splitting them would change which
Hamiltonian piece the substep ladder is integrating.

One boundary was named rather than closed: the warp↔flown handoff
corrector's B operator (`hjs_map_kick`) stays Newtonian-only, forwarding an
empty `OblatenessTable{}`. The corrector only fires on trivial (all-`n_k`=1)
ladders at warp boundaries — never the production nested seed — so a J2 term
there would be a correction to a second-order boundary refinement, below the
milestone's tolerance floor. This is a named deferral to Phase 47, tracked
explicitly rather than left open-ended.

## Bit-exact where the algebra allows it, ULP where it doesn't

The math-lock suite pins six z-axis hexfloat golden vectors — bit-exact
regression pins, each cross-checked against an in-test libm Vallado
reference to within 4 ULP before being trusted:

```cpp
{{7.0e6, 0.0, 0.0}, {-0x1.6761e84fb0f5ep-7, -0x0p+0, -0x0p+0}},
{{0.0, 0.0, 7.0e6}, {0x0p+0, 0x0p+0, 0x1.6761e84fb0f5ep-6}},
```

Two of the spin-axis symmetry properties came out bit-exact as planned:
power-of-two `r`-scaling (scaling `dr` by 2 scales the acceleration by
exactly 1/16, since `det_sqrt(4r²) == 2·det_sqrt(r²)` exactly) and
equatorial-mirror z-negation. Axis-permutation and arbitrary-rotation
invariance did not come out bit-exact, despite being expected as a
bit-exact lane: `j2_pair_accel` sums `r² = dr·dr` and `z = dr·ŝ` in a
fixed x/y/z slot order, so permuting or rotating the inputs reassociates
those sums — value-identical, not bit-identical, amplified roughly 5× through
the `r⁻⁵` prefactor. Measured worst deviation was 15 ULP for permutation and
19 ULP for rotation, magnitude-scaled; both lanes locked at 32 ULP rather than
asserted bit-exact. A genuine axis-handling bug would miss by orders of
magnitude, not a double-digit ULP count, so the property still catches what
it's meant to catch.

The one integration-level anchor is an Earth 700 km / 98.19° sun-synchronous
orbit: J2 alone should drive a nodal regression of +0.9856°/day. A
velocity-Verlet integration over 5 days recovered 0.99022°/day — 0.44% off
the analytic linearization — locked at 3% headroom. Mercury's perihelion
precession, the milestone's other J2 validation signal, was deferred to
Phase 46 rather than checked here.

## Where it is now (drift since 2026-07-12)

- **A short non-empty table gap (2026-07-13):** a short non-empty
  `OblatenessTable` — one that doesn't cover every body — applied J2 to some
  bodies and silently skipped the rest instead of refusing outright.
  `apply_j2_accelerations`, `oblateness_kick`, and the HJS Step-2b entry all
  gained a Release-mode guard that returns immediately on a short non-empty
  table (the worker constructor already rejects a size mismatch loudly; this
  defends any direct caller that bypasses it). Debug keeps the coverage
  assert it already had.
- **A documentation sweep (2026-07-13):** a validity-horizon note was
  added to `oblateness_catalog.hpp` — the frozen J2000 spin axes don't track
  each body's IAU-2015 time-linear pole precession, and the note bounds the
  resulting error (sub-1e-5 relative to the J2 force itself over the ≤50-year
  validation horizon) rather than leaving the frozen-axis choice
  undocumented.
- **Phase 47 disposition (2026-07-13):** the corrector's named deferral was
  amended to name both omitted terms — Phase 45's 1PN forwards an empty
  `PnParams` through the same `hjs_map_kick` path J2 does. Both stand as
  documented, zero-production-effect deferrals.
- **Phase 46.1 ON-flip (2026-07-12, same evening as Phase 44
  closed):** the live seed's `main.cpp` activated the full nine-row catalog
  (Mercury through Neptune, beyond the Sun/Earth/Jupiter/Mars rows Phase 44
  wired live) alongside the Phase 45 1PN worker enable — the catalog this
  phase built was fully exercised in production three phases later, not at
  Phase 44 close.
- As of 2026-07-21, `oblateness.{hpp,cpp}` and `oblateness_catalog.hpp` are
  unchanged since close — the kernel, the parallel table, and the three-tier
  wiring this phase built are what every later M0.8 phase (1PN, validation,
  Phase 47's fixes) and the shipped all-planet seed run on top of.
