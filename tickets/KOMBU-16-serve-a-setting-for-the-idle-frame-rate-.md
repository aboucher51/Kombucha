---
id: KOMBU-16
title: serve: a setting for the idle frame rate (SERVE_IDLE_FPS)
status: ready
priority: 3
owner: 
depends_on: []
touches: [tools/serve.sh, scripts/dev/screenshot_harness.gd, tools/check.local.sh, docs/godot-tooling.md]
batch: KOMBU-B1
created: 2026-10-28
updated: 2026-10-28
---

Make the served engine's idle frame rate a setting, so a project can idle lower than 10 fps.

Request from mapledot-pm (Mapledot MAPLE-171). KOMBU-7 made a waiting `--serve` engine draw at a fixed `SERVE_IDLE_FPS := 10` (scripts/dev/screenshot_harness.gd:120). Mapledot's play.sh used to freeze sessions at 5 fps; at 10, a frozen field session went from about 80% to 131% CPU.

What to do:
- A `--serve-idle-fps <n>` command-line value (read with Cmdline like `--serve-idle`), passed by tools/serve.sh from `SERVE_IDLE_FPS` (default 10). Keep 10 as the default; say in a comment what the number trades (reply latency: a command is picked up within one idle frame, so 5 fps is up to 0.2 s).
- Reject nonsense (0 or negative falls back to the default, with a printed note).
- Fixture: extend KOMBU-7's local-gate case in tools/check.local.sh to start a served engine with SERVE_IDLE_FPS=5 and check the engine reports or uses it (e.g. its "serving" line prints the idle fps).
- Docs: the serve paragraph in docs/godot-tooling.md and serve.sh's header comment.
When it lands, tell the PM so mapledot-pm can be told.

## Progress

## Left for later
