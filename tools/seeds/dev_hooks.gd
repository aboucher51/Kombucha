extends Node
## Project dev hooks — the ONE file where a project extends the shared debug
## console and screenshot harness. Those two scripts are owned by Kombucha
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
##
## The shared sandbox wipes SAVES but not SETTINGS: the redirected settings
## file survives the whole batch, so anything a console command can write
## there must be re-defaulted HERE, after the redirect (never before, or
## you write the player's real file) — and re-APPLIED, not only rewritten:
## a frame cap, vsync, a window mode, a UI scale, a rebuilt palette are
## engine state a scene reload does not touch (one scenario's 150% UI
## scale poisoned six after it, and the failures pointed at clicks).
## Shapes that have leaked in real
## projects: a renderer setting, a zoom level, campaign progress, the
## editor's last-opened mod, a match config held in statics, an AI policy
## held in a static, a "watching" flag on ambient NPCs, a weather state.
## Ambient real-time systems (spawners, roamers, watchers) need a console
## OFF switch a scenario can call first, and this hook turns them back on.
func sandbox() -> void:
	pass


## Undo anything `sandbox()` redirected, after the last scenario.
func restore() -> void:
	pass


## Every scenario line, asked BEFORE the harness's built-ins, so a project
## may take one over (a `settle` that knows its own busy nodes). Return ""
## for success, "ERROR: ..." for failure (the harness fails on exactly that
## shape), or null to say "not mine" and let the built-ins, then the debug
## console, try it. Assertions MUST return an error, never a "false" answer
## that passes.
func scenario_command(_parts: PackedStringArray, _line: String) -> Variant:
	return null


## Every console command by handler id, asked BEFORE the shared console's
## own handlers, so a project may take over a core command (its own
## `saves` text, a `locale` that persists). Project commands declare their
## surface in data/console_commands.project.json. Return the reply, or null
## for "not mine".
func console_dispatch(_handler: String, _args: Dictionary) -> Variant:
	return null
