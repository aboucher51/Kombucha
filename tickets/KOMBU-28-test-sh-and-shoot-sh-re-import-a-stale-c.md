---
id: KOMBU-28
title: test.sh and shoot.sh re-import a stale class cache too, through one shared helper
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [tools/check.sh, tools/test.sh, tools/shoot.sh, tools/selftest.sh, tools/tooling-manifest.txt, docs/godot-tooling.md, tools/class-cache.sh]
created: 2026-11-01
updated: 2026-11-01
---

KOMBU-27 made tools/check.sh compare .godot/global_script_class_cache.cfg with the class_name lines on disk and re-import when they differ. tools/test.sh and tools/shoot.sh still run against a stale cache, so a named test run on a fresh pull or worktree fails with parse errors that are not real (memory note fresh-worktree-needs-import: it cost one gate run on KOMBU-22).

What to do: move the comparison out of check.sh into one shared helper (like tools/parse-error.sh), and call it from test.sh and shoot.sh too. Keep the selftest case in section 4 and add one for a named test.sh run. Add the helper to tools/tooling-manifest.txt.

## Progress
- 2026-11-01 04:57 added tools/class-cache.sh to touches (the shared helper). Moved the comparison out of check.sh into it; test.sh and shoot.sh call it before their first engine; manifest lists it; selftest 2i: a named test.sh run from an empty cache re-imports and passes. Filed KOMBU-32 for serve.sh.
- 2026-11-01 05:00 gate green on 9beea86: check.sh --ci, 146 tests; selftest 'a named test run re-imports a stale class cache first' ok, KOMBU-27 cases still ok. Handed to kombucha-pm.
- 2026-11-01 05:01 done on main at 66813ab

## Left for later
- [[KOMBU-32]] serve.sh start re-imports a stale class cache too
