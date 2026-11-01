---
id: KOMBU-27
title: check.sh: re-import when the class cache does not match the class_name scripts
status: ready
priority: 3
owner: 
depends_on: []
touches: [tools/check.sh]
created: 2026-11-01
updated: 2026-11-01
---

Found in Tandem (TAND-95). On forge, a project's .godot/global_script_class_cache.cfg was a week old and listed no classes. tools/check.sh --quick then failed the tests and the boot with parse errors ('Identifier Cmdline not declared', 'Could not find type LevelView3D') though the code was fine. A headless run reads the list and never rebuilds it. godot4 --headless --path . --import fixed it.

What to do: before the tests, compare the (class, path) pairs in the cache with the class_name lines of the project's .gd files (skip folders with a .gdignore). When they differ, run --import and print a note line. Tandem's tools/check.local.sh has this comparison, but it runs after the tests, so it can only re-import and fail the run with 'run the check again'. A check that runs before the tests belongs here. Filed by tandem-worker, 2026-11-01.

## Progress

## Left for later
