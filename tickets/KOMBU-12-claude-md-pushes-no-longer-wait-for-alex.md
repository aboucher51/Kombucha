---
id: KOMBU-12
title: CLAUDE.md: pushes no longer wait for Alex's yes
status: done
priority: 3
owner: 
depends_on: []
touches: [CLAUDE.md]
created: 2026-10-27
updated: 2026-10-29
---

CLAUDE.md's "Agent tickets" section (KOMBU-2) says every push waits for Alex's yes. Alex changed that 2026-10-27: "Kombucha has permission to merge and push on demand." Rewrite that bullet: a worker pushes a green batch through the gate (tools/check.sh --ci) on its own and reports what landed to the PM; main still moves only through the gate. Keep the reason other projects depend on main (the next bullet).

## Progress
- 2026-10-27 18:08 2026-10-27 kombucha-worker: editing CLAUDE.md was blocked by this session's permission check (reason: self-modification). Didn't try another way. Proposed text for the bullet: '- **A green batch is pushed on demand, without waiting for Alex.** Alex set this on 2026-10-27; before that, every push to this public repo waited for his yes. The worker pushes once the gate is green and sends the PM what landed: the commits, the diffstat and the check result. When the worker's own session is not allowed to run git push, it stops before the push and sends the PM the branch and the check result, and the PM pushes it.' Reopened so Alex or the PM can make the edit.
- 2026-10-27 18:08 PM: quote Alex's words and date in the CLAUDE.md bullet: "Kombucha has permission to merge and push on demand" (2026-10-27). pm-brief and the worker brief defer to the project's CLAUDE.md for a public repo's push rule (forgemaster).
- 2026-10-27 18:09 PM (Alex via forgemaster, 2026-10-27): use this wording in CLAUDE.md: "Kombucha has permission to merge and push on demand (Alex, 2026-10-27). The PM pushes; ticket workers do not push. They hand finished, gated work to the PM." Replaces the earlier note's wording.
- 2026-10-27 18:12 PM: the worker's session blocks CLAUDE.md edits (self-modification) and the PM edits only tickets/. Put to Alex: edit it himself, or say which session may.
- 2026-10-28 03:08 From KOMBU-15 (kombucha-worker): CLAUDE.md's seam list (line ~31, 'extends through scripts/dev/dev_hooks.gd, data/console_commands.project.json and tools/check.local.sh') should also name tools/check.local.env. Left undone: CLAUDE.md edits are blocked for the worker. Proposed: 'extends through scripts/dev/dev_hooks.gd, data/console_commands.project.json, tools/check.local.sh and tools/check.local.env, which a sync never touches.'
- 2026-10-29 06:57 Alex 2026-10-29: TextCleaner (rig session running the docs cleanup) makes both CLAUDE.md edits (this one + KOMBU-15's seam line) and pushes them. Sent it the wording.
- 2026-10-29 07:33 TextCleaner pushed 431b68d (CLAUDE.md push rule + KOMBU-15 seam line); PM checked the diff.
- 2026-10-29 07:33 done on main at 431b68d

## Left for later
