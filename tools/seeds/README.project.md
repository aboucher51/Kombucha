# A Godot project

Scaffolded from [Kombucha](https://github.com/aboucher51/Kombucha): Godot
4.7 (GL Compatibility, GDScript) with testing, a screenshot harness, a
debug console and Claude Code conventions wired in from day one.

## What's inside

- **`CLAUDE.md`** — the working contract for Claude Code: every convention
  with what breaks without it. Add this project's own rules to it as they
  earn their place. It imports `docs/godot-tooling.md`, the tooling's
  rules, which `/sync-godot-tooling` keeps current.
- **`tools/check.sh`** — tests + headless boot (with a memory budget) +
  your local checks + every scenario, in one command. `--quick` skips the
  scenarios (no display needed). Green is the bar for a commit.
- **`tools/test.sh`** — GUT suite (vendored in `addons/gut`, tests in
  `tests/`), headless, across parallel shards.
- **`tools/shoot.sh`** / **`tools/serve.sh`** — the screenshot harness.
  Plain-text scenarios in `scenarios/` drive the game and capture PNGs
  into `shots/`; see `scenarios/example.txt`.
- **`tools/export.sh`** — release builds for every preset in
  `export_presets.cfg`, smoke-tested; CI runs it on `v*` tags.
- **Autoloads** — `EventBus`, `SaveManager` (redirectable paths, so tests
  never touch real saves), `Keybinds` (conflict-group rebinding),
  `AudioManager`, `GameManager`, `Pads` (one router for controllers), and
  a **debug console** on F12 whose vocabulary the scenarios share.
- **UI kit** (`scripts/ui/`) — `UITheme` (the whole look from nine palette
  constants, built in code), `PauseMenu`, `UiScaleRoot`.
- **Utilities** (`scripts/util/`) — `DataMerger`, `FunctionRegistry`,
  `L10n`, `BugReport`, `SaveCompat`.
- **Your seams** — `scripts/dev/dev_hooks.gd`,
  `data/console_commands.project.json` and `tools/check.local.sh` are
  yours; everything `tools/tooling-manifest.txt` lists is a synced copy
  that `/sync-godot-tooling` overwrites.
- **`scenes/main.tscn`** + **`scripts/main.gd`** — a placeholder boot
  scene meant to be replaced; the pause menu, theme, UI-sound wiring and
  harness seams (`state_text`, `is_busy`) in it are working examples.
- **`LICENSES.md`** — third-party ledger; every third-party addition gets
  a row in the same commit.
