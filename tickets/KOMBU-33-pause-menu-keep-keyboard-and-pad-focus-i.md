---
id: KOMBU-33
title: Pause menu: keep keyboard and pad focus inside the panel
status: ready
priority: 2
owner: 
depends_on: []
touches: [scripts/ui/pause_menu.gd, scenarios/, tests/]
created: 2026-11-01
updated: 2026-11-01
---

Keep keyboard and pad focus inside the pause menu while it is open. Make focus wrap from the last control back to the first, and the other way round.

What happened (emblem-autobattler-pm, EMBL-15, 2026-11-01): in emblem-autobattler, pressing `ui_down` on the pause menu's last slider moved focus to the start screen's Play button, behind the dim. Then `ui_accept` pressed Play. Its `scenarios/keyboard_menu.txt` went red. Any project with a focusable screen behind the pause menu has this bug. Kombucha's fixture never showed it, because no focusable control sat where Godot's focus search landed.

The project's fix: `_keep_focus_inside()` in emblem-autobattler's `scripts/ui/pause_menu.gd`, commit ba067c1. It points each focusable control's focus neighbours (`focus_neighbor_top`, `focus_neighbor_bottom`, `focus_next`, `focus_previous`) at the panel's own controls, with wrap-around. Read only the focus part. That project also removed the fixture's lever from its copy, and Kombucha keeps the lever.

What to do:
- Bring the focus fix into Kombucha's `scripts/ui/pause_menu.gd`. Think about whether it belongs in `UIFocus` (`scripts/ui/ui_focus.gd`) instead, so other modal panels can use it too.
- Make the fixture show the bug first. Add a focusable control behind the pause menu where focus would land, and a scenario that opens the menu, presses `ui_down` past the last control, and asserts that focus is still inside the menu. Watch the scenario go red before the fix. Put the new control off the boot screen, because the boot frame is a baseline (memory note boot-frame-is-a-baseline).
- Load `godot-ui` and `godot-game-accessibility` first.
- This is a kit file, so projects copy it by hand. After it lands, the PM tells emblem-autobattler-pm.

The gate is `tools/check.sh --ci`, green.

## Progress

## Left for later
