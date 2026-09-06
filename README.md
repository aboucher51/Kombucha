# Kombucha

A Claude Code plugin for Godot 4 projects. It gives Claude a way to prove
a change without you at the keyboard: headless tests, scripted
screenshots it can look at, a debug console it can drive, and one check
command that says green or names what broke.

## TL;DR

```bash
curl -fsSL https://raw.githubusercontent.com/aboucher51/Kombucha/main/tools/setup.sh | bash
```

That installs Godot 4.7 as `godot4`, this plugin and the two it pairs
with, and the setting Claude's GDScript language server needs; it is
safe to re-run and says what it did (`--with-map` adds the project map
tool). Then in Claude Code: `/new-godot-project MyGame` scaffolds a
project that starts green. Work in it; `tools/check.sh` is the bar
before any commit. `/sync-godot-tooling` keeps the tooling current.

Or by hand:

```bash
claude plugin marketplace add aboucher51/Kombucha
claude plugin install kombucha@kombucha
```

## Requirements

- Linux, or Windows with WSL2 and WSLg. Keep projects on the Linux
  filesystem, not `/mnt/c`.
- Godot 4.7 on the PATH as `godot4`; `git`, `python3`, `curl`.
- Optional: `xvfb-run` for CI-style runs, [godot-map](https://github.com/aboucher51/godot-map)
  for a project map Claude reads before grepping, and the
  [GodotPrompter](https://github.com/jame581/GodotPrompter) plugin, which
  decides *how* to build Godot systems while this decides how to prove them.

## Your first project

`/new-godot-project MyGame` creates `~/godot-projects/MyGame` with a kit
(save system, keybinds, audio, controller routing, a code-built UI
theme, a placeholder boot scene), the tooling, and a `CLAUDE.md` whose
every rule says what breaks without it. It imports, checks and makes the
first commit, so you start from green.

The tooling is not a drop-in for an existing project: it names the kit's
autoloads. Adopt the kit first, or start fresh.

## The loop

```bash
tools/check.sh              # tests + headless boot + your checks + every scenario
tools/check.sh --quick      # the same without scenarios (no display needed)
tools/test.sh               # just the GUT suite
tools/shoot.sh              # just the screenshot scenarios
tools/serve.sh start        # one engine kept alive; feed it scenario lines
tools/export.sh             # release builds for every preset, smoke-tested
```

Scenarios are plain-text files in `scenarios/`: `click PlayButton`,
`press ui_accept`, `assert_visible PauseMenu`, `shot title`. Unknown lines
go to the debug console (F12 in the game), so a console command and a
scenario line are one vocabulary. Claude writes a scenario for what it is
working on, runs it, and reads the shots and state back.

## Extending it in a project

Everything in `tools/tooling-manifest.txt` is a synced copy that
`/sync-godot-tooling` overwrites. A project extends through three files
the sync never touches:

| File | What goes there |
|---|---|
| `scripts/dev/dev_hooks.gd` | sandbox resets, scenario commands, console handlers |
| `data/console_commands.project.json` | the surface of project console commands |
| `tools/check.local.sh` | project checks: sims, balance gates, linters |

An improvement that belongs to everyone goes back with
`/update-kombucha`, which needs a clone of this repo (`GODOT_TOOLING`)
rather than the installed plugin.

## Developing Kombucha

This repo is the workshop, the fixture and the scaffold, not a game. A
tooling change the fixture cannot exercise needs the fixture extended in
the same commit; `tools/check.sh` green is the bar; `tools/selftest.sh`
proves the runner's guards, the sync and the scaffolder against scratch
copies. `CLAUDE.md` is the contract, `docs/roadmap.md` the order of work,
`docs/research/` the surveys behind the design. Releases are a version
bump in `.claude-plugin/plugin.json` and `marketplace.json`.

## Features and capabilities

- **Test runner**: GUT 9.7.1, headless, dealt across parallel shards
  balanced by the last run's timings; a test file that fails to parse is
  a failure, not a silent drop; a merged JUnit report per run.
- **Screenshot harness**: plain-text scenarios with `click`, `click_at`,
  `hover`, `press`, `scroll_to`, `wait` / `ticks` / `sleep` / `settle`,
  `shot` (full or 1:1 crop), `assert_visible`, `assert_onscreen`,
  `assert_tooltip`, `expect_shot` against committed per-renderer
  baselines with masks, `frame_budget`, and state readback (`state`,
  `assert key value`) from any node that opts in.
- **Runs on a display Claude can find or start**: WSLg with GPU
  rendering where offered, Xvfb in CI; scenarios dealt across processes,
  each sandboxed (saves, settings, keybinds, cursor, locale reset) and
  returned to the boot scene.
- **Serve mode**: one engine kept alive, answering scenario files and
  single lines against its live state in under a tenth of a second.
- **Debug console**: F12, JSON-declared commands with typed arguments and
  usage, the same `execute(line)` seam the scenarios use, project
  commands through hooks that are asked first.
- **One check command**: tests, a headless boot with an engine-error
  count and a memory budget, project checks, every scenario; names what
  failed; a note when the tooling copy is behind.
- **Export**: Linux, Windows and Web release builds for every declared
  preset, templates fetched on first run, the binary smoke-tested; CI
  workflows for tests, scenarios and tagged exports.
- **Kit**: autoloads for events, saves (redirectable paths, schema
  migration, refusals with reasons), keybinds (conflict groups,
  controllers through one router), audio, game state; a UI theme built
  from nine palette constants; window-scaled chrome with sharp text;
  localization with a pseudo-locale that exposes hardcoded strings; a bug
  report that never fails to build.
- **Headless drivers**: a skeleton for sims, balance gates and linters
  that run as an autoload behind a `--flag` and exit with a verdict.
- **A contract, not a wiki**: every convention in `CLAUDE.md` states the
  rule and what breaks without it, learned across ten projects; the
  tooling rules are one owned text every project imports.
- **Sync with drift report**: before overwriting an owned file, the sync
  names the lines a project added beyond the version it matches; the kit
  report says which kit files are behind and by what.

## License

MIT (`LICENSE`). Third-party pieces are listed in `LICENSES.md`.
