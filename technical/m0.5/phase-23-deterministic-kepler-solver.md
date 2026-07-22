# M0.5 Phase 23 — Deterministic Kepler Solver: Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-06-14/15**;
> the drift section traces `kepler_universal.{hpp,cpp}` through today's
> stack.

## Starting point

M0.4 closed with the exact O(N²) direct-force n-body loop and a whole-system
IAS15 fallback for close encounters — both fixed-step. Time-warp needs
bigger regular-regime steps than a fixed-step symplectic integrator can
take without energy drift; M0.5 scope research found the real lever is a
Wisdom-Holman (WH) symplectic base, replacing the two-body drift
with an analytic Kepler solve so a step can span most of an orbit instead of
a small fraction of one. That analytic solve is the whole of Phase 23 —
built and math-locked as a standalone pure function before Phase 24 wires a
WH map onto it, because it carries the milestone's single biggest risk:
regime-selection or iteration-count nondeterminism. The contract locked was
a near-parabolic-safe Kepler step: `(x0, v0, dt, k=μ) → (x, v)`, with no
worker/threading/render change.

## Why universal variables

A Kepler solver classically needs three different anomaly variables (E, D,
H) for the ellipse, parabola, and hyperbola. The universal-variable
formulation (Sundman; Stiefel/Scheifele; Vallado's textbook form) replaces
all three with one anomaly `χ` and one energy-like parameter:

```
β = 2/r0 − v0²/k        (β>0 elliptic, β=0 parabolic, β<0 hyperbolic)
```

with propagation controlled by Stumpff functions `c0(z)..c3(z)` at
`z = β·χ²`. One code path, no regime branch — a regime branch would be a
data-dependent branch. A doc-comment plus a representative-point test pins
the `β` convention, because the literature also uses `β = k/a`, which is
`k`× larger and silently wrong here.

## Why the Stumpff series, not det_sin/det_cos

The M0.5 scope-lock originally named hand-rolled `det_sin`/`det_cos` for
this phase — the closed Stumpff forms are `c2 = (1−cos√z)/z`,
`c3 = (√z−sin√z)/z^(3/2)`. Deep research on 2026-06-14 reversed that:
`det_sin`/`det_cos` need deterministic argument reduction — Cody-Waite
at minimum, Payne-Hanek for large arguments — a materially larger
deterministic surface. And the closed forms are ill-conditioned exactly
where the solver spends most of its time: as `z → 0`, `1 − cos√z` subtracts
two nearly-equal values — catastrophic cancellation.

The alternative, REBOUND's `stumpff_cs`, computes `c0..c3` as a power series
in `z`, pure `+ − × ÷`. `√z` never appears — `z = βχ²` is already the
square. It stays clean at `z → 0` by construction (`c0→1, c1→1, c2→½,
c3→⅙`) because the series is built from that limit outward, not approached
by subtraction.

`det_stumpff` (`kepler_universal.cpp:68`) ports the *structure*, not a
literal transcription — an initially-tried `cs4`/`cs5` recurrence diverged
at moderate `z` (−0.0949 vs oracle −0.0933 at z=21.3) and was replaced with
the equivalent Stumpff doubling identities:

```cpp
unsigned n = 0;
while (z > 1.0 || z < -1.0) { z *= 0.25; ++n; }   // exact power-of-2 reduction

double cs3 = kInvFactorial[19];                    // order-17 Horner, left-to-right
double cs2 = kInvFactorial[18];
for (int j = 17; j >= 3; j -= 2) {
    cs3 = kInvFactorial[j]     - z * cs3;
    cs2 = kInvFactorial[j - 1] - z * cs2;
}
for (unsigned i = 0; i < n; ++i) {                 // quarter-angle reconstruction
    scratch[3] = (old2 + old0 * old3) * 0.25;       // c3(4z) = (c2 + c0·c3)/4
    scratch[2] = (old1 * old1) * 0.5;               // c2(4z) = c1²/2
    scratch[1] = old0 * old1;                       // c1(4z) = c0·c1
    scratch[0] = 2.0 * old0 * old0 - 1.0;           // c0(4z) = 2c0² − 1
}
```

Quartering by `0.25` is exact (power of two, no rounding); the
reconstruction is Horner-evaluated left-to-right (never Estrin —
reassociation changes rounding). `kReduceLimit = 1.0` (not REBOUND's
`0.1`) keeps the whole Kepler hot path (`|z| ≤ 1`) on the direct order-17
Horner with zero doublings — the load-bearing ≤1-ULP claim. Measurement
also showed a flat "≤1 ULP across [−50,50]" bound isn't measurable:
doublings amplify rounding, and near a zero-crossing a picoscale absolute
error spans millions of ULP (the metric is degenerate at a zero, not a
sign of error). The lock split into a strict ≤1-ULP hot-path band and a
combined ULP-or-1e-11-absolute wide-sweep band — calibrate against
measured reality, don't weaken the meaningful bound.

## The seed, and a conditioning bug in the time equation

`kepler_step` seeds `χ` two ways, switched on a pure function of the input
state — never on convergence: the Vallado generic guess `χ = √μ·dt·α` in
the benign regime, or the Mikkola (1987) cubic seed (elliptic-only, clamped
`e ≤ 0.999`, ~3 significant figures across the whole elliptic band)
near-parabolic or at a large step. Mikkola's cube root routes through the
existing `det_cbrt`, not `std::cbrt`.

The literal time equation, `F = r0·G1 + η0·G2 + k·G3 − dt`,
solves for `χ ≈ dt/r0 ~ O(1e-6)` at heliocentric scale — ill-conditioned.
Measured: the `dt`/`−dt` round-trip degraded as `~dt⁴` (2.2e-8 at dt=1 day,
three orders above the 1e-13 bar), N-independent across N=1..12 — proof it
was conditioning, not truncation. The fix swaps to the equivalent,
well-scaled Vallado/Stiefel formulation (`χ ~ O(1e3..1e4)`), which
round-trips bit-exactly, with every locked invariant unchanged: geometric
`β`, the `det_stumpff` leaf, one branchless `α` path, the two-tier seed, and
`f·gdot − fdot·g == 1` (~1e-13).

## Why FIXED iteration count is the determinism core

REBOUND's Danby-quartic corrector runs until a tolerance or an FP-`==`
comparison says "close enough," with a bisection failsafe — rejected here.
A tolerance or `==` exit makes the loop's iteration count depend on
the input's bits: a 1-ULP difference between builds (compiler, FMA
contraction, libm) can flip whether one more iteration runs, and a
diverging op count means diverging final bits. Determinism dies at that
branch, not at any single arithmetic operation.

