---
name: new-godot-project
description: Scaffold a new Godot 4 project from Kombucha (the kit, the tooling and the contract, named, git-initialised, imported and checked green). Use when the user says "new godot project", "scaffold <name>", "start a project with the tooling", or similar.
---

# Scaffolding a new Godot project

Kombucha is the scaffold: its fixture is the smallest project the tooling
needs, which is also the smallest project a game starts from. Resolve
`<kombucha>` as `$GODOT_TOOLING` if set, else this plugin's own checkout,
`${CLAUDE_PLUGIN_ROOT}`. Its `tools/new-project.sh` does all the real work
— always use it rather than copying by hand, so the scaffold path stays
exercised (Kombucha's self-test runs it).

## Procedure

1. **Resolve the name and destination.** The skill argument usually gives a
   project name ("scaffold Sky Pirates"). Derive the directory from the
   name in PascalCase with no spaces (e.g. `SkyPirates`), under
   `~/godot-projects/` unless the user named a path. If no name was given
   at all, ask for one — it becomes both the window title and the exported
   binary name, so don't invent it. The project must land on the Linux
   filesystem, not `/mnt/c`: through that bridge every engine start costs
   ten seconds.

2. **Refuse to overwrite.** If the destination exists, stop and ask; the
   script also refuses, but check first so the error is a conversation, not
   a stack trace.

3. **Run the scaffolder:**

   ```bash
   "${GODOT_TOOLING:-$CLAUDE_PLUGIN_ROOT}/tools/new-project.sh" <destination> "<Project Name>"
   ```

   It copies the fixture minus Kombucha's own paths (plugin, skills, the
   tooling's tests and scenarios, research docs), strips the
   Kombucha-only sections of `CLAUDE.md` and `LICENSES.md`, sets
   `config/name`, seeds the three extension files and stamps
   `tools/TOOLING_VERSION`, git-inits on `main`, runs the Godot import,
   regenerates the project map (or drops it when `godot-map` is not
   installed), runs `tools/check.sh --quick`, and makes the one initial
   commit. It must end with `check: all green` — if anything fails, report
   the failure; do not hand over a red project. A source clone with
   uncommitted owned files is refused; commit there first.

4. **Report where the project landed** and the two day-one facts:
   `scenes/main.tscn` + `scripts/main.gd` are a placeholder boot scene
   meant to be replaced (the pause menu, theme, UI-sound wiring and the
   harness seams `state_text` / `is_busy` in them are working examples),
   and the project extends the tooling only through
   `scripts/dev/dev_hooks.gd`, `data/console_commands.project.json` and
   `tools/check.local.sh`; `/sync-godot-tooling` refreshes everything
   else, `/update-kombucha` sends a kit improvement back.

5. If the user wants to start working in it immediately, suggest opening a
   new Claude session in the project directory (its own `CLAUDE.md`,
   permissions and hooks are already in place) rather than working on it
   from this session's directory.
