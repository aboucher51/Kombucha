---
name: update-template
description: Backport an improvement from the current project into the shared Godot template repo (generalize it, run the template's own checks, commit there). Use when the user says "add this to the template", "backport this", "the template should have this", or asks to update/improve the template while working in another project.
---

# Backporting an improvement to the Template

The shared template lives at `/mnt/c/Users/Alex/godot-projects/Template`
(override with the `GODOT_TEMPLATE` environment variable if set). Every new
project is scaffolded from it, so an improvement backported once is
inherited by every future project.

## Procedure

1. **Confirm the target is really the template.** It must contain
   `tools/new-project.sh` and a `project.godot` — if either is missing, stop
   and tell the user the template was not found rather than guessing at
   another directory. Check `git -C <template> status --porcelain`: if the
   template has uncommitted changes, stop and ask before mixing work.

2. **Identify one coherent improvement.** The skill argument or the recent
   conversation names it — a utility class, a harness command, a convention
   that earned its place, a tool-script fix, a test technique. Port one
   thing per invocation; a grab-bag commit is unreviewable.

3. **Generalize before copying.** The template is game-agnostic:
   - Strip game-specific ids, names, content and doc references; rename to
     neutral vocabulary (the template uses `ACCENT` not `GOLD`).
   - Match the template's conventions — read its `CLAUDE.md` first. New
     conventions are written as *the rule plus what breaks without it*.
   - Anything third-party gets a row in `LICENSES.md` in the same commit.
   - New global state must be added to `_sandbox()` in
     `scripts/dev/screenshot_harness.gd`.
   - A new console command needs both halves: surface in
     `data/console_commands.json`, handler in `scripts/dev/debug_console.gd`.
   - New logic gets a GUT test in `tests/`; if the source project had
     tests, port them.

4. **Apply and verify in the template directory** (not the current
   project):

   ```bash
   cd "$TEMPLATE" && godot4 --headless --path . --import && tools/check.sh
   ```

   Use `tools/check.sh --quick` when no display is available. Do not commit
   on red.

5. **Commit in the template repo** with a message that says what was
   backported and which project it came from. The current project's own
   repo is untouched unless the user also wants the change here.

6. **Report back**: what was ported, what was generalized away, and whether
   the current project should now be reconciled with the template version
   (usually yes, so the two copies do not drift).

## What NOT to backport

- Game content, balance values, art, or anything a fresh project would
  immediately delete.
- Half-proven experiments — the template only takes conventions and code
  that have already earned their place in a real project.
- Project-local configuration (window size quirks, personal permissions).
