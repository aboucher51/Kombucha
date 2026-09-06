---
name: sync-godot-tooling
description: Pull the shared Godot test tooling (test/check/shoot/export scripts, screenshot harness, debug console, GUT) from the Kombucha repo into the current Godot project, or report how far behind it is. Use when the user says "sync the tooling", "update the test tools", "pull the harness from Kombucha", when tools/check.sh prints "tooling is N commits behind", or before changing any file that tools/tooling-manifest.txt lists.
---

# Syncing a project's tooling from Kombucha

Kombucha owns the Godot-to-Claude workflow tooling. Its checkout is this
plugin's own directory, `${CLAUDE_PLUGIN_ROOT}` (a developer working from
a clone sets `GODOT_TOOLING` to it instead); every path below that says
`<kombucha>` means that directory. Every other
project carries a **copy** of the paths listed in
`tools/tooling-manifest.txt`, stamped in `tools/TOOLING_VERSION` with the
Kombucha commit it came from. `tools/check.sh` prints a note when that
stamp falls behind.

Owned files are overwritten by a sync. A project extends them only through
three files a sync never touches:

| Extension point | What goes there |
|---|---|
| `scripts/dev/dev_hooks.gd` | project sandbox resets, scenario commands, console handlers |
| `data/console_commands.project.json` | the surface (name, usage, args) of project console commands |
| `tools/check.local.sh` | project checks: sims, balance gates, linters, net tests |

## Procedure

1. **Confirm the source.** `<kombucha>` is `$GODOT_TOOLING` if set, else
   `${CLAUDE_PLUGIN_ROOT}`; it must contain `tools/sync-tooling.sh` and
   `tools/tooling-manifest.txt`, and if not, stop and say so. If
   `git -C <kombucha> status --porcelain` shows changes to owned files,
   stop: they must be committed before they can be stamped.

2. **Report drift before writing anything:**

   ```bash
   <kombucha>/tools/sync-tooling.sh <project> --check
   ```

   `same` means the copy is current. `new` is a file the project lacks.
   `drift` is an owned file the project edited in place. **Drift is the
   important case**: the edit is either an improvement Kombucha should
   have (backport it there first, commit, then sync) or project-specific
   logic that belongs in one of the three extension files (move it, then
   sync). Read the diff and decide per file; never let a sync silently
   discard a fix. The seams to look for in an old-style project:
   - project handlers inside the closed `match` in `debug_console.gd` and
     their entries in `console_commands.json` move to `dev_hooks.gd`'s
     `console_dispatch` and `console_commands.project.json`;
   - project resets inside `_sandbox()` / `_restore()` in the harness move
     to `dev_hooks.gd`'s `sandbox()` / `restore()`;
   - project scenario commands in `_project_command()` move to
     `scenario_command()`;
   - extra steps in `check.sh` (sims, gates, nettests) move to
     `check.local.sh`, which receives `QUICK`.

   **Diff the WHOLE owned file, not just those seams.** A project fixes
   the tooling's own logic in place too (Digit's harness returned to the
   boot scene between scenarios where the original reloaded the current
   one), and a sync that only moved the seams erased it: five of eight
   scenarios then failed with "no node named 'PlayButton'". The cheap
   test: diff the project's copy against the Kombucha commit it was
   scaffolded from, ignoring comment lines, and account for every
   non-comment line before syncing:

   ```bash
   diff <(git -C <kombucha> show <first-commit>:<owned-file>) <project>/<owned-file> | grep -E '^[<>]' | grep -vE '^[<>]\s*#'
   ```

3. **Sync:**

   ```bash
   <kombucha>/tools/sync-tooling.sh <project>
   ```

   It copies the owned paths, seeds any missing extension file from
   `tools/seeds/`, writes `tools/TOOLING_VERSION`, re-imports, and runs the
   project's `tools/check.sh --quick`. Run `tools/check.sh` in full when a
   display is available; scenarios are where harness changes show.

4. **Reconcile CLAUDE.md.** The tooling rules are ONE owned text,
   `docs/godot-tooling.md`, which the sync copies in. The project's
   CLAUDE.md must import it: delete its own "Verifying a change",
   "Checking a change", "The debug console", "Tests" and "Seeing the
   game" sections and put a line reading `@docs/godot-tooling.md` where
   they were (the sync prints a `note:` while the line is missing).
   Project-specific test rules (a game's own waits, its own gates) stay in
   the project's CLAUDE.md beside the import.

5. **Commit in the project** with a message naming the Kombucha commit
   (first line of `tools/TOOLING_VERSION`).

## What this skill is not for

- Improving the tooling itself: do that in Kombucha, prove it against
  the fixture there, then sync outward.
- Non-tooling improvements (utilities, conventions, UI kit): those still
  travel with the `/update-kombucha` skill.
