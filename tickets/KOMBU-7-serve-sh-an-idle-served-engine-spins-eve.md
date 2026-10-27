---
id: KOMBU-7
title: serve.sh: an idle served engine spins every core, and outlives its folder
status: done
priority: 2
owner: kombucha-worker
depends_on: []
touches: [tools/serve.sh, scripts/dev/screenshot_harness.gd, tools/check.local.sh, docs/godot-tooling.md, .godot-map/graph.json]
created: 2026-10-25
updated: 2026-10-27
---

Found in Mapledot (MAPLE-62, 2026-10-25). A `tools/serve.sh` engine waiting for its next command draws frames as fast as it can. On forge (llvmpipe, Xvfb) one sat at about 2,000% CPU on a login screen, and a leftover one ran 17 hours at 15 cores after its worktree was removed.

What serve.sh and the harness's `_serve` loop do today:
- No frame cap while waiting for a command. Mapledot measured: a cap of 5 fps while idle takes a frozen session from ~2,000% to ~30%.
- No `LP_NUM_THREADS` cap, unlike shoot.sh.
- No idle timeout: an engine nobody talks to runs forever.
- `_serve` does `if dir == null: continue` when its folder is gone, so an engine whose worktree was removed polls forever.
- Nothing stops an engine whose `--path` project is gone.

Mapledot fixed its play sessions in its own files (PlaySession caps fps while frozen and stops itself after 30 idle minutes or when res://project.godot is gone; play.sh sets LP_NUM_THREADS=4 and kills orphaned `--serve` engines). The same belongs in serve.sh and the harness for every project: cap fps between commands, cap llvmpipe threads, quit when the serve folder or the project is gone, and quit after an idle limit (SERVE_IDLE_S).

## Progress
- 2026-10-26 18:15 Branch kombu-7-8-runners. Harness _serve: 10 fps while waiting, stops after --serve-idle s (serve.sh SERVE_IDLE_S, default 1800, 0 never) and when the serve folder or res://project.godot is gone. serve.sh: LP_NUM_THREADS 4 on llvmpipe, prints the harness's stop reason. Touches gained check.local.sh (3 new gate cases: idle CPU, idle limit, folder gone) and docs/godot-tooling.md. Proven: old harness 307% CPU + both stop cases red; fix 25% CPU + green.
- 2026-10-26 18:26 Committed 3ebcf5c (map graph.json regenerated, added to touches). Full check next, batched with KOMBU-8.
- 2026-10-26 18:28 Full check --ci green (109 s): 139 tests, 20 scenarios, 0 engine errors, the 7 new gate cases ok. Branch kombu-7-8-runners (3ebcf5c, a93b18f) on origin/main d125fc5. Push request sent to the PM; waiting for Alex's yes.
- 2026-10-26 23:27 Alex said yes (via kombucha-pm). Origin still d125fc5. git push was blocked by this session's permission check (auto mode classifier). Not pushed; branch kombu-7-8-runners still holds 3ebcf5c and a93b18f.
- 2026-10-27 18:06 2026-10-27: Alex's standing yes relayed by kombucha-pm; origin still d125fc5, but git push of kombu-11-xvfb-size was blocked again by this session's permission check. Not pushed; stopped as the PM asked.
- 2026-10-27 18:07 PM pushed kombu-11-xvfb-size (8c5c5b3) to main from kombucha-pm on Alex's direct go-ahead 2026-10-27 (the worker's session blocks git push).
- 2026-10-27 18:08 Landed on origin/main in d125fc5..8c5c5b3 (pushed by kombucha-pm on Alex's go-ahead).
- 2026-10-27 18:08 done on main at c2660d1

## Left for later
