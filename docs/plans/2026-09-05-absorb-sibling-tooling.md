# Plan: absorb the sibling projects' tooling improvements into Microbiome

Status: landed 2026-09-05 on branch `plans/2026-09-05` (tiers 1-5; see the roadmap). The sibling migration in the last section is the remaining work. Companion to
`2026-09-05-fast-visual-loop.md` (the parked speed plan); tier 1 here
overlaps its runner fixes, so whichever runs first strikes them for both.

## Context

Nine game projects were scaffolded from the Template and each improved the
tooling in place. Microbiome now owns that tooling (manifest + sync skill),
but its copy is the *oldest*: it lacks fixes that up to four projects made
independently, and syncing any sibling today would delete their work. This
plan pulls in every generic tooling improvement so the siblings can then be
synced without losing anything, and records the game-kit findings for a
separate Template pass.

Decisions taken with the user (2026-09-05): **tooling only this round**
(runner, check, harness, console, CI, conventions, dev utilities that serve
the loop); **everything generic** within that. Kit code (SaveManager,
Keybinds/controller, UiScaleRoot, UI theme, autoload seams) is *recorded*,
not ported. Survey sources: `docs/research/2026-09-05-sibling-project-lessons.md`
plus two code-shape reads today (cited inline as project:file).

Rules for every item: lands in its own commit, `tools/check.sh` green, the
fixture exercises it (a test or scenario), each new gate is proven able to
fail once, CLAUDE.md gets the rule plus what breaks without it.

## Tier 1: runner and check script

1. **Parse-failure guard** in `tools/test.sh`: FrogGame's `load_fails()`
   (grep `Failed to load script`; synthesise a `Failing Tests N (scripts
   that did not load)` line; force the log out) plus NavalWar's stronger
   reconciliation (unique `res://tests/test_*.gd` names seen vs files on
   disk; fewer ran = fail). Four projects hit this independently.
   Fixture: new owned `tools/selftest.sh` runs `test.sh` against a scratch
   copy of the project containing one unparsable test file and asserts
   exit 1 plus the message; `tools/check.local.sh` calls it.
2. **`check.sh`**: drop the `SHOOT_TIMEOUT=300` pin (Orbit, NavalWar);
   grep `shader` beside `SCRIPT ERROR|Parse Error` in boot and shoot logs
   (FrogGame); `GODOT="${GODOT:-godot4}"` in test/check/shoot/export/sync
   with a `--` skip line when `/usr/bin/time` is missing (FrogGame); parse
   `--quick` and `--ci` in any order (BossFights reads only `$1`); `--ci`
   means "everything needing no display" and exports `CHECK_CI=1` to
   `check.local.sh`; NavalWar's `mkdir` lock (five lines, exit 2) until
   per-process user data lands from the parked speed plan.
3. **`.github/workflows/ci.yml`**: NavalWar's `test.yml` shape (push, PR,
   dispatch, `concurrency: cancel-in-progress`, `--import` step because a
   fresh checkout has no `.godot/`) plus BossFights' cached Godot binary
   keyed by version and `timeout-minutes: 20`, running `tools/check.sh --ci`.
   Added to `tools/tooling-manifest.txt`.
4. **Harness instrumentation**: `scenario ok: <path> (<s> s)` (FrogGame), a
   `harness: renderer <adapter> / <driver>` line once at start, shots named
   `shots/<scenario-stem>-NN-<name>.png` (two scenarios that both `shot
   boot` overwrite each other today).

## Tier 2: sharded `tools/test.sh`

