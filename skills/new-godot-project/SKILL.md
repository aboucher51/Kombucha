---
name: new-godot-project
description: Scaffold a new Godot project from the shared Template repo (copies the template, sets the project name, git-inits, imports, verifies green). Use when the user says "new godot project", "start a project from the template", "scaffold <name>", or similar.
---

# Scaffolding a new Godot project from the Template

The Template is its own repo, `https://github.com/aboucher51/Template`:
the kit (autoloads, UI theme, save system, keybinds, pads) plus a copy of
Kombucha's tooling, which is what the tooling's scripts assume a project
has. Resolve it as `$GODOT_TEMPLATE` if set, else `~/godot-projects/Template`;
if neither exists, clone it there first:

```bash
git clone https://github.com/aboucher51/Template.git ~/godot-projects/Template
```

Its `tools/new-project.sh` does all the real work — always use it rather
than copying by hand, so the scaffold path stays exercised. After
scaffolding, `/sync-godot-tooling` in the new project brings its tooling
copy up to this plugin's version if the Template's is behind.

## Procedure

1. **Resolve the name and destination.** The skill argument usually gives a
   project name ("scaffold Sky Pirates"). Derive the directory from the
   name in PascalCase with no spaces (e.g. `SkyPirates`), siblinged next to
   the template unless the user named a path. If no name was given at all, ask for one — it becomes both
   the window title and the exported binary name, so don't invent it.

2. **Refuse to overwrite.** If the destination exists, stop and ask; the
   script also refuses, but check first so the error is a conversation, not
   a stack trace.

3. **Run the scaffolder from the template directory:**

   ```bash
   cd "${GODOT_TEMPLATE:-$HOME/godot-projects/Template}"
   tools/new-project.sh <destination> "<Project Name>"
   ```

   It copies everything (minus `.godot/`, `shots/`, `.git`), sets
   `config/name`, git-inits on `main` (inheriting the template's git
   identity), runs the Godot import, runs `tools/check.sh --quick`, and
   makes an initial commit. It must end with `check: all green` — if
   anything fails, report the failure; do not hand over a red project.

4. **Report where the project landed** and remind the user of the two
   day-one facts: `scenes/main.tscn` + `scripts/main.gd` are placeholder
   boot scenes meant to be replaced (the pause menu, theme, and UI-sound
   wiring in them are working examples), and `/update-template` from inside
   the new project backports improvements to the template.

5. If the user wants to start working in it immediately, suggest opening a
   new Claude session in the project directory (its own `CLAUDE.md`,
   permissions, and skills are already in place) rather than working on it
   from this session's directory.
