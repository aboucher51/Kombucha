---
id: KOMBU-13
title: JsonLines is synced to every project but none uses it
status: ready
priority: 5
owner: 
depends_on: []
touches: [tools/tooling-manifest.txt, scripts/util/json_lines.gd]
created: 2026-10-27
updated: 2026-10-27
---

From navalwar-pm (NAVAL-176, codebase review), FYI: JsonLines (scripts/util/json_lines.gd, line numbers for JSON diagnostics) looks unused in NavalWar.

PM check 2026-10-27: no .gd or .sh file in any project under ~/godot-projects uses the class. Only Kombucha's own tests/test_json_lines.gd does. Yet it is in tools/tooling-manifest.txt, so every sync copies it into every project (NavalWar, Mapledot, Swarm, IceEngine, Tandem).

Options: (a) move it out of the synced manifest and into the kit, cherry-picked by a project that loads mod data; (b) keep it as is, since it costs nothing at runtime; (c) delete it. Parked: no project is hurt by it. Ask Alex before (c).

## Progress

## Left for later
