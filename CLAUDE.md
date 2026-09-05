# CLAUDE.md

## What this repo is

Microbiome is the workshop for the Godot-to-Claude workflow itself: the
test runner, check script, screenshot harness, debug console, sandbox rules
and the conventions in this file. It is **not a game**. The scene,
autoloads, tests and scenarios here are a fixture that exists so the
tooling can be exercised; keep them minimal and do not grow game features.

Rules that follow from that:

- **A change here is a workflow change.** Judge it by what it lets Claude
  prove or see in a real project, not by what it does for the fixture.
- **The fixture must exercise every tool.** A harness command, check step
  or runner flag with nothing in `tests/` or `scenarios/` using it is
  untested tooling; extend the fixture in the same commit.
- **`tools/check.sh` green is the bar for every commit**, the same as in a
  game project.
- **The tooling is owned here and copied outward.** `tools/tooling-manifest.txt`
  lists the paths every project carries as a copy; `tools/sync-tooling.sh`
  (the `/sync-godot-tooling` skill) refreshes them and stamps
  `tools/TOOLING_VERSION`. A project never edits an owned file: it extends
  through `scripts/dev/dev_hooks.gd`, `data/console_commands.project.json`
  and `tools/check.local.sh`, which a sync never touches. Seeds for those
  live in `tools/seeds/`. Without this split, nine projects each carried a
  diverged harness and the same bug was fixed four times.
- **Lessons flow two ways.** Findings go in `docs/research/`; rules earn a
  place below as *the rule plus what breaks without it*; both are
  backported to `Template` with the `/update-template` skill so new
  projects inherit them. Read `docs/roadmap.md` for the current order.

## GodotPrompter

This project uses the GodotPrompter workflow plugin. Before implementing any
Godot system (movement, state machines, UI, save/load, AI, shaders, etc.),
check for a matching `godot-prompter:*` skill and invoke it first — it decides
*how* to build the system; your own judgment decides *what* to build. This
applies to subagents writing Godot code too. Run
`godot-prompter:using-godot-prompter` for the full skill index if unsure which
one matches.

## Project conventions

Godot 4.7, GL Compatibility renderer, GDScript with static typing. The
conventions below are the Template's; each transferred from a project where
it had already cost a debugging pass when violated. They are maintained here
first and backported. State every rule *and* what breaks without it.

### Layout

Split layout: `assets/`, `scenes/`, `scripts/`, `resources/`. Autoloads live
in `scripts/autoloads/` (EventBus, SaveManager, Keybinds, AudioManager,
GameManager) plus dev-only ones in `scripts/dev/` (DebugConsole,
ScreenshotHarness), all registered in `project.godot` in dependency order.
Keep autoloads small — move logic into standalone classes
(`scripts/util/`, `scripts/ui/`) and call them from the autoload.

### Styling lives in UITheme

`scripts/ui/ui_theme.gd` builds the whole Theme in code from nine palette
constants; `main.gd` applies it at the tree root. Change the look there — do
not scatter `.tres` themes or per-node `add_theme_*_override` calls that a
palette change cannot reach. `UITheme.accent_border()` is the highlight
variant.

### Code-built nodes: direct references, stable names

A node built in code gets a runtime auto-name (`@Button@3`) unless you set
`name` — so `get_node()` paths into code-built UI do not resolve, and the
screenshot harness cannot click it. Keep a direct reference (or
`set_meta()`) for your own access, and give anything the harness or a test
must find a stable `name` (see PauseMenu's `ResumeButton`, the console's
`ConsoleInput`).

### Autoloads must not name UI classes

An autoload naming a `class_name` from the UI layer (`var nav: NavMenu`,
`panel as ReadingPanel`) pulls that script — and everything it pulls — into
the load that runs *before* the autoloads finish. Any `preload` re-entered by
that chain hands back an **empty PackedScene whose `instantiate()` returns
null**, and the failure surfaces far away from the cause. In an autoload,
reach UI through groups, leave the variable untyped and gate on
`has_method()`. Where a preload is genuinely needed on that path, load it
lazily.

### Persistence goes through SaveManager's redirectable paths

`SaveManager.save_root` / `config_path` are variables so tests and the
screenshot harness can point the whole save system at scratch storage and
restore it afterwards. Route any new persistence through them — a suite run
must never edit the player's real saves or settings.

### Input is action-based, and Keybinds owns the catalog

Read input with `Input.get_axis()` / `is_action_just_pressed()` — never
compare `event.keycode` against a constant, which makes the control
unrebindable. Rebindable actions are declared in ONE place: the `ACTIONS`
table in `scripts/autoloads/keybinds.gd` (action, default key, label,
conflict group). Add new actions there, not piecemeal beside their
consumers.

Rules Keybinds enforces, each paid for elsewhere:

- **Conflicts are refused, not stolen** — `set_binding()` returns `false`
  when the key belongs to another action in the same group; `holder_of()`
  names the owner so UI can explain the refusal.
- **Pollers must check `Keybinds.capturing`** — `Input.get_vector()` and
  friends never see events a rebind-capture UI consumes, so pressing W to
  rebind it also pans the camera unless polling code checks the flag.
- Bindings store as legible `key:F5` / `mouse:3` strings in settings.cfg,
  so a support answer can say "put key:F5 back".

### Missing assets degrade, never error

Absent art or translation strings must fall back gracefully. A missing PNG
or untranslated key is a normal state, not an exception. For strings that
may be untranslated, use `L10n.tr_or_fallback(key, fallback)`
(`scripts/util/l10n.gd`); translations live in `localization/game.csv` —
re-import after editing it. The same rule shapes BugReport
(`scripts/dev/bug_report.gd`): a report about a broken game must not itself
refuse to build because the game is broken, so every missing piece becomes a
line in report.txt instead of a failure.

