extends Node
## Game-level state: scene transitions, pause, quit.
##
## Keep this small — move real logic into standalone classes and call them
## from here. An autoload must not name UI class_names in typed variables:
## that pulls the UI script chain into the autoload load pass, and any
## preload re-entered by that chain hands back an empty PackedScene whose
## instantiate() returns null (see CLAUDE.md). Reach UI through groups and
## has_method() instead.

signal scene_changed(scene_path: String)
signal game_paused(is_paused: bool)

var current_scene_path: String = ""
var is_paused: bool = false


func change_scene(path: String) -> void:
	current_scene_path = path
	scene_changed.emit(path)
	get_tree().change_scene_to_file(path)


func set_paused(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused
	game_paused.emit(paused)


func quit_game() -> void:
	get_tree().quit()


func _notification(what: int) -> void:
	# The window's close button never asks the game first — autosave here or
	# whatever happened since the last save is gone.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveManager.save_game()
