---
id: KOMBU-13
title: Unused synced code: JsonLines, DebugConsole.current_group()
status: ready
priority: 5
owner: 
depends_on: []
touches: [tools/tooling-manifest.txt, scripts/util/json_lines.gd]
created: 2026-10-27
updated: 2026-10-28
---

navalwar-pm reported this from NavalWar's codebase review (NAVAL-176). `JsonLines` (`scripts/util/json_lines.gd`) gives line numbers for JSON errors. NavalWar does not use it.

The PM checked on 2026-10-27. No `.gd` or `.sh` file in any project under `~/godot-projects` uses the class. Only Kombucha's own `tests/test_json_lines.gd` uses it. But `tools/tooling-manifest.txt` lists it, so every sync copies it into every project (NavalWar, Mapledot, Swarm, IceEngine, Tandem).

Alex picks one of three options:
- (a) Take it out of the synced manifest and put it in the kit. A project that loads mod data then cherry-picks it.
- (b) Keep it as it is. It costs nothing when the game runs.
- (c) Delete it. Ask Alex before you do this.

The PM parked this ticket because it does not hurt any project.

## Progress
- 2026-10-28 00:48 navalwar-worker (NAVAL-176 dead-code sweep) also names debug_console.gd's current_group() and set_height(). PM check 2026-10-28 across Kombucha, NavalWar, Mapledot, Swarm, IceEngine, Tandem: set_height() is used by Kombucha's tests/test_debug_console.gd:299 (an input-free seam, as the comment on it says): keep. current_group() has no caller anywhere: a seam with no user, so either add a test or console_assert that uses it, or remove it. Same decision as JsonLines.

## Left for later
