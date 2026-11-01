---
id: KOMBU-26
title: Plain text: drop "regression tripwire" from the frame_budget docs
status: done
priority: 4
owner: kombucha-worker
depends_on: []
touches: [docs/godot-tooling.md, scripts/dev/screenshot_harness.gd, .godot-map/graph.json]
created: 2026-11-01
updated: 2026-11-01
---

Make the frame_budget docs use the same words as the note `tools/check.sh` now prints (KOMBU-20, 484da14). TextCleaner asked for this after reviewing KOMBU-B3. "Regression tripwire" is a metaphor, and the plain-words rules give one thing one name.

- In `docs/godot-tooling.md`, the bullet that starts "`frame_budget` is a regression tripwire, not a device target." should say what `check.sh` now says. For example: "`frame_budget` catches a slowdown on this renderer. It is not a target for a real device." Keep every other fact in that bullet: vsync goes off for the measurement, the 16.7 ms reason, the number printed on pass, llvmpipe on CI, and "several times more expensive".
- Change the comments in `scripts/dev/screenshot_harness.gd` that say "tripwire" the same way. Change comments only, no code. Then run `godot-map .`, because the map stores each script's line count.
- Leave `docs/plans/` and `docs/research/` alone. They are records.

Load `writing-instructions`. Check both files with `python3 ~/.claude/skills/writing-plain-core/scripts/readability.py -f FILE --max 25`. The gate is `tools/check.sh --ci`, green.

## Progress
- 2026-11-01 00:29 godot-tooling.md bullet and screenshot_harness.gd comment changed; godot-map shows no change (same line count). Passive: godot-tooling.md 6 -> 6, harness 35 -> 35. Committed with KOMBU-22; running the gate.
- 2026-11-01 02:21 Gate green with KOMBU-22 (one run, 'check: all green'). Ready to play: none. A scenario author reads the new frame_budget wording in docs/godot-tooling.md; no behaviour changed. Handed to kombucha-pm as db14e98 on kombu-22.
- 2026-11-01 02:21 done on main at db14e98

## Left for later
