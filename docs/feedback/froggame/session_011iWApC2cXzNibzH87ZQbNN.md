# Feedback from FrogGame — session 011iWApC2cXzNibzH87ZQbNN

Source project: `~/godot-projects/FrogGame`, on tooling `33c70aa`
(synced 2026-09-06). One long session: two UX passes, a rebinding UI, a
settings sheet of some twenty options, and a six-step build of the
project's UX philosophy (icons, toasts, a battle layout, dropdowns, sound
families, a pad cursor). Everything below is a lesson that cost a
debugging pass there and would cost the next project the same one. Each
says what to change in Kombucha and what breaks without it. The FrogGame
files named are the reference implementations.

## 1. The harness's click drops in a two-shard batch (tooling bug)

`screenshot_harness.gd` `_click_point` pushes the press, awaits a frame,
then pushes the release. In a batch of two processes, the other shard
warps the ONE real cursor across this window during that frame; the
button sees the pointer leave mid-press and does not emit `pressed` on
the release. The symptom was always "the second click of a confirm
button fails only in the batch and passes alone", in five different
scenarios over a week, and it was written off as load each time.

Fix: push both events back to back, no await between them, then settle.
FrogGame carries the fix as a `click` override in
`dev_hooks.scenario_command` (`_click_same_frame`) that keeps the
harness's lookup, its layout-settle loop and its cursor warp; it should
be deleted there the day the harness has it.

## 2. The sandbox must reset what was APPLIED, not only the file

`_sandbox` redirects the settings file, but state applied from an
earlier scenario's settings survives the scene reload: a frame cap
(`Engine.max_fps`), vsync, a window mode, a rebuilt theme palette, a
save slot, a UI scale. One scenario that set the UI size to 150% and a
"Wait asks first" option poisoned six scenarios after it, and the
failures pointed at clicks, not at settings.

Two changes: (a) the kit gets one `GameSettings.reset_to_defaults(tree)`
that writes every default AND re-applies engine state through the same
path a boot uses, and `_sandbox` calls it through the project hook;
(b) the harness's docs say it in one line — anything applied from a
setting is global state, and the scratch settings file lives for the
whole process, not per scenario. FrogGame:
`scripts/ui/game_settings.gd` `reset_to_defaults`, called from
`dev_hooks.sandbox()`.

## 3. A missing ConfigFile key with no default logs an engine error

`AudioManager.apply_saved_volumes` reads
`SaveManager.get_setting(SECTION, bus_name)` and tests for null. The
engine logs an error for a missing key when no default is given, so the
first bus added after the settings file existed ("Ambience") produced an
error on every boot. Use a sentinel default (`-1.0`) and skip on it.
Kit change, two lines.

## 4. A three-screen check in `check.local.sh`

FrogGame names three target resolutions (Steam Deck 1280×800, 1080p,
ultrawide 3440×1440). Its `check.local.sh` runs one zone scenario at each
with `SHOOT_RESOLUTION`, and a console command `window` prints the size
the window manager actually granted; a refused size (WSLg gives
1720×720 for 3440×1440) is reported as `--` with the size it got, never
as a silent pass. The template's `check.local.sh` should ship this as a
commented section, and the harness should gain `window` as a built-in
(it is three lines). Found: a HUD bar that fit at 1280 was off the right
edge the moment a button was added, and only a named size caught it.

## 5. `assert_zone` as a harness built-in

`assert_zone <Node> <top|bottom|left|right>`: the named visible
Control's whole rect lies in that zone of the viewport (top = upper
half, bottom = lower third, left and right = that half). It is what a
layout rule needs to be enforced by a scenario rather than by eye. In
FrogGame's `dev_hooks.scenario_command`; belongs beside
`assert_onscreen`.

## 6. `select` for dropdowns

A click on an `OptionButton` only opens its popup, so a scenario cannot
pick from a dropdown by clicking. `select <Dropdown> <id-or-label>`
selects by the item's metadata id then by its text, emits
`item_selected`, and refuses a disabled item naming its tooltip;
`select_assert` reads it back. Any project that follows "a value is a
dropdown" needs it. In FrogGame's hooks; belongs in the harness.

## 7. Sound families in the kit's AudioManager

`ui_sounds` values as lists picked at random and never the same index
twice in a row (`pick(kind)` returns the stream, for tests); a single
stream still accepted; an unknown kind silence with no error; a `none`
kind that binds silently so a confirm button can say `select` when it
arms and `confirm` when it fires without a click on top. Small,
backwards compatible; every project with more than one click sound
wants it. FrogGame: `scripts/autoloads/audio_manager.gd` `pick`,
`scripts/ui/ui_sounds.gd` for loading a family from mod data.

## 8. Joypad in Keybinds, all the way

FrogGame's Keybinds copy gained: `pad:<button>` and `axis:<n>:<+|->`
encodings so a stick half is a binding like a key; a `pad` default per
action that fills the SECOND slot; a describer with readable names ("A",
"LT", "Left stick ←"); conflict refusal that treats a pad binding like a
key; and a settings capture (`_input`, before the GUI) that hears a
button press or a stick pushed past 0.5. Plus the rules the capture
needed: a modifier alone waits, the wheel is ignored, Escape and a click
away cancel, Backspace clears, a taken key is refused and the holder
named, `Keybinds.capturing` raised for pollers. The kit has the
catalogue and the pad-button half; the axis half, the capture screen and
the seams (`begin_capture`, `capture_text("F7" | "mouse:3" | "pad:0" |
"axis:0:-" | "escape" | "clear")`, console `settings_capture` /
`settings_key` / `settings_assert`) are what the next project will
rebuild. FrogGame: `scripts/ui/settings_panel.gd`, `tests/test_rebinding.gd`,
`scenarios/rebinding.txt`.

