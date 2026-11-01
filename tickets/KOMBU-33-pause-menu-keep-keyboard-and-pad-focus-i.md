---
id: KOMBU-33
title: Pause menu: keep keyboard and pad focus inside the panel
status: done
priority: 2
owner: kombucha-worker
depends_on: []
touches: [scripts/ui/pause_menu.gd, scenarios/, tests/, scripts/ui/ui_focus.gd, scripts/main.gd]
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
- 2026-11-01 05:14 added scripts/ui/ui_focus.gd (the fix lives in UIFocus.keep_inside so other modals can use it) and scripts/main.gd (a 'focus' state key, so a scenario can assert the focus owner) to touches. The fixture already showed the bug: ui_down from Quit -> Row01, Tab -> QualityDropdown, left -> Row01; no new control needed, boot frame unchanged. scenarios/pause_focus.txt red before the fix, green after; tests/test_ui_focus_ring.gd added. Filed KOMBU-34.
- 2026-11-01 05:17 gate green on fd9b396: check.sh --ci, 148 tests, 21 scenarios. Play pass done (Ready to play section). Handed to kombucha-pm.
- 2026-11-01 05:18 done on main at fd9b396

## Ready to play
What changed: while the pause menu is open, the arrow keys, Tab and a pad's stick stay inside the menu. Down from Quit goes back to the top slider (All sound), and up from the top goes to Quit. Left and right on a button do nothing, and on a slider they still change the volume. Before, down from Quit jumped to Row 1 behind the dim, Tab jumped to the Medium dropdown, and Enter then pressed whatever was behind.

What the scenarios and shots showed: scenarios/pause_focus.txt walks the whole ring: down, up, Tab, Shift+Tab, left, then Enter on Resume. It was red before the fix on all three escapes, and it is green after. In shots/keyboard_menu-01-focus-ring.png, the ring sits on Resume with nothing cut off. shots/pause_focus-01-after-resume.png shows the game back, with no row pressed.

Questions only a person can answer:
- With a pad, does wrapping from Quit back to the top feel right, or should focus stop at Quit?
- The sliders still draw no focus ring (Godot has no slider focus style). Can you tell which slider has focus when you play with a pad?
- Should Escape or the pad's back button inside the menu always resume, even while a slider has focus?

## Left for later
- [[KOMBU-34]] shoot.sh exits 0 when a scenario quits the engine mid-run
