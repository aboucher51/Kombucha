# CLAUDE.md

<!-- kombucha-only -->
## What this repo is

Kombucha is the workshop for the Godot-to-Claude workflow itself: the
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
- **This repo is also the Claude Code plugin** (`.claude-plugin/`,
  `skills/`): a user installs it from the marketplace and the skills
  find the tooling in the plugin checkout. Nothing under `tools/`,
  `skills/` or the docs may name a path on one machine; `GODOT_TOOLING`
  is the override (a clone with history, for backports and the kit
  report), `$HOME/godot-projects/` the convention.
- **The tooling is owned here and copied outward.** `tools/tooling-manifest.txt`
  lists the paths every project carries as a copy; `tools/sync-tooling.sh`
  (the `/sync-godot-tooling` skill) refreshes them and stamps
  `tools/TOOLING_VERSION`. A project never edits an owned file: it extends
  through `scripts/dev/dev_hooks.gd`, `data/console_commands.project.json`
  and `tools/check.local.sh`, which a sync never touches. Seeds for those
  live in `tools/seeds/`. Without this split, nine projects each carried a
  diverged harness and the same bug was fixed four times.
- **This repo is also the scaffold.** `tools/new-project.sh` copies the
  fixture minus Kombucha-only paths and strips the sections fenced
  `<!-- kombucha-only -->` from CLAUDE.md and LICENSES.md, so the kit,
  the contract and the conventions have ONE source. A kit improvement
  made in a game comes back here with `/update-kombucha`; projects
  cherry-pick kit files (`sync-tooling.sh --kit` says what is newer).
- **Lessons flow two ways.** Findings go in `docs/research/`; rules earn a
  place below as *the rule plus what breaks without it*, and every new
  project inherits them. Read `docs/roadmap.md` for the current order.
  A project's own reports arrive under `docs/feedback/<project>/` on a
  `feedback/` branch (`docs/feedback/README.md`): the project reports
  what it hit, this repo assesses it and appends the disposition. A
  project never reads this repo to write one.
<!-- /kombucha-only -->

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
conventions below are the kit's; each transferred from a project where it
had already cost a debugging pass when violated. They are maintained in
Kombucha and every scaffolded project starts with them; as a project grows
its own load-bearing conventions, record them here the same way. State
every rule *and* what breaks without it.

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

`SaveManager.save_root`, `config_path` and `mods_root` are variables so
tests and the screenshot harness can point the whole save system (and
mod loading) at scratch storage and restore it afterwards. Route any new
persistence through them — a suite run must never edit the player's real
saves, settings or mods.

- **Saves are written by the `save_provider` group.** Any node answering
  `save_key()`, `save_payload()` and `restore_payload(payload)` gets its
  slice in the slot; SaveManager reaches it by group and `has_method`,
  because an autoload must not name a scene class. An empty payload writes
  no key. Two projects converged on this seam before it was shared.
- **A save is stamped and migrated** (`SaveCompat`): schema, game version,
  optional mod ids. A change to what a provider writes bumps `SCHEMA`,
  adds a `_to_N` step and freezes a golden old-format fixture in a test
  that must load forever. A save from the future is refused with a
  reason, never guessed at; a save needing a missing mod is refused BY
  NAME. `SaveManager.last_load_problem` carries the reason for a UI.
- **JSON quietly breaks three things.** `JSON.stringify` sorts keys by
  default and Dictionary equality is order-sensitive, so a saved
  dictionary came back unequal to itself (pass `false`; SaveManager does).
  JSON has no int type: `500` comes back `500.0`, so restored
  dictionaries go through one normaliser and a test compares against
  floats. A 64-bit `rng.state` stored as a number is silently truncated
  to a double: store it as a string.
- **Restored equals fresh: one normaliser per record shape.** Every path
  that builds a record — fresh, from a template, from a save — goes
  through ONE function (`SimUnit.from_dict`, `Merit.normalise`) that
  fixes key ORDER and TYPES, and one test per shape asserts
  `restore(to_dict()) == to_dict()`. Migrations then reshape one field
  and the normaliser does the rest, and a golden fixture per schema pins
  the chain. Eight schema bumps in one afternoon held together on this;
  without it every migration re-derives what a record looks like.
- **Slots carry meta** (`saved_at`, `slot`, `version`, whatever the caller
  adds) at the top level, so `slot_meta()` and `list_slots()` describe a
  slot without parsing the payloads; numbered slots always list, anything
  else on disk is appended, because a save the listing does not mention is
  a save you cannot find again.
- **Every settings write emits `EventBus.settings_changed`**; live systems
  re-apply from that one seam, and listeners connect a METHOD, never a
  lambda (below).
