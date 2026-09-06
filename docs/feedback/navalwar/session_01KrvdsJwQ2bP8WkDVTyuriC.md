# Feedback from NavalWar — session 01KrvdsJwQ2bP8WkDVTyuriC

Source project: `~/godot-projects/NavalWar`, on tooling `33c70aa`
(synced 2026-09-06). One long session: multi-tile units, data-driven
board effects with bound sounds and lit frames, and the adoption of the
Frog Game's twelve UX rules end to end (icons, toasts, a command bar,
insets, a visibility scale, sound families, the Deck in the gate). Each
item below is something that cost a pass here and would cost the next
project the same one; each says what Kombucha should change and what
breaks without it. NavalWar files named are the reference
implementations. Several confirm FrogGame's findings from the day
before with a second data point, and say so.

## 1. Confirms FrogGame #1: a click "succeeds" and nothing happens, only in a batch

`scenarios/ux_rules.txt` clicked `PlayVsAIButton` in a two-shard batch,
the harness answered ok, and no match started; alone, paired with each
predecessor, and in its exact four-scenario chain it passed every time.
This is the same shape FrogGame reported: the other shard warps the
ONE real cursor across this window between the press and the release,
and the button never emits `pressed`. A project that has not read the
FrogGame file will spend an afternoon on it again (this one did). Land
FrogGame's `_click_same_frame` in the harness itself and delete the two
project-side copies.

## 2. The harness `click` should scroll a target into view itself

Buttons grew a few pixels taller (an icon slot) and a settings-sheet
header dropped below its `ScrollContainer`'s fold. `click` found the
node, reported the click, and nothing opened — the rect was outside the
scroll's visible rect. The rule is documented ("a row below the fold is
visible but not clickable: `scroll_to` first"), but a rule the harness
could apply itself is a scenario edit nobody should have to make:
`click` (and `hover`) should walk up to the nearest ScrollContainer and
`ensure_control_visible` when the target's rect is outside it, then
settle a frame. The failure mode is otherwise silent: an `ok` line and
a wrong screen. NavalWar: `scenarios/settings_panel.txt` has the manual
`scroll_to` lines that this would retire.

## 3. `assert`'s value cannot hold a space

`nw_assert anchor (4, 3)` split the value at the space and the assert
compared against `(4,`. Every Vector2i prints with a space, so any
position-shaped assertion has to invent a comma form (`4,3`) and a
custom key. The console's `assert <key> <value>` (and the harness's
`state`/`assert` seam) should declare the value as `rest`, exactly as
`say` and `toast` do. Cheap, and it removes a whole class of
"why does my assert see half the value" debugging.

## 4. An optional argument cannot precede a `rest` one

`ed_sprite <dest> <path>` takes `path` as `kind: rest`; giving it an
optional leading `<field>` was impossible, so NavalWar grew a second
command, `ed_asset <field> <dest> <path>`, for the same import pointed
at a different field. The declaration parser should accept optional
leading args (or a `--field=` style flag) before a `rest` arg; a
command family that forks per field is the wrong shape.

## 5. The `settle` group is the right seam, and nobody was in it

The harness's `settle [s] [group]` existed and no node in NavalWar
implemented `is_busy()` or joined the group; every scenario waited for
animations with `sleep 1.6`-style guesses. Once the board answered
`is_busy()` (move tweens or effects live), `settle` replaced those
sleeps and the effects scenario became deterministic. Two things worth
writing into the tooling text:

- Any scene node that animates should join `settle` and answer
  `is_busy()`; the kit's template scene could ship one that does, so a
  project sees the pattern on day one.
- **`is_busy()` must read the owner's own table, never
  `get_child_count()`**: a `queue_free`'d node is still a child until
  the frame ends, and a settle poll sees it busy one frame too long.
  NavalWar: `scripts/game/fx_layer.gd` (`_live` table).

## 6. A host reached by group must skip nodes on their way out

