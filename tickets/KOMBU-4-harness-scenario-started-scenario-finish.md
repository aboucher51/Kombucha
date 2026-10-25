---
id: KOMBU-4
title: Harness: scenario_started / scenario_finished hooks for dev_hooks
status: ready
priority: 3
owner: 
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, scripts/dev/dev_hooks.gd, tools/seeds/dev_hooks.gd, docs/godot-tooling.md]
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

## Left for later
