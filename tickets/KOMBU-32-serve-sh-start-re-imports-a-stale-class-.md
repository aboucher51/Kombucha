---
id: KOMBU-32
title: serve.sh start re-imports a stale class cache too
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [tools/serve.sh, tools/selftest.sh, docs/godot-tooling.md]
created: 2026-11-01
updated: 2026-11-01
---

KOMBU-28 put the class-cache comparison in tools/class-cache.sh and calls it from check.sh, test.sh and shoot.sh. tools/serve.sh start does not call it yet. A fresh worktree with no import is exactly the case behind KOMBU-29: serve.sh start now fails cleanly after SERVE_START_S, but it could import first and start.

What to do: call tools/class-cache.sh in serve.sh start, before the engine starts. Update the KOMBU-29 self-test case in tools/selftest.sh: a copy with no .godot/ would now serve, so plant a real parse error instead to keep proving the stop.

## Progress
- 2026-11-01 05:02 added docs/godot-tooling.md to touches: its class-cache and serve paragraphs named the old behaviour. serve.sh start calls tools/class-cache.sh; selftest: a copy with no .godot now imports and serves, and the stop case plants a parse error in the harness. Both tried by hand in a scratch copy (start1=0 with the note; start2=1, 0 processes left).
- 2026-11-01 05:05 gate green on 5620e47: check.sh --ci, 146 tests; selftest 'serve.sh start imports a fresh worktree, then serves' and 'a served engine that never starts serving is stopped, and start fails' ok. Handed to kombucha-pm.
- 2026-11-01 05:06 done on main at 5620e47

## Left for later
