# Plan: fast feedback — lint, engine errors as data, scoped dumps, the LSP

Status: proposed 2026-09-05. Companion to the project-map tool, which is
its own repo (`~/godot-projects/godot-map`) and is *consumed* here (item 5),
not built here.

## Context

Exploring and changing a Godot project from Claude Code today goes through
`tools/check.sh`: tests, a boot, scenarios. That is the right bar for a
commit, but the loop is slow for the two cheapest questions Claude asks
hundreds of times a session — "does this file parse?" and "what is this
node's state right now?" — and it answers the third, "what went wrong?",
with raw engine logs. `docs/research/2026-09-05-prior-art.md` lists all
three as gaps (items 2 and 7 in "pieces worth stealing"; the state-dump
point under "lessons"). A graphify-style survey on 2026-09-05 added a
fourth: nothing tells Claude the project's *shape* (which scenes carry which
scripts, who connects to which signal) without reading every `.tscn`.

Decisions taken with the user (2026-09-05):

- **Lint and error extraction belong in Kombucha** — they are owned
  tooling every project should carry unchanged.
- **The project map is a separate tool**, Python, one repo, used by all
  projects; Kombucha owns only the rule that says to read it and the check
  that keeps it fresh.
- **No whole-tree dumps.** A scoped `dump <NodePath>` is cheap and
  assertable; a root dump is a screenshot's worth of tokens in JSON.
- **The GDScript LSP plugin is machine setup, not project tooling.** User
  scope, one install for every project. Kombucha documents it and states
  the division of labour; nothing in the manifest depends on it, because
  CI has no LSP.
- **Editor-bridge MCP servers stay "not planned"** (roadmap).

Rules for every item, as in every plan here: its own commit, `tools/check.sh`
green, the fixture exercises it, each new gate is proven able to fail once,
`docs/godot-tooling.md` gets the rule plus what breaks without it.

## 1. `tools/lint.sh` — parse check before any run

**What.** `godot4 --headless --check-only -s <file>` per changed script.
Catches the "one typo, 180 s of test run" case: a parse or static-type
error in any `.gd`, in about a second per file on the Linux filesystem.

    tools/lint.sh                 changed + untracked .gd (git diff HEAD)
    tools/lint.sh --all           every .gd outside addons/ and .godot/
    tools/lint.sh a.gd b.gd       just these
    LINT_JOBS=4                   files checked in parallel (xargs -P)

**Shape.**

- Exit 1 if any file fails; print each failure through the extractor in
  item 2 as `res://path:line: message`, nothing on success but a count.
- `--check-only` boots an engine per file: ~0.8 s here, ~11 s on `/mnt`.
  Default to changed files only so the common case is a few seconds even
  on a slow checkout; `--all` is for `check.sh --ci` and a fresh clone.
- What it does *not* catch (and the doc must say): runtime errors — a
  null call, a wrong node path, a missing signal. Those stay with the
  boot check and the scenarios. Lint is the first gate, not the bar.
- `check.sh` gains a `── lint ──` section before `── tests ──` running
  `lint.sh --all`, so a parse error fails in seconds instead of after the
  suite. (`test.sh` already guards *test* scripts that fail to load; this
  covers the game's scripts, which today surface only as a GUT failure
  somewhere downstream or as a SCRIPT ERROR in the boot log.)

**Claude-side hook.** A `PostToolUse` hook on `Edit|Write` matching
`\.gd$` runs `tools/lint.sh <file>` and returns its output. Hooks live in
the project's `.claude/settings.json`, which is not owned (it carries each
project's permissions), so ship the snippet as `tools/seeds/claude-hooks.json`
and have `sync-tooling.sh --check` note when a project's settings lack the
hook — the same treatment as the missing `@docs/godot-tooling.md` import.

**Fixture.** `tools/selftest.sh` copies the fixture, breaks one script
(`var x: int = "a"`), and asserts `lint.sh` exits 1 naming
`res://…:line`. Also asserts `lint.sh` on the clean fixture exits 0.

**Manifest.** `tools/lint.sh`, `tools/seeds/claude-hooks.json`.

## 2. Engine errors as data — one extractor, every log

