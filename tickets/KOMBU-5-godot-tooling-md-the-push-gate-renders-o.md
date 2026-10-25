---
id: KOMBU-5
title: godot-tooling.md: the push gate renders only what a batch reaches
status: ready
priority: 4
owner: 
depends_on: [KOMBU-3, KOMBU-4]
touches: [docs/godot-tooling.md]
created: 2026-10-25
updated: 2026-10-25
---

Add one paragraph to docs/godot-tooling.md on "the push gate renders only what a batch reaches", so other projects with long scenario suites can copy NavalWar's approach.

Request from navalwar-worker (NAVAL-52). NavalWar's write-up (the recorder that notes what each scenario loads, the picker that chooses scenarios from a batch's changed files, and the sweep that re-records) will be the last section of NavalWar's docs/conventions/dev-seams.md once NAVAL-52 lands on NavalWar's develop branch. Read it there; do not copy NavalWar-specific names.

Write: the idea, the two seams it uses (KOMBU-3 and KOMBU-4), and the rule that the full sweep must still run (and re-record) when the queue is empty, plus what breaks without it (a stale record lets a broken scenario skip the gate forever). Keep it a paragraph or two in the style of the file: the rule plus what breaks without it.

Wait until NAVAL-52 has landed on NavalWar's develop (check `git -C ~/godot-projects/NavalWar log origin/develop` for docs/conventions/dev-seams.md).

## Progress

## Left for later
