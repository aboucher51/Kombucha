# Roadmap

What the surveys in `docs/research/` asked for, what landed on
2026-09-05, and what is left. Plans live in `docs/plans/`; each says its
own status at the top.

## Landed 2026-09-05 (branch `plans/2026-09-05`, Microbiome and Template)

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

## Next

1. **Migrate the siblings** (`docs/plans/2026-09-05-absorb-sibling-tooling.md`,
   last section): per project, `/sync-godot-tooling --check`, move in-file
   customisations into the seams, sync, full check. Order: Digit, Tandem,
   Zoofle, Orbit, procedural-factory, BossFights, Monmon, FrogGame,
   NavalWar. Carry the JsonLines line-base fix to Monmon.
2. **Kit adoption by siblings**: a `--kit` report mode for
   `sync-tooling.sh` listing kit files that differ and the Template commit
   that last touched each, so a project can cherry-pick.
3. **Verify the CI path** on a real push: the Xvfb branch of `shoot.sh` is
   exercised only by CI (xvfb is not installed locally). Set `SHOOT_SLOW`
   from the measured runner time.
4. **Visual regression**: `expect_shot <name> [tolerance]` against a
   checked-in baseline with mask rects. Feasible now that reruns are
   pixel-identical on llvmpipe; baselines are per rasterizer.
5. **Long-lived game process** fed by a command queue (file-based, or the
   native debugger port via `EngineDebugger.register_message_capture`), so
   iterating on one scenario costs zero boots.
6. **Windows binary through interop** (`GODOT=...console.exe`, `wslpath`,
   `taskkill` on timeout) once a Windows Godot build is installed; the
   /mnt boot cost makes it worth measuring.
7. **JUnit XML surfaced** from `test.sh` (it is already written per shard)
   and a JSONL trace per scenario beside the PNGs.

## Not planned

- Any editor-bridge MCP server as a dependency: it needs the editor open,
  which breaks the one-command, one-exit-code contract and CI.
- PlayGodot or its engine fork: 4.6-based, single-maintainer, and its
  headless screenshots are blank like everyone else's.
- Windowless rendering until upstream lands it (godot-proposals #5790):
  the virtual display is the answer, and it is not faster.
- `--fixed-fps` or vsync flags for the harness: measured, no gain, a real
  loss on heavy scenes under a software renderer.
