# M1.3 Phase 65.2 — Tile Pipe Bounding: Technical Deep-Dive

## The kill

A descent flight through the terrain streaming path died 2.5 minutes after launch. The kernel's own log named the cause:

```
Out of memory: Killed process (interstellar) total-vm:60883892kB, anon-rss:23054528kB
```

Resident memory had climbed to 23 GB before the OOM killer stepped in. A minute earlier the GPU driver had already started refusing allocations:

```
NVRM: NV_ERR_NO_MEMORY
```

The user-visible symptom was stutter and flicker in the final minute, then the process vanished. Both were downstream of the same growth: allocator churn from a container that never stopped expanding, then a driver that ran out of room to answer it.

## Every bound was already locked

The terrain streaming path has three memory bounds, and all three were doing their job. The resident-tile cache caps at 512 entries and evicts LRU. The request queue between the render thread and the streaming thread is a fixed 64-slot ring:

```cpp
inline constexpr std::size_t kTileRequestQueueCapacity = 64;
```

`request()` refuses once the ring is full and returns `false` — no growth possible, by construction:

```cpp
bool request(const TileRequest& key) {
    std::lock_guard lock{request_mutex_};
    if (write_ - read_ == kTileRequestQueueCapacity) {
        ++dropped_;
        return false;
    }
    slots_[write_ & (kTileRequestQueueCapacity - 1)] = key;
    ++write_;
    return true;
}
```

The upload budget is a fixed 4 tiles drained per frame. That comment above the queue constant promised the ring could never exceed its own capacity, and it never did — the 64-slot ring stayed at 64 slots for the entire flight. The tile that killed the process was never sitting in that queue. It had already been read off disk, decoded, and published. It was waiting somewhere else.

## The container nobody bounded

Between the request queue and the upload budget sits `results_`, the vector the streaming thread publishes decoded tiles into:

```cpp
struct TileSamples {
    ingest::TileHeader header{};
    std::vector<std::int16_t> samples;
};

struct TileResultHandle {
    TileRequest key{};
    bool miss = false;
    ingest::TileReadError error = ingest::TileReadError::kOk;
    std::unique_ptr<TileSamples> payload;
};
```

Nothing capped it. The render side's request logic — `want_tile` — checked the resident cache and a permanently-missing set before issuing a request, but it never checked whether a tile was already sitting in the pipe:

```cpp
const auto want_tile = [this](const TerrainNodeKey& node) {
    TerrainNodeKey tile{};
    if (!resolve_terrain_tile(node, tile) || terrain_cache_.contains(tile)
        || terrain_missing_.find(tile) != terrain_missing_.end()) {
        return;
    }
    terrain_request_scratch_.push_back(tile);
};
```

A tile that was wanted but not yet resident got re-requested every single frame until its result finally drained into the cache. The first request for a tile reads it from disk. Every request after that hits the operating system's page cache, so the streaming thread can service the entire 64-deep queue well inside one frame. Each of those duplicate reads publishes another full payload — 512×512 `int16` samples, 512 KiB — into `results_`. The drain only takes 4 tiles per frame. Publish rate and drain rate were never in the same order of magnitude, and the wanted set stayed large the whole descent.

23 GB divided by roughly 512 KiB per handle is about 46,000 duplicate payloads. That is the entire leak — one publish call, called far too often, into a vector nobody was watching.

## Two halves, deliberately both

The fix closes both ends of the loop, because either one alone leaves a hole.

On the render side, `OrbitDemo` gained an in-flight set, keyed the same way as the missing-tile set:

```cpp
std::unordered_set<TerrainNodeKey, TerrainNodeKeyHash> terrain_inflight_{};
```

`want_tile` now checks it alongside the cache and the missing set:

```cpp
if (!resolve_terrain_tile(node, tile) || terrain_cache_.contains(tile)
    || terrain_missing_.find(tile) != terrain_missing_.end()
    || terrain_inflight_.find(tile) != terrain_inflight_.end()) {
    return;
}
```

An address is inserted only when `request()` actually accepts it — a queue-full refusal leaves nothing in flight, so the selector's own retry next frame still works exactly as before:

```cpp
if (tile_streamer_->request(TileRequest{tile.face, tile.level, tile.x, tile.y})) {
    terrain_inflight_.insert(tile);
}
```

And it is erased as the first statement in the drain loop, before any miss or payload handling runs, so every exit path clears the same entry:

```cpp
for (TileResultHandle& handle : tile_streamer_->drain_up_to(kTerrainUploadBudgetTilesPerFrame)) {
    const TerrainNodeKey requested{handle.key.face, handle.key.level, handle.key.x, handle.key.y};
    terrain_inflight_.erase(requested);
    if (handle.miss) {
        // ...
```

A tile now loads at most once for as long as it stays wanted and unresident.

On the streamer side, `results_` got a hard cap with the same drop-and-count posture the request ring already used:

```cpp
inline constexpr std::size_t kTileResultsCapacity = 8 * kTileRequestQueueCapacity;  // 512
```

```cpp
void publish(TileResultHandle handle) {
    {
        std::lock_guard lock{results_mutex_};
        if (results_.size() < results_capacity_) {
            results_.push_back(std::move(handle));
            return;
        }
        ++dropped_results_;
    }
    // one-shot log line, outside the lock
}
```

The cap is not a tuning knob picked by feel. The largest legitimate backlog measured against the streaming path's own culled selector was 202 tiles in flight at once. A cap of 512 clears that by 2.53x. At worst-case occupancy, 512 handles at 512 KiB each is 256 MiB — a ceiling instead of an open sky, and about a 90x cut against the 23 GB the uncapped vector reached. With the render-side dedup in place, this cap should never be hit; a refusal here means the dedup has a hole somewhere, so a hit gets counted and logged once rather than silently absorbed.

## Test first

The regression case exercises the real streaming thread, not a model of it: it issues duplicate requests continuously while draining nothing, the same pattern the OOM flight ran. Recorded before the fix landed:

```
CHECK( streamer.results_ready_for_test() <= kResultsBound )
with expansion:
  640 (0x280) <= 512 (0x200)
```

The backlog grew to 640 against a 512-entry bound — the failure is the vector's own occupancy, not a symptom read off a stack trace. After the cap and the dedup landed, the identical drive holds at or under 512 every time.

Two more cases pin the edges. One injects a tiny 4-entry capacity, requests 7, and checks that exactly 3 are refused — drop-newest, by count, not by "some were dropped." The kept 4 are the first 4 requested, in arrival order, and the cap frees up again as soon as the backlog drains. The other runs the exact dedup protocol — skip in-flight, insert only on an accepted request, erase on every drain — over a full set of tile addresses and checks two things at once: the backlog never exceeds the number of tiles simultaneously wanted, and the streamer's own refusal counter stays at zero. If the dedup is doing its job, the cap should never fire.

## The same flight, forty minutes later

The identical descent that OOM-killed at 2.5 minutes now runs a full 40-minute flight — descent, then free flight — with resident memory climbing to a peak of 580 MB and staying flat. No stutter, no driver allocation failures, no growth curve. The 23 GB leak came from one uncapped vector fed by a feedback loop between a re-request pattern and an operating system page cache; closing the loop at both ends turned an unbounded climb into a number that stops moving.
