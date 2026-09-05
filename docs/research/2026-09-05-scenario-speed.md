# Scenario loop speed: what was measured and what was adopted

Date: 2026-09-05. The benchmark half of `docs/plans/2026-09-05-fast-visual-loop.md`,
run on the WSL2 machine (12 cores, Mesa 26, Godot 4.7.1). Every row was run
at least twice; wall time is `/usr/bin/time`, pixels are the md5 of the shot
set.

## The renderer is llvmpipe, not the GPU

The harness's new `harness: renderer` line answered the first question
before any benchmark ran: under WSLg, Godot's OpenGL driver lands on Mesa's
**llvmpipe** (software), not the d3d12 passthrough. The whole loop here is
CPU-rendered already, and the Xvfb fallback for CI renders with the same
rasterizer, so CI cost equals local cost.

## Pacing: not a lever here; fixed-fps rejected

| Config | Fixture, 7 scenarios | Wait-heavy (`wait 600`, `sleep 2`) | Pixels |
|---|---|---|---|
| as-is (vsync nominally on) | 2.80 s / 2.80 s | 5.61 s, peak 399 fps | identical |
| `--disable-vsync --max-fps 0` | 2.90 s / 2.90 s | 5.60 s, peak 403 fps | identical |
| plus `--fixed-fps 60` | 2.80 s / 2.80 s | 3.90 s | identical |

WSLg's Xwayland never throttles to a vblank: the game already runs at
~400 fps with vsync "on", so unthrottling changes nothing. The fixture's
scenarios cost 0.0 to 0.3 s each; the process boot (1.9 s) is the rest.

`--fixed-fps 60` made the wait-heavy scratch scenario faster (a 2 s
`sleep` becomes 120 fast frames) but the real workload **slower**:

| FrogGame, 36 scenarios, one process | Wall |
|---|---|
| as-is | 204 s |
| `--disable-vsync --max-fps 0 --fixed-fps 60` | 255 s |

The reason is the one the plan feared in the other direction: fixed-fps
advances game time by exactly 1/60 per frame, so whenever a frame takes
LONGER than 1/60 s (heavy scenes on llvmpipe) game time runs slower than
wall time and every tween and animation takes longer to finish. Rejected.
Reruns were pixel-identical without it, so determinism did not need it
either.

## Boot cost: the filesystem is the lever

| Project | On `/mnt/c` (WSL bridge) | On the Linux filesystem |
|---|---|---|
| Kombucha fixture (small) | 1.8–1.9 s | not measured |
| FrogGame (428 MB) | 10.7–10.9 s | 0.7–0.8 s |

Every process pays it: each test shard, the boot check, each scenario
shard. FrogGame's own note ("85 s natively") against the 204 s measured
here on `/mnt/c` says the whole scenario suite runs about 2.4× faster from
the Linux filesystem, not only the boot. `check.sh` now prints a note when
the checkout is under `/mnt`.

## Parallel scenario shards: adopted

Two halves of FrogGame's suite with separate `XDG_DATA_HOME`: **164 s
against 204 s** (both halves green, 36 of 36). llvmpipe is itself
multi-threaded, so shards contend for the same cores; the gain grows as
boot cost shrinks (on the Linux filesystem the fixed cost per shard is
under a second). `shoot.sh` now deals scenarios across `SHOOT_JOBS`
processes (auto: 2 for four or more scenarios) longest-first from the last
run's per-scenario seconds, and every process gets its own
`XDG_DATA_HOME`, which also retires the lock on `check.sh`.

Consequence for scenario authors: scenarios are reordered and split, so no
scenario may depend on another having run first (the two-part hooks
scenario became one, with the cross-scenario reset pinned by a unit test).

## Slowest scenarios (FrogGame, as-is)

18.3 s tactics_verbs, 13.7 s skirmish_combat, 10.9 s threat_display,
9.1 s hd2d, 8.2 s curtain_drift. Per-scenario seconds are now printed on
every pass so this list is always current.

## Not measured

Xvfb (not installed here; the code path ships and CI exercises it), a
Windows binary through interop (none installed), resolution 640x360
(pointless with pacing off the table).

## Decisions

- Adopted: per-process user data, `SHOOT_JOBS`, per-scenario timings,
  the `/mnt` note, the renderer line, Xvfb fallback for CI.
- Rejected: `--fixed-fps` and vsync flags (no gain, real loss on heavy
  scenes), resolution changes.
- Recommendation for every project on this machine: clone under the Linux
  filesystem for the loop, or point `GODOT` at a Windows binary.
