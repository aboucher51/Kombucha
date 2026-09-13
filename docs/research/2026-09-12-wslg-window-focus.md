# The scenario window takes the keyboard under WSLg: what was measured

Date: 2026-09-12, on the WSL2 machine (WSLg, two monitors: 3440x1440
primary and 1920x1080 at x=3440; Godot 4.7.2; Mesa 26, d3d12 on an RTX
3080). The complaint: every `shoot.sh` batch puts the engine window on the
primary monitor and takes focus from the editor, once per process.

## Method

A PowerShell probe run from WSL every ~0.7 s during a scenario:
`GetForegroundWindow` plus its title, class and owning process, and an
`EnumWindows` pass listing the WSLg host's (`msrdc.exe`) visible
`RAIL_WINDOW`s with their rects. X-side facts came from a ctypes
`XQueryTree` dump while the engine ran.

## Results

| Launch | Foreground during the run | Notes |
|---|---|---|
| as today (real display) | the Godot window, then the editor again when it quit | window at 1080,360 on the primary |
| `--screen 1` | the Godot window | moved, still activated |
| `display/window/size/no_focus=true` (via `override.cfg`) | a `RAIL_WINDOW` with an EMPTY title, same rect | X focus stayed off (the title never arrives), Windows activated it anyway |
| `--wid <unmapped X window>` | a RAIL window titled "top-level window" | the engine MAPS the parent it is given and creates its own window as a top-level beside it |
| Xvfb (`GALLIUM_DRIVER=d3d12`) | the editor, throughout | no Windows-side window at all; renderer `D3D12 (NVIDIA GeForce RTX 3080)`; 17/17 scenarios green including the `expect_shot` boot baseline made on the real display |

So the harness's existing `WINDOW_FLAG_NO_FOCUS` (set in `_ready()`, after
the map) and the engine's own no-focus setting both address X focus, and
the thing that takes the keyboard is Windows activating every new RAIL
window. No engine flag reaches that; a search of the WSLg issue tracker
found no configuration knob for it either (microsoft/wslg #894, #895).

## Xvfb on WSLg needs TCP

`/tmp/.X11-unix` is a read-only tmpfs under WSLg, so Xvfb cannot bind its
unix socket and `xvfb-run`'s default (`-nolisten tcp`) leaves it with no
listener at all, which is fatal. `xvfb-run -l` makes it listen on TCP
(cookie-authenticated through xvfb-run's auth file), and a client given
`DISPLAY=:N` falls back to TCP on localhost by itself when the socket is
missing (libxcb), so nothing else changes. Proven with the Ubuntu `xvfb`
package extracted unprivileged (no sudo on this machine at the time):
`xvfb-run -l -a` ran the tooltip and baseline scenarios green on the GPU.

## The GPU under Xvfb

Mesa reaches WSLg's d3d12 driver through its software winsys (there is no
DRM device), so `GALLIUM_DRIVER=d3d12` works on Xvfb exactly as it does on
Xwayland: same adapter name, same pixels. The kit's earlier assumption
that the virtual display means llvmpipe was only true for CI, where there
is no d3d12 driver. `SHOOT_GPU=0` keeps that path for making CI baselines.

## Adopted

`shoot.sh` and `serve.sh` prefer the virtual display whenever `xvfb-run`
is installed (`SHOOT_DISPLAY=auto`), pass `-l` when the socket directory
is not writable, use the GPU on either display, and scale the timeout
only when actually rendering in software. `check.sh --ci` pins
`SHOOT_GPU=0` so it reproduces CI's rasterizer, and `check.local.sh`
proves the virtual display with both rasterizers when the package is
present. `SHOOT_DISPLAY=real` remains for watching the window.

## Not adopted

- `--screen <N>` / `--position` as a fix: the window is still activated.
- The `no_focus` project setting or an `override.cfg` written per run: no
  effect on the Windows side, and a leftover file would ship a game that
  never takes focus.
- A Windows-side refocus after launch: `SetForegroundWindow` from a
  background process is refused by the foreground lock, and the harness
  would grow a platform branch.
- The Wayland display driver: Weston activates new toplevels the same way,
  and `Input.warp_mouse` (the harness's real-cursor hover) does not exist
  under Wayland.
