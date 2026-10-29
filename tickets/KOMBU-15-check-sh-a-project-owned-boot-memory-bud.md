---
id: KOMBU-15
title: check.sh: a project-owned boot memory budget that a sync keeps
status: done
priority: 2
owner: kombucha-worker
depends_on: []
touches: [tools/check.sh, tools/sync-tooling.sh, tools/seeds, tools/selftest.sh, docs/godot-tooling.md, tools/check.local.env, tools/new-project.sh, tools/tooling-manifest.txt]
batch: KOMBU-B1
created: 2026-10-28
updated: 2026-10-29
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
- 2026-10-28 03:08 tools/check.local.env added: check.sh reads KEY=VALUE lines as text (no shell), caller's env wins, budget line names its source; seed in tools/seeds, sync seeds it, new-project excludes Kombucha's copy so the seed lands; selftest proves file budget, env beats file, file never runs. Touches added: tools/check.local.env (the fixture's own file), tools/new-project.sh (scaffold must exclude Kombucha's copy so a project gets the seed), tools/tooling-manifest.txt (its header lists the project seams).
- 2026-10-28 03:17 Committed e5b9aa0 on worker/kombu-b1; full tools/check.sh --ci green on forge (143 tests). CLAUDE.md seam line left for KOMBU-12 (blocked edit). Waiting for PM to land.
- 2026-10-28 03:18 PM pushed a6dec5c to main.
- 2026-10-28 03:18 done on origin/main at a6dec5c
- 2026-10-29 07:33 CLAUDE.md seam line landed in 431b68d (TextCleaner).

## Ready to play
No game change; this is check output. What changed: a project sets its
boot memory budget in `tools/check.local.env`, which a sync never touches.
The check's line now says where the number came from, as in
`ok    boot memory 113 MB (budget 390 MB, tools/check.local.env)`.
What the run showed: the full `tools/check.sh --ci` is green on forge, and
the selftest's three new lines pass (file budget reported, caller's
variable beats the file, a `$(...)` value is not run and fails by name).
Breaking the precedence on purpose made the "caller beats the file" check
read the wrong source, so that check can fail.
Questions for a person:
- Mapledot: should its ci.yml stop passing CHECK_RSS_BUDGET_KB, now that
  the file can hold 615000?
- Is "environment" / "default" / "tools/check.local.env" clear enough as
  the source word in the check line?

## Left for later
