# Plan: the Template kit pass

Status: landed 2026-09-05 on Template branch `plans/2026-09-05` (tiers A-E, five commits, each green) and the fixture refreshed. The `--kit` report mode and sibling adoption remain. Companion to
`2026-09-05-absorb-sibling-tooling.md` (tooling) and the record of the kit
findings that plan defers. Source: the sibling survey of 2026-09-05
(`docs/research/2026-09-05-sibling-project-lessons.md` and the code-shape
reads cited inline as project:file).

## Context

**Kit** is the code that ships inside a game: the autoloads, `scripts/util`,
`scripts/ui`, the boot scene and `project.godot`. It is not in Microbiome's
tooling manifest and never will be: every game customises these files in
place and has no extension seam for them, so a wholesale sync would destroy
work. Kit improvements therefore travel the older way: they land in the
**Template**, new projects inherit them, and existing projects cherry-pick.

The survey found kit fixes that two or more projects made independently,
which means the Template is shipping known bugs to every new project. This
plan lands them in the Template, ordered by damage prevented per line, and
refreshes Microbiome's fixture from the Template afterwards so the tooling
keeps being proven against current kit.

Where the work happens: in the Template repo, on its own check, one commit
per tier. Microbiome's fixture is refreshed at the end of each tier
(`rsync` of the kit directories, then Microbiome's full check), because two
items below add redirectable state that the harness sandbox must know
about, and that is a tooling change.

## Tier A: bugs and one-line seams (highest damage per line)

| Item | Source | Change |
|---|---|---|
| **Saved dictionaries come back unequal to themselves** | NavalWar `save_manager.gd:73`, FrogGame `:63-65` (independent) | `JSON.stringify(data, "\t", false)`. Godot sorts keys by default and Dictionary equality is order-sensitive. Test: save then load a two-key dictionary in reverse insertion order, assert equality. |
| Load failure carries a reason | procedural-factory `save_manager.gd:32,61` | `last_load_problem: String`, `ERR_INVALID_DATA` on bad payload. Console `load` prints it. Test: corrupt file gives a non-empty reason. |
| `config/version` | FrogGame, NavalWar | `[application] config/version="0.1.0"`; saves stamp it. |
| Stretch aspect `expand` | 7 of 10 projects; Template's `keep` is the outlier | `window/stretch/aspect="expand"`. Prerequisite for the scale policy in tier C and the Steam Deck 16:10 check. Scenario at `SHOOT_RESOLUTION=1280x800` shooting the pause menu proves nothing letterboxes. |
| DataMerger `$delete` | FrogGame `data_merger.gd:16,52`, NavalWar `:17,53` (independent) | a bare `"$delete"` value drops the key in PATCH mode. Test alongside the existing `$replace` / `$remove` tests. |
| `L10n.data_text(type, id, field, fallback)` | NavalWar, FrogGame (identical) | two lines over `key()` + `tr_or_fallback()`. Test: untranslated key returns the fallback. |
| `EventBus.settings_changed` | NavalWar `event_bus.gd:17` | one signal every settings setter emits; listeners connect a **method**, never a lambda (rule in tier E). VolumeSliders and Keybinds emit it. |
| AudioManager `save_debounce` + `flush_volumes()` | FrogGame `audio_manager.gd:29-32,161-181` | verbatim (+18/-4). `GameManager.quit_game()` and the close-request notification flush before saving. Tests from FrogGame `test_audio_manager.gd`: debounced then written, quit inside the debounce still writes, second flush is a no-op; `after_each` flushes before restoring `config_path` (order is load-bearing). |
| Friendly key names | NavalWar `keybinds.gd:163` | `QuoteLeft` → `` ` ``, `Escape` → `Esc`, etc., in `describe()`. |
| Volume slider labels through L10n | NavalWar `volume_sliders.gd:17` | `ui.bus_master` etc. with the bus name as fallback; rows added to `game.csv`. |

## Tier B: save and data seams

- **`save_provider` group** (NavalWar `save_manager.gd:31-52`, FrogGame
  `:25-56`, converged): nodes in the group answer `save_key()`,
  `save_payload()`, `restore_payload()`; SaveManager reaches them by group
  and `has_method` (an autoload must not name a scene class). Fills the
  Template's empty `collect_save_data` / `apply_save_data` stubs. Take
  FrogGame's "skip empty payloads" detail. Test: a provider node in a test
  scene round-trips; a provider with an empty payload writes no key.
- **Slot metadata and listing** (NavalWar `:16,20,83,91,111`): `SLOT_COUNT`,
  a meta key stamping `saved_at`, `slot` and `config/version` at write time,
  `slot_meta(slot)`, `list_slots()` (numbered slots always listed, hand-named
  saves appended). Thumbnails (`write_thumbnail`/`thumbnail`, PNG beside the
  save, decoded from bytes) are optional; take them only if a fixture screen
  will show one.
- **SaveCompat skeleton** (FrogGame `save_compat.gd`, 82 lines; NavalWar's
  is heavier): schema-stamped payloads, ordered `_to_N` migration steps,
  refuse a save from the future, return `{ok, error, payload}`. The
  missing-mod refusal stays behind an optional hook. Tests: forward
  migration chain, future version refused with a reason.
- **`JsonValue.truthy(value, fallback)`** (NavalWar `json_value.gd`, 50
  lines): `bool()` refuses a String and `String()` refuses a bool, and an
  absent JSON field arrives as `false`. One place answers "is this field
  set". Test the four shapes (absent, bool, string, number).
- **`VersionUtil`** (byte-identical in NavalWar and FrogGame, 26 lines):
  dotted compare, `at_least`, malformed compares low instead of crashing a
  load path.
- **`BBCode.escape()` / `sanitise(text, limit)`** (NavalWar `bbcode.gd`, 38
  lines): any string interpolated into a `bbcode_enabled` label is live
  markup; sanitise on decode, not on input. Used by the save-name and
  bug-report paths in the Template.
- **`RuntimeTextures`** (Monmon, 36 lines): `res://` through the import
  pipeline, `user://` decoded at runtime, missing → one shared magenta
  placeholder. This is the executable form of "missing assets degrade,
  never error" for the mod case.
- **`ContentDB.load_layered(file)`** (Digit `content_db.gd`, 55 lines):
  `res://data/<f>` base plus every `user://mods/*/data/<f>` PATCH-merged in
  sorted order, `mods_root` a redirectable static like `save_root`. The
  lightest of the four mod-layering designs. **Tooling coupling:** the
  harness's core `_sandbox()` must redirect `mods_root` to scratch, so this
  item ships with a Microbiome commit.

## Tier C: UI kit

- **Focus ring** (NavalWar `ui_theme.gd:74` and `:50-53`): a `focus`
  stylebox on Button, OptionButton, CheckButton, CheckBox, HSlider,
  LineEdit, SpinBox, TextEdit. Keyboard and pad navigation are invisible
  without it. Scenario: `press ui_focus_next` twice on the pause menu,
  1:1 crop of the focused button.
- **`UIFocus.first(root)`** (NavalWar `ui_focus.gd`, 47 lines): depth-first
  focus of the first focusable Control, deferred, skipping disabled and
  queued-for-deletion nodes. PauseMenu calls it in `open()`. Rule: a menu
  that opens without grabbing focus is unreachable by pad.
- **`UITheme.pop_in(control)`** (Orbit `ui_theme.gd:75-95`): fade plus
  94%→100% settle, deferred **by instance id** because the control can be
  freed before the deferred call lands, `TWEEN_PAUSE_PROCESS` so it works
  while paused, fade-only fallback before layout settles. Test: freeing the
  control before the deferred call does not error (expected-error tracking
  off).
- **`UiScaleRoot` rework** (FrogGame `ui_scale_root.gd`): `extends Node`
  driving its parent in place (no reparenting, so `$Path` in screen scripts
  keeps working), `attach()`, `attach_if_outermost()` (returns null when not
  directly under a CanvasLayer or viewport, which stops double-scaling when
  a menu is embedded in one scene and standalone in another), `factor()`,
  and `static fit_for(viewport, reference)` so the ramp is unit-testable
  without a window. Tests for `fit_for` at three window sizes; the
  existing sharpness scenario (1:1 crop) must still pass.
- **Integer scale policy** (FrogGame `game_manager.gd:47,64`, NavalWar
  `:70+`, verbatim-identical): above design size, divide the automatic
  canvas scale to its floor via `content_scale_factor` so pixel art stays
  1:1 or 2:1 and the viewport expands (Godot's own `STRETCH_INTEGER`
  letterboxes instead; measured). Below design size keep the fractional
  shrink or a Steam Deck crops. Requires tier A's `expand`. Scenario at two
  resolutions asserting the factor through a `state` key.
- Optional, only if a fixture screen needs them: Zoofle's `OVERLAY_Z`
  constant (`z_index` beats tree order; paused objects rendered over the
  pause menu), FrogGame's `transitions_enabled` escape hatch for the
  harness, `user_zoom` with ctrl+wheel.

## Tier D: controller support

The single biggest generic capability any sibling has that the Template
lacks. All from NavalWar; no `project.godot` input-map change is needed.

- **`pad_router.gd`** (105 lines, pure): deadzone, dominant-axis quantise,
  0.35 s / 0.12 s held-direction echo clocks, device gating. Tests with
  synthetic axis values and a fake clock; no hardware.
- **`Pads` autoload** (115 lines): strips Godot's built-in joypad events off
  `ui_*` at startup and re-synthesises them through the router, so focus
  navigation, menus and the harness's `press` share one vocabulary;
  `process_mode = ALWAYS`; `using_pad` for hint strips. Registered after
  Keybinds.
- **Keybinds pad slots** (`keybinds.gd:171-176,180,205-212,243,263-269`):
  `"pad": JOY_BUTTON_*` in the `ACTIONS` catalog lands in slot 2, `joy:<n>`
  encode/decode in settings.cfg, xbox-style `PAD_NAMES`, `describe_event`
  for `InputEventJoypadButton`, same conflict refusal as keys. Tests
  mirror the existing key-binding tests for the pad slot.
- **Rules** (NavalWar CLAUDE.md 1803): a menu that opens without focus is
  unreachable by pad; keyboard Escape is both `ui_cancel` and `pause`, so a
  cancel path must skip events that also match pause; scenario `press
  <action>` fires the exact events the router fires, so pad play scripts
  need no new harness commands. Scenario: navigate and resume the pause
  menu with `press ui_down`, `press ui_accept` only.
- **Harness sandbox** must reset `Pads.router` and `using_pad` (NavalWar's
  `_sandbox` does). Tooling coupling: ships with a Microbiome commit.

## Tier E: rules for the Template's CLAUDE.md (rule plus what breaks)

Data and serialisation:

- `rng.state` is 64-bit and JSON numbers are doubles: store it as a
  **string** or a resumed run rolls different numbers (NavalWar, FrogGame).
- `JSON.stringify` sorts keys by default; pass `false` (tier A).
- JSON has no int type: `500` comes back `500.0`; normalise on restore, and
  restored dictionaries must equal fresh ones, key order included, through
  one normaliser (FrogGame 543).
- `String()` refuses a bool and `bool()` refuses a String; an absent field
  arrives as `false`, the common case. Use `str()` and `JsonValue.truthy()`;
  never a constructor cast on a value that came out of JSON (NavalWar 1603,
  1624).
- `Image.load()` on a `res://` path logs an export warning and fails the
  suite; decode from bytes (FrogGame 344, NavalWar 619).
- A translation key must not be a position: `dialogue.<id>-<n>` silently
  repointed every translation below an inserted line, in every language
  (NavalWar 2018).
- Text somebody else wrote is markup until escaped; sanitise on decode
  because the sender's client is the attacker's client, so a LineEdit
  `max_length` is not a limit (NavalWar 1994).

Engine and lifecycle (the ones not already taken by the tooling plan):

- Settings reach live systems through one signal, one seam each; listeners
  are methods; panels re-sync every control in `open()` (NavalWar 764).
- Window scaling snaps to integers above design size; Godot's
  `STRETCH_INTEGER` letterboxes instead, measured (NavalWar 130, FrogGame
  376).
- `@tool` previews: preview children without an `owner`; nothing on a
  `@tool` path may touch an autoload; `has_method()` is true for a
  placeholder instance, gate on `Engine.is_editor_hint()`; `_ready` re-runs
  on every script reload (Monmon 456). Include only when the Template
  gains a `@tool` script.
- Monmon's linter principle, for any future data linter: it has no rules of
  its own, it runs the real loaders and reports what they said, so linter
  and game cannot disagree.

## Recorded, not planned

- NavalWar `telemetry.gd` (local-first JSONL, opt-out): a product decision.
- Zoofle Android CI with a cached, never-committed debug keystore: take it
  the day a Template project targets Android.
- FrogGame `data/schema.json` + `gen_modding_docs.py --check` (docs
  generated from the schema, staleness gate in CI): take it with the first
  Template project that has a data schema.
- FrogGame `ui_from_render.py` (render-to-tintable-PNG, stdlib), Zoofle
  `make_android_icons.gd` and `square_sprites.gd` (animation-strip
  detection), NavalWar `steam_upload.sh`: generic developer scripts, listed
  in the survey, worth a `tools/extras/` in the Template if a second project
  needs any of them.

## How siblings adopt kit changes

There is no sync for kit and there should not be one. Add a `--kit` mode to
`tools/sync-tooling.sh` that only **reports** which kit files differ between
the Template and a project (autoloads, util, ui, project.godot keys), with
the Template commit that last touched each, so a project can cherry-pick
with `git diff` rather than rediscover. Projects that already have their
own version of an item (NavalWar has all of tier D) are the source, not the
target, and the report should say so.

## Order and coupling

A, then B, C, D, E. Each tier is one Template commit with green
`tools/check.sh`, then a fixture refresh in Microbiome (`rsync` of
`scripts/autoloads scripts/util scripts/ui scenes localization` plus the
`project.godot` keys, then Microbiome's full check). Two tiers (B's
`ContentDB.mods_root`, D's `Pads`) need the harness sandbox extended in
Microbiome first, synced to the Template, and only then the kit change, or
the Template's own scenarios leak state between runs.

## Verification

- Template `tools/check.sh` green per tier; new GUT tests per item as
  listed; the gate-must-fail rule applied to every new assertion (revert
  the fix, watch red, restore).
- Scenarios: pause menu at 1280x800 with `expand` (no letterbox), focus ring
  1:1 crop, pad-only navigation, scale factor at two resolutions.
- Microbiome full check green after each fixture refresh.
- `tools/sync-tooling.sh <project> --kit` lists the expected drift for
  NavalWar (source of tier D) and Digit (source of `ContentDB`).
