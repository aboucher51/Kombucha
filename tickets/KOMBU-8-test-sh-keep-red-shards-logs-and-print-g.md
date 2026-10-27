---
id: KOMBU-8
title: test.sh: keep red shards' logs and print GUT's error text
status: claimed
priority: 2
owner: kombucha-worker
pid: 1433256
depends_on: []
touches: [tools/test.sh, tools/selftest.sh, docs/godot-tooling.md, .gitignore]
created: 2026-10-26
updated: 2026-10-26
---

When the unit suite is red, keep the evidence and print the error text, so a flake can still be read after the run.

Request from navalwar-pm (NavalWar's NAVAL-87). A unit-suite flake could not be read afterwards:
- The gate printed only "[Failed]: Unexpected Errors:", with no error text under it.
- The shard logs and JUnit XML were in tools/test.sh's `mktemp -d` folder (`WORK`), gone by the time anyone looked; a rerun then overwrote .godot/test-results.xml.
- The "── failing assertions ──" list named a test from test_json_value.gd under test_objective_marks.gd's header, so the file label in that list may be wrong.

What to do (tools/test.sh):
1. When a shard is red (failed, timed out, or a script failed to load), copy its log and its JUnit XML to a kept, gitignored place before WORK is removed, like shoot.sh keeps shots/shard.*.log. Suggest `.godot/test-logs/shard.N.log` + `.xml`, cleared at the start of each run; print the path in the red summary. Green shards keep nothing.
2. Under "── failing assertions ──", print GUT's error text for an "Unexpected Errors" failure (the push_error / engine error lines GUT counted), not only the header line.
3. Find and fix why a test is listed under another script's header in that list (likely the log parser carrying the last-seen header across shard logs or across GUT's own ordering). Add a selftest case or a unit test with two scripts in one shard where the second fails.
- Fixture (CLAUDE.md: every runner flag needs a fixture user): tools/selftest.sh already proves runner guards against scratch copies; add a case with a test that push_errors unexpectedly and assert (a) the kept log exists, (b) the error text is printed, (c) it is listed under the right file.
- Docs: a line in docs/godot-tooling.md "Tests" where "A red run repeats its failing assertions" is.
When done, tell the PM so navalwar-pm can be told.

## Progress
- 2026-10-26 18:26 Committed a93b18f. Wrong label cause: report_failures read GUT's Run Summary too, whose script headers changed the label but whose '- test_x' names it ignored, so every failure was listed twice and the second under the next file. Now each log is read once (summary when present, else the stream), error lines under 'Unexpected Errors' are printed, red logs/XML kept in .godot/test-logs (suite clears shard.*, named clears named.*). .gitignore needs no change (.godot/ already ignored). Selftest 2g: 4 cases, all red on old test.sh, green on new. Found and filed KOMBU-9: tests that set treat_push_error_as NOTHING leak it to every later test in the shard.
- 2026-10-26 18:28 Full check --ci green (109 s): 139 tests, 20 scenarios, 0 engine errors, the 7 new gate cases ok. Branch kombu-7-8-runners (3ebcf5c, a93b18f) on origin/main d125fc5. Push request sent to the PM; waiting for Alex's yes.
- 2026-10-26 23:27 Push blocked the same way as KOMBU-7; see its note. Not pushed.

## Left for later
