---
id: KOMBU-41
title: Harness: pick a PopupMenu item by its text
status: ready
priority: 3
owner: 
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, docs/godot-tooling.md, scenarios/, scripts/, scenes/, .godot-map/graph.json, PROJECT_MAP.md]
batch: KOMBU-B4
created: 2026-11-06
updated: 2026-11-06
---

Give the screenshot harness a way to pick an item from a popup menu by its text, the way a person would.

What happened (iceengine-pm, ICE-58, 2026-11-06): while authoring a mod by scripted clicks, IceEngine could not choose "Rename" from an Edit menu or a context menu. A PopupMenu's items are not nodes, so `click <NodeName>` cannot reach them. IceEngine works around it with its own commands in `scripts/dev/dev_hooks.gd` (around line 2313: "The File menu's prompts without the popup"). Any project with a menu bar or a right-click menu has the same gap.

What to do:
- Add a harness command, for example `menu <MenuButtonOrPopup> <item text or id>`. It opens the menu (a `MenuButton`'s popup, or an open `PopupMenu` by name) and activates the item the way a click would, so the item's `id_pressed` signal fires. Look at how `select` handles an OptionButton for the pattern. It refuses a disabled item and names its tooltip.
- Refuse with an `ERROR:` reply that names the menu and lists its items when the text matches nothing, and when it matches more than one item.
- Make the fixture use it: a small menu off the boot screen (reached by `goto`, like the nested-scroll scene), and a scenario that picks an item and asserts what it did.
- Document the command beside `select` in `docs/godot-tooling.md`. Load `writing-instructions` first.

The gate is `tools/check.sh --ci`, green. When this lands, the PM tells iceengine-pm.

## Progress

## Left for later
