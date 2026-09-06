<!-- OWNED BY KOMBUCHA (tools/tooling-manifest.txt) and overwritten by
/sync-godot-tooling. Every project's CLAUDE.md imports this file with a
single `@docs/godot-tooling.md` line where its tooling sections used to be,
so a rule added in Kombucha reaches every synced project without a
hand-splice, and the copies cannot drift. Project-specific test rules stay
in the project's own CLAUDE.md, beside the import. -->

### Verifying a change

Re-import after adding a new `class_name`, autoload, or translation CSV:

```bash
godot4 --headless --path . --import
```

Smoke-test by running headless for a fixed duration:

```bash
timeout 8 godot4 --headless --path . > /tmp/run.log 2>&1; echo "EXIT=$?"
```

**Exit 124 means success** — it ran the full duration without crashing. Any
other exit code is a crash or early quit. Redirect to a file rather than
piping to `tail`/`head`: piping loses the engine's stdout and you will see an
empty log from a run that actually worked.

### Checking a change

```bash
tools/check.sh          # tests + boot (with memory budget) + all scenarios
tools/check.sh --quick  # tests + boot only (no display needed)
tools/export.sh         # Linux + Windows builds, then smoke-tests the binary
```

Use check.sh before saying something works. It names whatever failed.
**The execute bit is part of the commit**: git records it, and a
filesystem that ignores modes (`/mnt/c`, Git Bash) makes every file look
executable, so a script committed as 100644 works there and is
"Permission denied" the day the checkout lands on a real filesystem, with
a non-executable `check.local.sh` reading as "no local checks". check.sh's
first section fails on any `tools/*.sh` without the bit; the fix is
`chmod +x` plus `git update-index --chmod=+x`.
Project-specific checks (sims, gates, linters) go in `tools/check.local.sh`,
which check.sh runs between the boot and the scenarios with `QUICK` set;
check.sh itself is synced over. When a project's copy of the tooling is
behind, check.sh says so in a `note:` line — that is the cue to run
`/sync-godot-tooling`.
`tools/export.sh` fetches export templates on first run (~1 GB download,
cached) and applies the same exit-124 convention to the exported binary; CI
runs it on version tags (`.github/workflows/export.yml`).

### The debug console

F12 toggles it; `DebugConsole.execute(line) -> String` is the input-free
seam — scenarios pass unknown commands straight to it, so scenario lines
and console lines are ONE vocabulary. **A new command needs both halves**:
its surface (name, aliases, usage, args) in
`data/console_commands.project.json` and a handler in
`scripts/dev/dev_hooks.gd`'s `console_dispatch()`. The console itself
(`scripts/dev/debug_console.gd`, `data/console_commands.json`) is a synced
copy: a handler added to its closed `match` is overwritten by the next
sync, which is why one project's 600 lines of in-file commands cannot be
synced today.
Failures must be returned as `"ERROR: ..."` — the harness fails a scenario
on exactly that shape, so an assertion-like handler that answers `"false"`
instead passes silently.

### Tests

```bash
tools/test.sh               # all, across parallel shards
tools/test.sh test_smoke    # one script
TEST_JOBS=1 tools/test.sh   # one process — the readable log
```

GUT 9.7.1, vendored in `addons/gut`, tests in `tests/`, config in
`.gutconfig.json`. Everything in `tests/` is pure logic and runs headless —
anything needing a rendered frame belongs in a scenario instead.

**The suite runs in shards** (4 by default): a Godot test run is CPU-bound
and single-threaded while the suite is a pile of independent scripts. Each
shard gets its own `XDG_DATA_HOME` (every shard writes `user://`, and two
sharing it fight over the same files); a shard's config says `dirs: []`
(GUT ADDS `-gtest` entries to whatever the config names); an empty shard is
compacted away (GUT exits 1 on a config with no tests). Balance comes from
the LAST run's JUnit timings in `.godot/test-timings`, dealt longest-first.
**Sharding exposes cross-test leaks, which is a feature**: a script that
only passed because an earlier one had left something set now fails; fix
the dependency, never reorder the shards. When a sharded failure makes no
sense, run `TEST_JOBS=1` and compare.

**A test script that fails to parse is silently dropped and GUT exits 0.**
Four projects each discovered this behind an all-green check; the only tell
was the total test count falling. `test.sh` now greps every log for the
load failure and counts the scripts that ran against the files on disk, and
Kombucha's self-test proves both guards fire against a scratch copy with
a broken test file. A falling count is a file not loading, not fewer tests
passing.

**The JUnit report is merged across shards** into
`.godot/test-results.xml` (`TEST_JUNIT` moves it, empty skips it); CI
keeps it as the `test-results` artifact beside the shots, so a red run
can be read per test without the log.

**A slow test is usually a sleeping one.** Anything that waits out a real
timer belongs behind a seam a test can shorten; profile with the per-script
times in `.godot/test-timings`.

A test that exercises a deliberate refusal path (where the logged error *is*
the behaviour under test) must tell GUT the error is expected:
`gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.NOTHING`.

