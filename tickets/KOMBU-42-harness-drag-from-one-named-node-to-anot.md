---
id: KOMBU-42
title: Harness: drag from one named node to another
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, tests/test_screenshot_harness.gd, tools/new-project.sh, docs/godot-tooling.md, scenarios/, scripts/, scenes/, .godot-map/graph.json, PROJECT_MAP.md]
batch: KOMBU-B4
created: 2026-11-06
updated: 2026-11-06
---

Let the harness's `drag` end on a named node, not only on x y coordinates.

What happened (iceengine-pm, ICE-69, 2026-11-06): `drag <NodeName | x y> <to_x> <to_y> [steps]` takes a start node or point, but only a target x y. So dragging a list item onto a slot means guessing the slot's coordinates, which break when the layout moves. IceEngine works around it in its own `scripts/dev/dev_hooks.gd`.

What to do:
- Accept a node name as the target: `drag <from> <to>`, where each end is a node name or an x y pair. A named end uses the node's center, after the same scroll-into-view that `click` does (KOMBU-37). Keep every existing form of the line working, and keep the optional `steps`.
- Refuse a target that is ambiguous or not visible, the same way `click` does.
- Make sure Godot's own drag and drop (`_get_drag_data`, `_can_drop_data`, `_drop_data`) works through it, not just a hand-made lever. If the harness's synthetic motion cannot start a Godot drag, say so in the ticket and find the smallest fix.
- Make the fixture use it: a source and a target (a list item and a slot) off the boot screen, and a scenario that drags one onto the other by name and asserts the drop.
- Update the `drag` line in `docs/godot-tooling.md`. Load `writing-instructions` first.

The gate is `tools/check.sh --ci`, green. When this lands, the PM tells iceengine-pm.

## Progress
- 2026-11-06 18:37 drag takes a named end on both sides; Godot drag and drop works through pushed motion unchanged. scenarios/drag_drop.txt; red-proof: ignoring the named target turns it red.
- 2026-11-06 18:37 Same touches addition as KOMBU-41: the parse_drag tests and the scaffold's exclude list.
- 2026-11-06 18:41 Gate tools/check.sh --ci green on ce84c30 (forge, llvmpipe).
- 2026-11-06 18:41 done on main at ce84c30

## Ready to play
What changed: `drag` takes a node name or an x y pair at both ends, like `drag ItemApple DropSlot`. A named end is the node's centre, scrolled into view the way `click` does it. Godot's own drag and drop needed no fix: the pushed motion starts the drag and the release drops it.

What the scenarios and shots showed: `scenarios/drag_drop.txt` drags Apple onto the slot by name, then a Rock the slot refuses, then mixes a name and a point at each end. `shots/drag_drop-01-dropped-apple.png` shows "Apple" in the slot. With the named target ignored on purpose, the scenario went red at the first assert. The old `drag MasterSlider 0 360` lines in `scenarios/drag.txt` still pass.

Questions for a person:
- A word that is not a number is now a node name, so `drag Slider x 10` reads x as a target. Is that fine for IceEngine's lines?
- Should a drag show Godot's drag preview in a shot taken mid-drag? Today no verb stops halfway.

## Left for later
- none
