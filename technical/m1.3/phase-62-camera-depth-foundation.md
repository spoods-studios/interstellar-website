# M1.3 Phase 62 — Camera + Depth Foundation: Technical Deep-Dive

## Starting point

The renderer had no 3D camera and no depth buffer of any kind. Every draw call went through a 2D orthographic world→NDC helper, and `pDepthStencilState` was a null pointer at both pipeline-creation sites. Terrain LOD, atmospheric scattering, and surface-to-orbit flight all require a perspective camera and a depth strategy. Phase 62 builds the camera and locks the depth strategy with worked numbers.

## The criterion was written before the numbers

float32 depth must span a 1-metre near object to a horizon 2,300 km away in low orbit. Standard Z concentrates precision at the near plane and starves the far range. Two candidates: reversed-Z (store `near/w`, use float32's exponent structure) or logarithmic depth (remap in the shader).

The pass/fail bar was written and committed before any error number was computed. Two camera states: on the surface (near objects 1 m–10 km) and LEO at 400 km (horizon at 2,292,772.8 m). Each state has a smallest separation the buffer must resolve: 0.05 m at the surface state's 10 km ceiling, 5.0 m at the LEO horizon. Margin clause: the shipped strategy must clear each floor by at least 8×.

Reversed-Z with the far plane at infinity stores `z_ndc = near/w`. The float32 quantization error propagated back to world space:

```cpp
[[nodiscard]] inline double reversed_z_worst_case_depth_error_m(double eye_distance_m) noexcept {
    assert(eye_distance_m > 0.0 && "reversed_z_worst_case_depth_error_m: w must be positive");
    return eye_distance_m * kFloat32RelEps;
}
```

`w · 2⁻²³`. The near plane cancels out of the error. This is also measured: four near planes, including a non-dyadic 1.3 m, land in the same band around the same near-free model. The near plane ships at 1.0 m, chosen for frustum convenience.

Worked numbers: 1.1921×10⁻³ m worst case over the surface range against the 0.05 m floor — 41.94× margin. 2.7332×10⁻¹ m at the LEO horizon against 5.0 m — 18.29×. Both clear the required 8×.

Log-depth, modeled in the same currency:

```cpp
    return eye_distance_m * std::log(far_m / near_m) * kFloat32RelEps;
}
```

Log-depth meets both bare floors (1.7459×10⁻² m, 4.0028 m) and fails both margins (2.86×, 1.25×). A floor-only criterion would have passed both strategies; the margin clause selected one. Locked: reversed-Z float32 infinite-far. Log-depth is the named fallback with a quantified flip trigger, costed, never built.

`D32_SFLOAT` is not spec-mandated — only "one of `X8_D24_UNORM_PACK32` or `D32_SFLOAT`" is guaranteed. The pipeline runtime-queries the format and fails loud. A UNORM substitute would invalidate the error model, which depends on IEEE-754's floating exponent.

## The published frustum rows are wrong under reversed-Z

The camera kernel is Vulkan-free: rotation-only float64 view matrix (translation absent — the camera-relative pipeline subtracts the eye before float32 narrowing), projection delegated bit-for-bit to the depth kernel's matrix, frustum planes via Gribb-Hartmann row combinations.

Under infinite-far reversed-Z the classic near/far row combinations change: `row2` becomes `(0, 0, 0, near)` — zero normal, satisfied by every finite point, unnormalizable. The far plane is at infinity; no plane exists to extract. `row3 − row2` yields signed distance `w − near`: that is the near plane. The kernel returns five planes.

A 648-sample grid test classifies points against the planes and against what the projection actually clips. A negative control using the paper's verbatim `row2` misclassifies 50 of 648 samples.

The view basis is analytic, not cross-product `lookAt`. The cross-product form degenerates at pitch ±π/2 — straight down at the planet, straight up at space — both inside the documented pitch domain.

```cpp
    //   forward f = ( sin p,  cos p, 0)
    //   up      u = ( cos p, -sin p, 0)     f . u == 0 identically
    //   right   r = f x u = (0, 0, -1)      constant; the binormal, pointing left
```

Orthonormal by construction at every pitch.

## First depth-tested frame

The 3D view is a sibling frame entry, not a branch inside the existing 2D recorder. The map path's code is byte-unchanged; every M1.2 lock holds without re-verification. The new pass: `D32_SFLOAT` depth image on the swapchain lifecycle (resize recreates it), `depthCompareOp = GREATER_OR_EQUAL`, depth cleared to 0.0, new two-stage shader pair taking a view-projection matrix and camera-relative float32 positions.

Two integration details:

**The text overlay renders in a second, color-only rendering scope.** The HUD pipeline declares no depth attachment format; binding it inside the depth-attached scope is a dynamic-rendering format-match validation error. The frame is two scopes: scene with depth, overlay without.

**A memory barrier separates the scopes.** Rasterization order is guaranteed only within one rendering scope. The overlay's `loadOp = Load` reads the scene's color writes; without the barrier that read is unordered. Validation layers do not detect this; it surfaces as intermittent corruption on some hardware.

`M` flips between the map and a stress scene: three pairs of near-coplanar surfaces at separations `static_assert`ed above the locked floors times the margin factor, placed at the distances the scripted camera states inspect. Draw order puts each pair's far quad first, so only the depth test can produce the correct picture. Bracket keys fly the camera 2 m → 400 km through log-space blends. Result: zero shimmer at every state, validation layers clean, on hardware.

## Two defects found running the build

Both were outside the math.

**The depth-visualization ramp was inverted and compressed.** The diagnostic shader mapped `-log2(z)/40` to grey: near plane black, brightening with distance — opposite of the reversed-Z precision distribution the mode exists to show (near = high stored z = high precision) — and 40 decades of range left the visible scene in the bottom third of the ramp. Fixed: `1 + log2(z)/24`. Near bright, fading over the scene's span, background black.

**The build served stale shaders.** Shader staging next to the executable was a `POST_BUILD` hook on the exe target. A shader-only edit leaves the exe up-to-date, the copy never re-runs, and the binary loads the previous build's SPIR-V. Phase 62 contains the first shader-only edit since the shader pipeline was wired, so the defect had never fired. Fixed: per-shader `OUTPUT`-based `copy_if_different` custom commands with real dependency edges.

The depth math was proven three ways — closed form, executable assertions against the live matrix, compile-time floor checks. What broke was a copy step.

## State of the renderer

The renderer now has a perspective camera that holds float64 position and emits camera-relative float32, and a depth buffer whose worst-case error is measured at both ends of the flight envelope. The stress scene stands as a permanent regression test against z-fighting between ground and orbit. Phase 63 adds the cube-sphere mapping and the precision-composition function that put terrain geometry under this camera.
