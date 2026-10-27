---
id: KOMBU-10
title: test.sh: fail a run when a test switches off GUT's push_error tracking
status: claimed
priority: 3
owner: kombucha-worker
pid: 1433256
depends_on: []
touches: [tools/test.sh, tools/selftest.sh, docs/godot-tooling.md]
created: 2026-10-26
updated: 2026-10-27
---

Left over from KOMBU-9 (2026-10-26).

KOMBU-9 fixed Kombucha's own two tests and changed the docs. But every synced project followed the old docs line, `gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.NOTHING`. GUT keeps one tracker per process, so after that line every later test in the shard can log errors and still pass. A docs change does not fix the tests a project already has.

Idea: test.sh greps tests/ for `treat_push_error_as` (and `treat_engine_errors_as`) set to anything but FAILURE. It fails the run and names the file and line, with the fix: `assert_push_error("text")`. Prove it in selftest.sh with a planted test, both ways.

Let the PM decide whether this should be a failure or a warning at first, since it will turn projects' runs red on the next sync.

## Progress
- 2026-10-26 23:37 PM: failure vs warning put to Alex 2026-10-26. PM recommends a failure (red, naming file:line and the fix), since a warning under a green run is what hid this.
- 2026-10-27 18:07 Alex 2026-10-27: WARN, not fail. test.sh prints a warning naming file:line and the fix (assert_push_error), and the run stays green.

## Left for later
