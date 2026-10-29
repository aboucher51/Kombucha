# CLAUDE.md

> **How to write in this file:** Write each rule as a plain sentence that says who does what. Give orders to "you".
> Keep every code name, in backticks. Do not copy any bold slogans or semicolon chains you find below.

<!-- kombucha-only -->
## What this repo is

Kombucha is the workshop for the Godot-to-Claude workflow itself: the
test runner, check script, screenshot harness, debug console, sandbox rules
and the conventions in this file. It is **not a game**. The scene,
autoloads, tests and scenarios here are a fixture. The fixture exists so
that you can run the tooling against it. Keep the fixture minimal and do
not grow game features.

Rules that follow from that:

- **Judge a change here as a workflow change.** Ask what it lets Claude
  prove or see in a real project, not what it does for the fixture.
- **Make the fixture use every tool.** A harness command, check step
  or runner flag that nothing in `tests/` or `scenarios/` uses is
  untested tooling. Extend the fixture in the same commit.
- **Keep `tools/check.sh` green on every commit**, the same as in a
  game project.
- **This repo is also the Claude Code plugin** (`.claude-plugin/`,
  `skills/`). A user installs it from the marketplace, and the skills
  find the tooling in the plugin checkout. Never name a path on one
  machine anywhere under `tools/`, `skills/` or the docs. `GODOT_TOOLING`
  overrides the location (it points to a clone with history, for
  backports and the kit report). `$HOME/godot-projects/` is the
  convention.
- **Kombucha owns the tooling, and projects carry copies.**
  `tools/tooling-manifest.txt` lists the paths every project carries as a
  copy. `tools/sync-tooling.sh` (the `/sync-godot-tooling` skill)
  refreshes them and stamps `tools/TOOLING_VERSION`. A project never
  edits an owned file. It extends the tooling through
  `scripts/dev/dev_hooks.gd`, `data/console_commands.project.json`
  and `tools/check.local.sh`, which a sync never touches. It also extends
  it through `tools/check.local.env`, the project's own settings for
  `check.sh`, starting with `CHECK_RSS_BUDGET_KB` (the most memory, in KB,
  the game may use when it boots). A sync seeds that file once and never
  touches it again. Seeds for those live in `tools/seeds/`. Before this split, nine projects each carried a
  diverged harness, and projects fixed the same bug four separate times.
- **This repo is also the scaffold.** `tools/new-project.sh` copies the
  fixture minus Kombucha-only paths. It also strips the sections fenced
  `<!-- kombucha-only -->` from CLAUDE.md and LICENSES.md. So the kit,
  the contract and the conventions have ONE source. When you improve the
  kit in a game, bring it back here with `/update-kombucha`. Projects
  cherry-pick kit files (`sync-tooling.sh --kit` says what is newer).
- **Lessons move both ways between Kombucha and its projects.** Put findings in `docs/research/`. A rule
  earns a place below as *the rule plus what breaks without it*,
  and every new project inherits it. Read `docs/roadmap.md` for the
  current order.
- A project sends its own reports under `docs/feedback/<project>/` on a
  `feedback/` branch (`docs/feedback/README.md`). The project reports
  what it hit. This repo assesses the report and appends the disposition
  (what Kombucha decided to do about it). A project never reads this repo
  to write one.

## Agent tickets

Kombucha's ticket board lives in the checkout on forge, with the key
`KOMBU`. Its manager session is `kombucha-pm`, and it runs the one ticket
worker. The network policy says which machine does what:
https://claude.ai/artifact/YCi8J7ano5QjUVMBnFJk4M. Read it there. This
file does not copy it.

