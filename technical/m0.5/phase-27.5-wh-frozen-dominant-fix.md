# M0.5 Phase 27.5 — WH Frozen-Dominant Fix: Technical Deep-Dive

> Retroactive technical devlog. **Inserted phase** — not in the
> original M0.5 roadmap, opened same-day against a bug Phase 27's Pareto
> benchmark surfaced. Code shown **as built on 2026-06-15**; the drift
> section notes what carried forward.

## Starting point

Phase 27's fixed-accuracy Pareto sweep measured WH's `|dE/E|` floor on the
production 5-body SSB initial conditions at ~2.7e-5 — step-independent and
growing secularly with horizon, against Yoshida4's flat ~1e-13. A correct
symplectic map's error is bounded; a floor that grows with simulated time
is a modeling defect. A barycenter-drift probe confirmed it: the Sun's
position and velocity moved **exactly zero** across 2000 steps while the
system barycenter drifted ~1.7×10⁹ m. `main.cpp` was reverted to Yoshida4
the same session; this phase fixes the transform.

## What was built

### Fix 1 — COM-anchor the dominant body

The democratic-heliocentric transform stored the dominant body's absolute
position and velocity verbatim and restored them the same way — an exact
algebraic inverse, anchored to the wrong invariant. The correct
anchor is the barycenter. `to_democratic_heliocentric` now stashes the two
conserved quantities in the dominant slot instead of its raw state:

```cpp
// helio[dom].r = R_com = (Σ mₖrₖ)/M_total   (mass-weighted barycenter)
// helio[dom].v = P_total = Σ mₖvₖ            (total momentum)
// — both sums over ALL bodies, canonical slot order, +−×÷ only.
```

`from_democratic_heliocentric` rebuilds the now-moving dominant from them:
`r_dom = R_com − (Σ_{i≠dom} mᵢQᵢ)/M_total`, `v_dom = (P_total −
Σ_{i≠dom} mᵢvᵢ)/m_dom`. The kick, drift, and jump operators were untouched
— they were already correct; only the boundary transform was wrong. The
round-trip lock relaxed the dominant slot from bit-exact `==` to a few ULP
(reconstruction round-off, a sanctioned relaxation) while
non-dominant slots stayed bit-exact. The symplecticity fixture set was
hardened with eccentric (e 0.15–0.3) and inclined (~3–11°) cases, boosted
to their COM frame — the fixture verified to **fail on the old
frozen-Sun code** (max `|dE/E|` 1.23e-3) and pass after the fix. A new
COM/momentum no-drift lock measured the barycenter and total momentum
holding to roundoff (~3e-15) over ~634 simulated years, against ~7.5e-4 /
~2.7e-3 drift on the old code. The production floor dropped
2.67e-5 → 2.0e-5 and lost its secular signature — bounded,
step-independent, a genuine WH floor.

### The fix didn't win the Pareto (still)

WH beating Yoshida4 at matched accuracy on the production fixture was the
bar. It didn't clear it — 2.0e-5 is still nine orders above
Yoshida4's ~1e-13 on this fixture. The production seed stayed on Yoshida4
rather than re-flip to a "fixed" WH that still loses, and a single-purpose
diagnostic probe (discarded after use, not shipped) decomposed the
residual: a clean COM-frame two-body conserves to ~1e-5 at the shipped
step; a Sun-at-rest two-body similarly; but an artificially bulk-boosted
two-body (Sun moving ~12 m/s) jumped to ~2e-3 — 170× worse. The floor
scales with the system's *frame* velocity — not with the COM-anchor fix
above.

### Fix 2 — run the map in the COM rest frame

Root cause: the Kepler drift advances each body's velocity using its raw
barycentric value, and the jump term only handles the dominant body's
recoil — neither absorbs a bulk translation of the whole system. The
split is energy-conserving only in a zero-net-momentum frame, the standard
WHFast precondition. The shipped 5-body table is a subset of the real
solar system, so it carries the omitted planets' net momentum — a small
but nonzero `v_com` baked into every velocity, which is exactly what the
decomposition probe measured. `wh_step` now wraps the whole map:

```cpp
// v_com = (Σ mₖvₖ)/M_total, summed in canonical slot order (+−×÷, no libm).
// Subtract v_com from every velocity BEFORE the transform (run in the COM
// rest frame — where WH is symplectic); restore the bulk drift AFTER:
//   r[k] += v_com * dt;   v[k] += v_com;
```

For a massless test particle about a stationary dominant, `v_com = 0`
exactly, so the two-body-equals-`kepler_step` reduction stayed bit-for-bit
preserved. The production floor dropped again, 2.0e-5 → **4.4e-8** (~455×);
a boost-invariance lock confirmed a +30 km/s system now measures 8.1e-12
instead of 7× worse. The Pareto's flat-floor gate — which had encoded the
frozen-dominant bug as a passing assertion — was replaced with an honest
correct-integrator gate (every point under 1e-6, error growing with step,
not flat), and the WH golden vectors were regenerated a second time
against the COM-frame map. Even after this fix, WH still does not beat
Yoshida4 at matched accuracy on the small-N production fixture — the same
result held again, and the seed stayed on Yoshida4 (Phase 27 closes
that finding).

## Why it was built this way

- **Fix the invariant, not the symptom.** The first fix targeted the
  visibly wrong thing (a frozen Sun); the residual probe showed the deeper
  invariant — the whole map needs zero net momentum, and position-only
  correction can't provide that (energy is Galilean-position-invariant, so
  moving the COM's position can never change `|dE/E|`).
- **Report the honest result rather than declare victory on a partial
  fix.** Reporting "still not faster" honestly after the first fix is
  what surfaced the deeper frame-velocity root cause, instead of stopping
  one fix short of it.
- **Golden vectors are a determinism guard, not a physics oracle.** Both
  fixes changed the WH trajectory bits, so both re-froze the golden table
  — expected, since the table pins reproducibility, not correctness.

## Where it is now (drift since 2026-06-15)

- **2026-06-15, Phase 27 close:** with WH now correct, its genuine
  advantage is characterized as time-warp (large step), not small-N —
  Yoshida4 ships; this phase's fix is what made that finding trustworthy
  rather than moot.
- As of 2026-07-21 the COM-frame wrap in `wh_step` is unchanged and the
  boost-invariance lock remains green; the production seed has not
  re-flipped to WH, per the Phase 27 finding this fix enabled.
