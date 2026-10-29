# Kombucha

A Claude Code plugin for Godot 4 projects. It gives Claude a way to prove
a change without you at the keyboard: headless tests, scripted
screenshots it can look at, a debug console it can drive, and one check
command that says green or names what broke.

## TL;DR

```bash
curl -fsSL https://raw.githubusercontent.com/aboucher51/Kombucha/main/tools/setup.sh | bash
```

The setup script installs Godot 4.7 as `godot4`, this plugin and the two
plugins it pairs with, and the setting Claude's GDScript language server
needs. You can safely re-run it, and it says what it did (`--with-map` adds
the project map tool). Then, in Claude Code, `/new-godot-project MyGame`
scaffolds a project that starts green. Work in it. Run `tools/check.sh` and
get green before any commit. `/sync-godot-tooling` keeps the tooling
current.

Or by hand:

```bash
claude plugin marketplace add aboucher51/Kombucha
claude plugin install kombucha@kombucha
```

## Requirements

- Linux, or Windows with WSL2 and WSLg. Keep projects on the Linux
  filesystem, not `/mnt/c`.
- Godot on the PATH as `godot4`, at the patch version that `tools/GODOT_VERSION` pins (4.7.2 today). The setup script installs it.
- `git`, `python3`, `curl`.
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

You cannot drop the tooling into an existing project, because the tooling
names the kit's autoloads. Adopt the kit first, or start fresh.

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
`press ui_accept`, `assert_visible PauseMenu`, `shot title`. The harness
sends unknown lines to the debug console (F12 in the game), so a console command and a
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

Send an improvement that belongs to everyone back with
`/update-kombucha`. That skill needs a clone of this repo (`GODOT_TOOLING`),
not the installed plugin.

## Developing Kombucha

This repo is the workshop, the fixture and the scaffold, not a game. If
the fixture cannot exercise a tooling change, extend the fixture in the
same commit. Keep `tools/check.sh` green. `tools/selftest.sh` proves the
runner's guards, the sync and the scaffolder against scratch copies.
`CLAUDE.md` is the contract. `docs/roadmap.md` is the order of work.
`docs/research/` holds the surveys behind the design. To release, bump the
version in `.claude-plugin/plugin.json` and `marketplace.json`.

## Features and capabilities

- **Test runner**: GUT 9.7.1, headless, dealt across parallel shards
  balanced by the last run's timings. A test file that fails to parse
  counts as a failure, not a silent drop. Each run writes a merged JUnit
  report.
- **Screenshot harness**: plain-text scenarios with `click`, `click_at`,
  `hover`, `press`, `scroll_to`, `wait` / `ticks` / `sleep` / `settle`,
  `shot` (full or 1:1 crop), `assert_visible`, `assert_onscreen`,
  `assert_tooltip`, `expect_shot` against committed per-renderer
  baselines with masks, `frame_budget`, and state readback (`state`,
  `assert key value`) from any node that opts in.
- **Runs on a display Claude can find or start**: WSLg with GPU
  rendering where offered, Xvfb in CI. The harness deals scenarios across
  processes, each one sandboxed (saves, settings, keybinds, cursor, locale reset) and
  returned to the boot scene.
- **Serve mode**: one engine kept alive, answering scenario files and
  single lines against its live state in under a tenth of a second.
- **Debug console**: F12, JSON-declared commands with typed arguments and
  usage, the same `execute(line)` seam the scenarios use, project
  commands through hooks that the console asks first.
- **One check command**: tests, a headless boot with an engine-error
  count and a memory budget, project checks, every scenario. It names what
  failed, and prints a note when the tooling copy is behind.
- **Export**: Linux, Windows and Web release builds for every declared
  preset. It fetches templates on first run and smoke-tests the binary.
  CI workflows run tests, scenarios and tagged exports.
- **Kit**: autoloads for events, saves (redirectable paths, schema
  migration, refusals with reasons), keybinds (conflict groups,
  controllers through one router), audio and game state. A UI theme built
  from nine palette constants. Window-scaled chrome with sharp text.
  Localization with a pseudo-locale that exposes hardcoded strings. A bug
  report that never fails to build.
- **Headless drivers**: a skeleton for sims, balance gates and linters
  that run as an autoload behind a `--flag` and exit with a verdict.
- **A contract, not a wiki**: every convention in `CLAUDE.md` states the
  rule and what breaks without it, learned across ten projects. The
  tooling rules are one owned text that every project imports.
- **Sync with drift report**: before overwriting an owned file, the sync
  names the lines a project added beyond the version it matches. The kit
  report says which kit files are behind and by what.

## License

MIT (`LICENSE`). `LICENSES.md` lists the third-party pieces.
