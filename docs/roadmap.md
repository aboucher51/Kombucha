# Roadmap

What the surveys in `docs/research/` asked for, what landed on
2026-09-05, and what is left. Plans live in `docs/plans/`; each says its
own status at the top.

## Landed 2026-09-05 (branch `plans/2026-09-05`, Kombucha and Template)

- **Ownership**: manifest, `sync-tooling.sh`, `TOOLING_VERSION`, the
  `/sync-godot-tooling` skill, and the three extension seams
  (`dev_hooks.gd`, `console_commands.project.json`, `check.local.sh`).
- **Runner**: parse-failure guards (four projects had each written one),
  sharded `test.sh` dealt from JUnit timings, `GODOT` override, shader
  errors counted, `--quick`/`--ci` in any order, `ci.yml` on push and PR
  with scenarios on Xvfb, boot memory skipped not failed without GNU time.
- **Harness**: `ticks`, `settle` (errors on timeout), `click_at`,
  `scroll_to`, `hover`, `assert_tooltip`, `frame_budget`, Node3D
  `assert_onscreen`, ambiguity refusal, canvas-coordinate clicks,
  scenario-stem shot names, per-scenario seconds, renderer line, null
  capture guard, per-process user data, `SHOOT_JOBS` shards, Xvfb fallback,
  boot locale and cursor and kit seams reset in the sandbox.
- **Console**: `state` / `assert` over the `state` group, `locale`.
- **Utilities**: `Cmdline`, `JsonLines` (with the 0-based error-line fix),
  the driver skeleton, the localization contract test, the pseudo-locale.
- **Speed** (`docs/research/2026-09-05-scenario-speed.md`): pacing flags
  measured and rejected; filesystem location is the lever (10.8 s vs
  0.8 s boot); two shards 164 s vs 204 s on a 36-scenario suite.
- **Kit (Template)**: SaveManager sort-keys fix, load reasons, provider
  group, slot meta and listing, SaveCompat, `settings_changed`, audio
  debounce seam, JsonValue / VersionUtil / BBCode / RuntimeTextures /
  ContentDB, focus ring, UIFocus, pop_in, UiScaleRoot rework, integer
  window scaling, aspect expand, config/version, controller support (Pads,
  PadRouter, Keybinds pad slots), friendly key names, translated slider
  labels, the rules for all of it.

## Landed 2026-09-06

- **The execute bit**: every script was committed 100644 and the Linux
  move made `check.sh` itself "Permission denied" while a non-executable
  `check.local.sh` read as "no local checks". Bits recorded, a `scripts`
  section in check.sh, a loud FAIL for the local file, sync sets the bit.
- **CI verified on a real push** (former item 3): green first time on the
  Xvfb + llvmpipe path, whole job under a minute, renderer LLVM 20 on the
  runner against 21 here. Repo renamed to Kombucha on GitHub.
- **Visual regression** (former item 4): `expect_shot <name> [tolerance]`
  and `mask`, baselines per rasterizer under `scenarios/baselines/`,
  written with `SHOOT_BASELINES=update`, diff images on failure.
- **JUnit surfaced** (half of former item 7): shards merged into
  `.godot/test-results.xml`, kept by CI as `test-results`. The JSONL
  scenario trace is still open.
- Docs: the update-template skill routes tooling to Kombucha and kit to
  the Template; ownership headers say KOMBUCHA; `sleep` has a scenario.
- **Digit migrated** (first of former item 1): six console handlers moved
  to `dev_hooks.gd`, tooling synced and stamped, CLAUDE.md sections
  reconciled, full check green. Its one in-file harness fix (return to
  the BOOT scene between scenarios) is now Kombucha's, with an ordered
  scenario pair in `check.local.sh` proving it (`SHOOT_JOBS=1` keeps the
  given order). Lesson for the rest: diff the WHOLE owned file against
  the Kombucha commit the project was scaffolded from, not just the seams.
- **NavalWar scoped, not migrated**: 552 non-comment lines of console
  handlers (about 90 commands), 55 in the harness, 85 in its own sharded
  `test.sh`, a check.sh lock, and an uncommitted working tree. It needs
  its own session, started from a clean tree.

## Landed 2026-09-06, second pass

- **One tooling text**: the CLAUDE.md tooling sections are
  `docs/godot-tooling.md`, an owned file every project's CLAUDE.md
  imports with `@docs/godot-tooling.md`; the sync notes a missing import.
  No more hand-splicing rules into each project.
- **Drift with provenance**: `sync-tooling.sh --check` measures each
  drifted owned file against the Kombucha or Template version it is
  closest to and reports the project's own lines; `--diff` prints them.
- **The kit report** (former item 2): `--kit` lists, per Template kit
  file, the version a project's copy is at, its own lines, and the
  Template commits since.
- **The sync self-tests** in `tools/selftest.sh`: stamp, seeds, execute
  bit, drift report with the project's line, the import note, a dirty
  source refused. It caught a blank line counted as a project edit.
- **JSONL trace per scenario** (the rest of former item 7) beside the
  PNGs, proven complete by `check.local.sh`.
