---
id: KOMBU-19
title: Plain text: harness, console and kit error messages
status: done
priority: 3
owner: kombucha-worker
depends_on: []
touches: [tests/test_screenshot_harness.gd, scripts/dev/screenshot_harness.gd, scripts/dev/debug_console.gd, scripts/dev/dev_hooks.gd, scripts/autoloads/keybinds.gd, scripts/ui/ui_scale_root.gd, scripts/util/function_registry.gd, scripts/util/content_db.gd, scripts/autoloads/audio_manager.gd]
created: 2026-10-31
updated: 2026-11-01
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
- 2026-11-01 00:08 Claimed; worktree ../Kombucha-wt19 on branch kombu-19. Before: 3 passive of 106 messages (readability.py on the extracted message strings).
- 2026-11-01 00:09 Added tests/test_screenshot_harness.gd to touches: its until test asserts the exact 'after Ns still:' reply, which this ticket rewords. Edits done: 106 messages, passive 3 -> 2; every file within 1% of its old word count (message text alone +14%, from added next steps).
- 2026-11-01 00:11 tools/check.sh --ci green in the worktree (c6109e6), forge, software rendering.
- 2026-11-01 00:12 Mapledot scratch clone synced from c6109e6: tools/check.sh --quick all green, 1779 tests passing. Play pass: a scratch console scenario showed the new reply on one line. Origin unmoved; branch kombu-19 holds the single commit c6109e6. Handing to kombucha-pm.
- 2026-11-01 00:14 PM review: NavalWar tests/test_mod_console.gd:178-183 and test_debug_console.gd:149 assert 'ERROR: unknown command'. My cross-project grep piped into head and cut those lines off. Restored 'unknown command' in both core replies (kept the 'Type help' next step) and the button_problems comment. Re-grepped every old string across ~/godot-projects with no cutoff: no other reader. Amended to 09d5c67; re-running the gate.
- 2026-11-01 00:16 09d5c67: tools/check.sh --ci green. NavalWar scratch clone synced from 09d5c67: test_mod_console + test_debug_console 36/36 passing. Handed back to kombucha-pm.
- 2026-11-01 00:17 done on main at 09d5c67

## Ready to play
What changed: the scenario harness, the debug console and Keybinds now answer in plain sentences. A reply says what went wrong and, where it helps, what to do next. Examples: "no command named 'frobnicate'. Type 'help' to list them.", "still failing after 0.05s. Last reply: ...", "no baseline <path>. Run SHOOT_BASELINES=update tools/shoot.sh <scenario> to write it, then commit it." The em dashes are gone from every reply.

What the scenarios and shots showed: all scenarios in `tools/check.sh --ci` passed, including every `expect_fail` line. A scratch scenario typed a bad command into the console. The shot shows the new reply on one line, with nothing cut off.

Questions for a person:
- When you read a failed scenario's reply, does it tell you what to fix?
- Is "hover at (x, y) over 'Button' reached no control" clear, or would you rather see the old "hover did not register"?

## Left for later
- Nothing left over.
