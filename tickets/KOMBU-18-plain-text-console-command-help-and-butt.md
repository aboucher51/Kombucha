---
id: KOMBU-18
title: Plain text: console command help and button tips
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [data/console_commands.json, data/console_commands.project.json, tools/seeds/console_commands.project.json, tests/test_debug_console.gd, docs/feedback/README.md]
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
- 2026-10-31 21:24 PM, from TextCleaner: before the push, also run one synced project's quick check against this change. Clone a project into scratch (like git clone ~/godot-projects/Mapledot <scratch>). Never sync into a live project tree. Sync it from your worktree with tools/sync-tooling.sh, import it, then run its tools/check.sh --quick under a heavy slot. tools/check.sh --ci already runs the self-test here. Put both results in your report.
- 2026-10-31 22:46 claimed with KOMBU-B2; worktree ../Kombucha-wt-b2 on branch kombu-b2-text
- 2026-10-31 22:46 PM, from TextCleaner's review of KOMBU-17: in docs/feedback/README.md, change "how you misread it at first" to "how it was first misread". A report can describe someone else's misreading, like Alex's or a worker's. Added the file to touches.
- 2026-10-31 22:58 edits committed. Passive before->after: data/console_commands.json 0->0 (646->655 words), data/console_commands.project.json 0->0 (182->183), docs/feedback/README.md 1->1. tools/seeds/console_commands.project.json is [] and needed nothing. Changed: help, volume, state, console_release descriptions; seed and goto usage notes. test_debug_console.gd's volume check now looks for 'Set the volume of one sound bus'. Kept 'the fixture's own row', which the test checks. No other project's tests or scenarios check these strings (grep of ~/godot-projects).
- 2026-10-31 23:08 gate green: tools/check.sh --ci on f2bac4b (146 tests, all scenarios). Synced-project check: I cloned Mapledot to scratch, synced it from the worktree, imported it, and ran check.sh --quick. 1779 tests pass, and the boot passes. One item is red: project map stale. The clone's map was fresh before the sync. The sync copied the KOMBU-17 seed .gd files, whose line counts the map stores. Filed KOMBU-23.
- 2026-10-31 23:09 done on main at f2bac4b

## Left for later
- [[KOMBU-23]] a sync does not regenerate the project map, so a synced project's check goes red after any change to a synced .gd file
