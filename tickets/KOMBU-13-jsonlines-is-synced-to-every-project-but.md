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

From navalwar-pm (NAVAL-176, codebase review), FYI: JsonLines (scripts/util/json_lines.gd, line numbers for JSON diagnostics) looks unused in NavalWar.

PM check 2026-10-27: no .gd or .sh file in any project under ~/godot-projects uses the class. Only Kombucha's own tests/test_json_lines.gd does. Yet it is in tools/tooling-manifest.txt, so every sync copies it into every project (NavalWar, Mapledot, Swarm, IceEngine, Tandem).

Options: (a) move it out of the synced manifest and into the kit, cherry-picked by a project that loads mod data; (b) keep it as is, since it costs nothing at runtime; (c) delete it. Parked: no project is hurt by it. Ask Alex before (c).

## Progress
- 2026-10-28 00:48 navalwar-worker (NAVAL-176 dead-code sweep) also names debug_console.gd's current_group() and set_height(). PM check 2026-10-28 across Kombucha, NavalWar, Mapledot, Swarm, IceEngine, Tandem: set_height() is used by Kombucha's tests/test_debug_console.gd:299 (an input-free seam, as the comment on it says): keep. current_group() has no caller anywhere: a seam with no user, so either add a test or console_assert that uses it, or remove it. Same decision as JsonLines.

## Left for later
