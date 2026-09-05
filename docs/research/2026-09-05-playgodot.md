# PlayGodot, examined

Companion to `2026-09-05-prior-art.md`. Date: 2026-09-05.

## What it is

An external test driver for Godot games, modelled on Playwright. A Python
client (`pip install playgodot`, MIT, 38 stars) launches Godot with
`--remote-debug tcp://127.0.0.1:6007`, and the engine connects back to the
Python process using the stock RemoteDebugger wire format (4-byte length,
message name string, array of binary Variants). The Python side then sends
`automation:*` commands and awaits the replies.

The engine side is a fork, `Randroids-Dojo/godot`, branch `automation`.
The automation commands are implemented in C++ inside
`core/debugger/remote_debugger.cpp` (594 added lines, 27 in the header),
so no addon is needed in the game project.

## Command surface

Node access: `get_node`, `get_property`, `set_property`, `call_method`,
`scene_tree`, `query_nodes` (glob pattern), `count_nodes`. Scene control:
`current_scene`, `change_scene`, `reload_scene`, `pause`, `time_scale`,
`wait_signal`. Input: `inject_mouse_button`, `inject_mouse_motion`,
`inject_key`, `inject_action`, `inject_touch`. Capture: `screenshot`
(whole viewport or the viewport of a named CanvasItem) returned as PNG
bytes.

The Python API wraps these as `click(path)`, `drag(a, b)`, `press_key`,
`type_text`, `press_action`, `hold_action`, `tap`, `swipe`, `pinch`,
`wait_for_node`, `wait_for_visible`, `wait_for_signal`, `wait_for(lambda)`,
`screenshot`, `compare_screenshot` (mean squared error similarity),
`assert_screenshot(reference, threshold)`, and a `launch(scene=...)` option
to boot a specific scene instead of the main one.

## The headless claim does not hold

The README defaults `headless=True` and lists screenshots as a feature.
The fork's screenshot handler is:

```cpp
image = viewport->get_texture()->get_image();
```

Under `--headless` the display driver is `headless` and the rendering
driver is `dummy`, so there is no texture. Verified locally on Godot 4.7
with a ten-line SceneTree script: headless prints `Parameter "t" is null`
and the image is null; the same script under WSLg returns a 1152×648
image with the expected red pixel. PlayGodot's `_send_screenshot` sends an
empty byte array in that case. Its own example suite launches with
`headless=True` and contains no screenshot test.

So PlayGodot has the same constraint as our `shoot.sh`: a display (WSLg,
Xvfb) is needed for pixels. The upstream `--offscreen` proposal
(godot-proposals #5790, PR #94530) is still an open draft.

What the fork's headless work actually fixed is **GUI hit-testing**. The
stock `DisplayServerHeadless` reports a 0×0 window, so injected mouse
events never land on a Control. The fork gives it a `window_size` set
from `--resolution` and calls `process_events()` after each injection.
That is a real finding for our own headless UI smoke tests: under
`--headless`, `get_viewport().get_visible_rect()` is not what a scenario
expects, and a synthesised click can miss. Our harness never runs
headless so we have not hit it, but a headless `click` in a GUT test
would.

## Was the fork necessary?

Mostly no. Stock Godot 4 exposes
`EngineDebugger.register_message_capture(name, callable)` to GDScript,
which is exactly the hook the fork uses in C++: any `name:cmd` message
arriving over `--remote-debug` is routed to the callable. An autoload
registering an `automation` capture could implement every command above
in GDScript with no engine changes, and the Python client would not know
the difference. PlayGodot in fact started that way (v0.1 was a WebSocket
addon) and removed the addon in January 2026 in favour of the fork, citing
process isolation and "no changes to your game project". The only piece
that genuinely needs C++ is the headless window-size patch.

## Maintenance picture

- Fork is 18 commits ahead of upstream and 3594 behind as of today; last
  automation commit 2026-01-27; based on Godot 4.6.
- One pre-built release (`automation-latest`, 2025-12-07): Linux x86_64
  and macOS universal. No Windows binary.
- PlayGodot last commit 2026-02-02 (v0.5.1). Roadmap to 1.0 is unchecked.
- Several branches on the fork are named `claude/fix-...`; the project is
  substantially agent-written and single-maintainer.

Adopting it means building or trusting a 4.6-era engine binary for every
developer machine and CI, and losing the 4.7 features our projects use.

## What is worth taking

Not the tool. Three ideas from it:

1. **An external driver over the native debugger port is possible without
   a fork**, via `EngineDebugger.register_message_capture`. If we ever
   want a long-lived game instance that Claude talks to (the command-queue
   idea from the sibling-project survey), this is a socket-based
   alternative to file polling, and it reuses a port and protocol Godot
   already owns.
2. **`wait_for_signal`, `wait_for_visible`, `wait_for(condition)`** as
   first-class waits. Same conclusion as FrogGame's `settle`: waits should
   be conditions, not frame counts.
3. **`launch(scene=...)`** to boot one scene in isolation. Our scenarios
   always boot the main scene; a `--scene` argument to the harness would
   make UI scenes cheaper to shoot.

And one caution: "headless screenshots" in any tool's README should be
checked against its capture code before it changes a design decision.
