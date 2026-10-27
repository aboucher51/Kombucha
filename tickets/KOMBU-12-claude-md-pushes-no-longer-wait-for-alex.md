---
id: KOMBU-12
title: CLAUDE.md: pushes no longer wait for Alex's yes
status: claimed
priority: 3
owner: kombucha-worker
pid: 1433256
depends_on: []
touches: [CLAUDE.md]
created: 2026-10-27
updated: 2026-10-27
---

CLAUDE.md's "Agent tickets" section (KOMBU-2) says every push waits for Alex's yes. Alex changed that 2026-10-27: "Kombucha has permission to merge and push on demand." Rewrite that bullet: a worker pushes a green batch through the gate (tools/check.sh --ci) on its own and reports what landed to the PM; main still moves only through the gate. Keep the reason other projects depend on main (the next bullet).

## Progress

## Left for later
