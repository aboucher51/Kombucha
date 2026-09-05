extends Node
## Drives the running game from a plain-text scenario script and saves a PNG
## at each `shot`, so a visual change can be checked without a human watching
## the window.
##
## Autoloaded, but inert unless the game is launched with a scenario:
##
##     godot4 --path . -- --scenario scenarios/example.txt
##
## (the bare `--` matters: everything after it is ours, via
## OS.get_cmdline_user_args()). With no --scenario the harness frees itself
## and the game runs exactly as it otherwise would. Use tools/shoot.sh rather
## than invoking this by hand — it handles timeouts, logs and engine errors.
##
## `--seed <n>` makes a run repeatable — anything randomly placed needs that
## before a screenshot can be compared against a previous one.
##
## Built-in scenario commands:
##
##     shot <name> [x y w h]   capture shots/NN-<name>.png (optional 1:1 crop —
##                             use a crop to judge text sharpness; a downscaled
##                             full-window view hides exactly that detail)
##     wait <frames>           let the game run (animations, tweens, spawns)
##     sleep <seconds>         wall-clock wait, for anything on a Timer
##     click <NodeName>        synthesise a real mouse click on a named Control
##     press <action>          synthesise an input action press+release
##     assert_visible <NodeName>   fail unless the named Control is visible
##     assert_onscreen <NodeName>  fail if it escapes the visible viewport
##     expect_fail <command>   fail unless the wrapped command fails
##     # comment               ignored, as are blank lines
##
## Everything else goes to the project's dev hooks (scripts/dev/dev_hooks.gd,
## `scenario_command`) and then to the debug console. This file is OWNED BY
## MICROBIOME and overwritten by /sync-godot-tooling — project commands and
## project sandbox resets live in dev_hooks.gd, never here. When adding UI,
## add an input-free seam alongside it (a method the harness can call), or
## the feature is unscreenshotable and untestable.
## `click` synthesises REAL input — prefer it when what you need to prove is
## that the player's path works, not that a handler does. Give run-time-built
## controls a stable `name`: an auto-named `@Button@3` cannot be clicked.

const SHOT_DIR := "res://shots"
const SANDBOX_SAVE_ROOT := "user://sandbox_saves"
## Frames given to layout/tweens after a click before the next command.
const DEFAULT_SETTLE_FRAMES := 8

var _shot_index := 0
var _failures := 0
var _fixed_seed := -1
## The running scenario's file stem, so shots are named after it: two
## scenarios that both `shot boot` used to overwrite each other.
var _scenario_stem := ""


func _ready() -> void:
	var scenario_paths := _user_args("--scenario")
	if scenario_paths.is_empty():
		queue_free()
		return

	# Scenarios need a real window to render into, but they have no business
	# stealing the keyboard from whatever the developer is doing.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)

	# Before the first await, so it lands ahead of the main scene's _ready —
	# autoloads are readied before the main scene, which is the only reason
	# this ordering is available.
	var seed_arg := _user_arg("--seed")
	if not seed_arg.is_empty():
		_fixed_seed = int(seed_arg)
		seed(_fixed_seed)

	# The main scene builds in its own _ready; nothing is on screen to drive
	# or capture until it has.
	await get_tree().process_frame
	await get_tree().process_frame

	_sandbox()

	# Which rasterizer made the pixels: a GPU and a software renderer do not
	# produce identical images, and a log that says which one ran is what
	# makes a screenshot comparable to the last one.
	print("harness: renderer %s / %s" % [RenderingServer.get_video_adapter_name(),
		RenderingServer.get_current_rendering_driver_name()])

	# Every scenario in ONE process: booting Godot costs seconds, a scenario
	# well under one. Anything that leaks across the reload between scenarios
	# is a real bug worth finding, not a reason to pay for fresh processes.
	var failed: Array[String] = []
	for index in scenario_paths.size():
		if index > 0:
			await _reset_between_scenarios()
		_failures = 0
		_shot_index = 0
		await _run(scenario_paths[index])
		if _failures > 0:
			failed.append(scenario_paths[index])

	_restore()

	if scenario_paths.size() > 1:
		print("── batch: %d scenario(s), %d failed ──" % [scenario_paths.size(), failed.size()])
		for path in failed:
			print("  FAILED %s" % path)
	get_tree().quit(1 if not failed.is_empty() else 0)


