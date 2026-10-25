---
id: KOMBU-3
title: check.sh: let check.local.sh choose which scenarios to render
status: done
priority: 3
owner: kombucha-worker
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

## Questions
- [answered] 2026-10-25 15:55 Design for check.local.sh --scenarios. (1) check.sh only calls it with --scenarios when the file contains the text '--scenarios'. Otherwise an existing script that ignores its arguments would run all its checks twice, and its ok/FAIL lines would be read as scenario paths and fail. (2) Exit 0 with no output, or a non-zero exit: render all scenarios/*.txt (this is Kombucha's own answer). (3) Rendering NOTHING, which a gate needs when a batch touches nothing visible, is one line 'none'. The summary says 'scenarios: 0 of 20, chosen by check.local.sh'. (4) A listed path that does not exist fails the check and names the path. OK?
  - answer (2026-10-25 15:56): PM: plan approved as written (1)-(4). Grepping for the literal --scenarios is fine; say in a check.sh comment why (an old script would run twice and its ok/FAIL lines would read as paths). Make the 'none' word and the summary line part of the docs and the seed.

## Progress
- 2026-10-25 15:59 check.sh, both check.local.sh files, selftest (5 cases with a stubbed shoot.sh) and docs written per the approved plan; running the full check next
- 2026-10-25 16:59 full check --ci green in 167 s (139 tests, 20 scenarios, the 5 new selftest cases ok); commit eb8562b; waiting for Alex's yes to push
- 2026-10-25 17:33 pushed to main (9590555..eb8562b) after Alex's yes via kombucha-pm
- 2026-10-25 17:33 done on main at 79af98b

## Left for later
