# M1.3 Assets Phases 1–3 — Terrain Pipeline: Technical Deep-Dive

## Starting point

The engine's Phase 64 deep-dive describes a reader for a purpose-built binary tile format, and it credits an offline pipeline with everything the reader refuses to do: downloading gigabytes of GeoTIFFs, reprojecting them, and guaranteeing the tiles are void-free before the engine ever sees them. This post is about that pipeline. It lives in its own repository, `setare-assets`, and it is the first code in this project shipped outside the engine. The work split into three phases: acquisition with provenance (Assets Phase 1), reprojection onto the engine's cube-sphere grid (Assets Phase 2), and packaging into the locked tile contract (Assets Phase 3). The numbering is the asset repository's own — Assets Phase 3 and engine Phase 3 have nothing to do with each other.

## Downloads with receipts

Raw sources stay out of git. The SRTM tiles, the 862 MB GMTED2010 archive, and roughly 2.4 GB of Blue Marble imagery are all re-downloadable from NASA and USGS servers, so committing them would spend the repository's 10 GiB Git LFS quota on bytes anyone can fetch. The LFS filter in `.gitattributes` covers only `data/processed/**`; raw and intermediate data are gitignored and fetched on demand.

Provenance works on trust-on-first-use. The first fetch of a file has no known checksum, so the pipeline computes the sha256 and records it in a manifest; every later fetch verifies against the pinned hash. A `verify --fix` command walks the manifest, re-hashes the cache, and re-downloads anything missing or mismatched (`scripts/acquire/manifest.py`):

```python
if not file_path.exists():
    status = "missing"
else:
    computed = pooch.file_hash(str(file_path))
    status = "ok" if computed == entry["sha256"] else "mismatched"
if fix and status in ("missing", "mismatched"):
    if file_path.exists():
        file_path.unlink()
    fetch_with_tofu(entry["source_url"], path, key, cache_dir)
    status = "fixed"
```

The repair path has a test that truncates a cached SRTM tile to 100 bytes and requires the fix pass to restore the exact original 1,369,481 bytes. Region keys from the command line never reach a URL join directly: the keys of `manifests/regions.json` are the allowlist, and an unknown key fails with the valid set printed in the error. Phase 1 ended with 24 SRTM tiles cached for the three launch-site regions — 9 for Kennedy Space Center, 9 for Vandenberg, 6 for Starbase — each with a pinned manifest entry.

## Warping onto the cube

The engine addresses terrain by cube face, level, x, y. That grid is a cube-sphere with a per-axis equal-area correction, and no EPSG code or PROJ string describes it, so the standard reprojection stack — `gdalwarp`, `rasterio.warp`, `pyproj` — appears nowhere in the processing package. Each output tile computes its own u/v sample grid, forward-maps it through the cube-sphere functions to latitude/longitude, and pulls source pixels by inverting the source's affine transform and sampling bilinearly. The correction itself is closed-form (`scripts/process/mapping.py`):

```python
def equal_area_correct(x, y, z):
    xp = x * np.sqrt(1 - (y**2 + z**2) / 2 + (y**2 * z**2) / 3)
    yp = y * np.sqrt(1 - (z**2 + x**2) / 2 + (z**2 * x**2) / 3)
    zp = z * np.sqrt(1 - (x**2 + y**2) / 2 + (x**2 * y**2) / 3)
    return xp, yp, zp
```

The mapping module is checked against a reference table the engine exports, and that comparison caught the subtlest bug of the milestone. Two of the six faces carried a sign flip on their free axis. The flipped mapping round-tripped perfectly against itself, so every internal test passed. Against the engine's table, exactly two interior rows disagreed — Everest and Sydney — and the seam rows alone could never have discriminated the flip, because a mirrored face still meets its neighbours at the same seam coordinates. The fix was two entries in the face-axes table.

Intermediate output is Cloud-Optimized GeoTIFF written with `crs=None`, deliberately: a cube-face grid has no geographic CRS, and the checkpoint format stays agnostic about what the engine will eventually read. The maximum pyramid level derives from the source's ground-sample distance measured against the face edge length in meters. Parent tiles fold up from their children as an exact 2×2 mean with the rounding contract pinned per dtype, and GDAL runs single-threaded inside a scoped environment so a re-run reproduces the same bytes.

## Two sentinels and a hole at the South Pole

SRTM marks radar voids with −32768. Real data supplied a second sentinel the documentation does not mention: 32767 appears in coastal water pixels, and the tile covering Cape Canaveral's lagoon system carries 20,368 of them. The void scanner checks both sentinels unconditionally, plus NaN and whatever nodata value the source reports (`scripts/process/voids.py`):

```python
KNOWN_SENTINELS = (-32768, 32767)

def find_voids(array, reported_nodata):
    mask = np.zeros(array.shape, dtype=bool)
    if np.issubdtype(array.dtype, np.floating):
        mask |= np.isnan(array)
    for sentinel in KNOWN_SENTINELS:
        mask |= array == sentinel
    if reported_nodata is not None:
        mask |= array == reported_nodata
    return mask
```

