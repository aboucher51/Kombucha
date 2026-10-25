---
id: KOMBU-6
title: Harness drag: real cursor warps end a drag that checks button_mask
status: ready
priority: 2
owner: 
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, scenarios/drag.txt, scripts/main.gd, scenes/main.tscn, docs/godot-tooling.md]
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

## Left for later
