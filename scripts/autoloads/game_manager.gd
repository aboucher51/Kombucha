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


func _ready() -> void:
	get_window().size_changed.connect(_apply_scale_policy)
	_apply_scale_policy()


## Pixel art stays 1:1 or 2:1: at or above the design size the canvas
## scale snaps to an INTEGER and the viewport expands into the difference
## (aspect "expand" in project.godot); below design size the fractional
## shrink stays, because integer would crop a small screen. Godot's own
## STRETCH_INTEGER letterboxes instead of expanding — measured, not assumed
## — so the snap is done by hand through content_scale_factor. Two projects
## carry this code verbatim.
func _apply_scale_policy() -> void:
	var win := get_window()
	var factor := snapped_factor(Vector2(win.size), design_size())
	if not is_equal_approx(win.content_scale_factor, factor):
		win.content_scale_factor = factor


## The content_scale_factor that snaps the automatic scale to its floor
## above design size and leaves it alone below. Static so a test can pin
## the ramp without a window.
static func snapped_factor(window: Vector2, design: Vector2) -> float:
	if design.x <= 0.0 or design.y <= 0.0 or window.x <= 0.0 or window.y <= 0.0:
		return 1.0
	var auto_scale := minf(window.x / design.x, window.y / design.y)
	if auto_scale >= 1.0:
		return floorf(auto_scale) / auto_scale
	return 1.0


## The integer number of screen pixels one design pixel occupies right now
## (1 below design size), for anything that must land on whole pixels.
func canvas_scale() -> int:
	var win := get_window()
	var design := design_size()
	var auto_scale := minf(float(win.size.x) / design.x, float(win.size.y) / design.y)
	return maxi(1, int(floorf(auto_scale)))


static func design_size() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 720)))


func change_scene(path: String) -> void:
	current_scene_path = path
	scene_changed.emit(path)
	get_tree().change_scene_to_file(path)


func set_paused(paused: bool) -> void:
	is_paused = paused
	get_tree().paused = paused
	game_paused.emit(paused)


func quit_game() -> void:
	AudioManager.flush_volumes()
	get_tree().quit()


func _notification(what: int) -> void:
	# The window's close button never asks the game first — autosave here or
	# whatever happened since the last save is gone.
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		AudioManager.flush_volumes()
		SaveManager.save_game()