**Headless UI smoke recipe:** a crash in code-built UI that only mouse input
reaches is still testable headless — instantiate the real scene, let it
build, and call its handlers directly:

```gdscript
func test_scene_builds_and_handlers_run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame  # _ready has run; code-built UI exists
	# call the scene's input-free methods here and assert
```

This complements the screenshot harness: the harness proves the player's
path renders; this proves the wiring survives a refactor, cheaply, in CI.

**Frame-rate independence recipe** (for any pure simulation): run the same
seeded scenario twice at two `dt`s (1/30 and 1/120), record the sim-time at
which each event first became true rather than the end state (an end-state
comparison passes trivially once both runs finish), compare timestamps with
a tolerance you can derive (one slow tick per stage boundary) and discrete
counters exactly. Anything that drifts is accumulating delta somewhere.

### Seeing the game (screenshot harness)

For anything visual, do not ask the user what it looks like — capture it:

```bash
tools/shoot.sh                        # every scenario, one Godot process
tools/shoot.sh scenarios/example.txt  # just one
```

Scenarios are plain-text files in `scenarios/`, one command per line. Write a
new scenario for whatever you are working on rather than editing an existing
one. Needs a display (WSLg, `DISPLAY=:0`) — **not** `--headless`, which has
no renderer and captures blank frames. PNGs land in `shots/` (gitignored).

Built-in commands (`scripts/dev/screenshot_harness.gd`): `shot <name> [x y w
h]`, `wait <frames>`, `ticks <n>` (physics frames: game time), `sleep
<seconds>` (wall-clock, deliberately ignoring `Engine.time_scale`), `settle
[s] [group]` (wait until nothing in the group answers `is_busy()`, ERROR
after `s`), `click <NodeName>` (synthesises real input — prefer it when what
you need to prove is that the *player's* path works, not that a handler
does), `click_at <x> <y>` (viewport coordinates, for Node2D boards),
`scroll_to <NodeName>`, `hover <NodeName>`, `press <action>`,
`assert_visible`, `assert_onscreen` (Control, or Node3D through the live
camera), `assert_tooltip <NodeName> <text>`, `frame_budget <ms> [frames]`,
`expect_shot <name> [tolerance]`, `mask <x> <y> <w> <h>`, `expect_fail`,
and `#` comments. Project-specific commands go in
`scripts/dev/dev_hooks.gd`'s `scenario_command()` — return `""` on success,
`"ERROR: ..."` on failure, `null` to hand the line to the console. **The
harness only fails on error-shaped replies**, so an assertion command must
return an error, never a `"false"` answer that passes silently.

