# Kombucha

A Claude Code plugin for Godot 4 projects: the loop by which Claude edits
a project, proves the change headlessly, looks at it through scripted
screenshots, and reads the result back, without a human at the keyboard.

You get, in every project scaffolded with it:

- `tools/test.sh` — GUT 9.7.1, headless, dealt across parallel shards,
  with the guard four projects each needed: a test file that fails to
  parse is a failure, not a silent drop.
- `tools/shoot.sh` and `scenarios/*.txt` — plain-text screenshot
  scenarios (`click`, `press`, `shot`, `assert_visible`, `expect_shot`
  against committed baselines, state readback), run on a display Claude
  can find or start. `tools/serve.sh` keeps one engine alive to iterate
  against.
- A debug console (F12) whose `execute(line)` is the same vocabulary the
  scenarios use, so every command is scriptable and assertable.
- `tools/check.sh` — tests, a headless boot with a memory budget, your own
  local checks, every scenario. Green is the bar for a commit.
- `tools/export.sh` and CI workflows — Linux, Windows and Web builds,
  smoke-tested.
- `docs/godot-tooling.md`, imported into the project's `CLAUDE.md`: every
  rule with what breaks without it, learned across ten projects.

## Requirements

- Linux, or Windows with WSL2 and WSLg (screenshots need a display; the
  project should live on the Linux filesystem, not `/mnt/c`).
- Godot 4.7 on the PATH as `godot4`.
- `git`, `python3`, `curl`. Optional: `xvfb-run` for `check.sh --ci`;
  [godot-map](https://github.com/aboucher51/godot-map) for the project
  map `check.sh` reads when present.
- Claude Code. The [GodotPrompter](https://github.com/jame581/GodotPrompter)
  plugin pairs well: it decides *how* to build Godot systems, this decides
  how to prove them.

## Install

```bash
claude plugin marketplace add aboucher51/Kombucha
claude plugin install kombucha@kombucha
```

Then, in Claude Code:

- `/new-godot-project <Name>` scaffolds a project from the
  [Template](https://github.com/aboucher51/Template) repo, which carries
  the kit the tooling assumes (autoloads for saves, keybinds, audio,
  pads; a code-built UI theme) and a copy of this tooling. It clones the
  Template next to your projects on first use.
- `/sync-godot-tooling` in any such project refreshes its copy from the
  plugin's version and says what the project had changed in an owned
  file before overwriting it. `tools/check.sh` prints a note when the
  copy is behind.
- `/update-template` backports a kit improvement to the Template.

The tooling is not a drop-in for an arbitrary existing project: the
harness and console name the Template's autoloads. Adopting it in an
existing project means adopting the kit first.

## Extending it in a project

A project never edits an owned file (the list is
`tools/tooling-manifest.txt`; a sync overwrites them). It extends through
three files a sync never touches, seeded on first sync:

| File | What goes there |
|---|---|
| `scripts/dev/dev_hooks.gd` | sandbox resets, project scenario commands, console handlers; asked before the shared ones, so a project may take a core command over |
| `data/console_commands.project.json` | the surface (name, usage, args) of project console commands |
| `tools/check.local.sh` | project checks: sims, balance gates, linters |

## Developing the tooling

This repo is the workshop and the fixture, not a game. The main scene,
autoloads, tests and scenarios here are the smallest project the tooling
needs in order to exercise itself; a tool change the fixture cannot
exercise needs the fixture extended in the same commit.

```bash
tools/check.sh              # the bar: tests + boot + local checks + every scenario
tools/check.sh --quick      # no display needed
tools/selftest.sh           # the runner's guards and the sync script against scratch copies
```

`CLAUDE.md` is the contract, `docs/roadmap.md` the order of work,
`docs/research/` the surveys the design came from. To work from a clone
rather than the installed plugin, set `GODOT_TOOLING` to the clone.

## Layout

- `.claude-plugin/` — plugin and marketplace manifests. `skills/` — the
  three skills above.
- `tools/` — the scripts, `sync-tooling.sh` and its manifest, `seeds/`
  for a project's extension files, `new-project.sh` (used from the
  Template).
- `scripts/dev/` — screenshot harness, debug console, bug report, and the
  fixture's `dev_hooks.gd`. `data/console_commands.json` is the console's
  core command table.
- `tests/`, `.gutconfig.json`, `addons/gut/` — GUT and the fixture's suite.
- `scenarios/` — harness scripts; `scenarios/baselines/<renderer>/` the
  committed `expect_shot` frames, one set per rasterizer.
- `scripts/autoloads/`, `scripts/ui/`, `scripts/util/`, `scenes/` — the
  fixture game.

## License

MIT (see `LICENSE`). Third-party pieces are listed in `LICENSES.md`.
