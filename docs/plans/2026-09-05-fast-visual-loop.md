# Plan: the fastest accurate screenshot loop (and the headless verdict)

Status: run and landed 2026-09-05 with two changes of course; the numbers
and decisions are in `docs/research/2026-09-05-scenario-speed.md`.
Unthrottling and `--fixed-fps` were measured and REJECTED (WSLg is already
unthrottled; fixed-fps slows heavy scenes on a software renderer). Landed:
per-process `XDG_DATA_HOME`, `SHOOT_JOBS` shards with per-scenario
timings, the renderer line, the null-capture guard, scenario-stem shot
names, the `/mnt` boot-cost note, Xvfb fallback + `check.sh --ci` + CI
scenarios (the Xvfb path is exercised by CI, not locally). Not done: the
Windows-binary interop path (no binary installed), the long-lived process.

## Context

The user asked whether a truly headless screenshot framework is possible, then
set the real priority: **speed, with accuracy**. A window is fine if it is
faster. So the question becomes "what is the fastest accurate way to run the
scenario half of `tools/check.sh`", with headlessness as one candidate among
several, and the display-less route kept only as the CI / no-WSLg fallback.

Research done 2026-09-05 (verified, not assumed):

- **Windowless rendering is not possible in stock Godot 4.7/4.8.** `--headless`
  selects a dummy rasterizer; `get_viewport().get_texture().get_image()` is
  null (tested locally). Upstream: proposal #5790 open, PR #94530 abandoned
  draft, PR #103062 open Windows-only draft that still creates a hidden window.
  A windowless DisplayServer is C++ engine API only (not GDExtension), i.e. a
  fork, which is excluded. 4.8 dev snapshots (to dev 4, Aug 26) have nothing.
- **Display-less rendering is possible and upstream-endorsed:** Godot's own CI
  action runs rendered project tests under `xvfb-run` with Mesa llvmpipe
  (OpenGL) and lavapipe (Vulkan). But it is CPU rendering, so it is a
  *portability* win, not a speed win.
- **This machine:** WSLg with `DISPLAY=:0`, GPU passthrough (`d3d12_dri.so`),
  Mesa 26 with llvmpipe and lavapipe. No Xvfb, weston, docker, or Windows
  Godot binary installed. Fixture boots in 1.9 s on `/mnt/c`; FrogGame reports
  11 s on `/mnt/c` vs 1.4 s on the Linux filesystem.
- **The harness never unthrottles.** `scripts/dev/screenshot_harness.gd` sets
  no `Engine.max_fps` and never disables vsync, so every `wait N` costs at
  least N/60 s of wall time and every scenario runs at monitor pace. Godot has
  `--disable-vsync`, `--max-fps`, and `--fixed-fps` CLI flags, so this can be
  benchmarked before any code changes.