The fix is `for (i = 0; i < iters; ++i)` with no break, no tolerance, no
`==`, no bisection — the identical operation sequence runs every call
(confirmed via same-binary A/B bit-identity, `==` not `Approx`). The only
data-dependent branch left is the seed-band selector, a pure function of
input state — identical calls always take the identical branch.

Fixing the count doesn't guarantee it's *enough*, though. A full-domain
sweep (`e ∈ {0..0.999}`, hyperbolic `{1.001,1.1,2,5}`, parabolic-grazing
`e=1±1e-6`) showed the fixed-count Danby-quartic design didn't hold up: it
diverges for `e ≥ 0.9` away from periapsis, `e ≥ 0.99` at WH-realistic
steps, and hyperbolic — and a higher count made it *worse* (no
global-convergence guarantee from a seed landing ~5000× off true `χ` near
high-e periapsis). Surfaced here, standalone, instead of as unexplained
energy drift inside the WH map three phases later — the reason the phase
was front-loaded.

The fix is Laguerre-Conway order `n=5` (Conway 1986; Numerical Recipes
§9.5), globally convergent for Kepler's equation. Where Newton/Danby step by
`F/F'` alone, Laguerre-Conway adds curvature, the denominator-sign choice
`Fp + sgn(Fp)·√|h|` (chosen to maximize `|denom|`) being data-on-state —
the same determinism class as the seed-band select, not a convergence
check. Prototype LC n=5 cleared the entire in-domain grid at N=8 where the
Danby quartic cleared none.