`Toasts.say` picks the first visible node in the `toasts` group. In a
sharded test run the previous test's host, freed with
`add_child_autofree`, was still in the group and visible until the
frame ended, so "no host is no error" found a host. Two rules for the
kit's group-reached UI (and for any `get_first_node_in_group` in the
harness): skip `is_queued_for_deletion()` nodes, and a test asserting
absence awaits one frame first. NavalWar: `scripts/ui/toasts.gd`,
`tests/test_toasts.gd`.

## 7. Confirms FrogGame #4, and the Deck run was already fixed

NavalWar's future-work file said the 1280x800 run was blocked on the
next tooling sync; the sync had already brought the window-pixel warp
and nobody re-ran the check. Two suggestions:

- `/sync-godot-tooling` should print the headlines of the Kombucha
  commits it pulled, so a project knows which of its own notes just
  went stale.
- `check.local.sh` running the chrome scenarios at the three named
  sizes is now in two projects with the same shape (a loop over
  `SHOOT_RESOLUTION`, one line of `ok`/`FAIL` each). Ship it in the
  seed `check.local.sh` with the sizes as a variable, so the third
  project starts with it.

## 8. Kit candidates that now exist twice

FrogGame built them and NavalWar ported them the next day with small
changes each; a third port would be the third copy. Worth lifting into
the kit's `scripts/ui/` as-is, with the NavalWar differences as the
generalisations:

- `ConfirmButton` (two presses, self-disarm timer as a CHILD of the
  button so a screen change cannot fire it on a freed node; NavalWar
  adds `set_plain_text` for a label that changes while disarmed).
- `UiButton.make / confirm / chip / set_icon` plus `bind_all(root)`,
  the sweep that gives every unbound button its sound (NavalWar adds
  the sweep; `AudioManager.bind_button` marks a meta so the sweep is
  idempotent).
- `UiMotion` (`pop_in`, `fade_in`, `fade_out`, `slide_in`,
  `flourish`), one place reading reduce effects.
- `Toasts` with a `priority` per host (NavalWar's addition: the pause
  sheet's host must outrank the HUD's beneath it, or an acknowledgement
  lands behind the panel that covers it).
- `AudioManager.ui_event` accepting a LIST per kind and never
  repeating (`pick_sound`), and `load_catalogue` reading the lists from
  mod data through a bytes-decoding `sound()` loader.
- `UITheme.highlight_style()` as the one border (focus ring without a
  face, selection with one), `icon()` from a `ui.icons` catalogue with
  `has_asset` asked first so a missing icon is the word alone and never
  a placeholder square, and `font_px(base)` with `apply_visibility()`
  retuning the CACHED theme in place so nothing needs re-assigning.
- `DisplaySettings` insets and visibility, and `UiScaleRoot` laying out
  inside the inset rect (`scripts/ui/ui_scale_root.gd`).

## 9. The icon generator is one file and could be the kit's

`tools/gen_ui_icons.py` inlines FrogGame's signed-distance kit and
draws 53 verb icons in ~300 lines of stdlib Python. Verb ids are shared
between the two projects (end_turn, undo, menu, save, load, options,
quit, back, close, play, continue, next/prev, inspect, ready). Ship the
generator and the common verbs in the seed; a project adds its own
functions to `FILES`.

## 10. Two things the tooling did right, worth keeping

- `godot-map` catching a stale `PROJECT_MAP.md` on every `check.sh`
  worked as designed, but with the hook not merged into the project's
  `.claude/settings.json` every batch ended in "regenerate and re-run".
  Either the sync merges the hook, or `check.sh` regenerates the map
  itself when the tool is installed and the tree is clean of other
  changes.
- The JSONL trace per scenario (`shots/<stem>.jsonl`) was the fastest
  way to see which line failed and why, every single time; the
  `expect_fail` + `toast_assert` / `select_assert` pattern makes a
  scenario a real test. Keep encouraging assertion seams over shots.

## Disposition (Kombucha, 2026-09-06)

Assessed against the tooling at `4a1d6e0`; the items below landed in the
next commit. NavalWar is on `33c70aa` and gets 1, 7 and 8's audio item by
syncing.

- **1, batch click** — already done for FrogGame's report (same-frame
  press and release). Second independent hit; the sync closes it. Delete
  the project-side copy on sync.
