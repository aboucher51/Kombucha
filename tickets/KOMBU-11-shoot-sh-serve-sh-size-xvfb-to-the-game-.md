---
id: KOMBU-11
title: shoot.sh/serve.sh: size Xvfb to the game window, not 1280x720
status: ready
priority: 2
owner: 
depends_on: []
touches: [tools/shoot.sh, tools/serve.sh, tools/check.local.sh, docs/godot-tooling.md]
created: 2026-10-27
updated: 2026-10-27
---

Size the virtual display (Xvfb) to the game window, so `hover` and the real cursor reach the whole window in a project bigger than 1280x720.

Found by navalwar-worker (NavalWar NAVAL-120; NavalWar has a workaround in its own scenario and will sync the fix). shoot.sh and serve.sh (tools/serve.sh:89) start Xvfb with `-screen 0 ${SHOOT_RESOLUTION:-1280x720}x24`, but the window opens at the project's own size (NavalWar: 1600x900). X keeps the real cursor inside its screen, so a warp stops at (1279, 719). `hover` warps the real cursor, and that real motion lands after the synthetic one, so the hover reads whatever is under the clamped point. In NavalWar, Settings' Apply button at (1292, 760) read as hovering the scroll area above it. Clicks are not affected (they are pushed events). `drag` (KOMBU-6) waits for the real motion at the warped point, so it may also stall there for its 30 frames.

What to do (tools/shoot.sh, tools/serve.sh):
- Size the Xvfb screen from SHOOT_RESOLUTION if set, else from project.godot's window size (`window/size/window_width_override` / `_height_override` when set, else `viewport_width` / `viewport_height`), else 1280x720. Or a large fixed screen like 3840x2160, if that does not change any shot (window placement, baselines): measure, and say in a comment which and why.
- One helper both scripts use, so they cannot drift.
- Fixture: Kombucha's own window is 1280x720, so the bug cannot show here today. Prove it in the local gate (tools/check.local.sh), which already runs at named sizes: run a hover scenario at SHOOT_RESOLUTION larger than 1280x720 on a target near the bottom-right; it must go red on the old code and green on the new.
- Docs: a line in docs/godot-tooling.md where the virtual display is described.

## Progress

## Left for later
