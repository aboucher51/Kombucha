---
id: KOMBU-20
title: Plain text: messages the tool scripts print
status: ready
priority: 3
owner: 
depends_on: []
touches: [tools/check.sh, tools/test.sh, tools/shoot.sh, tools/serve.sh, tools/export.sh, tools/setup.sh, tools/sync-tooling.sh, tools/new-project.sh, tools/parse-error.sh, tools/selftest.sh]
batch: KOMBU-B3
created: 2026-10-31
updated: 2026-10-31
---

Rewrite the messages the tool scripts print in plain words. This is part of TextCleaner's cleanup of how Claude writes, which Alex approved on 2026-10-29.

Files: the `echo` lines that report an error, a note, a warning or a result in `tools/check.sh`, `tools/test.sh`, `tools/shoot.sh`, `tools/serve.sh`, `tools/export.sh`, `tools/setup.sh`, `tools/sync-tooling.sh`, `tools/new-project.sh`, `tools/parse-error.sh` and `tools/selftest.sh`. Also the usage text each script prints for `--help`, if it has one.

Load `writing-error-messages` for errors and refusals. Load `writing-instructions` for usage text and comments.

Keep these exactly, because people and scripts read them:
- the line prefixes `note:`, `test: warning:`, `parse error:`, `--`, and the `── failing assertions ──` header.
- the shape `parse error: <file>:<line> — <message>`.
- the line "N of M scenario(s), chosen by tools/check.local.sh" in meaning. `docs/godot-tooling.md` quotes it, so change both together or neither.
- every line `tools/selftest.sh` greps for. Read the self-test before you change any message.

Run `bash -n` on each changed script, one file per call (`bash -n a b` checks only `a`).

Every project gets these scripts on its next sync, so a wrong change spreads.

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
