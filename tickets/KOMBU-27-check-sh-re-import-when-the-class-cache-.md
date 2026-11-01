---
id: KOMBU-27
title: check.sh: re-import when the class cache does not match the class_name scripts
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [tools/check.sh, tools/selftest.sh, docs/godot-tooling.md]
created: 2026-11-01
updated: 2026-11-01
---

Found in Tandem (TAND-95). On forge, a project's .godot/global_script_class_cache.cfg was a week old and listed no classes. tools/check.sh --quick then failed the tests and the boot with parse errors ('Identifier Cmdline not declared', 'Could not find type LevelView3D') though the code was fine. A headless run reads the list and never rebuilds it. godot4 --headless --path . --import fixed it.

What to do: before the tests, compare the (class, path) pairs in the cache with the class_name lines of the project's .gd files (skip folders with a .gdignore). When they differ, run --import and print a note line. Tandem's tools/check.local.sh has this comparison, but it runs after the tests, so it can only re-import and fail the run with 'run the check again'. A check that runs before the tests belongs here. Filed by tandem-worker, 2026-11-01.

## Progress
- 2026-11-01 03:49 worktree ../Kombucha-wt-27 on kombu-27-class-cache; plan: class-cache section in check.sh before tests (find, not git: selftest scratch has no .git), self-test case in section 4, docs line
- 2026-11-01 03:49 added tools/selftest.sh (the fixture must prove the new step fires) and docs/godot-tooling.md (the step needs its doc line) to touches
- 2026-11-01 03:51 committed 01b2d33; comparison matches Kombucha, IceEngine, NavalWar, Tandem; found real stale caches in Mapledot (57 lines) and Swarm (1, leader.gd newer than cache). Running the gate.
- 2026-11-01 04:11 PM: when this lands, tell tandem-pm, so Tandem can sync and drop its check.local.sh workaround (TAND-95).
- 2026-11-01 04:42 gate green: tools/check.sh --ci (TEST_JOBS=8, shared slots), 146 tests, 20 scenarios; selftest 'a stale class cache is re-imported before the tests' and 'a matching class cache is left alone' ok. Handed to kombucha-pm.
- 2026-11-01 04:43 done on main at 292ff6e

## Left for later
- [[KOMBU-28]] test.sh and shoot.sh re-import a stale class cache too, through one shared helper
