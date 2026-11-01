---
id: KOMBU-22
title: Roadmap: bring the Next list up to date
status: done
priority: 4
owner: kombucha-worker
depends_on: []
touches: [docs/roadmap.md]
created: 2026-10-31
updated: 2026-11-01
---

Update the facts in the "Next" section of `docs/roadmap.md`. KOMBU-17 rewrote its wording only and kept every fact, but several facts are out of date.

- Item 2 asks for a `--kit` report mode in `sync-tooling.sh`. The "Landed 2026-09-06, second pass" section says that landed ("The kit report (former item 2)"). Move it out of Next, or say what is still missing.
- Item 1 lists Tandem, Zoofle, Orbit, procedural-factory, BossFights and Monmon as not migrated. The shared memory note `godot-tooling-ownership.md` says Digit, FrogGame, NavalWar, Zoofle, Orbit and procedural-factory were migrated by 2026-09-06. Check each project's `tools/TOOLING_VERSION` and fix the list.
- Item 2 and the "Shared as a plugin" section still name the Template repo. The "One repo" section says the Template repo is retired.
- Item 0 (move to the Linux filesystem) may be done. The memory note `linux-filesystem-move.md` says every project was copied to `~/godot-projects` on 2026-09-05.

Ask kombucha-pm before you drop an item. Leave each "Landed <date>" section as it is, because those sections are a record.

## Questions
- [answered] 2026-11-01 00:27 Roadmap Next: (a) Item 2 (--kit report) landed 2026-09-06 and now reads Kombucha's history; nothing is missing. May I drop it from Next? (b) Item 0 (Linux move): all projects were copied 2026-09-05. I plan to keep the item but reword it: the move is done; deleting the /mnt/c copies and mapping a Windows drive are left, and both are the user's call. OK?
  - answer (2026-11-01 00:27): PM: (a) Yes. Take item 2 out of Next, and add one line to the 2026-09-06 Landed section saying the --kit report landed there, so the record stays whole. (b) Yes, reword it that way: the move is done, and two steps are left for Alex (delete the /mnt/c copies, map a Windows drive). Don't add any new plans to Next.

## Progress
- 2026-11-01 00:28 Edited docs/roadmap.md Next per PM answer: item 2 dropped (kit report already recorded in 'Landed 2026-09-06, second pass', so no new line), item 0 reworded (move done; delete /mnt/c copies and map a drive left, Alex's call), item 1 list fixed (Tandem synced 2026-10-25 on forge; BossFights and Monmon left per the 2026-09-06 note; desktop copies cannot be read from forge, and GitHub copies predate the migration), map bullet updated (check.sh map gate 62c6a5c; CI lacks godot-map), Template removed from 'Shared as a plugin', items renumbered. Passive 9 -> 11 (kept 'were migrated', 'was copied': actor not recorded).
- 2026-11-01 02:09 First gate run red: the worktree was never imported (every class failed to load). Imported; re-running the gate.
- 2026-11-01 02:21 Gate green after the import: tools/check.sh --ci, 'check: all green'. origin/main has not moved. Ready to play: none (docs only, nothing a player or scenario author sees). Handed to kombucha-pm as db14e98 on kombu-22.
- 2026-11-01 02:21 done on main at db14e98

## Left for later
