---
id: KOMBU-20
title: Plain text: messages the tool scripts print
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [tools/check.sh, tools/test.sh, tools/shoot.sh, tools/serve.sh, tools/export.sh, tools/setup.sh, tools/sync-tooling.sh, tools/new-project.sh, tools/parse-error.sh, tools/selftest.sh]
batch: KOMBU-B3
created: 2026-10-31
updated: 2026-11-01
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
- 2026-11-01 00:17 PM, from TextCleaner's review of KOMBU-19: never cut off a cross-project grep with head, a match limit or a sample. For every printed line you change, grep ~/.claude, ~/vscodeprojects, Kombucha's tests and every project under ~/godot-projects with no limit. Save the output to a file. In your report, list every match that reads the line (test, scenario, script, brief, watchdog) and say what you did about each one.
- 2026-11-01 00:19 Edits done in worktree ../Kombucha-wtb3 (branch kombu-b3): 24 printed lines in check, test, shoot, serve, export, setup and sync-tooling. Kept every line selftest greps, check: all green, the behind note, slot names, parse error shape, chosen-by line, TOOLING_VERSION content. Uncut reader grep (31 old strings over ~/.claude, ~/vscodeprojects, ~/godot-projects, ~/forge-config, saved to a file): no reader parses a changed line. Passive: 0 of 55 before, 0 of 75 after on the changed lines; whole files unchanged. Words: setup.sh +2.7%, others under 1%.
- 2026-11-01 00:26 Rebased onto 07ea3df; gate green again on 484da14. Mapledot scratch synced from 12489b2 (same code): check --quick green, 1779 tests. Handing B3 to kombucha-pm.
- 2026-11-01 00:26 done on main at 484da14

## Ready to play
What changed: 24 lines that `check.sh`, `test.sh`, `shoot.sh`, `serve.sh`, `export.sh`, `setup.sh` and `sync-tooling.sh` print now read as plain sentences. Examples: "shoot: 3 engine error(s). A scenario can pass and still log engine errors." and "setup: a step above failed. Fix it and run setup again. Every step is safe to repeat."

What the runs showed: `tools/check.sh --ci` is green, and the self-test still finds every line it reads. A Mapledot scratch clone synced from the branch passed `tools/check.sh --quick` (1779 tests).

Questions for a person:
- Does the frames note ("this number catches a slowdown on this renderer. It is not a target for a real device.") say what you need when you read a check?
- Should the "behind" note lose its dash too? It stays as it is today, because the ticket keeps it byte for byte.

## Left for later
- Nothing left over.