**State readback before pixels.** The console's `state` and `assert <key>
<value>` reach any node in the `state` group that implements
`state_text()` and `assert_key(key, value)` (answer `""`, `"ERROR: ..."`, or
exactly `"ERROR: unknown key '<key>'"` so the next provider is asked; a
`prefix:` key exposes an open namespace). A JSON line is cheaper than a
screenshot and assertable; every board game reinvented this seam under its
own prefix before it was shared. **A scenario must assert state after
actions**: a click that cancels back to a menu without an error, followed
by more clicks that also do nothing, is a scenario of silent cancels that
passes.

Rules that keep the harness useful:

- **Waits are three verbs, on purpose.** `wait` is frames, `ticks` is
  physics frames (game time), `sleep` is wall-clock. Under a slow renderer
  physics falls behind wall time, so a wall-clock sleep under-waits
  exact-timed choreography (one project's ferry failed only in the batch);
  a timer-driven thing wants `sleep`. `settle` beats both when the thing
  you are waiting for can say it is busy.
- **A name shared by two nodes is an ERROR, not a coin toss.** Every lookup
  refuses an ambiguous name; assert on a uniquely named node instead. One
  project's `assert_onscreen Cliffs` used to answer about whichever area
  loaded first.
- **Synthetic clicks go through `push_input` in canvas coordinates**, never
  `Input.parse_input_event`, which treats the position as window pixels:
  under any stretch other than the design resolution every click lands
  somewhere else (found at Steam Deck resolution, where every scenario
  click missed). `click`, `click_at` and `hover` all use it.
- **A row below the fold is visible but not clickable**: `click` lands where
  the rect is, outside the viewport. `scroll_to` it first. A menu whose only
  seam is a clickable button is not fully scriptable once it scrolls; every
  menu action also needs a non-click seam.
- **`expect_shot` is the visual regression gate, and baselines are per
  rasterizer.** It compares the frame against
  `scenarios/baselines/<renderer>/<stem>-<name>.png` (committed; the
  directory is `.gdignore`d so the editor never imports it) and fails on
  ANY differing pixel by default, saving the actual frame and a
  red-on-dim diff beside the shots. Reruns on one machine are
  pixel-identical, so a difference is a change to look at, not noise; a
  moving element gets a `mask` line, because a tolerance wide enough to
  hide a clock also hides a real regression. `SHOOT_BASELINES=update
  tools/shoot.sh <scenario>` writes the baselines (the first frame per
  name; `expect_fail` never writes). The `<renderer>` directory is the
  adapter family (`llvmpipe`, `nvidia`): a GPU and a software rasterizer
  do not agree pixel for pixel, and a missing baseline for the machine's
  renderer is an ERROR that names the path, never a silent pass.
- **`frame_budget` is a regression tripwire, not a device target.** It
  turns vsync off for the measurement (with vsync on every scene reads
  16.7 ms and the gate can never fail) and prints the number on pass, so
  the trend is visible before the gate goes red. Under WSLg the renderer
  is llvmpipe, software; what it catches is the same scene on the same
  machine becoming several times more expensive.
- **The real cursor is global state.** `_sandbox()` parks it at (2, 2);
  left over a control it feeds hover and tooltips into every later
  scenario.

- **When adding UI, add the input-free seam alongside it.** Any interaction
  reachable only through an InputEvent cannot be screenshotted, scripted, or
  asserted on, and is effectively untestable.
- Give run-time-built controls a stable `name`; an auto-named `@Button@3`
  cannot be clicked or found.
- Put `assert_onscreen` after anything that places objects — something
  escaping the view is among the most repeated visual bugs.
- To judge text sharpness or fine detail, capture a **1:1 crop**
  (`shot <name> <x> <y> <w> <h>`) — a full-window shot is downscaled when
  viewed and hides exactly the detail in question.
- **Scenarios are dealt across processes and reordered by cost**
  (`SHOOT_JOBS`, longest-first from `.godot/shoot-timings`), each process
  with its own `XDG_DATA_HOME`, so no scenario may depend on another having
  run first and two `shoot.sh` runs cannot collide. Measured: two shards
  164 s against 204 s for a 36-scenario suite. `SHOOT_JOBS=1` keeps the
  order given, which is how an order-dependent pair is proven on purpose.
- **Between scenarios the harness returns to the BOOT scene**
  (`application/run/main_scene`), never a reload of wherever the last
  scenario navigated: one project's first scenario that pressed Play left
  every scenario after it starting inside the arena, and every `click
  PlayButton` failed with "no node named". A scenario is free to leave the
  boot scene; the next one starts on it.
- **Where the project lives is the biggest cost.** Through WSL's `/mnt/c`
  bridge a real project boots in ~11 s per process, from the Linux
  filesystem in under a second; `check.sh` says so when it notices. Pacing
  flags are not a lever here: under WSLg the game already runs unthrottled
  (~400 fps), and `--fixed-fps` makes heavy scenes SLOWER on a software
  renderer because game time falls behind wall time (measured, rejected).
- Scenarios run in a batch and the harness reloads the scene between
  them — but **anything global survives that reload**. When introducing new
  global state (autoload fields, static vars, write-through files), reset it
  in `sandbox()` in `scripts/dev/dev_hooks.gd` (the harness's own
  `_sandbox()` is synced over and only knows the Template autoloads), or a
  scenario that changes it poisons every scenario after it. The symptom is
  always misleading: a scenario that passes alone and fails in the batch,
  or vice versa.

### Reading a run as data

Every scenario leaves `shots/<stem>.jsonl` beside its PNGs: one JSON
object per executed line (`line`, `reply`, `ms`, `ok`) and a summary
last (`scenario`, `ok`, `failures`, `seconds`, `shots`). It answers "what
did this scenario do and where did the time go" with `grep` or `jq`,
without the engine log. The merged JUnit report is the same idea for the
suite. Both exist because a log is read once and a file is asked again.

The engine's own exit line `N resources still in use at exit` is NOT
counted as an error: it names a resource a `const preload` still holds
while the tree is torn down (`--verbose` says which), the count varies
between identical runs, and a gate on it would be a coin toss. A leak
that matters shows up as memory in the boot budget or as a growing
`frame_budget` number, which are gated.

### The tooling is a synced copy

`tools/test.sh`, `check.sh`, `shoot.sh`, `export.sh`, the screenshot
harness, the debug console, GUT and `.gutconfig.json` are owned by the
Kombucha repo and listed in `tools/tooling-manifest.txt`;
`tools/TOOLING_VERSION` says which Kombucha commit they came from. Do
not edit them here — a `/sync-godot-tooling` run overwrites them, and an
improvement made here is invisible to every other project. Improve them in
Kombucha, then sync. Extend them only through `scripts/dev/dev_hooks.gd`,
`data/console_commands.project.json` and `tools/check.local.sh`.

Before a sync, `tools/sync-tooling.sh <project> --check --diff` (run from
Kombucha) measures each drifted owned file against the Kombucha or
Template version it is closest to and prints the lines THIS project added
beyond it: what must move into a seam, or go to Kombucha first, before
the sync overwrites it. `--kit` is the same report for the kit files the
Template owns (autoloads, util, ui), which are cherry-picked, never
synced: per file, the Template version the copy is at, the project's own
lines, and the Template commits since.
