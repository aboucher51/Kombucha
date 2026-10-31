---
id: KOMBU-21
title: Plain text: the template's player-facing strings
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [scenarios/tooltip.txt, PROJECT_MAP.md, .godot-map/graph.json, tests/test_volume_sliders.gd, localization/game.csv, localization/game.en.translation, localization/game.xa.translation, scripts/ui/volume_sliders.gd, scripts/ui/pause_menu.gd]
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
- 2026-10-31 22:13 PM: Swarm already made this change in SWARM-12. Match its wording, so the kit and Swarm agree: ui.bus_master is "All sound", ui.bus_sfx is "Sound effects", and ui.resume_hint is "Close this menu and keep playing". Change the English fallbacks in code too: scripts/ui/pause_menu.gd line 62 (ui.resume_hint), and scripts/ui/volume_sliders.gd line 17, which falls back to the raw bus name ("Master", "SFX"). Give volume_sliders.gd plain fallback names for each bus (SWARM-16 asks for this). Keep the bus names themselves and the slider node names (MasterSlider, SFXSlider).
- 2026-10-31 22:14 PM: SWARM-16 waits on this ticket. When it lands, the PM tells swarm-pm, so Swarm can copy volume_sliders.gd from Kombucha.
- 2026-10-31 22:47 added tests/test_volume_sliders.gd to touches: it checks that every bus has a plain fallback label and that the en rows match the code fallbacks, so the copy Swarm takes (SWARM-16) stays covered.
- 2026-10-31 22:48 added scenarios/tooltip.txt (it asserts the ResumeButton tooltip text, now 'Close this menu and keep playing') and the project map files (the new test changes them) to touches.
- 2026-10-31 22:58 edits committed. Passive 0->0 in localization/game.csv (12->22 words, Swarm's wording, as the PM asked). xa rebuilt with make_pseudo_locale.py and imported. It matches Swarm's xa rows. The play pass showed that 'Sound effects' pushed its slider right (the HBox label was only 70 px at least). volume_sliders.gd now uses a two-column grid (VolumeGrid). test_volume_sliders.gd checks that every slider starts at the same x, and it went red on the old layout (80 vs 82, 116 vs 82). The fallback test went red with the old 'SFX' fallback.
- 2026-10-31 23:09 done on main at f2bac4b

## Ready to play
What changed: the pause menu's volume sliders now read "All sound", "Music" and "Sound effects" (before: "Master", "Music", "SFX"). The Resume button's tooltip now reads "Close this menu and keep playing". The three sliders now sit in a two-column grid, so they all start at the same x whatever the label length.

What the scenarios and shots showed: `pause_menu.txt`, `pseudo_locale.txt`, `tooltip.txt` and `drag.txt` pass on llvmpipe. In `shots/pause_menu-01-pause-open.png`, every label fits inside the panel, and the three sliders line up. In `shots/pseudo_locale-01-pseudo-locale.png`, the longest label ("[Şòùñđ èƒƒèçŧş~~~~]") fits, and the sliders still line up. The first shot, before the grid, showed the "Sound effects" slider starting about 35 px to the right of the "Music" slider.

Questions for a person:
- With the longer labels, the sliders are shorter than before. Is that length still easy to drag on a Steam Deck?
- Does "All sound" read clearly as the main volume, or would "Main volume" be plainer?
- The pause panel still sits over the "Template project" title text behind it, as it did before this change. Does that matter for a template?

## Left for later
