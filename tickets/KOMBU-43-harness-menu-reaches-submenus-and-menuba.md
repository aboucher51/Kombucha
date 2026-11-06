---
id: KOMBU-43
title: Harness: menu reaches submenus and MenuBar menus
status: ready
priority: 5
owner: 
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, docs/godot-tooling.md, scenarios/, scripts/harness_inputs.gd]
created: 2026-11-06
updated: 2026-11-06
---

The `menu` verb from KOMBU-41 picks an item from a MenuButton's popup or from an open PopupMenu. It does not reach two things yet:

- A submenu item (an item set with `set_item_submenu_node`). A line like `menu EditMenu "Export/As PNG"` could open each submenu on the way.
- A menu inside a `MenuBar`. The MenuBar's child PopupMenus are found by name, but the harness cannot open one yet, so the scenario must open it some other way first.

Do this when a project needs it. IceEngine's Edit menu and context menu did not.

The gate is `tools/check.sh --ci`, green.

## Progress
- 2026-11-06 18:41 PM: parked until a project needs submenus or MenuBar menus. iceengine-pm will say if ICE-58 does.

## Left for later
