# M1.2 Phase 57.1 — Engine Target Split (libinterstellar): Technical Deep-Dive

> Retroactive technical devlog. Code shown **as built on 2026-07-31**; M1.2 is
> still open, so the drift section traces what the boundary this phase stated
> picked up later in the milestone, not a milestone close.

## Starting point

The engine's build already separated into three CMake targets — a static
library (`interstellar-engine`), a sandbox executable that links it, and
several test binaries that link it too. What that separation did not have was
a name a consumer could ask for or a header list saying what it was safe to
depend on. The library's link dependencies — Vulkan, SDL2, glm, EnTT — were
all `PUBLIC`, so anything linking the library inherited the whole render
stack's compile surface for the privilege of including one physics header.
The archive itself came out as `libinterstellar-engine.a`, a name nobody had
committed to. Phase 57.1 closes both gaps: the literal artifact name a
decision that same milestone had already picked, and a header-by-header
statement of what a consumer may include.

## The rename that isn't a rename

The direct route — rename the `interstellar-engine` target to `interstellar`
so CMake's Unix `lib` prefix produces `libinterstellar.a` on its own — was
rejected on inspection. The executable target already owns the name
`interstellar`, so freeing it for the library would mean renaming the
executable too, and an out-of-repo launcher script hardcodes
the executable's build path. Renaming the exe breaks that wrapper the moment
it runs.

The change that shipped instead is a property, not a rename:

```cmake
set_target_properties(interstellar-engine PROPERTIES OUTPUT_NAME "interstellar")
```

Target `NAME` is untouched — every existing link site (the executable, four
test binaries) references it the same way it always did — but the archive
CMake emits now reads `libinterstellar.a`. GCC and Clang prepend `lib` to an
`OUTPUT_NAME`, so the library and the `interstellar` executable land side by
side with no collision. MSVC never prepends `lib`, so the same property
yields `interstellar.lib` beside `interstellar.exe` there — no per-platform
branching needed.

`build/engine/libinterstellar-engine.a` became `build/engine/libinterstellar.a`,
byte-size identical: 1,516,830 bytes on both sides of the rename. The sandbox
executable stayed at `build/engine/interstellar`, 779,104 bytes, unchanged.

## Proving nothing else moved

A property assignment touching zero source files is easy to get right and
easy to under-verify, so the phase's second half is a battery proving the
program around the new archive name is the same program.

A post-edit rebuild produced zero `Building CXX object` lines — one archive
re-link plus five executable re-links, no compilation. `ninja -t inputs
engine/interstellar` confirmed the link graph still names
`engine/libinterstellar.a` as an input. `git diff` against the root
`CMakeLists.txt` and the dependency-pin manifest came back empty; so did a
diff over `tests/`, `engine/src`, and `engine/include`. The whole change is
one added non-comment line plus a comment explaining it — no
`target_compile_options` line moved, added, or dropped.

Test discovery needed a second look. The plan's verification clause expected
Release and Debug to discover the same test count, and they don't — Release
discovers 1028, Debug 1024, and that four-test gap already existed before this
phase. Diffing the two configs' test-name sets by hand showed the gap is a
handful of cases gated behind `#ifdef NDEBUG`: they assert Release-path
graceful degradation (an undersized scratch buffer returning safely rather
than aborting) where Debug asserts instead. Cross-config equality was the
wrong gate; the right one is per-config parity — Release 1028 before the
change, 1028 after; Debug 1024 before, 1024 after. Both held, corroborated by
the same zero-recompile rebuild that makes discovery drift structurally
impossible.

A separate flag check re-swept all 210 translation units for the
`-ffp-contract=off` / `/fp:precise` pair the library's `PUBLIC` compile
options carry — 0 missing, before and after. Full-suite runs closed the
battery: 1028/1028 Release in 310.63 s, 1024/1024 Debug in 918.75 s, both
green, both unchanged from the pre-phase baseline. The deterministic force
kernel (`nbody_force.cpp`) diffed byte-identical against the last tagged
release. The Debug lane's own build directory picked up
`build-debug/engine/libinterstellar.a` at 34,234,002 bytes — a much larger
archive than Release's, as expected of an unoptimized build with debug
symbols, rebuilt link-only with zero recompiled translation units.