- **Recursive sandbox wipe** (NavalWar's fix): a mods tree with
  subdirectories is wiped whole.
- **The exit-time "resources still in use" line** was investigated: a
  `const preload` (`menu_close.wav`) held during teardown, count varying
  between identical runs. Documented as not gateable; not counted.
- **Xvfb locally**: `check.local.sh` forces a scenario through the
  virtual display when `xvfb-run` exists and prints a `--` line until it
  is installed (`sudo apt install xvfb`, needs the user's password).

- **The GPU** (former "not a lever" verdict revised): WSLg's Mesa d3d12
  driver renders FrogGame's 36 scenarios in 105 s against 208 s on
  llvmpipe, same 145 shots, and a settled frame is pixel-identical
  between GPU reruns. `shoot.sh` uses it by default (`SHOOT_GPU=0` for
  llvmpipe, which CI keeps); `expect_shot` baselines are per rasterizer,
  the fixture commits both. Found on the way: a frame captured mid-tween
  varies run to run on either rasterizer.
- **The long-lived engine** (former item 3): `--serve <dir>` in the
  harness and `tools/serve.sh start|run|say|stop`; commands are files,
  replies are files, verdict per command, `reset` returns to the boot
  scene. Proven in `check.local.sh` (runs, fails a bad line, stops).

- **Hooks first**: `console_dispatch` and `scenario_command` are asked
  before the core handlers and built-ins, so a project may take over
  `saves`, `locale` or `settle` from `dev_hooks.gd` (NavalWar had edited
  the synced console for that).
- **A hidden namesake is not ambiguous**: among nodes sharing a name the
  one visible in the tree wins when alone; two visible ones stay an
  error (FrogGame's hub and pause menu both build a `SettingsButton`).
- **FrogGame and NavalWar migrated** (the user's two active projects):
  79 and 81 console handlers moved to `dev_hooks.gd` by an extractor
  (kept in the session scratchpad; worth landing as a tool if another
  project needs it), sandbox resets to `sandbox()`/`restore()`, CLAUDE.md
  imports the tooling text. FrogGame's skirmish joined the `settle` group.
  NavalWar's commit sits on its `combat-popup` branch with only the
  tooling files, because another session was working in that tree and
  the sync had already clobbered its uncommitted console edits; its
  check was not run to completion there at that session's request.
  Two FrogGame scenarios (`campaign_loop`, `tactics_verbs`) failed once
  under CPU contention from concurrent checks and pass alone: their
  waits are frame-counted against wall-clock tweens.
- `checkout@v5` in both workflows (NavalWar's bump; v4 warns on Node 20).

## Next

0. **Move projects to the Linux filesystem**
   (`docs/plans/2026-09-05-linux-move.md`): Monmon trialled, boot 15.0 s
   to 0.8 s, full check 395 s to 217 s, identical results. Cut-over and the
   remaining projects are the user's call.
0. **Never sync into a tree another session is editing.** The sync
   overwrites owned files; uncommitted edits there are lost. Check
   `git status` immediately before, and ask the tree's session first.
1. **Migrate the remaining siblings** (`docs/plans/2026-09-05-absorb-sibling-tooling.md`,
   last section): per project, whole-file diff of every owned path against
   the scaffold commit, move in-file customisations into the seams (and
   generic fixes into Kombucha), sync, full check. Order: Tandem, Zoofle,
   Orbit, procedural-factory, BossFights, Monmon (FrogGame and NavalWar
   are done). Not active projects; the user works in FrogGame and
   NavalWar only, so these wait until they are picked up again. Carry the JsonLines line-base fix to Monmon.
2. **Kit adoption by siblings**: a `--kit` report mode for
   `sync-tooling.sh` listing kit files that differ and the Template commit
   that last touched each, so a project can cherry-pick.
3. **Windows binary through interop** (`GODOT=...console.exe`, `wslpath`,
   `taskkill` on timeout) once a Windows Godot build is installed; the
   /mnt boot cost makes it worth measuring.
4. **`SHOOT_SLOW`** from the measured runner time: CI's scenario half ran
   in seconds, so the default 3x is generous; revisit when a real suite
   runs there.
5. **Fast feedback** (`docs/plans/2026-09-05-fast-feedback.md`): one
   engine-error extractor (`path:line: message (xN)`) under every log and
   the `test.sh` gap it closes; `tools/lint.sh` (`--check-only` on changed
   scripts) as the first `check.sh` gate plus a PostToolUse hook seed;
   scoped `dump` / `assert_prop` harness commands; the GDScript LSP as
   documented machine setup; consuming the project map from
   `~/godot-projects/godot-map` (read before grepping, `--check` in CI).

## Shared as a plugin (2026-09-06)

The repo is a Claude Code plugin and its own marketplace
(`.claude-plugin/`, skills in `skills/`): `claude plugin marketplace add
aboucher51/Kombucha` then `claude plugin install kombucha@kombucha`. The
sync skill's source is the plugin checkout (`${CLAUDE_PLUGIN_ROOT}`, or
`GODOT_TOOLING` for a clone); `check.sh` finds the source from the path
the last sync stamped. The tooling assumes the Template kit, so the
entry point for a stranger is `/new-godot-project`, which clones the
Template; the Template repo must be public for that. Next: bump
`version` in both manifests on a release, and an install-from-marketplace
smoke in CI once the repo is public.

## One repo (2026-09-06)

The Template repo is retired: its kit was byte-identical to the fixture's,
so `tools/new-project.sh` now scaffolds from this repo, leaving the
Kombucha-only paths behind and stripping the `<!-- kombucha-only -->`
sections of CLAUDE.md and LICENSES.md. `/update-kombucha` replaces
`/update-template`; `--kit` measures against Kombucha's history (and the
old Template's, where a clone still exists). The self-test scaffolds a
project and checks what stayed behind.

## Not planned

- Any editor-bridge MCP server as a dependency: it needs the editor open,
  which breaks the one-command, one-exit-code contract and CI.
- PlayGodot or its engine fork: 4.6-based, single-maintainer, and its
  headless screenshots are blank like everyone else's.
- Windowless rendering until upstream lands it (godot-proposals #5790):
  the virtual display is the answer, and it is not faster.
- `--fixed-fps` or vsync flags for the harness: measured, no gain, a real
  loss on heavy scenes under a software renderer.
