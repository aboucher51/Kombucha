---
id: KOMBU-18
title: Plain text: console command help and button tips
status: ready
priority: 3
owner: 
depends_on: []
touches: [data/console_commands.json, data/console_commands.project.json, tools/seeds/console_commands.project.json, tests/test_debug_console.gd]
batch: KOMBU-B2
created: 2026-10-31
updated: 2026-10-31
---

Rewrite the help text of the debug console's commands and buttons in plain words. This is part of TextCleaner's cleanup of how Claude writes, which Alex approved on 2026-10-29.

Files:
- `data/console_commands.json`: each command's `description`, each argument's hint text, and each button's `label` and `tip`. Load `writing-descriptions` for descriptions and `writing-ui-labels-and-tooltips` for labels and tips.
- `data/console_commands.project.json` and `tools/seeds/console_commands.project.json`: the same fields.

Never change an `id`, an alias, an argument `name`, `kind`, `values`, `complete` source, or a button's `run` line. Code and scenarios read those. `tests/test_debug_console.gd` may assert help or suggestion text. Update such a check so it tests the same thing.

Every project gets these files on its next sync, so a wrong change spreads.

## Who else reads these lines
Other projects, PM briefs, workers and the watchdog grep some printed lines. Before you change any printed line or reply, grep `~/.claude`, Kombucha's own `tests/`, `scenarios/` and `tools/`, and every synced project under `~/godot-projects`. Keep these byte for byte, unless you change every reader in the same commit:
- `check: all green`
- the "tooling is N commits behind" note
- slot names (`heavy`, `render`, `agent`)
- scenario verbs and the console replies that scenarios parse
If you are unsure whether something reads a line, leave the line as it is and list it in a note.

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