## The state every scenario starts from. This resets what every project has
## (the Template autoloads); the project's OWN global state (autoload fields,
## static vars, files written through to disk) is reset in dev_hooks.gd's
## `sandbox()`, which runs right after this. Extend that whenever the project
## grows global state — anything global survives the scene reload between
## scenarios, and a scenario that leaves it changed poisons every scenario
## after it. The symptom is always misleading: a scenario that passes alone
## and fails in the batch, or vice versa.
func _sandbox() -> void:
	# Global and NOT reset by a scene reload; a scenario that pauses and does
	# not unpause would hang every scenario after it.
	Engine.time_scale = 1.0
	get_tree().paused = false
	# Saves and settings write through to disk — point the whole save system
	# at scratch so a suite run can neither edit the player's real files nor
	# leak one scenario's save into the next.
	SaveManager.save_root = SANDBOX_SAVE_ROOT
	SaveManager.config_path = "user://sandbox_settings.cfg"
	SaveManager.current_slot = SaveManager.DEFAULT_SLOT
	_wipe_dir(SANDBOX_SAVE_ROOT)
	# A scenario that rebinds a key edits the (redirected) settings file AND
	# the live InputMap — the next scenario must start from the default
	# keyboard. Bus volumes are the same shape of global state.
	Keybinds.reset_to_defaults()
	for bus_name in AudioManager.BUSES:
		AudioManager.set_bus_volume(bus_name, 1.0)
	_hook("sandbox")


## Put the machine back exactly as it was found, however the run went.
func _restore() -> void:
	_hook("restore")
	SaveManager.save_root = SaveManager.DEFAULT_SAVE_ROOT
	SaveManager.config_path = SaveManager.DEFAULT_CONFIG_PATH
	SaveManager.current_slot = SaveManager.DEFAULT_SLOT
	_wipe_dir(SANDBOX_SAVE_ROOT)
	DirAccess.remove_absolute("user://sandbox_settings.cfg")
	# The machine's own keybinds and volumes, back the way the player had them.
	Keybinds.apply_saved()
	AudioManager.apply_saved_volumes()


func _reset_between_scenarios() -> void:
	_sandbox()
	if _fixed_seed >= 0:
		seed(_fixed_seed)
	get_tree().reload_current_scene()
	await get_tree().process_frame
	await get_tree().process_frame


