---
id: KOMBU-32
title: serve.sh start re-imports a stale class cache too
status: ready
priority: 3
owner: 
depends_on: []
touches: [tools/serve.sh, tools/selftest.sh]
created: 2026-11-01
updated: 2026-11-01
---

KOMBU-28 put the class-cache comparison in tools/class-cache.sh and calls it from check.sh, test.sh and shoot.sh. tools/serve.sh start does not call it yet. A fresh worktree with no import is exactly the case behind KOMBU-29: serve.sh start now fails cleanly after SERVE_START_S, but it could import first and start.

What to do: call tools/class-cache.sh in serve.sh start, before the engine starts. Update the KOMBU-29 self-test case in tools/selftest.sh: a copy with no .godot/ would now serve, so plant a real parse error instead to keep proving the stop.

## Progress

## Left for later