- **2, `click` scrolls into view** — done: `click` and `hover` scroll a
  target whose rect is outside its ScrollContainer's; `scroll_to` forces
  it. `scenarios/click_below_fold.txt`. The manual `scroll_to` lines can
  go.
- **3, assert value** — the kit's `assert` has declared `value` as
  `rest` since its first commit; `nw_assert` declares it `string` in
  NavalWar's own `console_commands.project.json`, one word to change
  there. The rule is now in the tooling text.
- **4, optional before rest** — done as named flags: a spec with
  `"flag": true` is given as `--name=value` anywhere on the line and
  pulled out before the positional pass; kinds and defaults apply. So
  `ed_sprite --field=<f> <dest> <path>` is one command. Fixture: `note
  --kind=todo <text>`, with a test.
- **5, settle** — the scaffold's main scene already answers `is_busy()`
  in the `settle` group (every new project starts from it); the "own
  table, never child count" rule is in the tooling text.
- **6, group hosts on their way out** — done: `settle`, the console's
  `state` providers and SaveManager's provider loops skip
  `is_queued_for_deletion()`; a CLAUDE.md rule for group-reached UI.
- **7a, sync headlines** — done: a sync prints the Kombucha commits
  between the old stamp and the new one.
- **7b, three-screen loop** — done: the seed `check.local.sh` runs it
  live, sizes and scenario as variables, and prints `--` while the
  project has no layout scenario yet.
- **8 and 9, the UI kit pass** — deferred to a session of its own:
  ~1,150 lines here and ~1,450 in FrogGame with real differences between
  the copies, and the fixture's menus must be rebuilt on the pieces so
  each is exercised. The audio half (lists, `pick`) is already in.
- **10a, the map hook** — NavalWar has it now; Kombucha itself did not,
  and does. `check.sh` will not regenerate the map itself: a gate that
  edits the tree is not a gate.
- **10b** — noted; the JSONL trace and assertion seams stay the answer.

Found while syncing NavalWar onto this (2026-09-06, second commit):

- The widened error gate counted the renderer's exit-time leak
  accounting (`Texture with GL ID ... leaked`, `RID allocations ... were
  leaked at exit`), which NavalWar prints and the fixture does not. Those
  join "resources still in use" as ungated exit noise; the doc names all
  three.
- The gate then caught one real error per scenario that ended on an open
  menu: `UIFocus.first`'s bare `grab_focus.call_deferred()` landing
  after the harness tore the scene down. Fixed in the kit's
  `ui_focus.gd` (deferred by instance id, like `pop_in`); NavalWar's own
  copy, and its direct `grab_focus.call_deferred()` calls in `main.gd`,
  `hud.gd` and `pause_menu.gd`, have the same shape.
- `TEST_JOBS=1` on a 1,000-test suite was killed by the 180 s shard
  budget and reported as "88 scripts did not load". The budget now
  scales with 4/TEST_JOBS and a timed-out shard says so.
- Three hover-driven scenarios (`pad_play`, `tactical_view`,
  `info_dock_fog`) failed once in a two-shard batch and pass alone: the
  shared real cursor reaching the game's own hover state, the case the
  tooling text already reserves `SHOOT_JOBS=1` for.
- `test_toasts.gd test_no_host_is_no_error` failed in the sharded run
  and passes alone: a toast host left visible by a neighbouring test
  script in the same shard, a cross-test leak of NavalWar's own.

## 11. `UIFocus.grab(control)` — the id-deferred grab for ONE known control (later the same day)

