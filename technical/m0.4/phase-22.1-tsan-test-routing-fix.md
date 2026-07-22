# M0.4 Phase 22.1 — TSan Test Routing Fix: Technical Deep-Dive

> Retroactive technical devlog. **Inserted post-gate debt phase** — the
> debt surfaced during Phase 21.7's TSan confirmation, the gate closed
> over it 2026-06-13, and the milestone close-out disposed it "fix now"
> the same night: phase inserted 2026-06-14 00:24, fix landed 00:57,
> closed 00:58, M0.4 merged 01:43.

## Starting point

An unfiltered `ctest --test-dir build-tsan` was red by construction: 285/287.
The three failing entries (#110/#135/#136) were the bare Catch2-discovered
copies of the concurrency contention tests — the same tests that passed 3/3
clean as the dedicated `*_tsan` entries (#216–218).

The split exists because the suite registers those tests twice.
`catch_discover_tests` auto-registers every `TEST_CASE` as a bare ctest entry;
separately, dedicated `add_test` aliases run the contention cases with
`TSAN_OPTIONS=suppressions=tsan_suppressions.txt`. The suppressions cover two
documented by-design races: the seqlock page writes
(`engine/src/coordinate_service.cpp:112`) and the read-in-place snapshot reads
validated by the generation recheck
(`engine/src/physics_worker_thread.cpp:544-549`). The bare duplicates ran
without the file, so ThreadSanitizer flagged the benign races on every full
TSan run. The races were not the bug — the test registration routing in
`tests/CMakeLists.txt` was.

## What was built

### Why exclusion was off the table

Two fix shapes were on the table: route the suppressions into the bare
discovered entries, or exclude the by-design-race `TEST_CASE`s from
discovery so only the suppression-scoped `*_tsan` gate runs them. The
contention cases are `[math-lock]`-tagged (`test_seqlock_contention.cpp`,
`test_snapshot_contention.cpp`), and removing a math-lock-tagged test from
the enforcement surface requires reviewer sign-off — dropping them from
discovery is a removal. Routing is the only shape that avoids that: the
cases stay discovered, suppressions applied instead of excluded.

### The fix

`tests/CMakeLists.txt` only (plus a debt-tracking status line):

```cmake
if(EXISTS ${CMAKE_SOURCE_DIR}/tsan_suppressions.txt)
    catch_discover_tests(unit-tests
        PROPERTIES ENVIRONMENT
            "TSAN_OPTIONS=suppressions=${CMAKE_SOURCE_DIR}/tsan_suppressions.txt"
    )
else()
    catch_discover_tests(unit-tests)
endif()
```

Every discovered ctest entry now carries the suppressions. Two entries are not
covered by that block — the worker-touching `[.long]` `add_test` aliases
`long_property_suite` and `s05_hammer` (the 10k-cycle pause/resume hammer a
fix three days earlier had added) drive the worker threading and hit the
same benign races — so each gets the identical `ENVIRONMENT` property
explicitly, behind the same `if(EXISTS)` guard.

Applying the file globally masks nothing new: `tsan_suppressions.txt` is
scoped by function to the two benign sites (5 functions, all exercised
concurrently only by the contention tests), so a real race in any other code
path still surfaces under `halt_on_error`. On non-TSan Release/Debug builds
the environment variable is inert — no `-fsanitize=thread`, nothing reads it.

### Verification

Unfiltered `ctest --test-dir build-tsan` 287/287 green (was 285/287, red by
construction). Release 289 and Debug 287 default tiers unchanged and green —
same case counts, since routing changes an entry's environment, not the entry
set. `git diff` confined to `tests/CMakeLists.txt`; zero `engine/` diff, so
the engine's byte-identity held and the two-day-old gate tag stayed valid
with no re-review.

## Why it was built this way

- **The math-lock rule picked the shape.** Between the two candidate fixes,
  exclusion weakens the math-lock enforcement surface and routing does
  not; the decision was mechanical once the `[math-lock]` tags were
  checked.
- **Suppressions stay narrow rather than growing.** The fix moves the existing
  function-scoped file onto more entries; it adds no suppression. Widening the
  file to paper over the bare entries would have masked future real races in
  the worker.
- **Test-harness-only scope was a hard constraint.** The gate had passed
  fourteen hours earlier; any engine-source byte would have invalidated the
  byte-identity claim and re-opened review. The `if(EXISTS)` guard keeps
  configure working from a tree without the file.

## Where it is now (drift since 2026-06-14)

- **All three blocks are in today's `tests/CMakeLists.txt`** — the guarded
  `catch_discover_tests` at `:386` and the two alias blocks at `:783`/`:809` —
  with the Phase 22.1 provenance comments intact.
- **`tsan_suppressions.txt` is unchanged since 2026-06-08**: the routing fix
  never touched it, and no later phase widened it.
- **The unfiltered TSan tier became a standing gate.** Later milestones fix
  TSan findings in the tests themselves rather than the routing — M0.5's
  workers are parked before driving (2026-06-15) — so `build-tsan` runs stay
  green without new suppressions.
