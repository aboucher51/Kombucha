extends Node
## Project dev hooks — the ONE file where a project extends the shared debug
## console and screenshot harness. Those two scripts are owned by Microbiome
## and overwritten by /sync-godot-tooling; this file is yours and never
## touched by a sync. Every method below is optional: delete what you do
## not need, the tooling checks `has_method()` before calling.
##
## Loaded lazily by DebugConsole after the autoloads are up (so it may name
## game classes freely) and added as its child, so `get_tree()` and `await`
## work here. The harness reaches it through `DebugConsole.hooks`.


## Reset the PROJECT's global state so every scenario starts the same:
## autoload fields, static vars, files written through to disk. Runs after
## the shared sandbox (saves, settings, keybinds, volumes, time_scale). Any
## global left set here poisons every scenario after the one that set it.
func sandbox() -> void:
	pass


## Undo anything `sandbox()` redirected, after the last scenario.
func restore() -> void:
	pass


## A scenario line no built-in harness command claimed. Return "" for
## success, "ERROR: ..." for failure (the harness fails on exactly that
## shape), or null to say "not mine" and let the debug console try it.
## Assertions MUST return an error, never a "false" answer that passes.
func scenario_command(_parts: PackedStringArray, _line: String) -> Variant:
	return null


## A console command whose handler id (from data/console_commands.project.json)
## the shared console does not know. Return the reply, or null for "not mine".
func console_dispatch(_handler: String, _args: Dictionary) -> Variant:
	return null