The 34e17d3 fix made `UIFocus.first` safe, but a screen that knows
which control it wants (a modal's Close, a dialogue's Advance, a
pause sheet's Resume) still wrote `control.grab_focus.call_deferred()`
directly — eight of them in NavalWar — and the dialogue scenario's one
landed after teardown, the same `!is_inside_tree()` under a green
batch. NavalWar's copy of `ui_focus.gd` gained
`static func grab(control: Control)` (skip if queued for deletion,
then `_grab_deferred.call_deferred(id)`), and the eight calls route
through it. Worth lifting into the kit's `ui_focus.gd` beside `first`,
with the CLAUDE.md rule: a deferred `grab_focus` is always by instance
id, never on the control.

## 12. An engine error under a green batch names no scenario

The full check ended `66 scenario(s), 0 failed` and `shoot: 1 engine
error(s)` with the bare line `Condition "!is_inside_tree()" is true` —
and nothing said WHICH scenario raised it. The shard logs live in a
`mktemp -d` that is gone when `shoot.sh` returns, so the only way to
attribute it was to re-run the whole batch with the output captured and
read backwards from the error to the nearest `── scenario:` header
(four minutes to learn "dialogue.txt, after its last line"). Two cheap
fixes, either one enough: print the scenario each counted error fell
under (the header is already in the same stream), or keep the shard
logs beside the shots (`shots/shard.N.log`) the way the JSONL traces
are kept — a log is read once, a file is asked again.

## 13. The harness tears a scene down under a pending await

Between scenarios the harness returns to the boot scene, but a
coroutine mid-`await` (the AI turn loop waiting out its pacing timer,
a replay loop, anything sleeping on `create_timer`) resumes AFTER that
teardown with `is_instance_valid(self)` still true and
`is_inside_tree()` false. Anything it then does with the viewport —
`get_viewport()`, `create_tween()`, a deferred `grab_focus` — is the
`!is_inside_tree()` engine error, once per scenario that ended on that
seat. Worth a line in the tooling text beside the "anything global
survives the reload" rule: a resumed coroutine must check
`is_inside_tree()` before it touches the scene, and a deferred focus
is always by instance id (finding 11). NavalWar:
`skirmish._follow_allowed`, `UIFocus.grab`.

## 14. `settle` needs a word for animation that never ends

The settle rule says any node that animates answers `is_busy()`. The
first endless effect (a wounded hull smoking until it heals) hung every
`settle` in the batch the moment it was in a layer's table, and the AI's
own pacing (`_settle` awaiting `fx_settled`) with it. The fix is one
flag — an entry with no end is excluded from `is_busy()` — but the rule
should say so: `is_busy()` answers for work that will FINISH; a loop
with no end is scenery and must not be counted, or the first ambient
animation a project adds stops every scenario. NavalWar:
`fx_layer.gd` (`endless`).

## 15. A one-script test run buries its failing assertion

`TEST_JOBS=1 tools/test.sh test_fx_layer` ends with `---- 1 failing
tests ----` and the results path; the assertion text is a few hundred
lines up in GUT's own stream, so the reflex is a second run piped
through `grep Failed` (two tries here, the first pattern missed). The
summary could repeat each failing test's name and its `[Failed]` lines,
the way the JUnit report already has them per test — the log is right
there, and `test.sh` already greps it for the load-failure guard.

## Disposition, findings 11-15 (Kombucha, 2026-09-06)

- **11, `UIFocus.grab(control)`** — done, in the kit's `ui_focus.gd`
  beside `first()` (which now routes through it), with a test that a
  freed control is refused. The CLAUDE.md rule says a deferred
  `grab_focus` is always by instance id. NavalWar's eight call sites can
  become `UIFocus.grab(...)` when it cherry-picks the kit file.
- **12, an engine error names no scenario** — done, both halves: a
  counted error now prints as `<scenario>: <error>` (the shard log
  carries the headers in the same stream), and the shard logs are copied
  to `shots/shard.*.log` after every run, so the batch does not have to
  be re-run to read them. The self-test asserts the attribution.
- **13, a coroutine resuming after teardown** — a rule in the tooling
  text beside "anything global survives the reload": a resumed coroutine
  checks `is_inside_tree()` before it touches the scene, and a deferred
  focus goes through `UIFocus.grab()`.
- **14, `settle` and animation that never ends** — a rule in the same
  section: `is_busy()` answers for work that will FINISH, and a loop
  with no end is scenery that must be excluded, or the first ambient
  animation hangs every `settle` in the batch.
- **15, a one-script run buries its failing assertion** — done: a red
  run repeats them at the end under `── failing assertions ──`, script
  and test named, in both the named and the sharded path. The self-test
  plants a failing assertion and proves it comes back.
