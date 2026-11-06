---
id: KOMBU-44
title: Harness: reach a dialog's own buttons, and match menu text before a tab
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, tests/test_screenshot_harness.gd, tools/new-project.sh, docs/godot-tooling.md, scenarios/, scripts/harness_inputs.gd, scenes/harness_inputs.tscn, .godot-map/graph.json, PROJECT_MAP.md]
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
- 2026-11-06 18:54 Added tools/new-project.sh to touches: it keeps the new scenarios/dialog.txt out of a scaffold, like menu.txt.
- 2026-11-06 18:54 Both new scenario lines went red before the fix. Fix: lookup walks get_children(true); root_point adds an embedded Window's position (red-proof: without it the OK click misses); menu matches text before a tab. Window.get_embedder is not exposed to GDScript, so the harness walks up by hand.
- 2026-11-06 18:58 Gate tools/check.sh --ci green on 08669c3 (forge, llvmpipe): 26 scenarios, no ambiguous name.
- 2026-11-06 18:58 done on main at 08669c3

## Ready to play
What changed: the harness lookup now reaches internal children, so `click SavedOkButton` presses a dialog's own OK button once the game names it. The harness adds the dialog's position, so the click lands on the button. `menu EditMenu Save` picks a row written "Save\tCtrl+S". An exact match still wins, and two matches are still refused.

What the scenarios and shots showed: both new lines went red before the fix. `scenarios/dialog.txt` refuses the OK button while the dialog is closed, opens it, clicks OK by name and asserts `dialog confirmed`. `shots/dialog-01-dialog-open.png` shows the dialog centred with OK focused. When I removed the dialog-position step on purpose, the OK click missed and the scenario went red. All 26 scenarios in the gate passed, and no lookup reported a name as ambiguous.

Questions for a person:
- Godot gives a dialog's buttons auto-names. Should the kit name them for you (for example `<Dialog>Ok`), so a game needs no line of its own?
- A row's shortcut sits in its text after a tab. Should a scenario also be able to pick a row by its shortcut ("Ctrl+S")?

## Left for later
- none