## Stating the boundary: Public API Surface

The second half of the phase is a document, not a code change:
`vault/project/Public API Surface.md`, which classifies every header under
`engine/include/interstellar/` into one of three tiers.

| Class | Count | What it means |
|---|---|---|
| **PUBLIC** | 11 | a consumer may include the header and use anything it declares |
| **MIXED** | 3 | a consumer may include the header but only the symbols an explicit MAY-USE list names |
| **INTERNAL** | 25 | a consumer must not include the header at all |

The inventory was taken from a live `find` over the header tree rather than a
remembered count — planning had assumed 38 headers; the tree actually held
39, and the extra one folded into the classification without changing the
process.

Two PUBLIC headers had their names resolved from the SUMMARY records of the
phases that built them rather than guessed. The element-conversion round trip
between Kepler state and elements lives in `physics/kepler.hpp` — the same
header, extended, not a new file. The craft-orbital kernel resolved to
`physics/craft_integrator.hpp`, and its published surface was enumerated
symbol by symbol: the `craft_substep` entry point and its thrust-free
overload, seven context types (`CraftPerturber`, `CraftSubstepCtx`,
`CraftKick`, `CraftBoundaryCache`, `CraftThrust`, `CraftSubstepResult`), three
helper functions, and three locked constants (`kCraftSubstepN`, `kCraftDt`,
`kCraftPerturberMode`).

`physics/worker_thread.hpp` is the interesting case — a single header that
carries both the read-only surface a HUD or map view legitimately needs and
the entire `PhysicsWorker` machinery nothing outside the worker should touch.
Its MAY-USE list: `SnapshotView`, `FrameMeta`, `AxisCommand`, `CraftConfig`,
`BurnSpec`, and the producer side of `InputRing::push()`, plus the constants a
caller cannot read those types without — clump/axis/tick-cadence limits. Its
MUST-NOT-USE list: `PhysicsWorker` and every nested type, the log-throttle
helper, the rest of `InputRing`, the internal `Page` type, drift-alarm
thresholds, the subcycle calibration block, and everything gated behind
`INTERSTELLAR_TESTING` — with an explicit note that `BUILD_TESTS` defines that
macro `PUBLIC` on the library target, so a test-enabled consumer build can
*see* those hooks even though seeing them is not permission to use them.

Two more headers joined the MIXED tier purely from following types back to
their declarations: `physics/integrator.hpp` (only its `State` type is
public — `SnapshotView::state_of` returns one), and
`physics/encounter_detector.hpp` (only `Regime`, read off `SnapshotView` and
`FrameMeta`). Two candidate headers were checked and deliberately left out of
the closure: the oblateness kernel takes J2 as bare scalars rather than a
typed parameter object, so nothing pulls its header in; and the dominance
kernel (`select_dominant`) was excluded on purpose — publishing it would let
a consumer build a second, independent dominance heuristic next to the one
the engine already treats as the only source of truth.

One classification carries a labeled exception. `coordinates/conversions.hpp`
declares functions, not types, so a strict type-closure rule leaves it
INTERNAL. But a consumer receiving `Vec3f64` positions relative to a
published `Vec3i64` origin has no way to render them without converting
through exactly this header — the alternative is hand-rolling the
int64-to-float64-to-float32 origin shift the coordinate architecture exists
to prevent. It was classified PUBLIC under an "operational closure" label,
kept visually distinct in the document from the strict-closure entries so the
exception is auditable rather than silently blended in.

The document closes with an audit of every current includer of
`worker_thread.hpp` — seven translation units, each checked against the
MAY-USE/MUST-NOT-USE tables. All seven turned out to be either the header's
own implementation, the sandbox driver (a named, temporary exception), or
code that compiles into the library itself — none is an external consumer.
Two render-tier adapters use only `SnapshotView` and one MAY-USE constant,
which is the closest thing to a real consumer in the current tree and the
named watch item for later UI phases: the day a translation unit's symbol use
contains no MUST-NOT-USE entry and isn't engine-internal machinery, that is
the forced case for splitting a narrower `SnapshotView`-only header out of
`worker_thread.hpp`.