- **A settings read passes a default.** `ConfigFile.get_value` with no
  default logs an ENGINE ERROR for a missing key, so the first setting
  added after the file existed errs on every boot; `AudioManager` reads
  volumes with a `-1.0` sentinel and skips on it.

### Reading JSON values: `str()` and `JsonValue.truthy()`

`String()` refuses a bool and `bool()` refuses a String, and an absent JSON
field arrives as `false`, the common case, so a constructor cast on a
value that came out of JSON raises on ordinary data. Use `str()` for
Variant-to-text and `JsonValue.truthy(value, fallback)` for "is this field
set" (`typed_truthy` for a form field where the word "false" means false).
`ContentDB.load_layered(file)` layers `user://mods/*/data/<file>` over
`res://data/<file>` with `DataMerger` PATCH semantics in sorted order, and a
missing file is the normal case. Text a PERSON wrote is markup until
`BBCode.escape()`d, and `sanitise()` happens on decode, not on input: the
sender's client is the attacker's client, so a LineEdit `max_length` is
not a limit.

### Input is action-based, and Keybinds owns the catalog

Read input with `Input.get_axis()` / `is_action_just_pressed()` — never
compare `event.keycode` against a constant, which makes the control
unrebindable. Rebindable actions are declared in ONE place: the `ACTIONS`
table in `scripts/autoloads/keybinds.gd` (action, default key, optional
`pad` button, label, conflict group). Add new actions there, not piecemeal
beside their consumers.

Rules Keybinds enforces, each paid for elsewhere:

- **Conflicts are refused, not stolen** — `set_binding()` returns `false`
  when the key belongs to another action in the same group; `holder_of()`
  names the owner so UI can explain the refusal.
- **Pollers must check `Keybinds.capturing`** — `Input.get_vector()` and
  friends never see events a rebind-capture UI consumes, so pressing W to
  rebind it also pans the camera unless polling code checks the flag.
- Bindings store as legible `key:F5` / `mouse:3` / `joy:6` /
  `axis:1:-` strings in settings.cfg, so a support answer can say "put
  key:F5 back". **Half an axis is a binding like a key**: a stick pushed
  up rebinds and conflicts the same way, or every pad-aware project grows
  its own axis table beside Keybinds.
- **The rebinding rules live in Keybinds, not in the settings screen**:
  `begin_capture(action, slot)`, then raw events into `capture_event()`
  from the screen's `_input` (a modifier alone waits, the wheel is
  ignored, Escape and a click away cancel, Backspace clears, a stick
  counts past 0.5, a taken key is refused naming the holder), or
  `capture_text("F7" | "mouse:3" | "axis:0:-" | "escape" | "clear")` from
  a test or a scenario; `capture_ended` tells the row to redraw. The
  screen only displays. One project rebuilt these rules in 500 lines of
  UI before the seam existed.

**Controllers: one router, `ui_*` everywhere, focus is the contract.** The
`Pads` autoload is the ONE reader of raw joypad input: it strips Godot's
built-in joypad events off `ui_*` at startup and re-synthesises them
through `PadRouter` (deadzone, dominant axis, held-direction repeat), so
focus navigation, every menu and the harness's `press` share one
vocabulary, and a scenario written with `press ui_down` IS the pad path.
Consequences: a menu that opens without grabbing focus is unreachable by
pad (`UIFocus.first()` in `open()`); keyboard Escape is BOTH `ui_cancel`
and `pause`, so a cancel path must skip events that also match pause;
gating which pad may act is opt-in through the `pad_gate` group.

### UI kit rules

- **The focus ring is the theme's** (`UITheme.focus_ring()` on every
  focusable class): keyboard and pad navigation are invisible without it.
  An HSlider has no focus stylebox in Godot, so the ring shows on buttons.
- **Chrome motion goes on `offset_transform_*`, never `position` or
  `scale`.** A container lays its children out every frame, and a tween
  on a laid-out property fights it (a toast slid to the left edge because
  its rest position was captured before the stack had placed it). The
  offset transform is what the engine draws, not what the layout reads;
  `pop_in` is the reference. Also: `icon_alignment = CENTER` draws the
  icon UNDER centred text, not beside it.
- **`String.capitalize()` title-cases every word**, so a refusal from a
  sim ("needs troupe level 8") becomes "Needs Troupe Level 8" in a
  tooltip. Sentence text wants its first letter raised and nothing else.
- **An empty `Label` still takes a line in a `VBoxContainer`**: add the
  row only when there is text, or a locked entry leaves a gap where its
  explanation would be.
- **A `RichTextLabel` gives ONE word a tooltip** with
  `[hint=explanation with spaces]word[/hint]` — the way a card names a
  thing and explains it on hover without a second control.
- **Panels arrive with `UITheme.pop_in()`**, deferred by instance id so a
  control freed before the deferred call lands is not an error, and
  pause-mode process so it runs while the tree is paused.
