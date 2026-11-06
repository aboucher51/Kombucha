---
id: KOMBU-41
title: Harness: pick a PopupMenu item by its text
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, tests/test_screenshot_harness.gd, tools/new-project.sh, docs/godot-tooling.md, scenarios/, scripts/, scenes/, .godot-map/graph.json, PROJECT_MAP.md]
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
- 2026-11-06 18:34 Worktree ../Kombucha-b4 on branch kombu-b4. PopupMenu has no activate_item in 4.7; the menu verb emits id_pressed/index_pressed like select does.
- 2026-11-06 18:37 menu verb, fixture scene scenes/harness_inputs.tscn (goto), scenarios/menu.txt, tests; refusal texts checked in serve mode.
- 2026-11-06 18:37 Added tests/test_screenshot_harness.gd (pins menu_index and parse_drag) and tools/new-project.sh (keeps the fixture scene and scenarios out of a scaffold) to touches.
- 2026-11-06 18:41 Gate tools/check.sh --ci green on ce84c30 (forge, llvmpipe). Filed KOMBU-43.
- 2026-11-06 18:41 done on main at ce84c30

## Ready to play
What changed: scenarios can now write `menu <MenuButton or PopupMenu> <item text or id>`. The harness opens a MenuButton's menu and fires the item the way a click would. A plain PopupMenu must be open first.

What the scenarios and shots showed: `scenarios/menu.txt` picks Rename by text and Duplicate by id from the fixture's Edit menu, opens the context menu with a click and picks Close. It also checks four refusals (a disabled item, an unknown item, two items named Copy, a closed menu). In serve mode each refusal names the menu and lists its items. `shots/menu-01-context-open.png` shows the context menu open under its button, with nothing cut off.

Questions for a person:
- Should text win over an id? Today an item whose text is "7" beats the item with id 7.
- Is refusing a closed PopupMenu right, or should the harness open it at the mouse?

## Left for later
- [[KOMBU-43]] submenus and MenuBar menus