## 9. An autoload signal wants a METHOD, disconnected on exit

Found twice. A pause menu connected a lambda capturing a label to
`Keybinds.bindings_changed`; the autoload outlives the menu, the next
scene's key reset fired it on a freed label, and every later scenario
logged "Lambda capture was freed" — 738 engine errors under an all-green
check. Connect a method, disconnect in `_exit_tree`. One paragraph for
the kit's CLAUDE.md, next to the existing autoload rules.

## 10. Chrome motion on `offset_transform_*`, never `position` or `scale`

Godot 4.7's visual-only offset transform is the right target for UI
motion: a container lays its children out every frame, and a tween on
`position` fights it (the first toast slid to the left edge because its
rest position was captured before the stack had placed it). Also worth
one line: `icon_alignment = CENTER` draws the icon UNDER centred text,
not beside it; an icon goes at the left of its word and a very wide
button shrinks to a centred pill. FrogGame: `scripts/ui/ui_motion.gd`,
`scripts/ui/ui_button.gd`.

## 11. Patterns worth a stripped example, not a file

- **A verb helper**: one call sets a button's icon (from a mod
  catalogue, tinted through the theme's icon colours), text, tooltip
  and click sound, so the same picture appears wherever the verb does
  and a missing icon is the word alone. `UiButton.make / confirm`.
- **One toast node per screen, reached by group**: `say(text, kind)`,
  kinds refuse / ack / event, stacking to five, holding a data-driven
  time, a `newest_name` so the harness can find the latest plate
  without breaking its uniqueness rule. `Toasts`.
- **One focus stylebox for every control** that is also what
  code-built selections use, so the pad's cursor and "selected" are one
  signal. A brighter frame alone did not read in a 1:1 crop; a ring that
  is also BIGGER did.
- **A motion vocabulary with a kill switch**: `UiMotion.enabled` is what
  the sandbox turns off, so a shot a few frames after a click is never
  mid-pop and every existing shot stays deterministic; `motion on` is
  the console's way back.

## 12. Two harness observations, no change proposed

- `shoot.sh` wipes `shots/` on every run, so a shot from an earlier
  single-scenario run is gone after the next; reading a shot has to
  follow the run that made it. Fine once known; not written anywhere.
- The `.godot/shoot-timings` file is overwritten by a single-scenario
  run, which re-deals the next batch; a flake that "only shows after a
  new scenario re-dealt the shards" is partly that.

## What not to port

The UX philosophy's rules are FrogGame's decisions (three target
screens, information top and left, the action menu floating by the
frog). The SHAPE of a rule — what we do, why, what breaks without it,
how it is checked — is the same shape as CLAUDE.md's conventions and is
worth copying as a template for a `docs/ux-philosophy.md` in Template.

## Disposition (Kombucha, 2026-09-06)

Assessed and acted on in one commit; FrogGame's overrides listed under
"delete on sync" can go the day it syncs past it.

- **1, click** — done: `_click_point` pushes press and release in the
  same frame. Delete FrogGame's `_click_same_frame` override on sync.
- **2, applied settings** — (b) done: one paragraph in the tooling doc
  and the seed's `dev_hooks.gd`. (a) not ported: the kit applies only
  keybinds, volumes, locale, deadzone and UI scale from settings, and the
  sandbox already resets all but UI scale; a kit `GameSettings` would be
  a settings sheet the kit does not have. FrogGame keeps its own.
- **3, ConfigFile default** — done (`-1.0` sentinel), with a test, and a
  CLAUDE.md rule. The bigger finding hiding under it and under 9: the
  boot and batch gates grepped only `SCRIPT ERROR`, so a plain engine
  `ERROR:` line (this one, the freed lambda) never counted. **Both gates
  now count every `ERROR:` line** (minus the exit-time "resources still
  in use" line), and `selftest.sh` proves each can go red. Verified
  green on the fixture first.
- **4, three screens** — done: `window` is a harness built-in, the seed
  `check.local.sh` carries the loop commented, the fixture's local check
  runs the zone scenario at two sizes and checks the `window` reply.
- **5, `assert_zone`** — done, built-in, `scenarios/zones.txt`. Delete
  FrogGame's override on sync.
- **6, `select` / `select_assert`** — done, built-in, with a fixture
  dropdown and `scenarios/dropdown.txt`. Delete FrogGame's on sync.
- **7, sound families** — done: `AudioManager.pick(kind)`, lists never
  repeat, a bare stream and an unknown kind (`none`) as before; test.
- **8, joypad** — the autoload half ported: `axis:<n>:<+|->` bindings
  (`joy:` kept as the stored button encoding, so no settings.cfg
  migrates), the axis describer, and the capture rules as a UI-free
  seam in Keybinds (`begin_capture`, `capture_event`, `capture_text`,
  `capture_ended`), with tests. The settings screen itself stays a
  project piece until a second project needs it; FrogGame's panel can
  shrink to a display over the seam when it syncs.
- **9, lambda** — CLAUDE.md now says connect a method AND disconnect in
  `_exit_tree`; the gate change above is what actually catches it.
- **10, offset transform** — done: `pop_in` moved to
  `offset_transform_scale`, a UI kit rule with the icon note.
- **11, patterns** — the motion kill switch not adopted: the batch would
  stop exercising the pop-in path, and `settle`/`wait` past it is the
  documented answer. The verb helper and toasts are FrogGame UX.
- **12** — `SHOOT_KEEP` and the wipe are in the tooling doc; the timings
  file is now merged, so a single-scenario run updates one row.
