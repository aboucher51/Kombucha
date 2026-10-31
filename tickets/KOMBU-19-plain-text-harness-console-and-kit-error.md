---
id: KOMBU-19
title: Plain text: harness, console and kit error messages
status: ready
priority: 3
owner: 
depends_on: []
touches: [scripts/dev/screenshot_harness.gd, scripts/dev/debug_console.gd, scripts/dev/dev_hooks.gd, scripts/autoloads/keybinds.gd, scripts/ui/ui_scale_root.gd, scripts/util/function_registry.gd, scripts/util/content_db.gd, scripts/autoloads/audio_manager.gd]
created: 2026-10-31
updated: 2026-10-31
---

Rewrite the error and refusal messages in the harness, the console and the kit in plain words. This is part of TextCleaner's cleanup of how Claude writes, which Alex approved on 2026-10-29.

Files and rough counts of `"ERROR` replies (2026-10-31):
- `scripts/dev/screenshot_harness.gd` (69)
- `scripts/dev/debug_console.gd` (25)
- `scripts/dev/dev_hooks.gd` (4)
- `scripts/autoloads/keybinds.gd` (7)
- the `push_error` and `push_warning` texts in `scripts/` (about 9, in `debug_console.gd`, `ui_scale_root.gd`, `function_registry.gd`, `content_db.gd`, `audio_manager.gd`, `screenshot_harness.gd`)

Load `writing-error-messages`.

Keep these exactly, because code parses them:
- the `ERROR: ` prefix on every reply. The harness fails a scenario on that shape.
- `ERROR: unknown key '<key>'`. The console asks the next state provider on exactly that text.
- any text a test checks with `assert_push_error` or `assert_engine_error`, unless you update that test to check the same thing.

Grep `tests/`, `scenarios/` and `tools/` (the self-test) for every message you change. Keep every name the message gives, like the node name, the path or the value it got.

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

## Left for later
