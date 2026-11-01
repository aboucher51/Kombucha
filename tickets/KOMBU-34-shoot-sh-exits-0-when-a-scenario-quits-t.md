---
id: KOMBU-34
title: shoot.sh exits 0 when a scenario quits the engine mid-run
status: ready
priority: 2
owner: 
depends_on: []
touches: [tools/shoot.sh, tools/selftest.sh]
created: 2026-11-01
updated: 2026-11-01
---

Found on KOMBU-33 (2026-11-01). In the red run of scenarios/pause_focus.txt, a ui_accept pressed the pause menu's Quit button, and GameManager.quit_game ended the engine in the middle of the scenario. tools/shoot.sh then exited 0. It printed 'shoot: 0 shot(s)' and no scenario summary, and it wrote no shots/<stem>.jsonl. The FAIL lines before the quit were in the log, but the exit code said green. So a scenario that quits the game passes, and every scenario dealt after it on that shard never runs.

What to do: make shoot.sh fail when a scenario it dealt has no summary line (no 'scenario ok' or 'scenario FAIL' in the shard log, or no summary row in its JSONL). Name the scenario and say the engine ended before it finished. Prove it in tools/selftest.sh with a scratch scenario that quits (console 'quit', or press QuitButton).

## Progress

## Left for later