Assumption (from the user's "speed first" answer): no headless-Wayland or
web-export/Playwright spikes this round; both are recorded as rejected routes
with reasons.

## Verdict to record

Headless in the literal sense: no, not without a fork, and nothing upstream is
close. Display-less (virtual X server, CPU render): yes, today, one apt
package, and it is what the engine's own CI does. Faster: no, the CPU
rasterizer is slower than the WSLg GPU path already in use. Speed comes from
four other levers, each measured below: frame pacing, boot cost, parallelism,
and resolution.

## Phase 1: benchmark matrix (nothing committed until these are recorded)

All runs from Microbiome unless noted; each config run **twice**; record
wall time (`/usr/bin/time -f 'wall=%e'`), Godot's startup adapter line,
`md5sum shots/*.png`, exit code, engine-error count. Log to the scratchpad,
one file per row. Determinism = identical md5 set between the two runs.

Two things to know before reading the numbers:

- **The fixture is too small to show the pacing lever.** Its five scenarios
  total about 100 frames, under two seconds at 60 Hz, so unthrottling can
  save at most about a second and a half there. Add a wait-heavy scratch
  scenario (`wait 600`, `sleep 2`, `shot end`, written to the scratchpad;
  the harness opens an absolute path) and run it under each pacing config.
  FrogGame's 36-scenario suite (85 s today) is the real workload.
- **Prove vsync is actually off** with `--print-fps` in every pacing row:
  60 means the driver ignored the flag. Under WSLg's Xwayland the fallback
  is Mesa's `vblank_mode=0` environment variable.

| # | Lever | Command shape | What it answers |
|---|---|---|---|
| B1 | baseline | `tools/shoot.sh` (WSLg GPU, vsync on) | today's cost and whether GPU reruns are pixel-identical |
| B2 | pacing | `timeout 120 godot4 --path . --disable-vsync --max-fps 0 -- --scenario <all five> --seed 1` | how much vsync costs; whether tweens/timers still land (accuracy) |
| B3 | pacing + determinism | as B2 plus `--fixed-fps 60` | whether a frame-stepped clock keeps `wait N` meaning N/60 game seconds while rendering flat out, and whether reruns become pixel-identical |
| W1-W3 | pacing, isolated | the wait-heavy scratch scenario under B1, B2 and B3 flags | the unthrottle gain by itself: `wait 600` is 10 s at 60 Hz; W3 also shows `sleep 2` becoming 120 fast game frames under fixed-fps |
| B4 | resolution | B3 with `--resolution 640x360` | pixel cost; only worth it if B3 is still slow |
| B5 | CPU render cost | B3 with `LIBGL_ALWAYS_SOFTWARE=1` | what CI (llvmpipe) will cost relative to the GPU; adapter line must say llvmpipe |
| B6 | boot cost | `/usr/bin/time timeout 30 godot4 --headless --path <p> --quit` for Microbiome and FrogGame, on `/mnt/c` and after `cp -r` to `~/tmp/`; also with `--audio-driver Dummy` | whether filesystem location is the dominant cost for real projects, and whether PulseAudio init is worth skipping |
| B6b | boot cost, Windows binary | only after a Windows 4.7 **console** build is installed (none found here): `Godot_v4.7-stable_win64_console.exe --path "$(wslpath -w $PWD)" --quit-after 2` | the interop lever; also whether `timeout` kills it (it only kills the WSL stub; see step 3) |
| B7 | real workload | FrogGame: `tools/shoot.sh` as-is vs the B3 flags passed through (edit nothing; invoke godot4 directly with its scenarios) | the numbers that matter: 36 scenarios, today 85 s |
| B8 | parallelism | two shoot processes at once, half the fixture scenarios each, each with its own `XDG_DATA_HOME` (as `FrogGame/tools/test.sh` shards do) and its own shots directory | whether the sandbox collides and what the wall-time gain is. Note shot names already collide today: numbering restarts at 01 per scenario, so two scenarios that both `shot boot` overwrite each other; in parallel that becomes a race |
| B9 | fallback | after `sudo apt install xvfb` (user's call): `xvfb-run -a -s "-screen 0 1280x720x24" env LIBGL_ALWAYS_SOFTWARE=1 tools/shoot.sh` | that the CI path works with unchanged scripts; its cost vs B5 |

Accuracy gate for B2/B3: all five scenarios still pass, and the pause-menu
shots (tween-timed) look the same as B1 when viewed. If B2 breaks a
tween-timed shot but B3 does not, fixed-fps is the semantic to adopt.

## Phase 2: implementation, ordered by expected payoff per effort

1. **Unthrottle the harness, with a frame-stepped clock if B3 wins.**
   `scripts/dev/screenshot_harness.gd`: in `_ready` set `Engine.max_fps = 0`
   and `DisplayServer.window_set_vsync_mode(VSYNC_DISABLED)`; restore both in
   `_restore()`. `tools/shoot.sh`: pass `--disable-vsync` and, if B3 wins,
   `--fixed-fps ${SHOOT_FIXED_FPS:-60}` (0 disables); if B2 showed the
   driver ignoring `--disable-vsync`, also `export vblank_mode=0`. Document
   the semantic change: under the harness every wait is game time, so `sleep` no longer
   means wall-clock seconds (this resolves the Orbit vs FrogGame
   disagreement in the sibling survey in favour of a deterministic clock).
2. **Tier-1 runner fixes that the numbers need**, same files: per-scenario
   elapsed seconds on pass (`_run`), a `harness: renderer <adapter> / <driver>`
   line at start, `_shot` returns `ERROR: no rendered frame` on a null image
   instead of crashing (extract `static func capture(viewport) -> Image` so a
   headless GUT test can pin it), shots named
   `shots/<scenario-stem>-NN-<name>.png` so scenarios stop overwriting each
   other, `check.sh` drops its `SHOOT_TIMEOUT=300` pin, `shoot.sh`/`check.sh`
   grep `shader` beside script/parse errors.
3. **Boot cost.** `GODOT="${GODOT:-godot4}"` in test/check/shoot (FrogGame's
   change), and a `skip` line instead of a failure when `/usr/bin/time` is
   absent. Windows binary from WSL: when `$GODOT` ends in `.exe`, pass
   `--path "$(wslpath -w "$ROOT")"`, require the `_console.exe` build (the
   GUI build does not write stdout to a pipe, and shoot.sh greps the log),
   and on exit 124 run `taskkill.exe /F /IM <exe>` because `timeout` only
   kills the WSL interop stub. Record the B6 numbers in the research doc with
   a recommendation (Linux filesystem or a Windows binary) rather than code,
   since the choice is per machine; add a `note:` in check.sh when the root
   is under `/mnt/` and the boot was slow, if B6 justifies it.
4. **Scenario sharding.** `tools/shoot.sh` gains `SHOOT_JOBS` (default 1 until
   B8 proves the gain): deals scenario files across processes, each with its
   own `XDG_DATA_HOME` and a `--shots-dir` harness argument so PNGs do not
   collide, then merges the per-process summaries into the same greppable
   shape. Only `XDG_DATA_HOME` moves, not `XDG_CACHE_HOME`, so the shader
   cache stays warm. Per-process user data also makes concurrent `check.sh`
   runs safe, which is the whole reason NavalWar added a lock; the lock item
   in the roadmap is superseded by this. Side effect worth having: scenarios
   boot from default settings instead of the developer's saved ones. Fixture: `check.local.sh` runs the
   batch with `SHOOT_JOBS=2` and requires the same shot count.
5. **Display-less fallback and CI** (the agent-drafted mechanics, kept
   secondary). `shoot.sh`: detect a real display (`/tmp/.X11-unix/X<n>` or a
   Wayland socket); `SHOOT_DISPLAY=auto|real|xvfb`; the Xvfb branch runs
   `xvfb-run -a -s "-screen 0 <res>x24"` with `LIBGL_ALWAYS_SOFTWARE=1` and
   `--audio-driver Dummy`, under `timeout -k 5` so a timeout kills the X
   server; no display and no `xvfb-run` exits 2 with an install hint. Timeout
   under Xvfb scales by `SHOOT_SLOW`, set from B5/B9. `check.sh --ci` forces
   `SHOOT_DISPLAY=xvfb` and passes `CHECK_CI=1` to `check.local.sh`. New
   `.github/workflows/ci.yml` (on push and PR; installs `xvfb libgl1-mesa-dri
   mesa-vulkan-drivers time` plus the X libs the binary dlopens; installs
   Godot 4.7 as `export.yml` does; imports; runs `tools/check.sh --ci`;
   uploads `shots/` with `if: always()`). Add `ci.yml` to
   `tools/tooling-manifest.txt`. Fixture: `check.local.sh` forces one
   scenario through `SHOOT_DISPLAY=xvfb` when `xvfb-run` exists (skip line
   otherwise) so the branch is exercised on the WSLg machine where it would
   otherwise rot.
6. **Not this round, recorded as such:** long-lived game process fed by a
   command queue (roadmap tier 6), headless Wayland (weston; Godot #90612
   unresolved; no Wayland socket here despite the env var), web export +
   Playwright (adds Node, an export per run, a different renderer).

## Verification

- `tools/check.sh` under WSLg: green, same output shape, scenarios line shows
  the adapter and per-scenario seconds; total wall time recorded against B1.
- `tools/shoot.sh` twice: identical md5 set if fixed-fps was adopted, else the
  documented exception.
- `tools/test.sh test_screenshot_harness`: the null-capture test passes
  headless.
- FrogGame re-run with the new flags through its own (older) harness: the
  85 s batch number becomes the headline in the research doc.
- `SHOOT_JOBS=2 tools/shoot.sh`: same shot count, no sandbox collision, wall
  time recorded.
- If Xvfb is installed: `SHOOT_DISPLAY=xvfb tools/shoot.sh` green with
  `llvmpipe` in the renderer line; `DISPLAY=:77 tools/shoot.sh` auto-provisions;
  `tools/check.sh --ci` green locally. Push a branch and confirm the workflow
  is green with a viewable shots artifact, and that a deliberately broken
  scenario turns it red.
- `tools/sync-tooling.sh ../Template --check` reports the changed owned files;
  sync the Template afterwards and run its full check.

## Docs

- `docs/research/2026-09-05-fast-visual-loop.md` (new): the verdict above,
  the closed doors with dates, the benchmark table with numbers, the
  fixed-fps decision and why, boot-cost numbers per filesystem, sharding
  gain, the CI cost, and the rejected routes with reasons.
- `docs/roadmap.md`: strike the tier-1 items that landed, the `--ci`/`ci.yml`
  item, and "Devcontainer with Xvfb"; add "Not planned: windowless rendering
  until upstream #5790 lands"; note visual-regression `expect_shot` is now
  feasible if reruns are pixel-identical.
- `CLAUDE.md` rules, each with what breaks without it: the harness runs
  unthrottled on a frame-stepped clock so waits are game time (without it,
  scenarios are paced by the monitor and a `wait 10` covers different game
  time on different machines); scenarios need a display *server*, not a
  monitor, and `shoot.sh` starts Xvfb when there is none (without it the
  scenario half never runs in CI); pixel baselines are per rasterizer if B1
  vs B5 differ; `--headless` captures nothing and the harness says so.
- `README.md`: `check.sh --ci` in the loop table; the shoot line says a
  display server is found or started.
