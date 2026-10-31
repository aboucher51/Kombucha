---
id: KOMBU-21
title: Plain text: the template's player-facing strings
status: ready
priority: 3
owner: 
depends_on: []
touches: [localization/game.csv, localization/game.en.translation, localization/game.xa.translation]
batch: KOMBU-B2
created: 2026-10-31
updated: 2026-10-31
---

Check the template's player-facing strings in `localization/game.csv` against the plain-words rules. This is part of TextCleaner's cleanup of how Claude writes, which Alex approved on 2026-10-29. Every new project starts with these rows.

The rows today are `ui.paused`, `ui.resume`, `ui.quit`, `ui.bus_master`, `ui.bus_music`, `ui.bus_sfx` and `ui.resume_hint`. Most are already plain. `ui.bus_sfx` shows "SFX" on the volume slider, which is jargon. "Sound effects" is the likely fix.

Load `writing-ui-labels-and-tooltips`.

- Change only the `en` column by hand. Then re-run `tools/make_pseudo_locale.py` to rebuild the `xa` column, and run the import.
- Never rename a key, and never rename the audio bus `SFX` itself. `audio_manager.gd` and `tests/test_smoke.gd` use the bus name.
- If an English fallback in code repeats a row's text, change both in the same commit.
- Shoot `scenarios/pseudo_locale.txt` and the volume slider screen, and look at the shots. A longer label must still fit.

## How to do it
- Read `~/.claude/rig/text-cleanup-brief.md` first. Follow its "Rules that review taught us" section.
- Before you write each kind of text, load the skill the brief's table names.
- Before you edit a file, list every number, name, path, key and test name in it. After the edit, check that each one is still there.
- Before you change a string, grep `scripts/`, `tests/`, `scenarios/` and `tools/` for it. If a test or scenario asserts the string, update that check so it tests the same thing. If a script parses the string, leave it alone.
- Keep each file within 10% of its old word count.
- Check every changed file with `python3 ~/.claude/skills/writing-plain-core/scripts/readability.py -f FILE --max 25`. Write the passive counts before and after into a ticket note, so the PM can send them to TextCleaner.
- Note any line where you were unsure who acts or what a line means. Leave such a line as it was.
- The gate is `tools/check.sh --ci`, green.

## Progress

## Left for later
