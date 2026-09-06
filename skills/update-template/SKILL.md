---
name: update-template
description: Backport an improvement from the current project into the shared Godot template repo (generalize it, run the template's own checks, commit there). Use when the user says "add this to the template", "backport this", "the template should have this", or asks to update/improve the template while working in another project. Tooling (runner, harness, console, check scripts) is NOT backported here; it is owned by Kombucha and travels with /sync-godot-tooling.
---

# Backporting an improvement to the Template

The shared template lives at `/home/alex/godot-projects/Template`
(override with the `GODOT_TEMPLATE` environment variable if set). Every new
project is scaffolded from it, so an improvement backported once is
inherited by every future project.

Two repos, two routes. Decide which one the improvement is before touching
anything:

| The improvement is… | It goes to | How |
|---|---|---|
| Kit: an autoload, `scripts/util`, `scripts/ui`, a convention, a test technique, a CLAUDE.md rule | the Template | this skill |
| Tooling: `tools/*.sh`, the screenshot harness, the debug console core, `data/console_commands.json`, GUT, the CI workflows, anything in `tools/tooling-manifest.txt` | Kombucha (`/home/alex/godot-projects/Kombucha`) | change it there, prove it against the fixture, then `/sync-godot-tooling` outward |

The Template carries a **copy** of the tooling like every other project.
Editing an owned file in the Template is drift that the next sync erases;
`tools/sync-tooling.sh <template> --check` from Kombucha lists the owned
paths, and the Template's own `check.sh` prints a note when its copy is
behind.

## Procedure

1. **Confirm the target is really the template.** It must contain
   `tools/new-project.sh` and a `project.godot` — if either is missing, stop
   and tell the user the template was not found rather than guessing at
   another directory. Check `git -C <template> status --porcelain`: if the
   template has uncommitted changes, stop and ask before mixing work.

2. **Identify one coherent improvement.** The skill argument or the recent
   conversation names it — a utility class, a kit seam, a convention that
   earned its place, a test technique. Port one thing per invocation; a
   grab-bag commit is unreviewable. If it turns out to be tooling, stop and
   say so: it belongs in Kombucha (table above).

3. **Generalize before copying.** The template is game-agnostic:
   - Strip game-specific ids, names, content and doc references; rename to
     neutral vocabulary (the template uses `ACCENT` not `GOLD`).
   - Match the template's conventions — read its `CLAUDE.md` first. New
     conventions are written as *the rule plus what breaks without it*.
   - Anything third-party gets a row in `LICENSES.md` in the same commit.
   - **New global state** (an autoload field, a static var, a file written
     through to disk) must be reset between scenarios. The Template's own
     resets live in `scripts/dev/dev_hooks.gd`'s `sandbox()` — never in the
     harness's `_sandbox()`, which is Kombucha's and overwritten by a sync.
     If the state is something EVERY project will have (a new kit
     autoload), the harness reset belongs in Kombucha, duck-typed so older
     projects are not broken by it.
   - **A new console command** needs both halves in the project seams:
     its surface in `data/console_commands.project.json`, its handler in
     `dev_hooks.gd`'s `console_dispatch()`. A command every project should
     have goes to Kombucha's core table instead.
   - A new scenario command goes in `dev_hooks.gd`'s `scenario_command()`;
     a harness built-in goes to Kombucha.
   - New logic gets a GUT test in `tests/`; if the source project had
     tests, port them. Anything visual gets a scenario in `scenarios/`.
   - A new `ui.*` string is a key plus a row in `localization/game.csv`;
     re-run `tools/make_pseudo_locale.py`.

4. **Apply and verify in the template directory** (not the current
   project):

   ```bash
   cd "$TEMPLATE" && godot4 --headless --path . --import && tools/check.sh
   ```

   Use `tools/check.sh --quick` when no display is available. Do not commit
   on red. If `check.sh` prints a `note: tooling is N commit(s) behind`,
   that is separate work: run `/sync-godot-tooling` in the Template in its
   own commit, before or after, never mixed in.

5. **Commit in the template repo** with a message that says what was
   backported and which project it came from. The current project's own
   repo is untouched unless the user also wants the change here.

6. **Report back**: what was ported, what was generalized away, and whether
   the current project should now be reconciled with the template version
   (usually yes, so the two copies do not drift). If Kombucha's fixture
   should pick up the kit change (it is scaffolded from the Template and
   proves the tooling against current kit), say so.

## What NOT to backport

- Tooling: it has an owner, and a fix landed only in the Template reaches
  no existing project and is erased from the Template by the next sync.
- Game content, balance values, art, or anything a fresh project would
  immediately delete.
- Half-proven experiments — the template only takes conventions and code
  that have already earned their place in a real project.
- Project-local configuration (window size quirks, personal permissions).
