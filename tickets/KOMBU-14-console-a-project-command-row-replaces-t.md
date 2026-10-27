---
id: KOMBU-14
title: Console: a project command row replaces the core row with the same id
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [scripts/dev/debug_console.gd, data/console_commands.project.json, scripts/dev/dev_hooks.gd, tests/test_debug_console.gd, docs/godot-tooling.md, PROJECT_MAP.md, .godot-map/graph.json]
created: 2026-10-27
updated: 2026-10-27
---

Let a project's console command row REPLACE a core row with the same id, so a project that takes over a core command shows its own usage and is listed once.

Request from navalwar-pm (NavalWar NAVAL-184). `seed` is declared in both data/console_commands.json (core) and NavalWar's data/console_commands.project.json. DebugConsole._absorb (scripts/dev/debug_console.gd:121) appends both rows, and _find_command (:550) returns the first, the core one. So `help seed` shows the core usage, dev_hooks runs the project's handler (hooks are asked first), and `help` lists seed twice.

What to do:
- When the project file's row has the same `id` as a core row, it replaces the core row in place (keep the core's position in `help`). The same rule the hooks already follow for handlers: the project is asked first.
- Decide and document what a project row whose id or alias collides with a core ALIAS does (suggest: the project wins and the core alias is dropped from that core row; say so in a comment).
- Suggestions (DebugConsole.suggest), help, usage errors and completion all read the replaced row.
- Fixture: the fixture's data/console_commands.project.json overrides one core command's surface (with a dev_hooks handler if it needs one). A unit test in tests/test_debug_console.gd asserts `help <id>` shows the project usage and `help` lists it once. Prove it red on today's code.
- Docs: one sentence in docs/godot-tooling.md 'The debug console', where 'The hooks are asked first' is.
When it lands, tell navalwar-pm (NavalWar will sync).

## Progress
- 2026-10-27 20:51 merge_commands: project row with a core id replaces it in place; a project id/alias that is a core alias takes it (dropped from the core row); _find_command tries ids before aliases. Fixture project file declares seed again (core handler still runs it, so dev_hooks.gd needs no change). Two tests in test_debug_console.gd: red on old code (help seed showed core usage, help listed seed twice, merge_commands missing), green now. Docs sentence added. Map files regenerated; added them to touches. Full check next.
- 2026-10-27 21:08 Full check --ci green on b057879 (141 tests, 20 scenarios, 0 engine errors), on origin/main 3c264f4. Branch kombu-14-console-override, worktree ../Kombucha-k14. Handed to kombucha-pm. When it lands, navalwar-pm should hear (NavalWar NAVAL-184 will sync).
- 2026-10-27 21:08 PM pushed b057879 to main.
- 2026-10-27 21:08 Landed on origin/main in 3c264f4..b057879 (pushed by kombucha-pm).
- 2026-10-27 21:08 done on origin/main at b057879

## Left for later
