# Microbiome

The home of the Godot-to-Claude workflow: the loop by which Claude Code
edits a Godot project, proves the change headlessly, looks at it through
scripted screenshots, and reads the result back. The loop is iterated here
and backported to the `Template` repo, from which every real game project
is scaffolded.

This is not a game. The main scene, autoloads, tests and scenarios in this
repo are a **fixture**: the smallest working project the tooling needs in
order to exercise itself. Keep it small. Anything that only a game would
want goes in a game.

## The loop

```bash
tools/test.sh               # GUT suite, headless
tools/check.sh --quick      # tests + headless boot with a memory budget
tools/check.sh              # ...plus every scenario through the harness
tools/check.sh --ci         # the same on a virtual display (Xvfb), for CI
tools/shoot.sh              # screenshot scenarios only, dealt across
                            # SHOOT_JOBS processes; finds or starts a display
tools/export.sh             # Linux + Windows builds, smoke-tested
```

`CLAUDE.md` is the contract: every rule in it names what breaks without
it, and every tool above is what lets Claude say "this works" without a
human at the keyboard.

## How other projects get it

Every project carries a copy of the paths in `tools/tooling-manifest.txt`,
stamped with the Microbiome commit in `tools/TOOLING_VERSION`. The global
`/sync-godot-tooling` skill (which runs `tools/sync-tooling.sh`) refreshes
the copy, and each project's `check.sh` says when it is behind. Projects
extend the tooling only through `scripts/dev/dev_hooks.gd`,
`data/console_commands.project.json` and `tools/check.local.sh`; seeds for
those are in `tools/seeds/`.

## Working here

1. Read `docs/roadmap.md` for what is next and why.
2. Change the tooling, then prove it against the fixture with
   `tools/check.sh`. A tooling change that the fixture cannot exercise
   needs the fixture extended in the same commit.
3. Record what was learned in `CLAUDE.md` (rule plus failure mode) or
   `docs/research/` (findings).
4. Backport with the `/update-template` skill so new projects inherit it.
   The Template remains the source for `tools/new-project.sh`; do not
   scaffold games from this repo.

## Layout

- `tools/` — the runner scripts above, `sync-tooling.sh` and its manifest,
  `seeds/` for a project's extension files, `check.local.sh` (the fixture's
  own local check), and `new-project.sh` (the scaffolder, iterated here,
  used from Template).
- `scripts/dev/` — the screenshot harness, debug console, bug report, and
  `dev_hooks.gd`, the fixture's project extension. `data/console_commands.json`
  is the console's core command table; the `.project.json` beside it is
  the fixture's.
- `tests/`, `.gutconfig.json`, `addons/gut` — GUT 9.7.1 and the fixture's
  suite.
- `scenarios/` — plain-text harness scripts, one command per line.
- `scripts/autoloads/`, `scripts/ui/`, `scripts/util/`, `scenes/` — the
  fixture game.
- `docs/research/` — surveys of prior art, the sibling projects' test
  tooling, and PlayGodot. `docs/roadmap.md` — the iteration order they
  produced.
- `.claude/` — pre-approved permissions for the tools, and the
  `update-template` skill.
- `LICENSES.md` — third-party ledger. `claude-log.md` — gitignored
  session memory appended by the global PostCompact hook.
