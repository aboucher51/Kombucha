---
id: KOMBU-42
title: Harness: drag from one named node to another
status: ready
priority: 3
owner: 
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, docs/godot-tooling.md, scenarios/, scripts/, scenes/, .godot-map/graph.json, PROJECT_MAP.md]
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

## Left for later
