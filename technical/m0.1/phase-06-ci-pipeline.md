# M0.1 Phase 6 — CI Pipeline: Technical Deep-Dive

> Retroactive technical devlog. Workflow shown **as built on
> 2026-04-13**; a drift section at the end tracks what changed since and
> why, from the full ci.yml commit history (9 commits to date).

## Starting point

Five phases of working code, all verified by hand on one machine. Phase 6
adds a GitHub Actions workflow (`.github/workflows/ci.yml`): on every push
to `main` or a `milestone/*` branch and every PR into `main`, a
GitHub-hosted `windows-latest` runner checks out the repo, builds with
MSVC, and runs the ctest suite. M0.1's definition of done included CI — the
bootstrap isn't "solid" if it only builds on the dev box.

## What was built

### The workflow

One job on `windows-latest` (the dev platform at the time), eight steps:

```yaml
on:
  push:        { branches: [main, "milestone/*"] }
  pull_request: { branches: [main] }
```

1. **Checkout**
2. **Install Vulkan SDK** — needed for headers, loader, and `glslc`
3. **Setup vcpkg** — pinned to a specific commit for reproducible dependency
   builds
4. **Configure CMake** — vcpkg toolchain, Release, `BUILD_TESTS=ON`
5. **Build** — MSVC
6. **Run tests** — `ctest --output-on-failure`
7. **Verify shader compilation** — asserts `triangle.vert.spv` /
   `triangle.frag.spv` exist in the build tree; Phase 3's CMake shader
   pipeline gets a standing regression check
8. **Verify validation layers** — checks `VK_LAYER_KHRONOS_validation` is
   present in the SDK install

The branch triggers encode the workflow the project still uses: milestone
branches get CI on every push, `main` is protected by PR checks.

### The headless-GPU limitation

The summary states plainly: no GPU on CI runners means no
actual rendering — the workflow can verify the build compiles with
validation enabled and the layers exist, but real validation testing
happens during local development, where layers are always-on in debug. That
division of labor — CI compiles, runs unit tests, and checks artifacts;
runtime validation needs real hardware — still holds, and it is the gap
the 2026-07 Windows-smoke-test decision closes from the
other side.

### The same-day fix

The initial workflow used the `humbletim/install-vulkan-sdk` action, which
failed on its first real run. Fix (same day): download the
LunarG installer directly with `Invoke-WebRequest`, run it silently, and
cache `C:\VulkanSDK` keyed on the SDK version via `actions/cache` — turning
the slowest step into a cache hit on subsequent runs. A week later,
the action came back with a corrected tag; the cache stayed.
The SDK install step has remained the most failure-prone part of the
pipeline (see drift).

## Why it was built this way

- **vcpkg pinned by commit.** Dependency resolution comes from one vcpkg
  revision, not "latest" — the same reproducibility posture the engine
  later applied to every third-party input.
- **Artifact checks over exit codes.** The shader step doesn't trust
  the build's exit status; it asserts the `.spv` files exist. Cheap, and it
  catches a class of failure (custom-command silently skipped) that a green
  build hides.
- **Milestone branches in the trigger list.** The
  branch-per-milestone workflow (each milestone merges to `main` by PR) was
  already in place; CI was wired to match it before M0.2 existed.

## Where it is now (drift since 2026-04-13)

ci.yml has 9 commits of history; the current file is 102 lines, two jobs.

- **2026-04-22:** vcpkg commit bumped to fix a Catch2 build failure —
  first dependency-drift repair.
- **2026-06-05:** the `linux` job added, matching the Fedora dev toolchain
  (GCC, Ninja, system SDL2/GLM/Vulkan packages, EnTT/Catch2 via
  FetchContent) — the dev machine had moved to Fedora, which flipped the
  lanes' roles: Linux became the mirror of local development and Windows
  became the cross-platform guard. The Windows lane has caught real MSVC
  breaks at nearly every milestone close since (M0.5 builtins/M_PI, M0.6
  SDK bump + `unistd.h`, M0.8 `M_PI` again).
- **2026-06-24 (M0.6 supply-chain review):** every third-party action
  SHA-pinned to an immutable commit — a mutable `@vN` tag can silently move
  to new code running with repo permissions.
- **2026-06-25 (M0.6 close):** SDK bumped 1.4.309.0 → 1.4.341.0 broke the
  Windows lane (`Vulkan_LIBRARY-NOTFOUND` at configure); reverted to
  309 with a comment explaining the pin — the SDK install step again.
- **M0.8:** the Windows lane's 2× billing multiplier exhausted the GitHub
  Actions free tier (2000 min/month); the org spending limit was raised —
  both lanes kept, cost accepted, Patreon-funded later.
- **The shader artifact check still runs on every push** — same
  `triangle.vert.spv` assertion, now alongside the full math-lock and
  cross-platform golden-vector suites that the `ctest` step grew into
  (449 tests at M0.8 close).
