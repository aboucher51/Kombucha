---
id: KOMBU-1
title: Harness: a drag verb (press, move, release) for sliders and levers
status: done
priority: 2
owner: kombucha-worker
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, scripts/main.gd, PROJECT_MAP.md, .godot-map/graph.json, scenarios/drag.txt, tests/test_screenshot_harness.gd, docs/godot-tooling.md]
created: 2026-10-25
updated: 2026-10-25
---

Add a `drag` verb to the screenshot harness, so a scenario can drag a slider, lever or scroll handle the way a player does.

From Alex via rigmaster (was NavalWar's NAVAL-21): NavalWar's music Speed lever says it follows the mouse while dragged, and no scenario can prove it. Today the harness only has click, click_at, hover, press and key.

What to do:
- `drag <NodeName | x y> <x y> [steps]` in `scripts/dev/screenshot_harness.gd`. The start is a named Control's centre (resolved, waited on and scrolled into view exactly as `_click` does) or canvas coordinates. The end is canvas coordinates. `steps` is how many motion events go between press and release (default something small, like 8).
- Press the left button at the start, send `steps` InputEventMouseMotion events with `button_mask = MOUSE_BUTTON_MASK_LEFT` and a `relative`, then release at the end. All through `get_viewport().push_input(event, true)` in canvas coordinates, warping the real cursor with `_warp_cursor` like `_click_point` does (see the comments on `_click_point` and `_warp_cursor` for why).
- The button is held across frames on purpose here, unlike click. Read the "shards share the ONE cursor" comment on `_click_point`: decide how a drag survives another shard warping the cursor mid-drag (e.g. re-warp before each motion), and write the reason in a comment.
- Usage and lookup errors return "ERROR: ..." like the other verbs.
- Fixture (CLAUDE.md: every harness command needs a fixture user): a new scenario, e.g. `scenarios/drag.txt`, that opens the pause menu and drags `MasterSlider` (scripts/ui/volume_sliders.gd) to a new spot, then asserts the volume moved (state readback, not pixels). Add an `expect_fail` line for a bad target. A unit test in tests/test_screenshot_harness.gd for argument parsing if the code splits that out.
- Docs: add `drag` to the built-in command list in docs/godot-tooling.md ("Seeing the game"), with one line on when to use it over click.

Then other projects get it with /sync-godot-tooling (NavalWar first; tell the PM in the report so navalwar-pm can be told).

## Progress
- 2026-10-25 14:38 drag verb, parse test, scenarios/drag.txt written; added scripts/main.gd to touches: the fixture needs a master_volume state key so the scenario reads the volume back instead of pixels
- 2026-10-25 15:08 drag.txt green; proven able to fail: with no motion events and no per-step warps the slider stays at 50 and lines 9 and 12 go red; motion events alone (no warps) pass
- 2026-10-25 15:10 added PROJECT_MAP.md and .godot-map/graph.json to touches: check.sh fails on a stale map after the new scenario and state key
- 2026-10-25 15:11 full tools/check.sh --ci green on forge in 71 s after rebase (commit df769bf); play pass written; waiting for Alex's yes to push
- 2026-10-25 15:30 pushed to main as df769bf (Alex said push it, directly)
- 2026-10-25 15:30 done on main at 03a0505

## Ready to play
- What changed: scenarios can now say `drag <NodeName | x y> <to_x> <to_y> [steps]`. It presses the left button, moves with the button held for `steps` frames (8 by default), and lets go at the end.
- What the scenario showed: `scenarios/drag.txt` drags the pause menu's Master slider past its left end (volume reads 0) and past its right end (volume reads 100). The shot `drag-01-dragged-left.png` shows the Master knob at the far left, the Music and SFX knobs untouched, and no cut-off or overlapping text. Bad lines (unknown slider, missing end point, 0 steps) fail as they should.
- Proof the scenario can fail: with the moves taken out, the slider stays at 50 and the scenario goes red.
- Questions for a person:
  1. Does NavalWar's Speed lever need a drag that stops partway (for example, half speed), or is "all the way left / all the way right" enough proof?
  2. Should `drag` also take a node name for the END point (drag this knob onto that box), for drag-and-drop UIs?
  3. Is 8 moves a good default, or do levers in NavalWar need slower drags to show the follow?
