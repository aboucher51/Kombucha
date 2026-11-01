---
id: KOMBU-30
title: A new project fails its first check: a console test needs the fixture's own command row
status: claimed
priority: 1
owner: kombucha-worker
pid: 2996295
depends_on: []
touches: [tests/test_debug_console.gd, tools/selftest.sh, tools/new-project.sh, scripts/dev/debug_console.gd]
created: 2026-11-01
updated: 2026-11-01
---

Make a freshly scaffolded project pass its first check. This blocks Alex's new project, emblem-autobattler. forgemaster waits for this ticket to land before it scaffolds again.

What happened (forgemaster, 2026-11-01): `tools/new-project.sh ../emblem-autobattler "Emblem Autobattler"` from current main. The scaffold's first check failed 1 of 105 tests, so the script made no commit:
`res://tests/test_debug_console.gd test_a_project_row_replaces_the_core_row_with_its_id`: "Expected 'seed <n>' to contain 'the fixture's own row'". The full log is at /tmp/claude-1000/-home-aboucher51-forge-config/123fa573-ee0a-4504-a6eb-13befa1a785f/scratchpad/emblem-new.log on forge.

Cause, found by the PM: `tests/test_debug_console.gd` lines 115-122 (added in b057879, KOMBU-14) read the `seed` row in Kombucha's own `data/console_commands.project.json`. `tools/new-project.sh` (line 87) leaves that file out of a new project and seeds an empty one. So the test cannot pass in any new project. The text cleanup did not cause this.

What to do:
- Make the test bring its own project row. For example, point the console at a scratch project-commands file in `before_each`, and restore the old path in `after_each`, the same way the save tests redirect `SaveManager`. Keep what the test proves: a project row with a core row's id replaces that row in `help`, in the suggestions and in dispatch. If the console has no seam for the file path yet, add one.
- Look for any other test in `tests/` that reads a path `new-project.sh` leaves out, like `dev_hooks.gd`, the excluded scenarios, `check.local.sh` or `check.local.env`. Fix each one the same way.
- Prove it in `tools/selftest.sh`. The new-project step runs with `--no-check` today, so it never ran the scaffold's tests. After the scaffold, run the scaffold's `tools/test.sh` (headless, quick), and require it green. Watch that step go red on today's main before you fix the test.

When it lands, the PM tells forgemaster that main scaffolds green. The gate is `tools/check.sh --ci`, green.

## Progress
- 2026-11-01 04:30 PM: forgemaster pushed emblem-autobattler with the red test anyway (Alex wanted to start). When this lands, tell forgemaster and emblem-autobattler-pm. tests/test_debug_console.gd is not in tools/tooling-manifest.txt, so a sync will not carry the fix. emblem-autobattler must copy the fixed test by hand. Say so in your report.
- 2026-11-01 04:31 PM, second scaffold bug in the same files (from emblem-autobattler-pm): new-project.sh copied Kombucha's whole tickets/ folder into the new repo. That was 28 KOMBU-* tickets, the batches, PUSH_POLICY ("pm") and KEY ("KOMBU"). A copied claim kept kombucha-worker's real pid. Fix: leave tickets/ out of the scaffold entirely (tickets/*.md, tickets/batches/, PUSH_POLICY, HOLD, KEY). The new project's PM runs tk init with its own key, and only Alex sets PUSH_POLICY. Prove it in the self-test's new-project step: the scaffold has no tickets/ files from Kombucha. emblem-autobattler already removed its copies in 8241499.
- 2026-11-01 04:44 red proof: scaffold from main carries tickets/ (KEY, KOMBU-*) and its tests fail 1 of 105 (test_a_project_row_replaces_the_core_row_with_its_id). Added scripts/dev/debug_console.gd to touches: the console had no seam for the project-commands path; added project_commands_path + reload_commands() (synced file, so projects get the seam on sync).
- 2026-11-01 04:47 gate green on ded6377: check.sh --ci, 146 tests; selftest 'the scaffold carries no tickets from Kombucha' and 'the scaffold's own tests pass (105 tests)' ok (both red on main before the fix). Handed to kombucha-pm.

## Left for later
- [[KOMBU-31]] sync the tests that check owned tooling (test_debug_console.gd first)
