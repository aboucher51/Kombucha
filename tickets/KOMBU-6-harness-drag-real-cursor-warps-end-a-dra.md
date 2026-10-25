---
id: KOMBU-6
title: Harness drag: real cursor warps end a drag that checks button_mask
status: done
priority: 2
owner: kombucha-worker
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, scenarios/drag.txt, scripts/main.gd, scenes/main.tscn, docs/godot-tooling.md, PROJECT_MAP.md, .godot-map/graph.json, scripts/ui/pause_menu.gd]
created: 2026-10-25
updated: 2026-10-25
---

Fix the harness `drag` verb (KOMBU-1) so it can move a control that ends its drag on a mouse motion with no button held. NavalWar's music Speed lever works this way, and so would most hand-made sliders. Today `drag` cannot move it.

Found by navalwar-worker (NAVAL-53; NavalWar's lever test is NAVAL-59, waiting on this). It logged the lever's _gui_input at Kombucha 57bf7c3 on Xvfb (forge, SHOOT_DISPLAY auto):
- The pushed press arrives, and the lever starts dragging.
- Every drag step brings TWO motion events: the harness's own (button_mask 1) and a real one from `_warp_cursor` (button_mask 0, one frame late, at the warped spot).
- The buttonless motion ends the drag. That is right for a real mouse released outside the window.
- Removing only the per-step warp is not enough: the warp before the press lands one frame after the press, still with no button.
An HSlider ignores button_mask, which is why scenarios/drag.txt passes and missed this.

What to do (scripts/dev/screenshot_harness.gd, `drag`):
- Warp to the start, wait until the OS motion from that warp has arrived, then press.
- Do not warp while the button is held. The per-step re-warp was KOMBU-1's guard against another shard moving the shared cursor mid-drag on the REAL display. Decide what to do there (for example: no warps while held on any display, and say in a comment and in docs/godot-tooling.md that a drag on the real display wants SHOOT_JOBS=1, like hover). Write the reason in a comment.
- Fixture: add a small control to the fixture that ends its drag on any motion with no button held, like the lever (a code-built Control with a stable name, in the pause menu or main scene). Drag it in scenarios/drag.txt and assert its value through state readback. Prove the scenario goes red with today's code before the fix.
- Tell the PM when done, so navalwar-pm can be told.

## Progress
- 2026-10-25 19:58 Branch kombu-6-drag-warp. Fixture: code-built Lever in main.gd (lets go on a buttonless motion), state key 'lever'; drag.txt drags it. RED on today's harness: lever stuck at 50 (drag.txt:22, :24). Fix: drag warps to the start and waits for the window to see that OS motion (window_input), then presses; no warps while held; warp to the end after release. Docs line added. Green run waiting on the render slot.
- 2026-10-25 20:14 Scenario green with the fix (lever 0 and 100). Added PROJECT_MAP.md and .godot-map/graph.json to touches: main.gd's new functions change the generated map. Commit 75699a1 on origin/main 57bf7c3. Running the full check.
- 2026-10-25 20:19 Full check 1 was red only on baseline.txt: the lever on the boot screen changed the committed boot baseline (4790 px = its rect). Forge cannot redraw the nvidia (desktop GPU) baseline, so the lever moved into the pause menu (ticket allowed it); the boot frame is unchanged. Touches gained scripts/ui/pause_menu.gd, and PROJECT_MAP.md and .godot-map/graph.json (regenerated map). Re-proving red/green, then the full check again.
- 2026-10-25 20:52 Full check green: 139 tests, 20 scenarios, 0 engine errors (32 min, mostly waiting for the render slot). Commit 85dd1a3 on origin/main 57bf7c3, 7 files, +136 -20. Push request sent to the PM; waiting for Alex's yes.
- 2026-10-25 22:18 Pushed after Alex's yes (via PM): 57bf7c3..85dd1a3.
- 2026-10-25 22:18 done on main at fefc33e

## Left for later
