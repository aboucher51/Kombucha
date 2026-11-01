---
id: KOMBU-30
title: A new project fails its first check: a console test needs the fixture's own command row
status: ready
priority: 1
owner: 
depends_on: []
touches: [tests/test_debug_console.gd, tools/selftest.sh, tools/new-project.sh]
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

## Left for later
