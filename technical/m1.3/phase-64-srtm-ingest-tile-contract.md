# M1.3 Phase 64 — SRTM Ingest + Tile Format Contract: Technical Deep-Dive

## Starting point

Phase 63 locked the cube-sphere mapping. No elevation data flows through it yet. The terrain data comes from real sources — SRTM at 30 m, GMTED2010 at 450 m — and those arrive as GeoTIFFs that need GDAL, reprojection machinery, and gigabytes of intermediate processing. None of that belongs in the engine. The offline asset pipeline does the heavy lifting and the engine reads a purpose-built binary format with `std::ifstream` and nothing else. Phase 64 defines that format as a locked contract, builds the reader against it, and validates the first real Earth data through it.

## The 32-byte tile header

Every tile file is a fixed 32-byte header followed by 512×512 little-endian `int16` elevation samples in meters — 524,320 bytes exactly, every file, checkable before reading a single field. The header carries magic bytes, a major/minor format version, its own length, the tile's face/level/x/y address, the grid dimensions, the sample type, and the validity range the payload promises to stay inside.

`int16` meters is a deliberate floor. SRTM and GMTED are integer-meter products natively, so the narrowing from the pipeline's `float32` intermediate loses nothing, and it halves the committed dataset size. Earth's relief fits with room to spare: the deepest land depression is the Dead Sea shore near −430 m, the highest summit 8,849 m, and the contract pins validity at −450 to +9,000.

There is no nodata value. The pipeline guarantees void-free tiles — its own extraction stage traps the −32768 sentinel SRTM uses for radar voids — so the format refuses to reserve a magic elevation at all. A sentinel that leaks through a future pipeline regression does not read as a 32-kilometre pit; it fails the validity range and the reader rejects the tile loudly. The ocean is exact `int16` zero everywhere, applied as a post-quantization clamp, which keeps land below sea level legal (Death Valley at −86 m passes) while genuine seafloor bathymetry (thousands of meters down) stays rejectable.

Elevation heights pass through from the sources unchanged and apply as radial offsets above the sphere at R = 6,371.0088 km. No geoid model exists anywhere in the chain. The ~±100 m difference between orthometric heights and heights above a perfect sphere is absorbed as visual error, invisible at this milestone's rendering scale, and the contract says so explicitly rather than leaving the datum question open.

## Grid registration and shared edges

Tiles are grid-registered with a stride of 511: a 512-sample tile spans 511 intervals, and the sample at

```
u = (511 * x + i) / (511 * 2^L)
```

for column `i` of tile `x` at level `L`. The consequence is that tile `x`'s column 511 and tile `x+1`'s column 0 are the *same* grid point, and the contract requires them to be bit-identical. Terrain stitching in the next phase reads one tile at a time and never fetches a neighbor to close a crack — the shared border is already in both files. The duplication costs 0.4% of the dataset and makes seam correctness a per-tile-pair equality test on the data itself, checkable offline before any tile renders.

## The reader's validation ladder

The reader deserializes the header field by field with `memcpy` at explicit offsets. Casting the raw buffer to a header struct would be shorter and wrong three ways: struct layout is compiler-specific, the cast is undefined behavior on alignment grounds, and it silently assumes the host is little-endian. Field-by-field reads compile to the same instructions and stay correct on every lane the engine builds on.

Validation is a 13-rung ladder, ordered so nothing is trusted before it is checked: file exists, file is at least a header long, magic matches, major version is supported, header length is sane, reserved fields are zero, each address field is in range, dimensions are 512×512, the sample type is known, the self-described validity range matches the contract, file size matches the header's promise, and finally every payload sample lands inside the validity range. Each rung has a test that corrupts exactly that field in a fixture tile and requires exactly that rejection. A test battery that is all green on arrival proves nothing, so the ladder-order case was mutation-probed — reordering two rungs turned the right tests red, then the change was reverted.

