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
`tools/export.sh` fetches export templates on first run (~1 GB download,
cached) and applies the same exit-124 convention to the exported binary; CI
runs it on version tags (`.github/workflows/export.yml`).

### The debug console

F12 toggles it; `DebugConsole.execute(line) -> String` is the input-free
seam — scenarios pass unknown commands straight to it, so scenario lines
and console lines are ONE vocabulary. **A new command needs both halves**:
its surface (name, aliases, usage, args) in `data/console_commands.json`
and a handler in the closed `match` in `scripts/dev/debug_console.gd`.
Failures must be returned as `"ERROR: ..."` — the harness fails a scenario
on exactly that shape, so an assertion-like handler that answers `"false"`
instead passes silently.

### Tests

```bash
tools/test.sh               # all
tools/test.sh test_smoke    # one script
```

GUT 9.7.1, vendored in `addons/gut`, tests in `tests/`, config in
`.gutconfig.json`. Everything in `tests/` is pure logic and runs headless —
anything needing a rendered frame belongs in a scenario instead.

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
h]`, `wait <frames>`, `sleep <seconds>` (wall-clock, deliberately ignoring
`Engine.time_scale`), `click <NodeName>` (synthesises real input — prefer it
when what you need to prove is that the *player's* path works, not that a
handler does), `assert_visible`, `assert_onscreen`, `expect_fail`, and `#`
comments. Project-specific commands go in `_project_command()` — return `""`
on success, `"ERROR: ..."` on failure. **The harness only fails on
error-shaped replies**, so an assertion command must return an error, never a
`"false"` answer that passes silently.

Rules that keep the harness useful:

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
  global state (autoload fields, static vars, write-through files), add it to
  `_sandbox()` in the harness, or a scenario that changes it poisons every
  scenario after it. The symptom is always misleading: a scenario that passes
  alone and fails in the batch, or vice versa.

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
