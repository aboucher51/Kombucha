# Godot project template

A Godot 4.7 (GL Compatibility, GDScript) scaffold with testing, a screenshot
harness, and Claude Code conventions wired in from day one.

## Starting a new project

```bash
tools/new-project.sh ../MyGame "My Game"
```

This copies the template (minus `.godot/` and `shots/*.png`), sets the
project name in `project.godot`, initialises a git repo, and runs the import
plus the full check so you start green. Or do it by hand: copy the directory,
edit `config/name` in `project.godot`, delete this section of the README.

## What's inside

- **`CLAUDE.md`** — working conventions for Claude Code, including the
  GodotPrompter skill-first rule. Add project-specific conventions to it as
  they earn their place.
- **`tools/check.sh`** — tests + headless boot (with a memory budget) + all
  scenarios, in one command. `--quick` skips scenarios (no display needed).
- **`tools/test.sh`** — GUT suite (vendored in `addons/gut`, tests in
  `tests/`), headless.
- **`tools/shoot.sh`** — screenshot harness. Plain-text scenarios in
  `scenarios/` drive the game and capture PNGs into `shots/`; see
  `scenarios/example.txt` and the harness section of `CLAUDE.md`.
- **`tools/export.sh`** — Linux + Windows release builds (PCK embedded),
  auto-fetches export templates on first run, smoke-tests the built binary.
  CI runs it on `v*` tags (`.github/workflows/export.yml`).
- **Autoloads** — `EventBus`, `SaveManager` (redirectable paths so tests
  never touch real saves), `Keybinds` (conflict-group rebinding, `key:F5`
  storage), `AudioManager` (SFX pool with pitch variance, unscaled-time
  music crossfade, semantic `ui_event()` sound map, debounced persistence),
  `GameManager` (pause, scene changes, autosave on quit), and a
  **debug console** on F12 (`data/console_commands.json` + closed-match
  handlers; scenarios share its vocabulary).
- **UI kit** (`scripts/ui/`) — `UITheme` (whole look from nine palette
  constants, built in code), `PauseMenu` + `VolumeSliders` (working on
  Escape from boot), `UiScaleRoot` (window-scaled chrome with sharp text).
- **Utilities** (`scripts/util/`) — `DataMerger` (deep-merge/patch for
  layered data), `FunctionRegistry` (string-id → Callable hooks), `L10n`
  (namespaced translation keys + fallback), `BugReport` (zip of save +
  settings + log tail, degrade-never-error).
- **Placeholder audio** — `tools/generate_placeholder_audio.py` synthesized
  the UI sound set in `assets/audio/`; replace files, keep event names.
- **`/update-template` skill** (`.claude/skills/`) — from any scaffolded
  project, backports an improvement into this template: generalizes it,
  runs the template's checks, commits here.
- **`.claude/settings.json`** — pre-approved permissions for the tools above,
  so a fresh project doesn't re-prompt.
- **`LICENSES.md`** — third-party ledger; every third-party addition gets a
  row in the same commit. **`claude-log.md`** — gitignored session memory,
  appended by the global PostCompact hook.
