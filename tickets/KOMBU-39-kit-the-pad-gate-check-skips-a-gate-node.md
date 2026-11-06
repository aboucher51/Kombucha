---
id: KOMBU-39
title: Kit: the pad gate check skips a gate node on its way out
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [scripts/autoloads/pads.gd, tests/test_pads.gd, .godot-map/graph.json, PROJECT_MAP.md]
created: 2026-11-06
updated: 2026-11-06
---

Make `Pads._allowed()` in `scripts/autoloads/pads.gd` skip a `pad_gate` node that `is_queued_for_deletion()`.

CLAUDE.md says every group loop in the kit skips nodes on their way out. A freed gate stays in its group until the frame ends. Until then it still refuses pads, so a seat change that frees the old gate blocks a pad for one frame.

Found while working KOMBU-38. Add a test beside `tests/test_pads.gd`: free a gate with `queue_free()` and check that the pad acts in the same frame.

## Progress
- 2026-11-06 09:26 PM: when this lands, tell dwarf-mountain-pm. Their DWARF-95 (copy pads.gd and pad_router.gd back) waits on it.
- 2026-11-06 09:26 New test red before the fix (a queued-for-deletion gate still refused pad B), green after: _allowed skips is_queued_for_deletion. Map regenerated (graph.json stores line counts): adding .godot-map/graph.json and PROJECT_MAP.md to touches.
- 2026-11-06 09:30 tools/check.sh --ci green on forge. Commit 276c21e on kombu-39-gate-freed, worktree ~/godot-projects/Kombucha-wt-39. No Ready to play: nothing a player or scenario author sees changes. Handing to kombucha-pm.
- 2026-11-06 09:30 done on main at 276c21e

## Left for later
