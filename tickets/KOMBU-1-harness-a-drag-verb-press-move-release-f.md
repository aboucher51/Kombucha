---
id: KOMBU-1
title: Harness: a drag verb (press, move, release) for sliders and levers
status: ready
priority: 2
owner: 
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, scenarios/drag.txt, tests/test_screenshot_harness.gd, docs/godot-tooling.md]
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

## Left for later
