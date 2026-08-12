---
schema_version: 1
open_count: 5
waived_count: 0
fixed_count: 0
total_count: 5
last_updated: 2026-08-12T14:47:35.592Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 3 | deviation | tests/lib.smoke.mjs |  | Plan 03-01 Task 4 test input replaced with the real pages/how-its-made prose block; the plan's 81-char paraphrase could not reach truncate's cut path | open |  | 2026-07-22T20:55:47.583Z |  |
| 2 | 3 | deviation | src/pages/rss.xml.ts |  | absolutize()'s a/href branch is unexercised by real content (zero anchors in all 9 devlog bodies); gated by a live negative assertion in tests/distribution.smoke.sh rather than a fixture | open |  | 2026-07-22T21:30:27.076Z |  |
| 3 | 4 | deviation | assets/m1.1-hero-first-burn.png |  | M1.1 hero upscaled 1139x1068 -> 1200x1125 (Lanczos, studio-side commit 54f30e9) to clear the OG large-embed floor; author may prefer regenerating the matplotlib plot at native >=1200 width | open |  | 2026-08-08T21:19:49.821Z |  |
| 4 | 04 | unmet-truth | src/lib/site.mjs |  | ANLT-01 live certification deferred (D-61): pageviews-recorded cannot be certified until the developer signs up, sets GOATCOUNTER_CODE, pushes, and confirms the dashboard | open |  | 2026-08-08T21:39:24.515Z |  |
| 5 | quick-260812-eot | unrun-verify | src/styles/global.css |  | Task 1 human-check (npm run preview visual pass for hero image at desktop/sub-640px widths) not run -- no browser tool available in executor context; substituted automated build-artifact grep proving the CSS rule + intrinsic ratio are present | open |  | 2026-08-12T14:47:35.592Z |  |

````json
[
  {
    "id": 1,
    "kind": "deviation",
    "phase": "3",
    "file": "tests/lib.smoke.mjs",
    "line": null,
    "description": "Plan 03-01 Task 4 test input replaced with the real pages/how-its-made prose block; the plan's 81-char paraphrase could not reach truncate's cut path",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-22T20:55:47.583Z",
    "resolved_at": null
  },
  {
    "id": 2,
    "kind": "deviation",
    "phase": "3",
    "file": "src/pages/rss.xml.ts",
    "line": null,
    "description": "absolutize()'s a/href branch is unexercised by real content (zero anchors in all 9 devlog bodies); gated by a live negative assertion in tests/distribution.smoke.sh rather than a fixture",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-07-22T21:30:27.076Z",
    "resolved_at": null
  },
  {
    "id": 3,
    "kind": "deviation",
    "phase": "4",
    "file": "assets/m1.1-hero-first-burn.png",
    "line": null,
    "description": "M1.1 hero upscaled 1139x1068 -> 1200x1125 (Lanczos, studio-side commit 54f30e9) to clear the OG large-embed floor; author may prefer regenerating the matplotlib plot at native >=1200 width",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-08T21:19:49.821Z",
    "resolved_at": null
  },
  {
    "id": 4,
    "kind": "unmet-truth",
    "phase": "04",
    "file": "src/lib/site.mjs",
    "line": null,
    "description": "ANLT-01 live certification deferred (D-61): pageviews-recorded cannot be certified until the developer signs up, sets GOATCOUNTER_CODE, pushes, and confirms the dashboard",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-08T21:39:24.515Z",
    "resolved_at": null
  },
  {
    "id": 5,
    "kind": "unrun-verify",
    "phase": "quick-260812-eot",
    "file": "src/styles/global.css",
    "line": null,
    "description": "Task 1 human-check (npm run preview visual pass for hero image at desktop/sub-640px widths) not run -- no browser tool available in executor context; substituted automated build-artifact grep proving the CSS rule + intrinsic ratio are present",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-08-12T14:47:35.592Z",
    "resolved_at": null
  }
]
````
