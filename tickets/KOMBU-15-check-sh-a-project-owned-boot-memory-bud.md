---
id: KOMBU-15
title: check.sh: a project-owned boot memory budget that a sync keeps
status: ready
priority: 2
owner: 
depends_on: []
touches: [tools/check.sh, tools/sync-tooling.sh, tools/seeds, tools/selftest.sh, docs/godot-tooling.md]
batch: KOMBU-B1
created: 2026-10-28
updated: 2026-10-28
---

Let a project set its own boot memory budget in a file a sync never touches, so a sync stops resetting it.

Request from mapledot-pm (after MAPLE-124's sync to bcc0a20). tools/check.sh:128 reads `BUDGET_KB=${CHECK_RSS_BUDGET_KB:-400000}`. Mapledot's budget is 615000 KB (Alex's call, 2026-10-22), and its CI workflow passes it as an env var, but a local `tools/check.sh` has no env var, so Mapledot edited check.sh by hand and every sync reset it.

What to do:
- A project-owned settings file that check.sh reads, e.g. `tools/check.local.env` (plain KEY=VALUE lines; read safely, not by `source`-ing arbitrary shell, or say why sourcing is fine), never synced. First key: CHECK_RSS_BUDGET_KB. An env var set by the caller still wins over the file (so ci.yml keeps working).
- The sync must never touch it: check how tools/sync-tooling.sh treats project-owned files (dev_hooks.gd, console_commands.project.json, check.local.sh) and add it the same way; a seed in tools/seeds/ with the key commented out and one line on what it is.
- Fixture: Kombucha uses the seam (its own file may set the default explicitly), and tools/selftest.sh proves a project file's budget is the one check.sh reports, and that the env var beats the file.
- Docs: docs/godot-tooling.md, where check.sh's project seams are listed; CLAUDE.md's list of project seams ("extends through scripts/dev/dev_hooks.gd, data/console_commands.project.json and tools/check.local.sh") also names the new file. NOTE: CLAUDE.md edits are blocked for the worker (KOMBU-12); if so, leave CLAUDE.md, note it on KOMBU-12, and do the rest.
When it lands, tell the PM so mapledot-pm can be told.

## Progress

## Left for later
