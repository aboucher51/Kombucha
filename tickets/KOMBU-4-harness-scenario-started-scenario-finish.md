---
id: KOMBU-4
title: Harness: scenario_started / scenario_finished hooks for dev_hooks
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, scripts/dev/dev_hooks.gd, scenarios/hooks.txt, PROJECT_MAP.md, .godot-map/graph.json, tests/test_screenshot_harness.gd, tools/seeds/dev_hooks.gd, docs/godot-tooling.md]
created: 2026-10-25
updated: 2026-10-25
---

Tell the dev hooks when a scenario starts and ends, so a project can record what each scenario loads without reading the harness's private fields.

Request from navalwar-worker (NAVAL-52): NavalWar records which scripts and scenes each scenario loads, to pick its gate's scenarios. To know which scenario is running it reads the harness's private `_scenario_stem` (scripts/dev/screenshot_harness.gd, set around line 334), which breaks the day the harness renames it.

What to do:
- In the harness, call `hooks.scenario_started(path)` before a scenario's first line and `hooks.scenario_finished(path, ok)` after its last (including when it fails or errors), only when the hooks have the method (`has_method`, like `scenario_command` and the method dispatch near line 514). Say in a comment where they run relative to `_sandbox()` and the return to the boot scene.
- Optionally also expose a read-only public `scenario_stem` (or path). Pick one way and keep it small.
- Seed: add both hooks to tools/seeds/dev_hooks.gd as commented, do-nothing stubs with one line each on what they are for.
- Fixture: Kombucha's scripts/dev/dev_hooks.gd implements both, recording something a scenario or test can assert (for example, the stem of the scenario that started, readable through `state`/`assert`), and a scenario proves start fires before the first line and finished fires with the right ok flag. Prove it can fail.
- Docs: one line in docs/godot-tooling.md where dev_hooks' seams are listed.

## Progress
- 2026-10-25 15:57 hooks called from _run; fixture dev_hooks notes the started stem (hooks.txt asserts it on line 1) and records last_finished; test covers ok and failed scenarios and goes red with the calls removed. Added scenarios/hooks.txt and tests/test_screenshot_harness.gd to touches: they are the fixture users
- 2026-10-25 16:55 added PROJECT_MAP.md and .godot-map/graph.json to touches: the new hook methods made the map stale
- 2026-10-25 16:59 full check --ci green in 167 s; commits 0973dff + f907b8c (map); waiting for Alex's yes to push
- 2026-10-25 17:33 pushed to main (9590555..eb8562b)
- 2026-10-25 17:33 done on main at 79af98b

## Left for later
