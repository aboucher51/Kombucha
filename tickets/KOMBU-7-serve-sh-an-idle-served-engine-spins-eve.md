---
id: KOMBU-7
title: serve.sh: an idle served engine spins every core, and outlives its folder
status: ready
priority: 2
owner: 
depends_on: []
touches: [tools/serve.sh, scripts/dev/screenshot_harness.gd]
created: 2026-10-25
updated: 2026-10-25
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

## Left for later