- **`UiScaleRoot` drives its parent in place** (`attach()` /
  `attach_if_outermost()`): no reparenting, so `$Path` in the screen's
  script keeps working; attaching twice scales twice, which is what
  `attach_if_outermost` refuses when the screen is embedded.
- **Window scaling snaps to integers above design size** (`GameManager`
  `_apply_scale_policy`, `snapped_factor`): pixel art stays 1:1 or 2:1
  and the viewport expands (aspect `expand`, the kit default, which
  seven of ten projects had switched to). Godot's own `STRETCH_INTEGER`
  letterboxes instead, measured. Below design size keep the fractional
  shrink or a Steam Deck crops.
- **A translation key must not be a position.** `dialogue.<id>-<n>`
  addressed a line by index, so inserting a line silently repointed every
  translation below it, in every language. Anything a translator keys off
  needs an identity that survives a reorder.

### Missing assets degrade, never error

Absent art or translation strings must fall back gracefully. A missing PNG
or untranslated key is a normal state, not an exception. For strings that
may be untranslated, use `L10n.tr_or_fallback(key, fallback)`
(`scripts/util/l10n.gd`); translations live in `localization/game.csv` —
re-import after editing it. **The localization test is the contract:**
`tests/test_localization.gd` scans `scripts/` for every `ui.*` key and fails
when the CSV lacks a row, so a new string is a key plus a row in the same
commit, never a bare literal. The `xa` column is the pseudo-locale
(`tools/make_pseudo_locale.py`, re-run after adding strings): every string
comes out accented, bracketed and ~35% longer, so plain English in
`scenarios/pseudo_locale.txt`'s shot is a HARDCODED string the scanner
could not see, and a layout that only fits English breaks visibly. A
language dropdown must filter `xa` out; the console's `locale xa` reaches
it. The same rule shapes BugReport
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
- **A deferred `grab_focus` is deferred BY INSTANCE ID**, through
  `UIFocus.first()` or `UIFocus.grab(control)`. A bare
  `control.grab_focus.call_deferred()` lands after the scene it belongs
  to is gone (the harness returns to the boot scene between scenarios)
  and logs `Condition "!is_inside_tree()" is true` — an engine error
  under a green batch, found twice, eight call sites the second time.
- **A node reached by group must skip nodes on their way out.** A
  `queue_free`'d node stays in its group, visible, until the frame ends:
  a toast host picked by `get_first_node_in_group` found the previous
  test's freed host, and "no host is no error" found a host. Every group
  loop in the kit skips `is_queued_for_deletion()`, and a test asserting
  absence awaits one frame first.
- **A child's `_ready()` runs before its parent's, and groups are not filled
  yet.** A pause menu asked in `_ready()` whether a match was running,
  always got no, and its Save button had never once appeared in a running
  game; nothing asserted it. Ask in `open()`, when the answer is knowable.
- **Signals from an autoload need a method, not a lambda.** Godot drops a
  connection whose bound object was freed, but a lambda is bound to
  nothing; it merely captures `self`. A scene node's lambda connected to an
  autoload signal outlives the scene and fails on the next emit with
  "Lambda capture at index 0 was freed". Connect a METHOD and disconnect
  it in `_exit_tree()`. Same for any lambda capturing a thing that can
  die first (a tween callback capturing a sprite): bind an id and look
  it up. Found twice in one project after this rule was written: the
  second time as 738 engine errors under a green check, which is why the
  gates now count every `ERROR:` line.
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

### The tooling: one text for every project

The sections below are `docs/godot-tooling.md`, an owned file every synced
project imports here. Edit that file, never a project's copy.

@docs/godot-tooling.md

<!-- kombucha-only -->
### Kombucha-only checks

`tools/selftest.sh` proves the runner's guards (a broken test file is red,
shards agree with one process) and the sync script (stamps, seeds, sets
the execute bit, reports drift, refuses a dirty source) against scratch
copies; `tools/check.local.sh` here is the fixture's own gate and runs it,
plus the manifest check, the driver skeleton both ways, and the ordered
scenario pair. A game project has nothing to prove there.
<!-- /kombucha-only -->

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
- A catalog entry that names a `pad` button lands it in the SECONDARY slot;
  without one the secondary stays unbound
  (`test_a_catalog_pad_button_lands_in_the_secondary_slot`,
  `test_secondary_slot_defaults_unbound_without_a_pad_entry`).
- A save from a newer schema is refused with a reason, never migrated
  downward (`test_a_save_from_the_future_is_refused_with_a_reason`).
- A saved dictionary equals itself coming back, keys in insertion order
  (`test_a_saved_dictionary_equals_itself_key_order_included`).
