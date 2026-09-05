# Roadmap

The iteration order for the workflow, distilled from the three surveys in
`docs/research/` (2026-09-05). Ordered by how many projects paid for the
lesson, then by how mechanical the change is. Each item names its source
so the reasoning can be re-read. Strike items through as they land and
are backported.

## Parked plans

`docs/plans/2026-09-05-absorb-sibling-tooling.md`: the approved order for
pulling the siblings' tooling improvements in (five tiers: runner guards,
sharded tests, harness commands, rules and driver skeleton, loop-serving
utilities), what is recorded for a later Template kit pass, and the sibling
migration order afterwards. Supersedes tiers 1-5 below once started.

`docs/plans/2026-09-05-template-kit-pass.md`: the game-kit fixes the survey
found (SaveManager sorted keys, save-provider seam, stretch aspect,
controller support, UI scale root rework, focus ring, data rules). Lands in
the Template, not here; Microbiome's fixture is refreshed after each tier.

`docs/plans/2026-09-05-fast-visual-loop.md`: the speed-first plan for the
scenario loop (benchmark matrix, unthrottle with a fixed engine clock,
scenario sharding, Xvfb as the CI fallback) and the headless verdict:
windowless rendering is not possible in stock Godot, display-less is, and
it is slower. Revisit before starting tier 1 or 2 below, since it folds
several of their items in.

## 0. Ownership (landed 2026-09-05)

- ~~**One source, copied outward.** `tools/tooling-manifest.txt`,
  `tools/sync-tooling.sh`, `tools/TOOLING_VERSION`, the
  `/sync-godot-tooling` skill, and the three extension seams
  (`dev_hooks.gd`, `console_commands.project.json`, `check.local.sh`) so a
  sync never clobbers project code.~~
- **Migrate the sibling projects.** Blocked on tiers 1 and 2: syncing today
  would delete their guards and harness commands. Absorb those here first,
  then sync each project, moving its in-file customisations into the seams.

## 1. Runner and check script fixes (small, several projects hit each)

- **Parse-failure guard in `tools/test.sh`.** A test file that fails to
  parse is silently dropped and GUT exits 0. Grep for the load failure
  and fail the run. Four projects wrote this guard separately.
  (sibling-lessons §1)
- **Remove the `SHOOT_TIMEOUT` pin in `check.sh`**; let `shoot.sh` scale
  with the scenario count. Broke two projects as suites grew.
  (sibling-lessons §2)
- **`GODOT` binary override** in test, check and shoot. Booting through the
  WSL bridge costs ~11 s against 1.4 s natively. Skip, do not fail, the
  memory budget when `/usr/bin/time` is absent. (sibling-lessons §7)
- **Grep `shader` alongside script and parse errors** in boot and shoot
  logs. (sibling-lessons §11)
- **Print each scenario's elapsed seconds on pass.** (sibling-lessons §12)

## 2. Harness commands

- **`settle [seconds]`**: wait until nothing in a named group reports
  `is_busy()`. The wait-until primitive both surveys asked for.
  (sibling-lessons §13, prior-art §3)
- **`ticks N`** in physics frames beside wall-clock `sleep`, with the rule
  for which to use when. (sibling-lessons §14)
- **`assert_onscreen` refuses ambiguous names** and accepts Node3D via the
  camera. (sibling-lessons §16)
- **`scroll_to <NodeName>`** and **`click_at x y`** for below-the-fold rows
  and non-Control boards. (sibling-lessons §17, §21)
- **Generic `state` and `assert <key> <value>`** over a registry seam the
  game fills in. Every board game reinvented these under its own prefix,
  and state readback before pixels is the token-cost rule the MCP
  servers converged on. (sibling-lessons §19, prior-art §5)
- **`frame_budget <ms> [frames]`** with vsync off, printed even on pass.
  (sibling-lessons §15)
- **`--scene` argument** so a scenario can boot one scene in isolation.
  (playgodot §what is worth taking)

## 3. CLAUDE.md rules

Settings-file persistence between scenarios; ambient real-time systems need
a console off switch the sandbox restores; scenarios assert state after
actions because silent cancels pass; `set_anchors_and_offsets_preset`;
every menu action needs a non-click seam; a playtest must not bank
progress. (sibling-lessons §3, §4, §5, §20, §22, §23)

## 4. Structured output and parallelism

- **JUnit XML from GUT** (`-gjunit_xml_file`) and a **JSONL trace per
  scenario** beside the PNGs. (prior-art §1)
- **Sharded `test.sh`** with per-shard data dirs and longest-first dealing
  from the last run's timings. (sibling-lessons §6)
- **Lock on `check.sh`**; the sandbox path is fixed. (sibling-lessons §8)
- **`--ci` mode and a `ci.yml` on push and PR.** (sibling-lessons §9)

## 5. Fixture code fixes with tests

- **A seam for anything a test would otherwise sleep through**:
  `AudioManager.save_debounce` variable and `flush_volumes()`.
  (sibling-lessons §24)
- **Localization contract test** that scans scripts for `ui.*` keys and
  fails on a missing CSV row. (sibling-lessons §25)

## 6. Patterns needing a skeleton

- **Self-freeing autoload gated on a `--flag` user argument**, the shape
  every sim, balance, bench, lint and net driver took because `-s` scripts
  run without autoloads. Ship a skeleton with the gate-must-fail rule
  written beside it. (sibling-lessons §27, §29, §30)
- **Visual regression**: `expect_shot <name> [tolerance]` against a
  checked-in baseline with mask rects. (prior-art §5)
- **Long-lived game instance** fed by a command queue, file-based or over
  the native debugger port via `EngineDebugger.register_message_capture`.
  (prior-art §8, playgodot)
- **Devcontainer with Xvfb** so the scenario half of `check.sh` runs in
  CI. (prior-art §10)

## Not planned

- Any editor-bridge MCP server as a dependency: it needs the editor open,
  which breaks the one-command, one-exit-code contract and CI.
- PlayGodot or its engine fork: 4.6-based, single-maintainer, and its
  headless screenshots are blank like everyone else's.
