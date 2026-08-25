# M1.3 Phase 66.4 — Sizing the Terrain Cache Against a Live Flight: Technical Deep-Dive

## Starting point

The terrain cache holds resident tiles — 512 KiB of elevation samples per tile,
plus the mesh baked from them — and its capacity, `kTerrainResidentTileCap`,
bounds how much of the planet can be resident at once. Every number that
constant had ever been locked against came out of a synthetic test manifest:
most recently 768 tiles, set against a measured synthetic envelope peak of 467
with 1.64× headroom. That manifest transcribes the Kennedy Space Center
high-resolution inset and the global tile set, and omits the other two insets —
Starbase and Vandenberg — by construction.

Live flights recorded something the test harness could not explain. During
every whole-view detail collapse in phase 66.2's sign-off flight, the cache
read `res:768/768`, its full capacity. Whether that meant the shipped dataset
wants more than 768 tiles was unanswerable from the log. This phase answers it.

## Why the existing counter cannot answer it

`res:` reports occupancy. An LRU cache that has filled stays full — occupancy
records that the cache reached capacity at some point in the flight, while the
quantity that sizes a cache is how many tiles a single frame wants resident at
once. Raising the cap does not repair the reading: with eviction pressure gone,
occupancy climbs monotonically toward the union of every tile the whole flight
touched, and a union over-states any single frame — tiles from the descent are
still being counted while the camera is back at orbit. Occupancy is censored at
the cap from below and inflated by retention from above, and the peak
simultaneous working set sits between the two, unmeasured.

## The instrument

The fix is a counter that reads demand before the cache can censor it. `want:`
counts the frame's streamed want set — the tiles the selector and its prefetch
ring ask to have resident, after horizon culling and before the capacity check
— and rides the existing periodic terrain log line in `cur/peak` form, so the
line's 120-frame print cadence cannot hide a spike between prints. The set is
determined by the camera pose alone; a cold cache and a warm cache report the
same demand, so the counter needs no warm-up exclusion and no override
configuration. It ships permanently: the next time the dataset grows, the
re-derivation is a flight and a grep.

## The measurement

One continuous flight over the shipped dataset at the shipped 768 cap, 145,560
terrain frames: a parked hold at 50 km, fast and slow descents and ascents
between the surface and 3,000 km, a stationary hover, sustained horizon-grazing
sweeps at 300–400 km — the altitude band where the synthetic envelope peaked —
and low passes over the high-resolution insets. The flight reached Kennedy
Space Center and Starbase; the Vandenberg approach descended about 700 km north
of its inset, so that box's contribution is bounded by the other two rather
than measured. Both measured insets peaked below the flight's overall maximum.

Peak `want:` reads **571 tiles**, 285.5 MiB. The old cap's headroom over live
demand is 768 / 571 = 1.345×, below the 1.5× floor the lock idiom requires.
That shortfall, and nothing about the collapses, is what justifies moving the
constant.

## The re-lock

The sizing rule is the one the previous lock used: the smallest multiple of 256
whose headroom over the measured peak clears 1.5×. 1.5 × 571 = 856.5, so the
cap moves to **1024** — 1.793× headroom, a 512 MiB reachable ceiling, 128 MiB
above the old one. The measured peak is pinned in the calibration suite as
`kTerrainLiveEnvelopePeakTiles = 571` under a two-sided lock: the cap must
clear 1.5× the peak and must stay under 4.0×, so a demand regression and a
silent over-allocation both fail a test instead of waiting for a review to
notice. Provenance moves with the number — the constant is now derived from a
flight over the shipped dataset instead of a manifest that omits two of the
three high-resolution insets.

## What the flight disproved

The expected finding was thrash: a cache smaller than its working set, evicting
tiles it is about to need again. The log shows none. Across all 68 collapse
events recorded at the old cap, the largest simultaneous demand on a collapsing
frame was 547 tiles, under the 768 the cache held, and the cache refused zero
insertions across the whole flight. The verification flight at 1024 confirms it
from the other side: peak eviction churn fell from 4,992 to 274, and ten
collapse events persisted anyway — nine of them with zero evictions in their
window. Capacity is eliminated as the collapse mechanism. The remaining cause
lives in tile selection and is tracked as its own defect with both flights'
evidence attached; the cap re-lock stands on the headroom floor and was never
claimed as the collapse fix.

## What's next

Phase 67's stretch visuals: aerial perspective from the scattering tables,
ocean and land shading via the water mask — which also owns a shading seam this
phase's flights recorded over Kennedy Space Center marshland — city lights on
the night side, and horizon culling in tile selection. The selection-side
collapse defect closes before the milestone does.

*Built solo by Spoods Studios.*
