---
id: KOMBU-23
title: Sync: regenerate the project map after copying the tooling
status: claimed
priority: 2
owner: kombucha-worker
pid: 2496951
depends_on: []
touches: [tools/sync-tooling.sh, skills/sync-godot-tooling/SKILL.md, tools/selftest.sh]
created: 2026-10-31
updated: 2026-10-31
---

Make `tools/sync-tooling.sh` regenerate the project's map after it copies the owned files, when `godot-map` is installed. Otherwise every sync that changes a synced `.gd` file fails the project's next check.

What happened: for KOMBU-B2, I cloned Mapledot into scratch, synced it from Kombucha, imported it and ran its `tools/check.sh --quick`. All 1779 tests passed. The check still failed on one item: "project map (run godot-map . and commit)". The clone's map was fresh before the sync. After the sync, `.godot-map/graph.json` was stale only because KOMBU-17 changed the line counts of `tools/seeds/dev_hooks.gd` (87 -> 92) and `tools/seeds/dev_driver.gd` (37 -> 38). The map stores each script's `"lines"`.

So today, any Kombucha change to a synced `.gd` file (the seeds, the harness, the console) turns every project's map check red after its next sync. Neither `sync-tooling.sh` nor the `/sync-godot-tooling` skill mentions `godot-map`.

What to do:
- After the copy, run `godot-map .` in the project when the tool is on PATH. Print a line that says the map was regenerated. When the tool is missing, print a `--` line that tells the user to run it.
- Make the skill tell the user to commit `PROJECT_MAP.md` and `.godot-map/` with the sync.
- Prove it in `tools/selftest.sh`: sync a scratch project whose seed line count changes, and check that the project's map check stays green.

## Progress
- 2026-10-31 23:09 claimed; worktree ../Kombucha-wt-23 on branch kombu-23-sync-map

## Left for later
