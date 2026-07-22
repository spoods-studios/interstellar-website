---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 0
total_count: 1
last_updated: 2026-07-22T20:55:47.583Z
---

# Broken Windows Ledger

> Cross-phase defect register. `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 3 | deviation | tests/lib.smoke.mjs |  | Plan 03-01 Task 4 test input replaced with the real pages/how-its-made prose block; the plan's 81-char paraphrase could not reach truncate's cut path | open |  | 2026-07-22T20:55:47.583Z |  |

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
  }
]
````
