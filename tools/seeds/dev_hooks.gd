extends Node
## Project dev hooks. This is the one file where a project extends the
## shared debug console and screenshot harness. Kombucha owns those two
## scripts, and /sync-godot-tooling overwrites them. This file is yours, and
## a sync never touches it. Every method below is optional. Delete what you
## do not need, because the tooling checks `has_method()` before it calls.
##
## DebugConsole loads this file lazily, after the autoloads are up, so this
## file may name game classes freely. DebugConsole adds it as its child, so
## `get_tree()` and `await` work here. The harness reaches it through
## `DebugConsole.hooks`.


## Reset the project's own global state so every scenario starts the same:
## autoload fields, static vars, files written through to disk. The harness
## calls this after the shared sandbox (saves, settings, keybinds, volumes,
## time_scale). Any global you leave set here poisons every scenario after
## the one that set it.
##
## The shared sandbox wipes saves but not settings. The redirected settings
## file survives the whole batch. So reset here anything a console command
## can write there, after the redirect. Never reset it before the redirect,
## or you write the player's real file. Re-apply each setting too, not only
## rewrite it. A frame cap, vsync, a window mode, a UI scale and a rebuilt
## palette are engine state, and a scene reload does not touch them. (One
## scenario's 150% UI scale poisoned six after it, and the failures pointed
## at clicks.)
## These have leaked in real projects: a renderer setting, a zoom level,
## campaign progress, the editor's last-opened mod, a match config held in
## statics, an AI policy held in a static, a "watching" flag on ambient
## NPCs, a weather state.
## Ambient real-time systems (spawners, roamers, watchers) need a console
## off switch that a scenario can call first. This hook turns them back on.
func sandbox() -> void:
	pass


## Undo anything `sandbox()` redirected, after the last scenario.
func restore() -> void:
	pass


## The harness calls this just before a scenario runs its first line
## (after the sandbox and the return to the boot scene). Use it to record
## what each scenario loads.
#func scenario_started(_path: String) -> void:
#	pass


## The harness calls this after a scenario runs its last line. `ok` is
## false if any line failed.
#func scenario_finished(_path: String, _ok: bool) -> void:
#	pass


## The harness asks this about every scenario line before its own
## built-ins, so a project may take a built-in over (a `settle` that knows
## its own busy nodes). Return "" for success. Return "ERROR: ..." for
## failure, because the harness fails on exactly that shape. Return null to
## say "not mine", and the built-ins, then the debug console, try the line.
## An assertion must return an error, never a "false" answer that passes.
func scenario_command(_parts: PackedStringArray, _line: String) -> Variant:
	return null


## The console asks this about every command, by handler id, before its
## own handlers. So a project may take over a core command (its own `saves`
## text, a `locale` that persists). Declare a project command's surface in
## data/console_commands.project.json. Return the reply, or null for "not
## mine".
func console_dispatch(_handler: String, _args: Dictionary) -> Variant:
	return null


## The console's dev gate. The console asks this before its default (a
## debug build, or an export with the `dev` custom feature). Return true or
## false to decide, or null to keep the default. A hook that only adds a
## case can call `DebugConsole.default_allowed()`, which is the default. A
## player export must answer false, or the cheats the console reaches ship.
func console_allowed() -> Variant:
	return null


## Values for an argument that declares `"complete": "<source>"` in
## data/console_commands.project.json: unit ids, map ids, anything from the
## live registry. The console asks this before the core sources (commands,
## saves, actions, locales). Return an Array of strings, or null for "not
## mine". `prefix` holds the text typed so far. The
## console filters the list again, so you may return the whole list.
func console_complete(_source: String, _prefix: String) -> Variant:
	return null
