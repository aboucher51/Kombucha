---
id: KOMBU-16
title: serve: a setting for the idle frame rate (SERVE_IDLE_FPS)
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [tools/serve.sh, scripts/dev/screenshot_harness.gd, tools/check.local.sh, docs/godot-tooling.md, tests/test_screenshot_harness.gd]
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
- 2026-10-28 03:09 --serve-idle-fps added (harness _serve_idle_fps: empty or not a whole number >0 -> 10 with a printed note); serve.sh passes SERVE_IDLE_FPS; serving line prints '(idle N fps)'. check.local.sh: SERVE_IDLE_FPS=5 reaches the engine, =0 falls back with a note. Added tests/test_screenshot_harness.gd to touches: two pure unit tests for the parser, cheaper than a boot.
- 2026-10-28 03:17 Committed a6dec5c on worker/kombu-b1; full tools/check.sh --ci green on forge. Waiting for PM to land.
- 2026-10-28 03:18 PM pushed a6dec5c to main.
- 2026-10-28 03:18 done on origin/main at a6dec5c

## Ready to play
No game change; this is serve output. What changed: `SERVE_IDLE_FPS=5
tools/serve.sh start` makes a waiting engine draw at 5 frames per second.
The engine log's first line says the rate, as in
`harness: serving <dir> (idle 5 fps)`. A value of 0, below 0 or a word
gets 10, with a note line.
What the run showed: the local gate starts an engine with 5 and one with
0 and both lines pass; the CPU check at the default still passes. Two unit
tests pin the value parser.
Questions for a person:
- Should serve.sh print the idle rate on its own `serve: running` line
  too, not only in the engine log?
- Is 10 still the right default, or should forge default lower?

## Left for later
