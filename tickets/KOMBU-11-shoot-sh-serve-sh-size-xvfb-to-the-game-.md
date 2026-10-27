---
id: KOMBU-11
title: shoot.sh/serve.sh: size Xvfb to the game window, not 1280x720
status: done
priority: 2
owner: kombucha-worker
depends_on: []
touches: [tools/shoot.sh, tools/serve.sh, tools/check.local.sh, docs/godot-tooling.md, tools/xvfb-screen.sh, tools/tooling-manifest.txt]
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
- 2026-10-27 04:02 Claimed (PM said build on top of kombu-9-error-tracker). Network policy re-read 2026-10-27.
- 2026-10-27 04:05 Added tools/xvfb-screen.sh (the one helper both scripts call, as the ticket asks) and tools/tooling-manifest.txt (so the helper syncs with them) to touches. Sizing: SHOOT_RESOLUTION, else project.godot window override, else viewport, floor 1280x720; not a big fixed screen, because a fullscreen project would grow to it and change its shots. Proof: scratch copy at 1600x900, hover TwinA (x=1532): old shoot.sh and old serve.sh land on CenterContainer, new ones pass. New local gate case red on old shoot.sh, green on new.
- 2026-10-27 04:07 Full check --ci green on 8c5c5b3 (139 tests, 20 scenarios, 0 engine errors, new Xvfb-screen case ok), origin/main d125fc5. Branch kombu-11-xvfb-size on top of kombu-9-error-tracker. Waiting for Alex's yes and for git push to be allowed in this session.
- 2026-10-27 18:06 2026-10-27: Alex's standing yes relayed by kombucha-pm; origin still d125fc5, but git push of kombu-11-xvfb-size was blocked again by this session's permission check. Not pushed; stopped as the PM asked.
- 2026-10-27 18:07 PM pushed kombu-11-xvfb-size (8c5c5b3) to main from kombucha-pm on Alex's direct go-ahead 2026-10-27 (the worker's session blocks git push).
- 2026-10-27 18:08 Landed on origin/main in d125fc5..8c5c5b3 (pushed by kombucha-pm on Alex's go-ahead).
- 2026-10-27 18:08 done on main at c2660d1

## Left for later
