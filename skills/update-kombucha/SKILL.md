---
name: update-kombucha
description: Backport an improvement from the current Godot project into Kombucha, the repo that scaffolds every project (generalize it, prove it against Kombucha's fixture, commit there). Use when the user says "backport this", "add this to the kit", "the template should have this", "every project should get this", or asks to improve the shared tooling or conventions while working in a game project.
---

# Backporting an improvement to Kombucha

Kombucha holds everything a project starts with: the **kit** (autoloads,
`scripts/util`, `scripts/ui`, the conventions in `CLAUDE.md`), the
**tooling** (`tools/*.sh`, the screenshot harness, the debug console,
GUT, the CI workflows: everything `tools/tooling-manifest.txt` lists),
and the fixture that proves them. An improvement you make once there reaches
every future project. Existing projects get it by sync (tooling) or
cherry-pick (kit).

**A feedback report is the lighter route.** When the improvement is not
yet generalised, or the session only wants to say what it hit and what it
wants, write a report instead of a backport. Write one file per session at
`docs/feedback/<project>/session_<id>.md` in Kombucha, on a branch
`feedback/<project>-session-<id>`, following `docs/feedback/README.md`
there. Report from the project's side only: what happened, what it
cost, what the project wants, and which project file is the reference. Do
not read Kombucha's code to assess what it already has or how it should
change. A Kombucha session does that, and appends its disposition (what it
decided to do) to the same file.

Backporting needs a **clone with history**, not the installed plugin
(which has no `.git`). `$GODOT_TOOLING` must point at one. If it is
unset or not a git checkout, stop and say so. Do not edit the plugin
cache.

## Procedure

1. **Name what the improvement is**, because the two kinds travel
   differently once they are in Kombucha:

   | The improvement is… | Reaches existing projects by |
   |---|---|
   | Kit: an autoload, `scripts/util`, `scripts/ui`, a convention, a test technique, a CLAUDE.md rule | cherry-pick (`tools/sync-tooling.sh <project> --kit` lists what is newer) |
   | Tooling: anything in `tools/tooling-manifest.txt`, a harness or console command, a check step | `/sync-godot-tooling` (the sync overwrites owned files wholesale) |

   A project-specific thing (a game's own console command, its sandbox
   reset, its balance gate) is neither. Put it in the project's
   `dev_hooks.gd`, `console_commands.project.json` or `check.local.sh`.

2. **Confirm the clone is clean.** `git -C "$GODOT_TOOLING" status
   --porcelain` must print nothing, and no other session may be editing
   the clone. (Once, a sync from a dirty source stamped in-progress files
   into three projects.)

3. **Generalize.** Strip the game's names, numbers and assumptions. A
   backported rule states the rule *and* what breaks without it, the way
   every entry in Kombucha's `CLAUDE.md` does. For a tooling change, make
   the fixture use it in the same commit: a test in `tests/`, a scenario
   in `scenarios/`, or a self-test case.

4. **Apply it in the clone and prove it.** `tools/check.sh` there must be
   green (`--quick` when no display is available, but say so).

5. **Commit in Kombucha** with a message that names the project the
   lesson came from and what it cost there. Do not push unless asked.

6. **Bring it back.** For tooling, run `/sync-godot-tooling` in the
   project, because its own copy is now behind. For kit, the project
   already has the change, and other projects pick it up from the `--kit`
   report.
