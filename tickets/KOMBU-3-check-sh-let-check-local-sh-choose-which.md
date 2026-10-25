---
id: KOMBU-3
title: check.sh: let check.local.sh choose which scenarios to render
status: ready
priority: 3
owner: 
depends_on: []
touches: [tools/check.sh, tools/check.local.sh, tools/seeds/check.local.sh, tools/selftest.sh, docs/godot-tooling.md]
created: 2026-10-25
updated: 2026-10-25
---

Let a project choose which scenarios `tools/check.sh` renders, so a project whose push gate renders only what a batch touches can still use check.sh.

Request from navalwar-worker (NAVAL-52, faster push gate; measurements in NAVAL-52 on NavalWar's board, ~/godot-projects/NavalWar/tickets on forge). Today check.sh always renders `scenarios/*.txt` (tools/check.sh, the `SCENARIOS=(scenarios/*.txt)` line). NavalWar works around it with its own tools/gate.sh (check.sh --quick, then shoot.sh on a list); with this, it goes back to `NW_CHECK=gate tools/check.sh`.

What to do:
- In check.sh, before rendering: if tools/check.local.sh exists and is executable, run `tools/check.local.sh --scenarios` (with QUICK and CHECK_CI set as today). Exit 0 with output: render those paths (one per line; blank lines skipped). No output, or a non-zero exit: keep today's `scenarios/*.txt`. Decide and document what an empty list with exit 0 means (render nothing, say so in the summary line) and what a listed path that does not exist does (fail, naming it).
- check.sh prints which set it rendered ("scenarios: 12 of 195, chosen by check.local.sh"), so a gate that renders less is never mistaken for the full sweep.
- The existing `check.local.sh` call (QUICK=... tools/check.local.sh) must not change for projects whose script ignores arguments. Note: a check.local.sh that runs its checks on ANY call would run them twice; the seed (tools/seeds/check.local.sh) must answer `--scenarios` first and exit, and the docs must say so.
- Kombucha's own tools/check.local.sh answers `--scenarios` with nothing (Kombucha's gate renders everything, see CLAUDE.md "Agent tickets").
- Fixture (CLAUDE.md: tooling with no fixture user is untested): prove both paths in tools/selftest.sh against a scratch copy: a check.local.sh that lists one scenario renders only it; one that exits non-zero renders all.
- Docs: docs/godot-tooling.md "Checking a change" gets the seam in a few lines.

## Progress

## Left for later