func _run(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		file = FileAccess.open("res://" + path, FileAccess.READ)
	if file == null:
		_fail(path, 0, "cannot open scenario file")
		return
	print("── scenario: %s ──" % path)
	_scenario_stem = path.get_file().get_basename()
	var started := Time.get_ticks_msec()
	var line_number := 0
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		line_number += 1
		if line.is_empty() or line.begins_with("#"):
			continue
		var reply := await _execute(line)
		if _is_error(reply):
			_fail(path, line_number, "%s -> %s" % [line, reply])
	# The seconds are the point: with dozens of scenarios in one process,
	# the expensive ones must be visible without a profiler.
	if _failures == 0:
		print("scenario ok: %s (%.1fs)" % [path, float(Time.get_ticks_msec() - started) / 1000.0])


func _execute(line: String) -> String:
	var parts := line.split(" ", false)
	match parts[0]:
		"shot":
			return await _shot(parts)
		"wait":
			if parts.size() < 2:
				return "ERROR: usage: wait <frames>"
			for i in maxi(1, int(parts[1])):
				await get_tree().process_frame
			return ""
		"sleep":
			if parts.size() < 2:
				return "ERROR: usage: sleep <seconds>"
			# Wall-clock on purpose: "sleep two seconds" means two real
			# seconds, whatever Engine.time_scale is doing.
			await get_tree().create_timer(float(parts[1]), true, false, true).timeout
			return ""
		"click":
			return await _click(parts)
		"press":
			return await _press(parts)
		"assert_visible":
			if parts.size() < 2:
				return "ERROR: usage: assert_visible <NodeName>"
			var target := _find_control(parts[1])
			if target == null:
				return "ERROR: no Control named '%s'" % parts[1]
			if not target.is_visible_in_tree():
				return "ERROR: '%s' is not visible" % parts[1]
			return ""
		"assert_onscreen":
			return _assert_onscreen(parts)
		"expect_fail":
			if parts.size() < 2:
				return "ERROR: usage: expect_fail <command>"
			var inner := await _execute(" ".join(parts.slice(1)))
			if _is_error(inner):
				return ""
			return "ERROR: expected failure but got: '%s'" % inner
		_:
			return await _project_command(parts, line)


## Anything that isn't a built-in goes to the debug console, so scenario
## lines and console lines are ONE vocabulary — a line can be pasted either
## way. The console's replies are "ERROR:"-prefixed on failure and the
## harness fails on exactly that shape, so a command that merely answers
## "false" passes silently: an assertion-like handler must return an error,
## never an answer.
func _project_command(parts: PackedStringArray, line: String) -> String:
	var hooks: Object = DebugConsole.hooks
	if hooks != null and hooks.has_method("scenario_command"):
		var reply: Variant = await hooks.scenario_command(parts, line)
		if reply != null:
			return str(reply)
	return DebugConsole.execute(line)


## Calls an optional dev-hooks method by name; a project without hooks, or
## without that hook, is the normal case and costs nothing.
func _hook(method: String) -> void:
	var hooks: Object = DebugConsole.hooks
	if hooks != null and hooks.has_method(method):
		hooks.call(method)


func _shot(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "ERROR: usage: shot <name> [x y w h]"
	# Let pending layout/tweens settle so the capture isn't mid-animation.
	for i in DEFAULT_SETTLE_FRAMES:
		await get_tree().process_frame
	var image := capture(get_viewport())
	if image == null:
		return "ERROR: no rendered frame — this display driver has no rasterizer (--headless?)"
	if parts.size() >= 6:
		var rect := Rect2i(int(parts[2]), int(parts[3]), int(parts[4]), int(parts[5]))
		rect = rect.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		if not rect.has_area():
			return "ERROR: crop rect is off-image"
		image = image.get_region(rect)
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	_shot_index += 1
	var file_path := "%s/%s-%02d-%s.png" % [SHOT_DIR, _scenario_stem, _shot_index, parts[1]]
	var err := image.save_png(file_path)
	if err != OK:
		return "ERROR: save_png failed (%d)" % err
	print("shot: %s" % file_path)
	return ""


## The viewport's last rendered frame, or null when there is no rasterizer
## to have drawn one. Static so a headless GUT run can pin the null case.
## Under --headless the display server is "headless" and the dummy
## rasterizer has no image: asking the texture for one logs an engine error
## and returns null, so the answer is decided before asking.
static func capture(viewport: Viewport) -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	var texture := viewport.get_texture()
	if texture == null:
		return null
	return texture.get_image()


## Synthesises a real press+release at the centre of the named Control, so
## the whole input path is exercised — not just the handler.
func _click(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "ERROR: usage: click <NodeName>"
	var target := _find_control(parts[1])
	if target == null:
		return "ERROR: no Control named '%s'" % parts[1]
	if not target.is_visible_in_tree():
		return "ERROR: '%s' is not visible" % parts[1]
	var at := target.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		Input.parse_input_event(event)
		await get_tree().process_frame
	for i in DEFAULT_SETTLE_FRAMES:
		await get_tree().process_frame
	return ""


## Synthesises an InputEventAction press+release, exercising every
## is_action_pressed handler the way a keystroke would.
func _press(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "ERROR: usage: press <action>"
	if not InputMap.has_action(parts[1]):
		return "ERROR: no input action '%s'" % parts[1]
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = parts[1]
		event.pressed = pressed
		Input.parse_input_event(event)
		await get_tree().process_frame
	for i in DEFAULT_SETTLE_FRAMES:
		await get_tree().process_frame
	return ""


func _assert_onscreen(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "ERROR: usage: assert_onscreen <NodeName>"
	var target := _find_control(parts[1])
	if target == null:
		return "ERROR: no Control named '%s'" % parts[1]
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var rect := target.get_global_rect()
	if not view.encloses(rect):
		return "ERROR: '%s' at %s escapes the view %s" % [parts[1], rect, view]
	return ""


func _find_control(node_name: String) -> Control:
	var root := get_tree().root
	var found := root.find_child(node_name, true, false)
	return found as Control


func _is_error(reply: String) -> bool:
	return reply.begins_with("ERROR") or reply.begins_with("error")


func _fail(path: String, line_number: int, message: String) -> void:
	_failures += 1
	push_error("scenario %s:%d %s" % [path, line_number, message])
	print("FAIL %s:%d %s" % [path, line_number, message])


func _wipe_dir(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


## Every `--<name> <value>` in the post-`--` arguments, in order.
func _user_args(name: String) -> Array[String]:
	var values: Array[String] = []
	var args := OS.get_cmdline_user_args()
	for index in args.size():
		if args[index] == name and index + 1 < args.size():
			values.append(args[index + 1])
	return values


func _user_arg(name: String) -> String:
	var values := _user_args(name)
	return values[0] if not values.is_empty() else ""