- **The push gate is the full check: `tools/check.sh --ci`, green.** On
  forge it runs with software rendering, like CI, under a heavy slot. A
  full run there took about 70 seconds (measured 2026-10-25, with another
  project's heavy run on the machine). So there is no smaller gate and no
  separate sweep. Without a named gate, a worker guesses which check
  counts and may hand over work that passed only the quick one, which
  renders nothing.
- **Kombucha has permission to merge and push on demand (Alex, 2026-10-27).**
  The PM pushes; ticket workers do not push. They hand finished, gated
  work to the PM. Before that date, every push to this public repo waited
  for Alex's yes, and that held up tooling other projects were waiting on.
- **Change main only through the gate.** Other projects pull this
  checkout before `/sync-godot-tooling`. So a broken main spreads into
  every project that syncs that day.
<!-- /kombucha-only -->

## GodotPrompter

This project uses the GodotPrompter workflow plugin. Before you implement any
Godot system (movement, state machines, UI, save/load, AI, shaders, etc.),
check for a matching `godot-prompter:*` skill and invoke it first. The skill
decides *how* to build the system. Your own judgment decides *what* to build.
Subagents that write Godot code follow this rule too. If you are unsure which
skill matches, run `godot-prompter:using-godot-prompter` for the full skill
index.

## Project conventions

Godot 4.7, GL Compatibility renderer, GDScript with static typing. The
conventions below are the kit's. Each one came from a project where breaking
it had already cost a debugging pass. Kombucha maintains them, and every
scaffolded project starts with them. As a project grows its own
load-bearing conventions, record them here the same way. State every rule
*and* what breaks without it.

### Layout

Split layout: `assets/`, `scenes/`, `scripts/`, `resources/`. Autoloads live
in `scripts/autoloads/` (EventBus, SaveManager, Keybinds, AudioManager,
GameManager) plus dev-only ones in `scripts/dev/` (DebugConsole,
ScreenshotHarness). `project.godot` registers all of them in dependency
order. Keep autoloads small. Move logic into standalone classes
(`scripts/util/`, `scripts/ui/`) and call them from the autoload.

### Styling lives in UITheme

`scripts/ui/ui_theme.gd` builds the whole Theme in code from nine palette
constants. `main.gd` applies it at the tree root. Change the look there. Do
not scatter `.tres` themes or per-node `add_theme_*_override` calls, because
a palette change cannot reach them. `UITheme.accent_border()` is the highlight
variant.

### Code-built nodes: direct references, stable names

A node built in code gets a runtime auto-name (`@Button@3`) unless you set
`name`. So `get_node()` paths into code-built UI do not resolve, and the
screenshot harness cannot click the node. Keep a direct reference (or
`set_meta()`) for your own access. Give anything the harness or a test
must find a stable `name` (see PauseMenu's `ResumeButton`, the console's
`ConsoleInput`).

### Autoloads must not name UI classes

An autoload that names a `class_name` from the UI layer (`var nav: NavMenu`,
`panel as ReadingPanel`) pulls that script, and everything it pulls, into
the load that runs *before* the autoloads finish. Any `preload` that this
chain re-enters hands back an **empty PackedScene whose `instantiate()` returns
null**. The failure then shows up far away from the cause. In an autoload,
reach UI through groups, leave the variable untyped and gate on
`has_method()`. Where that path really needs a preload, load it lazily.

### Persistence goes through SaveManager's redirectable paths

`SaveManager.save_root`, `config_path` and `mods_root` are variables, so
tests and the screenshot harness can point the whole save system (and
mod loading) at scratch storage and restore it afterwards. Route any new
persistence through them. A suite run must never edit the player's real
saves, settings or mods.

- **The `save_provider` group writes the saves.** Any node that answers
  `save_key()`, `save_payload()` and `restore_payload(payload)` gets its
  slice in the slot. SaveManager reaches it by group and `has_method`,
  because an autoload must not name a scene class. An empty payload writes
  no key. Two projects arrived at this seam on their own before Kombucha
  shared it.
- **`SaveCompat` stamps and migrates every save** with its schema, game
  version and optional mod ids. When you change what a provider writes,
  bump `SCHEMA`, add a `_to_N` step, and freeze a golden old-format fixture
  in a test that must load forever.
- The save loader refuses a save from the future with a reason, and never
  guesses at it. It refuses a save that needs a missing mod BY NAME.
  `SaveManager.last_load_problem` carries the reason for a UI.
- **JSON quietly breaks three things.** First, `JSON.stringify` sorts keys
  by default, and Dictionary equality is order-sensitive. So a saved
  dictionary came back unequal to itself. Pass `false` (SaveManager does).
- Second, JSON has no int type: `500` comes back `500.0`. So restored
  dictionaries go through one normaliser, and a test compares against
  floats.
- Third, JSON silently truncates a 64-bit `rng.state` stored as a number to
  a double. Store it as a string.
- **Give each record shape one normaliser, so a restored record equals a
  fresh one.** Every path that builds a record (fresh, from a template,
  from a save) goes through ONE function (`SimUnit.from_dict`,
  `Merit.normalise`). That function fixes key ORDER and TYPES. One test
  per shape asserts `restore(to_dict()) == to_dict()`. A migration then
  reshapes one field, and the normaliser does the rest. A golden fixture
  per schema pins the chain. Eight schema bumps in one afternoon held
  together on this. Without it, every migration re-derives what a record
  looks like.
- **Slots carry meta** (`saved_at`, `slot`, `version`, whatever the caller
  adds) at the top level. So `slot_meta()` and `list_slots()` describe a
  slot without parsing the payloads.
- `list_slots()` always lists numbered slots, and appends anything else it
  finds on disk. A save the listing does not mention is a save you cannot
  find again.
- **Every settings write emits `EventBus.settings_changed`.** Live systems
  re-apply from that one seam. Listeners connect a METHOD, never a
  lambda (see below).
- **Pass a default on every settings read.** `ConfigFile.get_value` with no
  default logs an ENGINE ERROR for a missing key. So the first setting
  added after the file existed errs on every boot. `AudioManager` reads
  volumes with a `-1.0` sentinel and skips on it.

### Reading JSON values: `str()` and `JsonValue.truthy()`

`String()` refuses a bool, and `bool()` refuses a String. An absent JSON
field arrives as `false`, which is the common case. So a constructor cast
on a value that came out of JSON raises on ordinary data. Use `str()` for
Variant-to-text. Use `JsonValue.truthy(value, fallback)` for "is this field
set" (`typed_truthy` for a form field where the word "false" means false).

`ContentDB.load_layered(file)` layers `user://mods/*/data/<file>` over
`res://data/<file>` with `DataMerger` PATCH semantics in sorted order. A
missing file is the normal case.

Treat text a PERSON wrote as markup until you `BBCode.escape()` it.
`sanitise()` happens on decode, not on input. The sender's client is the
attacker's client, so a LineEdit `max_length` is not a limit.

### Input is action-based, and Keybinds owns the catalog

Read input with `Input.get_axis()` / `is_action_just_pressed()`. Never
compare `event.keycode` against a constant, because that makes the control
unrebindable. The `ACTIONS` table in `scripts/autoloads/keybinds.gd` is the
ONE place that declares rebindable actions (action, default key, optional
`pad` button, label, conflict group). Add new actions there, not piecemeal
beside the code that uses them.

Keybinds enforces these rules. Each one cost a debugging pass somewhere:

- **Keybinds refuses a conflict and never steals the key.** `set_binding()`
  returns `false` when the key belongs to another action in the same
  group. `holder_of()` names the owner so UI can explain the refusal.
- **Code that polls input must check `Keybinds.capturing`.**
  `Input.get_vector()` and friends never see events that a rebind-capture
  UI consumes. So pressing W to rebind it also pans the camera, unless
  the polling code checks the flag.
- Keybinds stores bindings as legible `key:F5` / `mouse:3` / `joy:6` /
  `axis:1:-` strings in settings.cfg, so a support answer can say "put
  key:F5 back".
- **Half an axis is a binding like a key.** A stick pushed up rebinds and
  conflicts the same way. Otherwise every pad-aware project grows its own
  axis table beside Keybinds.
- **The rebinding rules live in Keybinds, not in the settings screen.**
  The screen calls `begin_capture(action, slot)`, then feeds raw events
  into `capture_event()` from its `_input`. In capture, a modifier alone
  waits, and Keybinds ignores the wheel. Escape and a click away cancel,
  and Backspace clears. A stick counts past 0.5. Keybinds refuses a taken
  key and names the holder.
- A test or a scenario calls
  `capture_text("F7" | "mouse:3" | "axis:0:-" | "escape" | "clear")`
  instead. `capture_ended` tells the row to redraw. The screen only
  displays. One project rebuilt these rules in 500 lines of UI before the
  seam existed.

**One router reads every controller, and menus use only `ui_*` actions and focus.** The
`Pads` autoload is the ONE reader of raw joypad input. At startup it strips
Godot's built-in joypad events off `ui_*`, and it re-synthesises them
through `PadRouter` (deadzone, dominant axis, held-direction repeat). So
focus navigation, every menu and the harness's `press` share one
vocabulary, and a scenario written with `press ui_down` IS the pad path.
What follows from this:

- A menu that opens without grabbing focus is unreachable by pad. Call
  `UIFocus.first()` in `open()`.
- Keyboard Escape is BOTH `ui_cancel` and `pause`. So a cancel path must
  skip events that also match pause.
- Gating which pad may act is opt-in, through the `pad_gate` group.

### UI kit rules

- **The theme draws the focus ring** (`UITheme.focus_ring()` on every
  focusable class). Keyboard and pad navigation are invisible without it.
  An HSlider has no focus stylebox in Godot, so the ring shows on buttons.
- **Put chrome motion on `offset_transform_*`, never on `position` or
  `scale`.** A container lays its children out every frame, and a tween
  on a laid-out property fights the container. (A toast slid to the left
  edge, because the code captured its rest position before the stack had
  placed it.) The engine draws the offset transform, and the layout does
  not read it. `pop_in` is the reference.
- `icon_alignment = CENTER` draws the icon UNDER centred text, not beside it.
- **`String.capitalize()` title-cases every word.** So a refusal from a
  sim ("needs troupe level 8") becomes "Needs Troupe Level 8" in a
  tooltip. For sentence text, raise the first letter and nothing else.
- **An empty `Label` still takes a line in a `VBoxContainer`.** Add the
  row only when there is text. Otherwise a locked entry leaves a gap where
  its explanation would be.
- **A `RichTextLabel` gives ONE word a tooltip** with
  `[hint=explanation with spaces]word[/hint]`. A card uses this to name a
  thing and explain it on hover without a second control.
- **Panels arrive with `UITheme.pop_in()`.** It defers by instance id, so
  a control freed before the deferred call lands is not an error. It uses
  pause-mode process, so it runs while the tree is paused.
- **`UiScaleRoot` drives its parent in place** (`attach()` /
  `attach_if_outermost()`). It does no reparenting, so `$Path` in the
  screen's script keeps working. Attaching twice scales twice.
  `attach_if_outermost` refuses that when the screen sits inside another.
- **Window scaling snaps to integers above design size** (`GameManager`
  `_apply_scale_policy`, `snapped_factor`). Pixel art stays 1:1 or 2:1,
  and the viewport expands (aspect `expand`, the kit default, which
  seven of ten projects had switched to). Godot's own `STRETCH_INTEGER`
  letterboxes instead (measured). Below design size, keep the fractional
  shrink, or a Steam Deck crops.
- **A translation key must not be a position.** `dialogue.<id>-<n>`
  addressed a line by index. So inserting a line silently repointed every
  translation below it, in every language. Anything a translator keys off
  needs an identity that survives a reorder.

### Missing assets degrade, never error

When art or a translation string is missing, fall back. Never raise an
error. A missing PNG or untranslated key is a normal state, not an
exception. For strings that may lack a translation, use
`L10n.tr_or_fallback(key, fallback)` (`scripts/util/l10n.gd`).
Translations live in `localization/game.csv`. Re-import after you edit it.

**The localization test checks that every UI string has a row.** `tests/test_localization.gd`
scans `scripts/` for every `ui.*` key and fails when the CSV lacks a row.
So a new string is a key plus a row in the same commit, never a bare
literal.

The `xa` column is the pseudo-locale. `tools/make_pseudo_locale.py` builds
it. Re-run that script after you add strings. The pseudo-locale makes every
string accented, bracketed and ~35% longer. So plain English in `scenarios/pseudo_locale.txt`'s shot is a
HARDCODED string the scanner could not see, and a layout that only fits
English breaks visibly. A language dropdown must filter `xa` out. The
console's `locale xa` reaches it.

The same rule shapes BugReport (`scripts/dev/bug_report.gd`). A report about
a broken game must still build, even though the game is broken. So BugReport turns
every missing piece into a line in report.txt instead of a failure.

### Scaling UI keeps text sharp only via oversampling

When you scale a Control, Godot scales its rasterised output. Godot's
automatic font oversampling follows the viewport's content scale and knows
nothing about a Control's own `scale`. So text goes soft as the window grows.
`UiScaleRoot` (`scripts/ui/ui_scale_root.gd`) exists for exactly this. It
lays chrome out in a design-space rect and drives
`Window.oversampling_override` to match its factor. Any new scaling path must
do the same. Judge sharpness with a 1:1 crop (`shot <name> <x> <y> <w> <h>`).
The viewer shrinks a full-window shot, which hides exactly the detail in
question.

### Debug code

Put temporary debug in `scripts/main.gd`, and **always** revert it before
you finish. Better, write a test instead of temporary debug. A debug loop
leaves nothing behind, and you delete every assertion that caught a bug the
moment it passes. A test keeps catching it.

### Third-party licences

`LICENSES.md` is a running ledger. Give anything third-party that enters the
repo a row there **in the same commit that adds it**. Keep any licence file
that ships with a pack where it landed. The ledger only summarises.

### Headless drivers: a self-freeing autoload behind a `--flag`

Build a dev mode that runs from the command line (a sim, a balance gate, a
linter, a bench) as an **autoload that frees itself when its flag is
absent**. Never build it as a `-s` tool script. Godot runs `-s` scripts
WITHOUT autoloads, so any class that names one fails to compile there with a
misleading "identifier not found". A class cycle that only resolves once the
autoloads register cannot compile at all. `tools/seeds/dev_driver.gd` is the
skeleton (`Cmdline.has_flag`, `queue_free()`, `call_deferred`,
`quit(status)`). `scripts/dev/selftest_driver.gd` is the fixture's copy.

The exit code is the verdict, so `check.sh` can gate on it. **Prove that a
gate can fail before you trust it.** Restore the bug it guards against once,
and watch it go red. One project proved its balance gate by restoring an
exploitable heal and seeing red. Another project's AI "still beats random"
check fell to a coin flip twice, from a sign error that nothing else noticed.

### Godot pitfalls the harness has caught

A screenshot or a scenario found each of these after the code looked right.
Two projects found several of them on their own.

- **Set anchors before the node enters the tree, or set anchors and offsets together.** `set_anchors_preset()`
  on a Control already in the tree preserves its current rect by writing
  compensating offsets. So a fresh 0-size Control "anchored full-rect" in
  its own `_ready()` stays 0×0, and everything inside piles into the
  top-left. Use `set_anchors_and_offsets_preset()`, or set anchors before
  `add_child()`.
- `Control.position` on an anchored control is parent-relative. Place it
  with `offset_*`. (Two projects found both of these on their own.)
- **Defer a `grab_focus` BY INSTANCE ID**, through `UIFocus.first()` or
  `UIFocus.grab(control)`. A bare `control.grab_focus.call_deferred()`
  lands after the scene it belongs to is gone (the harness returns to the
  boot scene between scenarios). It then logs
  `Condition "!is_inside_tree()" is true`, an engine error under a green
  batch. This bug turned up twice, with eight call sites the second time.
- **Code that reaches a node by group must skip nodes on their way out.**
  A `queue_free`'d node stays in its group, visible, until the frame ends.
  A toast host picked by `get_first_node_in_group` found the previous
  test's freed host, and the "no host is no error" test found a host.
  Every group loop in the kit skips `is_queued_for_deletion()`. A test
  that asserts absence awaits one frame first.
- **A child's `_ready()` runs before its parent's, and groups are not filled
  yet.** A pause menu asked in `_ready()` whether a match was running, and
  always got no. Its Save button had never once appeared in a running
  game, and nothing asserted it. Ask in `open()`, when the answer is
  knowable.
- **Connect autoload signals to a method, not a lambda.** Godot drops a
  connection after your code frees the bound object, but a lambda is bound to
  nothing. It merely captures `self`. A scene node's lambda connected to an
  autoload signal outlives the scene and fails on the next emit with
  "Lambda capture at index 0 was freed". Connect a METHOD and disconnect
  it in `_exit_tree()`.
- The same holds for any lambda that captures a thing that can die first
  (a tween callback that captures a sprite). Bind an id and look it up.
  One project hit this twice after Kombucha wrote this rule. The second
  time it showed as 738 engine errors under a green check. That is why the
  gates now count every `ERROR:` line.
- **A code-built UI tree must theme itself.** A Control under a bare
  CanvasLayer inherits no theme and renders Godot's translucent defaults.
  The game then bleeds through its panels. It looks like a layout bug, and
  the fix is one missing `theme = UITheme.get_theme()` in the subtree's own
  `_ready()`.
- **`Image.load()` on a `res://` path fails the suite.** The engine logs
  "loaded resource as image file, this will not work on export", and the
  gates count that as an engine error. Decode from bytes instead:
  `FileAccess.get_file_as_bytes` plus `Image.load_png_from_buffer`.
- **Engine tooltips are unreliable under WSLg** (they depend on focus and
  pointer chatter). `assert_tooltip` reads the tooltip text instead of
  waiting for the popup. A game that draws hints in its own overlay
  asserts on that overlay.

### The tooling: one text for every project

The sections below are `docs/godot-tooling.md`, an owned file every synced
project imports here. Edit that file, never a project's copy.

@docs/godot-tooling.md

<!-- kombucha-only -->
### Kombucha-only checks

`tools/selftest.sh` runs against scratch copies. It proves the runner's
guards: a broken test file is red, shards agree with one process, a named run
has a private `user://`, and the default shard count follows `nproc`. It also
proves the sync script: it stamps, seeds, sets the execute bit, reports drift
and refuses a dirty source. `tools/check.local.sh` here is the fixture's own
gate. It runs the self-test, plus the manifest check, the driver skeleton
both ways, and the ordered scenario pair. A game project has nothing to
prove there.
<!-- /kombucha-only -->

## Interpretation notes (decided + tested)

This list records each ambiguity that came up, how we decided it, and which
test pins the decision. It exists so nobody argues the case again. Add to it
whenever you make a judgment call that the code alone would not explain.

- Binding a key already taken in the same conflict group is *refused*, not
  stolen (`test_conflict_within_group_is_refused_not_stolen`).
- Bus volume 0 means *muted*. No code may store `-inf` dB
  (`test_zero_is_mute_not_negative_infinity`).
- A missing UI sound, translation, or asset is silence/fallback, never an
  error (`test_ui_event_with_no_sound_is_silence`).
- A catalog entry that names a `pad` button lands it in the SECONDARY slot.
  Without one, the secondary stays unbound
  (`test_a_catalog_pad_button_lands_in_the_secondary_slot`,
  `test_secondary_slot_defaults_unbound_without_a_pad_entry`).
- The save loader refuses a save from a newer schema with a reason, and
  never migrates it downward
  (`test_a_save_from_the_future_is_refused_with_a_reason`).
- A saved dictionary equals itself coming back, keys in insertion order
  (`test_a_saved_dictionary_equals_itself_key_order_included`).