The exact byte layout is pinned by a golden test: 32 hand-computed literal bytes in the test source, compared against a header the writer produces. If any field moves, widens, or reorders, that test names the byte that changed. The whole reader battery is locked from this phase forward — the format can gain fields through minor version bumps (old readers still find the payload through the header-length field), but changing an existing field's meaning is a breaking major bump by construction.

## The manifest parser

Discovery is one `manifest.json` at the dataset root declaring layers, level ranges, and per-region coverage extents. The engine has no JSON dependency and did not gain one for this. The manifest schema is co-owned with the pipeline and constrained to a subset that a small recursive-descent parser handles completely: ASCII strings with no escape sequences, integers and plain decimal floats with no exponent notation, nesting capped at depth 8, file size capped at 1 MiB, no comments, no trailing commas, no duplicate keys. Everything outside the subset is rejected, with a test per exclusion. Parsing runs once at startup, never on the streaming path.

Tile lookup answers requests with the best available data at or above the requested level per region. The shipped dataset has a hole in its pyramid — global coverage stops at level 5, the three launch-site regions start at level 7, and no level 6 exists anywhere. That shape needed zero special-case code: quadtree descent bottoms out where a region's declared coverage ends, which is the same logic partial regional coverage needs anyway.

## Validating the first real dataset

The acceptance tool walks an entire dataset: every tile through the full reader ladder, every horizontal and vertical tile pair checked for bit-identical shared borders, cross-face edges probed through the locked Phase 63 mapping, and six landmark spot-checks against surveyed elevations. It validates its own machinery first — a self-test builds a clean synthetic dataset plus five poisoned variants, and each poison must fail with exactly its own violation class. On the real 4.3 GiB delivery the full walk takes 6.5 seconds.

The first delivery failed with 814 violations, and every one of them was a real data defect. Three root causes fell out of the pattern of the failures:

The manifest sat in the wrong place under the wrong name, so discovery found nothing. Rectangular coverage declarations overstated the actual tile set by 61 files — the fix was exact row-by-row extent decomposition on the pipeline side. And the corners kept a lesson about cube-sphere topology: a tile corner's value depends on diagonal neighbors, and at a cube vertex — where three faces meet — "the diagonal neighbor" is not even well defined. The violation counts told the story before any code was read: 387 cross-face mismatches, all at corner samples, concentrated at the eight cube vertices; then after the first fix, a residue of exactly-one-sample-per-seam mismatches of ±1 m, where a re-emitted border tile's corner had been quantized through a different code path than its untouched neighbor. The final rule computes every unique grid sample once, identically, regardless of which tile emits it: each corner takes the value-sorted average of whichever of its candidate contributors physically exist, so the answer is symmetric for every missing-neighbor combination by construction.

Four deliveries brought the count 814 → 91 → 5 → 1 → 0. The last standing violation belonged to the engine.

## Calibrating the landmark spot-checks

Tranquillon Peak, the high point above the Vandenberg launch site, is surveyed at 648–658 m depending on the source. The 30 m elevation data at the checked coordinate reads 606 m. That is not a data error. A 30 m raster cell holds the mean elevation over its footprint, a sharp ridge loses tens of meters to that averaging, and the check samples one fixed grid point that quantization may land slightly off-summit. The same physics shows up at Kennedy Space Center: the pad survey says 14.6 m, the cell says 3 m.

The check exists to detect data regressions at a fixed coordinate, and a survey summit is the wrong reference for that job. The expected value is now calibrated to the accepted delivery (606 m ± 12 m, the tolerance derived from SRTM's published ~5.5 m RMSE with margin), with the survey range recorded beside it as provenance. Any future re-emit that moves this coordinate outside the band fails the walk. Mount Everest gets the opposite treatment: at 450 m resolution the summit cell reads 8,629 m against a surveyed 8,849 m, and no fixed tolerance is honest about a 220 m averaging artifact, so the check asserts a regime — the cell must read above 8,000 m — rather than pretending precision the source never had.

The full suite stands at 1,348 tests, with the dataset acceptance gate now a permanent member: it skips loudly when the sample data is absent and runs the complete 8,784-tile walk when present, so a fresh checkout stays green and a data regression cannot arrive unnoticed.
