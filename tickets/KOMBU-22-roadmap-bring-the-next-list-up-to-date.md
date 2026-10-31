---
id: KOMBU-22
title: Roadmap: bring the Next list up to date
status: ready
priority: 4
owner: 
depends_on: []
touches: [docs/roadmap.md]
created: 2026-10-31
updated: 2026-10-31
---

Update the facts in the "Next" section of `docs/roadmap.md`. KOMBU-17 rewrote its wording only and kept every fact, but several facts are out of date.

- Item 2 asks for a `--kit` report mode in `sync-tooling.sh`. The "Landed 2026-09-06, second pass" section says that landed ("The kit report (former item 2)"). Move it out of Next, or say what is still missing.
- Item 1 lists Tandem, Zoofle, Orbit, procedural-factory, BossFights and Monmon as not migrated. The shared memory note `godot-tooling-ownership.md` says Digit, FrogGame, NavalWar, Zoofle, Orbit and procedural-factory were migrated by 2026-09-06. Check each project's `tools/TOOLING_VERSION` and fix the list.
- Item 2 and the "Shared as a plugin" section still name the Template repo. The "One repo" section says the Template repo is retired.
- Item 0 (move to the Linux filesystem) may be done. The memory note `linux-filesystem-move.md` says every project was copied to `~/godot-projects` on 2026-09-05.

Ask kombucha-pm before you drop an item. Leave each "Landed <date>" section as it is, because those sections are a record.

## Progress

## Left for later
