---
id: KOMBU-2
title: CLAUDE.md: an Agent tickets section that names the push gate
status: ready
priority: 2
owner: 
depends_on: []
touches: [CLAUDE.md]
created: 2026-10-25
updated: 2026-10-25
---

Add an "Agent tickets" section to CLAUDE.md that names Kombucha's push gate, so a ticket worker knows which check to run before a push.

From forgemaster on setup: the agent-tickets skill asks every PM project's CLAUDE.md to name a push gate. Kombucha's names none yet. The network policy (https://claude.ai/artifact/YCi8J7ano5QjUVMBnFJk4M, rule 11) gives NavalWar's and Mapledot's as examples; link to the policy, do not copy its rules.

What to write (short, in the style of the rest of CLAUDE.md: the rule plus what breaks without it):
- The push gate: CLAUDE.md already says `tools/check.sh` green is the bar for every commit. Measure a full `tools/check.sh --ci` on forge under a heavy slot (software rendering, like CI) and record the wall time. If it is a few minutes, the full check IS the gate and there is no separate sweep; say so.
- Pushes to this public repo need Alex's yes: the worker stops before `git push`, reports what it would push, and waits for the PM.
- Other projects pull this checkout before /sync-godot-tooling, so main only moves through the gate.
- Board lives on forge, PM is kombucha-pm, key KOMBU.
Keep this section out of what new-project.sh copies if it is Kombucha-only (fence it `<!-- kombucha-only -->`, see the top of CLAUDE.md).

## Progress

## Left for later