## Why it was built this way

- **A property over a rename.** The desired artifact name was already
  possible two ways; only one of them left the executable's path — and the
  external tooling that hardcodes it — untouched.
- **Per-config parity, not cross-config equality.** Chasing a false premise
  (Release and Debug should discover the same test count) would have failed
  a correct, unchanged tree. The actual invariant a config-neutral CMake
  change can promise is that each config's own count doesn't move.
- **Type closure, walked from real signatures.** Headers didn't get
  classified from their subject matter; a header is PUBLIC only if a symbol
  it declares is reachable from something a consumer legitimately holds
  (`SnapshotView`, `FrameMeta`, the craft kernel's context types). That
  discipline is what caught `worker_thread.hpp`'s split nature and kept the
  dominance kernel out of the surface on purpose.
- **A live filesystem walk over a remembered count.** Classifying against
  whatever `find` returns, rather than a planning-time header list, is what
  let a header nobody had accounted for land correctly instead of silently
  falling through a gap.

## Where it is now

The boundary this phase stated started out as a document a human had to
trust. A later hardening pass this milestone turned the structural half of
it into a build-time gate: `tests/check_include_boundaries.py`, run at
default test tier in both lanes, walks the transitive include closure of
every PUBLIC header and fails if one reaches an INTERNAL header — directly,
or through another PUBLIC header — with the whole offending path in the
failure message rather than just the endpoint. A MIXED header still
terminates that walk, exactly as the original document specified, but its own
INTERNAL edges are now pinned to an explicit inventory: gaining or losing one
without updating the pin fails the build. The same script also checks that
every header on disk is classified exactly once, and enforces three
narrower, code-level claims that render-tier banners had been making about
themselves without any machine checking them — that one file is free of any
SDL include, that another's project includes are restricted to a two-header
allowlist, and that a third neither includes nor names a specific internal
composer type. All of it runs on comment-stripped source, so a banner that
merely *discusses* a forbidden header or type in prose doesn't trip the same
check that catches an actual include line.

`Vulkan::Vulkan` and `SDL2::SDL2` moved from `PUBLIC` to `PRIVATE` on the
library target in that same pass — both are implementation detail of the
render tier's own translation units, and making them `PUBLIC` had meant every
consumer compiled with the SDL2 and Vulkan header search paths just to
include a physics header. `glm::glm` stayed `PUBLIC`, since public headers
genuinely use `glm` types in their own signatures. `EnTT` came out of the
target entirely, unused. A `PROJECT_IS_TOP_LEVEL` guard now wraps the shader
pipeline and the sandbox executable, so a build that consumes the library as
a subdirectory no longer pays for a required `glslc` toolchain, eight SPIR-V
compiles, or a GUI executable it never asked for.

A standing consumer probe backs the document instead of just the document
asserting it: a throwaway CMake project outside the main tree pulls the
library in via `FetchContent` against the working source tree and compiles
one translation unit against nothing but `interstellar/render/projection.hpp`.
Continuous integration inspects that probe's own `compile_commands.json` for
the `-std=c++20` and `-ffp-contract=off` tokens on its compile line — proof
those arrive purely from the library's `PUBLIC` usage requirements, since the
probe project sets neither itself — and checks the probe's `CMakeCache.txt`
to confirm `glslc` was never searched for and the test subdirectory was never
configured on that path.

The header census itself kept growing as later phases in the milestone added
files: by a later point in M1.2 the same document counted 46 headers instead
of 39, all still reconciled through the same live-`find`-driven classification
process rather than a remembered number, and a second checker
(`tests/check_doc_citations.py`) now fails the build if a header on disk has
no row in the document, in either direction. One PUBLIC-to-INTERNAL edge that
had existed since before this phase — the 1PN force header reaching directly
into the locked deterministic-force-kernel header — was closed by extracting
a small internal leaf header for the type it actually needed, which is the
kind of fix `check_include_boundaries.py` exists to make permanent: the edge
cannot reopen without failing the build the moment it does.