**What.** Godot prints an error as two or three lines:

    SCRIPT ERROR: Invalid call. Nonexistent function 'foo' in base 'Node'.
       at: _ready (res://scripts/main.gd:12)

`check.sh` and `shoot.sh` grep these with `SCRIPT ERROR|Parse Error|shader`
and dump matching lines; `export.sh` greps `ERROR`; `test.sh` and
`serve.sh` do not look at all. A single extractor turns every log into

    res://scripts/main.gd:12: Invalid call. Nonexistent function 'foo' in base 'Node'.  (x3)

— one line per distinct error, `file:line` first (clickable, greppable,
what Claude actually needs), a repeat count instead of the same error 300
times from a `_process` loop.

**Shape.** `tools/lib/engine_errors.sh`, sourced, or a standalone
`tools/engine-errors.sh <log> [<log>...]` — standalone is simpler to test
and works from `serve.sh`. Recognises `SCRIPT ERROR`, `ERROR`, `USER
ERROR`, `Parse Error`, `SHADER ERROR`, `WARNING` optionally (`--warnings`),
pairs each with the following `at:` line, prints
`path:line: message (xN)` sorted by first appearance, exits 1 if any.
GDScript parse errors carry the path in the first line
(`Parse Error: ... at res://…:line`); handle both shapes.

**Call sites.**

- `check.sh` boot: replace the grep; print the extracted lines under the
  FAIL instead of `cat`-ing the whole boot log.
- `shoot.sh`: replace the `head -5` of raw lines with the extracted list.
- `test.sh`: **the gap** — a green shard prints nothing, so a SCRIPT ERROR
  raised by game code during a *passing* test is invisible today. Run the
  extractor over every shard log; any error is a FAIL line
  `engine errors during tests (N)` and the lines are printed, even when
  GUT is green.
- `serve.sh run|say`: the reply already tails the log from the command's
  start; append the extractor's output for that slice so an error caused
  by the line just sent is in the reply, not in a file to go and read.
- `export.sh` smoke: same replacement for the `grep -ci ERROR`.

**Fixture.** A console command in the fixture (`dev_hooks`-style but owned,
e.g. `raise_error`) that calls a nonexistent method once; a scenario under
`expect_fail`-like handling proving `shoot.sh` reports exactly one
extracted line; a test that triggers it and asserts `test.sh` exits 1 with
the `engine errors during tests` line even though the GUT assertions pass.
`selftest.sh` feeds the extractor a fixed log with three repeats and a
parse error and asserts the two output lines.

**Manifest.** `tools/engine-errors.sh` (plus the fixture command).

## 3. Harness `dump` and `assert_prop` — state before pixels, scoped

**What.** Two scenario commands (and therefore two `serve.sh say` lines):

    dump <NodePath> [prop ...]      one JSON line for that node
    assert_prop <NodePath> <prop> <value>

`dump` with no props returns the built-ins: `type`, `visible`, `text` if
any, `position`/`size` for Controls and Node2D, `global_position` for
Node3D, `script` path, `groups`, and the **names and types of direct
children only** — never grandchildren. Named props are read with
`get_indexed()` so `theme_override_colors/font_color` works. Output is one
JSON line prefixed `dump: ` so it lands in the JSONL trace and in the
`serve.sh` reply. `assert_prop` compares `str()` of the value and fails
like `assert` does.

**Why scoped.** A full `get_tree()` dump of a real project is thousands of
tokens and mostly noise; the prior-art survey already noted the tools that
hide screenshots behind JSON readback do it for token cost. One node plus
its children answers "is it there, where, what does it say" for the price
of a log line. Anything wider is what the project map (item 5) is for,
statically.

**Fixture.** A scenario that `dump`s `TitleLabel` and `assert_prop`s its
`text`, plus one `assert_prop` that is wrong under `expect_fail`.
`test_screenshot_harness.gd` asserts the JSON keys.

**Doc.** Rule: *readback before pixels* — reach for `state`, `dump`,
`assert_prop` before `shot`; a screenshot is for layout and look, not for
"did the value change".

## 4. The GDScript LSP: machine setup and the division of labour

**What lands here.**

- `docs/machine-setup.md` (Kombucha only, not synced): what a fresh
  machine needs beyond the repo — `godot4` on PATH, Node (user-space
  install under `~/.local/node`, since the native Claude Code build does
  not bring Node), `uv`, the GDScript LSP plugin at user scope with
  `GODOT_EDITOR_PATH` set in `~/.claude/settings.json` `env` (so detached
  remote-control sessions get it), the project-map tool. Copy the exact
  commands from the install done on 2026-09-05.
- One section in `docs/godot-tooling.md`, *Where errors come from*:
  the LSP while editing (diagnostics, go-to-definition, hover types,
  symbols — no engine run), `lint.sh` in hooks and `check.sh` (parse and
  types, CI-safe, no LSP needed), the boot check and scenarios for runtime
  errors, the extractor for reading any of them. Rule: *trust an LSP
  diagnostic over a guess, but the LSP is not on CI — lint is the gate.*
- The watch item: each LSP backend is a real `--editor` instance on the
  project and may reimport while `check.sh` or `shoot.sh` runs headless
  against the same `.godot/`. If import errors turn flaky after the
  install, that is the first suspect; the fix would be a `--lsp-backend`
  note in `docs/machine-setup.md` telling the user to stop the backend
  before long batches, or pinning the backend to a copy of the project.

**Not in the manifest.** Nothing. The plugin has no per-project files and
CI has no LSP.

## 5. Consume the project map

Built in `~/godot-projects/godot-map` (own plan there). Kombucha's part:

- `docs/godot-tooling.md`, *Exploring the project*: read `PROJECT_MAP.md`
  before grepping for "who uses this scene / script / signal"; regenerate
  with `godot-map .` after adding or moving scenes or scripts. Rule plus
  what breaks: without it Claude reads twenty `.tscn` files to find one
  connection, or guesses a node path that does not exist.
- `check.sh --ci` (and `--quick`): if `godot-map` is on PATH, run
  `godot-map . --check` and FAIL on a stale map (the tool exits 1 when the
  committed map differs from a fresh one); print `--` when it is not
  installed, the same shape as the missing `/usr/bin/time`. The map is
  committed so a checkout is readable without the tool.
- `.gitignore` seed: nothing — `PROJECT_MAP.md` is committed,
  `.godot-map/` (the JSON) is committed too; both are small.

## Order

1. Item 2 first — every other item prints through it.
2. Item 1, with the hook seed and the `check.sh` section.
3. Item 3.
4. Item 4's docs, once the plugin has run for a few sessions and the
   import-contention question has an answer.
5. Item 5 when the map tool produces stable output.

## Not in this plan

- An editor-bridge MCP server (roadmap: not planned).
- gdtoolkit's `gdlint`/`gdformat`: a second toolchain for what `--check-only`
  already answers; revisit only if style lint is wanted.
- A long-lived lint server to avoid the per-file engine boot: `serve.sh`
  is the long-lived engine, and the LSP already is that server for the
  editing path.
