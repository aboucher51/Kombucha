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

## Next

0. **Move projects to the Linux filesystem**
   (`docs/plans/2026-09-05-linux-move.md`): Monmon trialled, boot 15.0 s
   to 0.8 s, full check 395 s to 217 s, identical results. Cut-over and the
   remaining projects are the user's call.
1. **Migrate the remaining siblings** (`docs/plans/2026-09-05-absorb-sibling-tooling.md`,
   last section): per project, whole-file diff of every owned path against
   the scaffold commit, move in-file customisations into the seams (and
   generic fixes into Kombucha), sync, full check. Order: Tandem, Zoofle,
   Orbit, procedural-factory, BossFights, Monmon, FrogGame, NavalWar
   (scoped above). Carry the JsonLines line-base fix to Monmon.
2. **Kit adoption by siblings**: a `--kit` report mode for
   `sync-tooling.sh` listing kit files that differ and the Template commit
   that last touched each, so a project can cherry-pick.
3. **Long-lived game process** fed by a command queue (file-based, or the
   native debugger port via `EngineDebugger.register_message_capture`), so
   iterating on one scenario costs zero boots.
4. **Windows binary through interop** (`GODOT=...console.exe`, `wslpath`,
   `taskkill` on timeout) once a Windows Godot build is installed; the
   /mnt boot cost makes it worth measuring.
5. **A JSONL trace per scenario** beside the PNGs (the JUnit half landed).
6. **`SHOOT_SLOW`** from the measured runner time: CI's scenario half ran
   in seconds, so the default 3x is generous; revisit when a real suite
   runs there.

## Not planned

- Any editor-bridge MCP server as a dependency: it needs the editor open,
  which breaks the one-command, one-exit-code contract and CI.
- PlayGodot or its engine fork: 4.6-based, single-maintainer, and its
  headless screenshots are blank like everyone else's.
- Windowless rendering until upstream lands it (godot-proposals #5790):
  the virtual display is the answer, and it is not faster.
- `--fixed-fps` or vsync flags for the harness: measured, no gain, a real
  loss on heavy scenes under a software renderer.
