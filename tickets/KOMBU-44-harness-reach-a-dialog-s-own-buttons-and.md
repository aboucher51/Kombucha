---
id: KOMBU-44
title: Harness: reach a dialog's own buttons, and match menu text before a tab
status: ready
priority: 3
owner: 
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, tests/test_screenshot_harness.gd, docs/godot-tooling.md, scenarios/, scripts/harness_inputs.gd, scenes/harness_inputs.tscn, .godot-map/graph.json, PROJECT_MAP.md]
created: 2026-11-06
updated: 2026-11-06
---

Fix two gaps IceEngine hit with the new harness commands (iceengine-pm, 2026-11-06).

1. The harness's node lookup skips a node's internal children. An AcceptDialog's OK button is one of those, and so are the buttons of a ConfirmationDialog or a FileDialog. `Node.find_children` includes them, but the harness's lookup does not. So `click` cannot press a dialog's own buttons by name. IceEngine names those buttons and presses them through its own `dev_hooks.gd` for now.
   - Make the lookup include internal children, so `click`, `hover`, `assert_visible` and the rest reach a dialog's own buttons. Keep the rule that a name shared by two visible nodes is an ERROR.
   - Check that the change does not make any existing scenario's name ambiguous. Run every scenario.
2. `menu` needs an item's exact text. A row with a shortcut, like "Save\tCtrl+S", can only be picked by id today.
   - Also match the text before the first tab. Keep exact matches working, and keep the refusal when two items match.

Make the fixture use both: a dialog in `scenes/harness_inputs.tscn` whose OK button a scenario clicks by name, and a menu item with a shortcut that a scenario picks by its text. Watch each new scenario line go red before the fix. Update `docs/godot-tooling.md` where it describes the lookup and `menu`. Load `writing-instructions` first.

The gate is `tools/check.sh --ci`, green. When this lands, the PM tells iceengine-pm.

## Progress

## Left for later