**Locking N on symplecticity, not residual.** The fixed count is set
by running the two-body map for thousands of periods and checking the
long-horizon energy-error trend, not single-step residual. WHFast §2.7's
reasoning: an under-iterated corrector still returns a finite state every
step, but the leftover error is **biased** — it accumulates one direction,
so total energy error grows *linearly* with time (`|ΔE/E| ~ t`). A
converged symplectic map instead random-walks, growing only as `√t`
(Brouwer). Single-step residual can't tell "small and random" from "small
and one-sided."

A 4000-period test fits `log|ΔE/E|` vs `log t`, requires the low-e slope
near ½ (rejects ≈1) — measured 0.314, peak `|ΔE/E|` 1.9e-13 (e=0.1) to
8.8e-12 (e=0.9). It also ran the map at N, N+4, N+8 and required
byte-identical output: if raising N changes nothing, the corrector has
reached its fixed point and the residual growth is round-off, not
truncation. That confirmed **N=8** (worst orbit e=0.99 near periapsis,
sweep margin 0.057), replacing the "PROVISIONAL" marker in the header.

**The cross-platform guard.** `-ffp-contract=off` is a repo-global flag, not
a pragma — GCC ignores `#pragma STDC FP_CONTRACT`, so the flag is the only
lever against silent FMA contraction (GCC/Clang/MSVC default it three
different ways). Necessary but not sufficient: a frozen 7-case golden-vector
table of exact IEEE-754 bit patterns is asserted `==` on every CI lane —
the check that catches a divergence. A configure-time `FATAL_ERROR`
backstops it if `-ffast-math`/`-Ofast` ever slips in.

## Where it is now (drift since 2026-06-15)

- **Phase 24 (2026-06-15)**: WH's KDK drift step *is* `kepler_step` — a
  lock asserts a massless test particle's propagation equals
  `kepler_step(dt)` bit-for-bit. Phases 25/26 (same day): the predictive
  periapsis trigger and the test-particle tier both ride the same path.
- **Phase 29 (2026-06-16)**: the fixed-N corrector returns a
  finite-but-*wrong* state when a step spans more revolutions than its
  convergence domain covers (`e=0.5` at 12 rev/step gave `|dE/E|=3.97` at
  N=8 — the earlier sweep sampled only 0.37 of a period and missed it).
  `kKeplerIterations` raised **8 → 12** (byte-identical for every
  converged input, per the N+4-invariance test); a production
  `kepler_consume_worst_residual()` health signal makes an out-of-domain
  solve observable. The same pass consolidated `det_sqrt`, hand-copied
  into three TUs, into one canonical `det_math.hpp`; `det_stumpff`'s
  `double cs[4]` became `std::array<double,4>&` (a decaying pointer had
  no enforced extent).
- A later fix: `__builtin_memcpy` in `det_sqrt`'s bit-seed had no MSVC
  equivalent — switched to portable `std::memcpy`.
- **Phase 34 (2026-06-24)**: the test seams from the earlier sweeps became
  `thread_local`; the WH worker boundary rejects non-finite/non-positive
  dominant mass before `kepler_step`; the domain claim was narrowed to
  exclude subnormal `r0` (already unreachable for a physical orbit).
- As of 2026-07-21, `kepler_step` is the Kepler-drift primitive for every WH
  tier shipped since, including the nested (HJS) map added in M0.7 for
  satellite dynamics — the fixed-N Laguerre-Conway corrector and
  `det_stumpff` are unchanged since the N=12 re-lock.