### Scaling UI keeps text sharp only via oversampling

Scaling a Control scales its rasterised output — Godot's automatic font
oversampling follows the viewport's content scale and knows nothing about a
Control's own `scale`, so text goes soft as the window grows. `UiScaleRoot`
(`scripts/ui/ui_scale_root.gd`) exists for exactly this: it lays chrome out
in a design-space rect and drives `Window.oversampling_override` to match
its factor. Any new scaling path must do the same. Judge sharpness with a
1:1 crop (`shot <name> <x> <y> <w> <h>`) — a full-window shot is downscaled
when viewed and hides exactly the detail in question.

### Debug code

Temporary debug goes in `scripts/main.gd` and is **always** reverted before
finishing. Prefer a test over temporary debug entirely: a debug loop leaves
nothing behind, and every assertion that caught a bug gets deleted the moment
it passes — a test keeps catching it.

### Headless drivers: a self-freeing autoload behind a `--flag`

A dev mode that runs from the command line (a sim, a balance gate, a linter,
a bench) is an **autoload that frees itself when its flag is absent**, never
a `-s` tool script: `-s` scripts run WITHOUT autoloads, so any class that
names one fails to compile there with a misleading "identifier not found",
and a class cycle that only resolves once the autoloads register cannot
compile at all. `tools/seeds/dev_driver.gd` is the skeleton
(`Cmdline.has_flag`, `queue_free()`, `call_deferred`, `quit(status)`);
`scripts/dev/selftest_driver.gd` is the fixture's copy. The exit code is the
verdict, so `check.sh` can gate on it — and **a gate must be proven able to
fail**: restore the bug it guards against once, watch it go red, then trust
it. One project's balance gate was verified by restoring an exploitable heal
and confirming red; another's AI "still beats random" check regressed to a
coin flip twice from a sign error nothing else noticed.

### Godot pitfalls the harness has caught

Each of these was found by a screenshot or a scenario after the code looked
right; several were found by two projects independently.

- **Anchor before the tree, or anchor-and-offset.** `set_anchors_preset()`
  on a Control already in the tree preserves its current rect by writing
  compensating offsets, so a fresh 0-size Control "anchored full-rect" in
  its own `_ready()` stays 0×0 and everything inside piles into the
  top-left. Use `set_anchors_and_offsets_preset()`, or set anchors before
  `add_child()`. And `Control.position` on an anchored control is
  parent-relative: place with `offset_*`. (Two projects, independently.)
- **A child's `_ready()` runs before its parent's, and groups are not filled
  yet.** A pause menu asked in `_ready()` whether a match was running,
  always got no, and its Save button had never once appeared in a running
  game; nothing asserted it. Ask in `open()`, when the answer is knowable.
- **Signals from an autoload need a method, not a lambda.** Godot drops a
  connection whose bound object was freed, but a lambda is bound to
  nothing; it merely captures `self`. A scene node's lambda connected to an
  autoload signal outlives the scene and fails on the next emit with
  "Lambda capture at index 0 was freed". Same for any lambda capturing a
  thing that can die first (a tween callback capturing a sprite): bind an
  id and look it up.
- **A code-built UI tree must theme itself.** A Control under a bare
  CanvasLayer inherits no theme, renders Godot's translucent defaults, and
  the game bleeds through its panels; it looks like a layout bug and is one
  missing `theme = UITheme.get_theme()` in the subtree's own `_ready()`.
- **`Image.load()` on a `res://` path fails the suite.** It logs "loaded
  resource as image file, this will not work on export", which counts as an
  engine error. Decode from bytes: `FileAccess.get_file_as_bytes` plus
  `Image.load_png_from_buffer`.
- **Engine tooltips are unreliable under WSLg** (focus and pointer-chatter
  dependent). `assert_tooltip` reads the tooltip text instead of waiting for
  the popup; a game that draws hints in its own overlay asserts on that.

### Third-party licences

`LICENSES.md` is a running ledger. Anything third-party that enters the repo
gets a row there **in the same commit that adds it**. Keep any licence file
that ships with a pack where it landed; the ledger only summarises.

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
`tools/selftest.sh` proves both guards fire against a scratch copy with a
broken test file. A falling count is a file not loading, not fewer tests
passing.

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
`expect_fail`, and `#` comments. Project-specific commands go in
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
- Scenarios batch into one process and the harness reloads the scene between
  them — but **anything global survives that reload**. When introducing new
  global state (autoload fields, static vars, write-through files), reset it
  in `sandbox()` in `scripts/dev/dev_hooks.gd` (the harness's own
  `_sandbox()` is synced over and only knows the Template autoloads), or a
  scenario that changes it poisons every scenario after it. The symptom is
  always misleading: a scenario that passes alone and fails in the batch,
  or vice versa.

## Interpretation notes (decided + tested)

Ambiguities that came up, how they were decided, and where the decision is
pinned by a test — so they are not re-litigated. Add to this list whenever a
judgment call gets made that the code alone would not explain.

- Binding a key already taken in the same conflict group is *refused*, not
  stolen (`test_conflict_within_group_is_refused_not_stolen`).
- Bus volume 0 means *muted*, and `-inf` dB must never be stored
  (`test_zero_is_mute_not_negative_infinity`).
- A missing UI sound, translation, or asset is silence/fallback, never an
  error (`test_ui_event_with_no_sound_is_silence`).