FrogGame's runner (`FrogGame/tools/test.sh` 40-200): per-shard
`XDG_DATA_HOME`; per-shard gutconfig with `dirs: []` and a `tests` list (GUT
*adds* `-gtest` entries to whatever the config names); JUnit XML per shard
merged into `.godot/test-timings` and dealt longest-first next run, unknown
scripts priced at the average with a `+0.001` floor; empty shards compacted
(GUT exits 1 on an empty config); `TEST_JOBS` default 4 clamped by script
count and `nproc`; `TEST_JOBS=1` for the readable log; aggregated summary in
the same greppable shape; tier-1 guards applied per shard. Single-script mode
unchanged. Fixture: `check.local.sh` runs `TEST_JOBS=2` once and asserts the
counts equal `TEST_JOBS=1`. CLAUDE.md: sharding *exposes* cross-test leaks
(FrogGame: one script relied on another having set GUT's error tolerance);
fix the dependency, never reorder shards.

## Tier 3: harness and console commands

| Command | Source | Design |
|---|---|---|
| `settle [seconds] [group]` | FrogGame 212-227 | group defaults to `settle`; polls `is_busy()` guarded by `has_method`; **errors on timeout** (FrogGame falls through silently, hiding a hung animation). Fixture: a node in the group whose `is_busy()` clears after a few frames. |
| `ticks <n>` beside wall-clock `sleep` | Orbit 214-224 vs FrogGame 228-234 | ship both; `ticks` awaits physics frames using `Engine.physics_ticks_per_second` (Orbit hardcodes 60). Rule: choreography and anything under `time_scale` use `ticks`; OS timers use `sleep`. Compatible with the parked `--fixed-fps` plan. |
| `scroll_to <NodeName>` | Orbit 240-258 | as-is (`ScrollContainer.ensure_control_visible`, 4 frames). Fixture: a ScrollContainer with a row below the fold in `main.tscn`; `expect_fail click` before, `click` after. |
| `assert_onscreen` ambiguity refusal, Node3D support | Monmon 423-476 | `_find_all`, error on more than one match; Node3D via camera unproject of the AABB centre. Fixture: two same-named nodes. |
| `frame_budget <ms> [frames]` | Monmon 332-364 | verbatim (vsync and max_fps off, 10 warm-up frames, average and worst, `  frames:` printed on pass); `check.sh` surfaces it under `── frames ──`, `--` when absent. Fixture: `scenarios/frame_budget.txt` with a generous budget; CLAUDE.md: regression tripwire, not a device target. |
| `assert_tooltip <NodeName> <substring>`, `hover <NodeName>` | procedural-factory 298-355 | `assert_tooltip` reads `Control.get_tooltip()` (deterministic, no dwell); `hover` keeps the real-mouse path (warp, motion event, `gui_get_hovered_control` check). `_sandbox()` parks the cursor at (2,2): the real cursor is global state. Fixture: tooltip on the pause menu's Resume button. |
| `click_at <x> <y>` | NavalWar `nw_click`, FrogGame `fg_click` | synthesised click at viewport coordinates for non-Control boards. **Correctness fix from NavalWar (CLAUDE.md 1787):** synthetic clicks must go through `push_input(event, true)` in canvas coordinates; `parse_input_event` treats the position as window pixels and misses under any non-design stretch. Apply to `click` too. Fixture: click the title label's rect. |
| `state`, `assert <key> <value>` | FrogGame's design (`_fg`, `assert_key`) over NavalWar's | core console commands: any node in group `state` implementing `state_text() -> String` and `assert_key(key, value) -> String` (unknown key = error; `prefix:` fallback for open namespaces). Console owns only lookup and the error contract. Fixture: `main.gd` joins the group and exposes two keys. |

## Tier 4: sandbox, driver skeleton, CLAUDE.md rules

- **Settings in the redirected config survive between scenarios** (NavalWar,
  Monmon, FrogGame 5890a0a): reset after the redirect, never before. Seed
  hooks (`tools/seeds/dev_hooks.gd`) get a comment listing the shapes seen
  (renderer, zoom, campaign progress, editor last-mod).
- **Ambient real-time systems need a console off switch the sandbox
  restores** (Zoofle rain, Monmon roamers). **Scenarios assert state after
  actions** (FrogGame silent cancels). **Every menu action needs a non-click
  seam** (NavalWar scrolling roster). **A playtest must not bank progress.**
- **`-s` scripts run without autoloads; use a self-freeing `--flag`
  autoload** (Orbit, NavalWar): new `scripts/util/cmdline.gd` with Monmon's
  `user_args` / `user_arg` / `has_flag` trio (harness switches to it), and
  `tools/seeds/dev_driver.gd`: find flag, `queue_free()` if absent,
  `call_deferred` the work, `get_tree().quit(status)`. Fixture: a
  `--selftest` driver that exits 0, invoked from `check.local.sh`, proven to
  exit 1 when told to.
- **A gate must be proven able to fail** (Monmon): written beside the
  skeleton; applied to every fixture gate in this plan.
- **Generic Godot pitfalls the harness catches** (rules with failure modes):
  `set_anchors_and_offsets_preset` (Orbit and Digit independently); a child's
  `_ready()` runs before its parent's (NavalWar); autoload signals need a
  method, not a lambda (NavalWar); a code-built UI tree must theme itself
  (NavalWar); reading an image on a `res://` path with `Image.load()` fails
  the suite, decode from bytes (FrogGame and NavalWar); engine tooltips are
  unreliable under WSLg (procedural-factory sets the delay to a day).
- **Test section additions**: the parse-error symptom (Zoofle); the
  frame-rate-independence recipe (Tandem: same seeded sim at two `dt`s,
  compare event timestamps with a derived tolerance, counters exactly).

## Tier 5: dev utilities that serve the loop

- `JsonLines` (Monmon `scripts/dev/json_lines.gd`, 74 lines, no deps) into
  `scripts/util/` with a test: exact line for a syntax error, token line for
  a semantic message, 0 when unknown. It is what turns a data finding into a
  `file:line` Claude can open.
- **Localization contract test** (NavalWar `tests/test_localization.gd`
  1-50): regex-scan `scripts/` for `tr_or_fallback("ui.*")`, fail when
  `TranslationServer.translate(key) == key`; the "scan actually finds keys"
  guard with the threshold derived from the fixture, not hardcoded to 80.
- **Pseudo-locale** (NavalWar `tools/make_pseudo_locale.py`, stdlib): an
  `xa` column in `localization/game.csv`, registered translation, a scenario
  that switches locale and shoots the pause menu. The only mechanism in any
  project that makes a hardcoded string visible in a screenshot. (Touches
  the fixture's CSV, which is why it is last and flagged.)

## Recorded, not ported: the kit findings

Planned separately in `2026-09-05-template-kit-pass.md`, which is also the
record of the findings. Headline items, each found in two projects
independently unless noted: `JSON.stringify(data, "\t", false)` in
SaveManager (sorted keys make a saved dictionary unequal to itself; Template
is wrong today); the `save_provider` group seam filling Template's empty
stubs; `window/stretch/aspect="expand"` (Template's `keep` is the outlier in
7 of 10) with the integer-snap scale policy; `config/version`; DataMerger
`$delete`; `L10n.data_text`; `VersionUtil` (byte-identical in two projects);
NavalWar's controller layer (`Pads` + `pad_router.gd` + Keybinds pad slots),
`ui_focus.gd` and the focus ring; FrogGame's `UiScaleRoot` rework with
testable `fit_for`; `json_value.gd`, `bbcode.gd`, `save_compat.gd` skeleton,
`runtime_textures.gd`, Digit's `ContentDB.load_layered`;
`EventBus.settings_changed`; AudioManager `save_debounce` + `flush_volumes`
with FrogGame's tests; `last_load_problem`; the JSON rules (rng state as a
string, `sort_keys`, ints become floats, `truthy()`), "a translation key must
not be a position", "text somebody else wrote is markup"; the `@tool`
preview rules; Zoofle's Android CI with a cached keystore;
`gen_modding_docs.py --check`; `ui_from_render.py`; `make_android_icons.gd`.

## Deliberately not taken

Sim/bot drivers, balance gates, data linters, net tests: game-shaped; the
driver skeleton and gate-must-fail rule are their residue. Monmon's linter
principle ("no rules of its own, it runs the real loaders") goes in the kit
doc. Two match runners / control rows: survey only.

## After it lands: migrate the siblings

Finding to carry to Monmon: `JSON.get_error_line()` is 0-based on 4.7, so
its `json_lines.gd` (and `lint.sh` output) reports syntax errors one line
early; Microbiome's copy adds 1 and has a test pinning it.

Per project: `/sync-godot-tooling --check`; move in-file console handlers to
`dev_hooks.gd` + `console_commands.project.json`, `_sandbox()` additions to
`sandbox()`, extra check steps to `check.local.sh`; sync; full check; commit
naming the Microbiome commit. Order: Template, Digit, Tandem, Zoofle (no
harness changes), then Orbit, procedural-factory, BossFights, Monmon,
FrogGame, NavalWar (most in-file customisation last).

## Verification

- `tools/check.sh` green after every tier; each tier its own commit.
- Every new gate disabled once and seen red, noted in the commit message.
- `tools/selftest.sh`: broken test file exits 1 with the load message;
  `TEST_JOBS=2` counts equal `TEST_JOBS=1`; `.godot/test-timings` written.
- New scenarios (`settle`, `scroll_to`, ambiguity, `frame_budget`, tooltip,
  `click_at`, `state`/`assert`, pseudo-locale) pass in the batch and alone.
- `tools/sync-tooling.sh ../Template`, then Template's full check green.
- Docs: roadmap struck per tier; CLAUDE.md rules with failure modes; README
  command list (`--ci`, `TEST_JOBS`); kit-findings research doc written.

## Files

`tools/test.sh`, `tools/check.sh`, `tools/shoot.sh`, `tools/selftest.sh`
(new), `tools/check.local.sh`, `tools/tooling-manifest.txt`,
`tools/seeds/dev_hooks.gd`, `tools/seeds/dev_driver.gd` (new),
`tools/make_pseudo_locale.py` (new), `.github/workflows/ci.yml` (new),
`scripts/dev/screenshot_harness.gd`, `scripts/dev/debug_console.gd`,
`data/console_commands.json`, `scripts/util/cmdline.gd` (new),
`scripts/util/json_lines.gd` (new), `scripts/main.gd` + `scenes/main.tscn`
(fixture seams), `scenarios/*.txt` (new), `tests/*.gd` (new),
`localization/game.csv`, `CLAUDE.md`, `README.md`, `docs/roadmap.md`,
`docs/research/2026-09-05-kit-findings.md` (new).
