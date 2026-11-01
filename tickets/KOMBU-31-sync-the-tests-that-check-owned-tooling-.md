---
id: KOMBU-31
title: Sync the tests that check owned tooling (test_debug_console.gd first)
status: ready
priority: 3
owner: 
depends_on: []
touches: [tools/tooling-manifest.txt, tools/selftest.sh, docs/godot-tooling.md]
created: 2026-11-01
updated: 2026-11-01
---

KOMBU-30 fixed tests/test_debug_console.gd, but tools/tooling-manifest.txt does not list it. So a sync never brings the fix to a project, and emblem-autobattler must copy it by hand. The same holds for every kit test that only checks owned tooling (the console, the harness parts a project keeps).

What to do: decide which tests in tests/ check only owned files, and list those in the manifest so a sync carries them. A test that checks kit files a project may change (autoloads, UI) stays a copy. Prove it in the self-test's sync step: a sync refreshes a listed test.

## Progress

## Left for later
