---
id: KOMBU-29
title: Serve engines outlive a failed gate run
status: ready
priority: 2
owner: 
depends_on: []
touches: [tools/check.local.sh, tools/serve.sh, tools/selftest.sh]
created: 2026-11-01
updated: 2026-11-01
---

Make sure no served engine survives a check run, even when the run fails. Make `tools/serve.sh start` fail when its engine never starts serving.

What happened (forgemaster, 2026-11-01): three engines started by `tools/check.local.sh`'s serve-mode checks (serve folders `a`, `b` and `c` under a scratch dir) ran for 3 hours after the run ended. Together they used about 8 to 9 cores. They came from the KOMBU-22 worker's first gate run in `Kombucha-wt22`. That run was red because the new worktree was never imported, so every class failed to load. Each engine sat under its own `xvfb-run`, with systemd as its parent. Even the engine started with `--serve-idle 2` kept running. The engines also outlived the removal of both the worktree and their serve folders. forgemaster stopped them by hand.

The PM's guess, not checked: with the classes broken, the harness never reached its serve loop. So the idle exit and the "project or serve folder is gone" exit never ran, and `serve.sh stop` found no engine it knew about.

What to do:
- In `tools/check.local.sh`, record every engine the serve checks start. Stop each one in an `EXIT` trap, so a failing or interrupted run still cleans up. Stop the engine's `xvfb-run` and `Xvfb` too.
- In `tools/serve.sh start`, wait for the engine's `harness: serving` line. If it does not come within a time limit, kill the engine and its display server, print why, and exit non-zero.
- Prove it in `tools/selftest.sh`: start the serve checks in a scratch copy whose harness cannot load (for example, skip the import), and check that no engine is left running afterwards. Watch the step go red before the fix.

Read `docs/godot-tooling.md` ("A served engine waiting for a command draws at 10 fps") and the serve parts of `scripts/dev/screenshot_harness.gd` first. The gate is `tools/check.sh --ci`, green.

## Progress

## Left for later
