---
id: KOMBU-5
title: godot-tooling.md: the push gate renders only what a batch reaches
status: done
priority: 4
owner: kombucha-worker
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
- 2026-10-25 17:34 PM: parked at p5 until NAVAL-52 lands on NavalWar's develop (its write-up is the source); set back to 4 then.
- 2026-10-25 17:34 PM: NAVAL-52 landed on NavalWar develop at 352edfdb (navalwar-pm). Unparked. Source: docs/conventions/dev-seams.md, last section, at that commit.
- 2026-10-25 17:35 paragraph written after the --scenarios seam in Checking a change; running the full check
- 2026-10-25 17:57 full check --ci green (139 tests, 20 scenarios; 1344 s, mostly waiting for the render slot); commit aabd556; waiting for Alex's yes to push
- 2026-10-25 19:42 Amended a blank line after the new paragraph (PM asked). Now 9df0f11, 18 insertions, on origin/main 57bf7c3. No re-check (doc whitespace only, PM agreed). Waiting for Alex's yes.
- 2026-10-25 22:18 Rebased cleanly onto 85dd1a3 (KOMBU-6) as 5996bb3. Re-running the full check before pushing, per the brief and CLAUDE.md's gate rule.
- 2026-10-25 22:20 Check green after the rebase: 139 tests, 20 scenarios, 0 engine errors (111 s). Pushed after Alex's yes (via PM): 85dd1a3..5996bb3.
- 2026-10-25 22:20 done on main at fefc33e

## Left for later