Voids fill from the nearest valid sample via a distance transform, and an assertion downstream of the fill guarantees the packaged dataset is void-free. That guarantee is why the engine's tile format could refuse to reserve a nodata value at all.

Coverage gaps needed a second source. GMTED2010 spans −56° to +84° latitude, and the cube mapping places each pole at the center of a face, so about 58% of the south polar face had no source data. ETOPO 2022 fills the polar caps with a hard boundary between the two sources: each source is sampled only against its own masked point set, so no blend zone smears one dataset into the other.

The tiler also manufactured tiles that should not exist. Face 1 of the cube is centered on longitude 180, so its own `atan2` branch cut looks exactly like an antimeridian crossing to bounding-box logic, and every launch-site region gained 12 spurious all-zero tiles — 36 in total. The fix distinguishes a genuine crossing from the branch cut by measuring the longitude span in the 360-shifted domain, and a `prune` command removes already-emitted stale tiles, because the resumable sweep can skip a tile it would regenerate but can never delete an extra.

## Quantize once, share every edge

The packaging adapter owns the only coupling to the engine's format: a 32-byte header behind the magic bytes `ISET`, a 512×512 int16 payload, 524,320 bytes per tile, validity band −450 m to +9,000 m. The engine's Phase 64 deep-dive explains the reader's side of this contract; the pipeline's side is a construction rule. Tiles are grid-registered with a stride of 511, so a tile's last column and its neighbour's first column are the same physical grid point, and the contract requires the two files to store it bit-identically. The pipeline meets that by resampling every sample from a halo-padded array that includes neighbour data, then quantizing exactly once with half-to-even rounding — two tiles that share a grid point run the same arithmetic on the same inputs and cannot disagree.

Quantization also surfaced real data where the design assumed none. The pipeline's internal plausibility floor is −500 m; the contract floor is −450 m. The band between them was expected to be empty, and a scan found 2,608,663 real bathymetry pixels there across 121 tiles, all in the launch-site boxes — the Kennedy Space Center box includes a stretch of open Atlantic where SRTM reports genuine seafloor. The ocean clamp now takes its floor from the format module: depths below −450 m clamp to exact zero, while shallow near-coast bathymetry above the floor keeps its measured depth. Flattening every water pixel to zero would require a land/water mask the pipeline does not have yet, and a mask-free clamp of all negatives would flatten Death Valley along with the sea. The residual coastline step between the global set and the boxes is bounded at 450 m, down from 4,075 m before the regeneration.

## Four rounds against the engine's validator

The engine's acceptance tool walked the committed dataset four times, and the violation count fell 814 → 91 → 5 → 0. Three root causes on the pipeline side account for the drop.

Round 1 found all three. The dataset manifest sat nested inside the processed tree instead of at the dataset root, so discovery found nothing. Rectangular extent declarations promised 61 tiles that region-intersection culling had never emitted; the fix replaces bounding boxes with an exact row-by-row run-length decomposition of the tiles that actually exist, merged across adjacent identical rows. And 387 cross-face corner mismatches plus 365 same-face seam mismatches traced to one omission: a tile with no diagonal neighbour repeated its own corner pixel, while the tile across the seam computed the same grid point from real diagonal data. The re-emit rewrote 442 of 8,784 tiles.

Round 2 left 91 violations in two classes. The first was cube vertices: where three faces meet, "the diagonal neighbour" is not well defined, and each of the three incident faces now copies one canonical vertex value computed once for the group. The second was subtler — 44 tiles differing by exactly one pixel at ±1 m, where two tiles sharing a corner were each missing a different neighbour and each substituted a different fallback.

Round 3 left 5 survivors, all mirror images of that fallback asymmetry at concave stair-step region boundaries. The final rule deletes every role-specific fallback: a corner is the value-sorted average of whichever of its candidate contributors physically exist — the tile's own pixel, the u-neighbour's, the v-neighbour's, the diagonal's. Every tile sharing the corner enumerates the identical pool of real contributors, so the answer is symmetric for every missing-neighbour combination by construction (`scripts/package/tiles.py`):

```python
values = [own]
if u_line is not None:
    values.append(float(u_line[row_idx]))
if v_line is not None:
    values.append(float(v_line[col_idx]))
if diagonal is not None:
    values.append(float(diagonal))
values.sort()
total = values[0]
for value in values[1:]:
    total += value
return total / len(values)
```

Round 4 came back clean: 8,784 of 8,784 tiles accepted, with 8,541,696 shared seam samples and 49,104 cross-face corner probes bit-identical between the pipeline's arithmetic and the engine's.

## What shipped

The committed dataset holds 8,784 elevation tiles — global coverage at levels 0–5 plus the three launch-site regions at levels 7–9 — and 8,190 three-band imagery tiles, totalling 4.29 GiB of Git LFS storage against a 6 GiB target and the 10 GiB free-tier ceiling. A pre-commit gate projects quota usage from `git lfs ls-files --json`, because the human-readable variant rounds byte counts to three significant figures and cannot back an exact-byte check. A fresh clone materializes the full dataset in about 9 seconds with zero network bytes. The pipeline's next slice generalizes the same machinery to Moon and Mars DEMs and packages the imagery layer into the engine format; that work waits for engine milestone M1.5.
