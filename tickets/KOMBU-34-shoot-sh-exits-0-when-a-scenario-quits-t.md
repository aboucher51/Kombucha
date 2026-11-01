---
id: KOMBU-34
title: shoot.sh exits 0 when a scenario quits the engine mid-run
status: done
priority: 2
owner: kombucha-worker
depends_on: []
touches: [tools/shoot.sh, tools/selftest.sh, docs/godot-tooling.md, scripts/dev/screenshot_harness.gd, PROJECT_MAP.md, .godot-map/graph.json]
created: 2026-11-01
updated: 2026-11-01
---

Found on KOMBU-33 (2026-11-01). In the red run of scenarios/pause_focus.txt, a ui_accept pressed the pause menu's Quit button, and GameManager.quit_game ended the engine in the middle of the scenario. tools/shoot.sh then exited 0. It printed 'shoot: 0 shot(s)' and no scenario summary, and it wrote no shots/<stem>.jsonl. The FAIL lines before the quit were in the log, but the exit code said green. So a scenario that quits the game passes, and every scenario dealt after it on that shard never runs.

What to do: make shoot.sh fail when a scenario it dealt has no summary line (no 'scenario ok' or 'scenario FAIL' in the shard log, or no summary row in its JSONL). Name the scenario and say the engine ended before it finished. Prove it in tools/selftest.sh with a scratch scenario that quits (console 'quit', or press QuitButton).

## Progress
- 2026-11-01 05:20 added docs/godot-tooling.md to touches: one paragraph telling projects that shoot.sh now fails a scenario that quits, and not to press Quit in a scenario
- 2026-11-01 05:20 shoot.sh names every dealt scenario with no fresh JSONL summary row and exits 1. Red-proof: old shoot.sh exits 0 on a quit+example pair, new exits 1 and names both. selftest case added. Running the full gate next.
- 2026-11-01 05:24 gate green (check.sh --ci, exit 0; selftest line 'a scenario that quits the game is red' ok). Commit 18b902a on branch kombu-34, worktree ../Kombucha-wt-34. Handed to kombucha-pm.
- 2026-11-01 05:24 PM: emblem-autobattler hit the same bug (EMBL-20) and adds two more symptoms. (2) shots/<stem>.jsonl is never written, so the failures that scenario already recorded are lost. (3) No later scenario dealt to that process runs. Repro in emblem-autobattler f2a8f8f: comment out UIFocus.keep_inside(_panel) in pause_menu.gd, then SHOOT_JOBS=1 tools/shoot.sh scenarios/pause_focus_wrap.txt scenarios/example.txt. Their suggested fix, which the worker judges: during a scenario, the harness traps a quit and replies "ERROR: the game quit during the scenario". shoot.sh also fails when a process ends before it reports every scenario it was dealt. Added screenshot_harness.gd to touches. Tell the PM when this lands, so the PM can tell emblem-autobattler-pm.
- 2026-11-01 05:29 took EMBL-20's harness half. The harness's _exit_tree() fails a scenario still running at its quit line and writes its trace with the summary row (GDScript cannot override SceneTree.quit, so this records the quit and does not block it). The selftest checks both halves. Added PROJECT_MAP.md and .godot-map/graph.json to touches: regenerated after the harness edit. Gate green again after the rebase onto 1f5841c. Commits fe2ce65 + new HEAD.
- 2026-11-01 05:29 done on main at 484ed19

## Ready to play
- What changed: when a scenario quits the game, the harness now prints `FAIL <scenario>:<line> ERROR: the game quit during the scenario, after this line.` at the line that quit, and still writes `shots/<stem>.jsonl` with its summary row. `tools/shoot.sh` checks that every scenario it dealt wrote a fresh summary row. For each one that did not (one the quit kept from running, or a crash or timeout), it prints `shoot: <scenario> did not finish. It wrote no summary.` and exits 1.
- What the run showed: a scratch scenario `shot before / quit / shot after`, then `example.txt`, with `SHOOT_JOBS=1`. The old shoot.sh exited 0. The new one exits 1, fails the scratch scenario at line 2 with its trace kept, and names `example.txt` as never run. The full `tools/check.sh --ci` is green, so no scenario that finishes gets flagged.
- Questions for a person:
  1. Should a timed-out run also list the unfinished scenarios (it does now), or is the timeout line enough?
  2. A quit still stops the batch on that shard. Is a red run that names the skipped scenarios enough, or should shoot.sh start a fresh engine and run them?

## Left for later
