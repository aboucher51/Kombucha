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
##     ticks <n>               n PHYSICS frames: game time, for choreography
##                             and anything under Engine.time_scale
##     sleep <seconds>         wall-clock wait, for anything on an OS timer
##     settle [s] [group]      wait until no node in the group (default
##                             "settle") answers is_busy() true; ERROR after s
##     click <NodeName>        synthesise a real mouse click on a named Control
##     click_at <x> <y>        the same at viewport coordinates (Node2D boards)
##     scroll_to <NodeName>    scroll a ScrollContainer row into view first
##     hover <NodeName>        move the real mouse over it and verify it took
##     press <action>          synthesise an input action press+release
##     assert_visible <NodeName>   fail unless the named Control is visible
##     assert_onscreen <NodeName>  fail if it escapes the visible viewport
##                             (Control, or Node3D through the live camera)
##     assert_tooltip <NodeName> <text>  fail unless its tooltip contains text
##     frame_budget <ms> [n]   fail if the average frame over n exceeds ms
##     expect_fail <command>   fail unless the wrapped command fails
##     # comment               ignored, as are blank lines
##
## A name shared by two nodes is an ERROR, not a coin toss: every lookup
## refuses an ambiguous name rather than answering about whichever loaded
## first (that was a test decided by load order, once).
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
## Set by _find_named / _find_control when they return null: the reason.
var _lookup_error := ""
var _failures := 0
var _fixed_seed := -1
## The running scenario's file stem, so shots are named after it: two
## scenarios that both `shot boot` used to overwrite each other.
var _scenario_stem := ""


func _ready() -> void:
	var scenario_paths := Cmdline.values("--scenario")
	if scenario_paths.is_empty():
		queue_free()
		return

	# Scenarios need a real window to render into, but they have no business
	# stealing the keyboard from whatever the developer is doing.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS, true)

	# Before the first await, so it lands ahead of the main scene's _ready —
	# autoloads are readied before the main scene, which is the only reason
	# this ordering is available.
	var seed_arg := Cmdline.value("--seed")
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
	# The REAL cursor is global state too: parked over a control it feeds
	# hover and tooltips into every scenario after the one that moved it.
	Input.warp_mouse(Vector2(2, 2))
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
			# seconds, whatever Engine.time_scale is doing. Choreography
			# wants `ticks`: under a slow renderer physics falls behind
			# wall time and a wall-clock sleep under-waits it.
			await get_tree().create_timer(float(parts[1]), true, false, true).timeout
			return ""
		"ticks":
			if parts.size() < 2:
				return "ERROR: usage: ticks <n>"
			for i in maxi(1, int(parts[1])):
				await get_tree().physics_frame
			return ""
		"settle":
			return await _settle(parts)
		"click":
			return await _click(parts)
		"click_at":
			if parts.size() < 3:
				return "ERROR: usage: click_at <x> <y>"
			return await _click_point(Vector2(float(parts[1]), float(parts[2])))
		"scroll_to":
			return await _scroll_to(parts)
		"hover":
			return await _hover(parts)
		"press":
			return await _press(parts)
		"assert_visible":
			if parts.size() < 2:
				return "ERROR: usage: assert_visible <NodeName>"
			var target := _find_control(parts[1])
			if target == null:
				return _lookup_error
			if not target.is_visible_in_tree():
				return "ERROR: '%s' is not visible" % parts[1]
			return ""
		"assert_onscreen":
			return _assert_onscreen(parts)
		"assert_tooltip":
			return _assert_tooltip(parts)
		"frame_budget":
			return await _frame_budget(parts)
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
		return _lookup_error
	if not target.is_visible_in_tree():
		return "ERROR: '%s' is not visible" % parts[1]
	return await _click_point(target.get_global_transform_with_canvas() * (target.size / 2.0))


## A click at viewport (canvas) coordinates. push_input with local coords,
## NOT Input.parse_input_event: the latter treats the position as WINDOW
## pixels, so under any stretch other than the design resolution every
## synthetic click lands somewhere else (found at Steam Deck resolution,
## where every scenario click missed).
func _click_point(at: Vector2) -> String:
	Input.warp_mouse(at)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	for i in DEFAULT_SETTLE_FRAMES:
		await get_tree().process_frame
	return ""


## A row below the fold of a long list is visible but NOT clickable: the
## click lands where the rect is, outside the viewport. Scroll it into
## view first (a list's own follow_focus does this for keyboard users).
func _scroll_to(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "ERROR: usage: scroll_to <NodeName>"
	var target := _find_control(parts[1])
	if target == null:
		return _lookup_error
	var holder: Node = target
	while holder != null and holder is not ScrollContainer:
		holder = holder.get_parent()
	if holder == null:
		return "ERROR: '%s' is not inside a ScrollContainer" % parts[1]
	(holder as ScrollContainer).ensure_control_visible(target)
	for i in 4:
		await get_tree().process_frame
	return ""


## Wait until nothing in the group reports is_busy(), or fail after the
## limit. Deterministic where a `sleep` after a move was a guess — and an
## error on expiry, because a hung animation that quietly degrades into a
## four-second sleep is exactly the bug a scenario exists to catch.
func _settle(parts: PackedStringArray) -> String:
	var limit := float(parts[1]) if parts.size() > 1 else 4.0
	var group := parts[2] if parts.size() > 2 else "settle"
	var deadline := Time.get_ticks_msec() + int(limit * 1000.0)
	while true:
		var busy: Array[String] = []
		for node in get_tree().get_nodes_in_group(group):
			if node.has_method("is_busy") and node.is_busy():
				busy.append(str(node.name))
		if busy.is_empty():
			await get_tree().process_frame
			return ""
		if Time.get_ticks_msec() >= deadline:
			return "ERROR: still busy after %.1fs: %s" % [limit, ", ".join(busy)]
		await get_tree().process_frame
	return ""


## Moves the REAL mouse over the Control (warp plus a motion event through
## the same canvas path as clicks) and verifies the GUI agrees about what is
## under it — two distinct failures: nothing registered, or the wrong thing.
func _hover(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "ERROR: usage: hover <NodeName>"
	var target := _find_control(parts[1])
	if target == null:
		return _lookup_error
	if not target.is_visible_in_tree():
		return "ERROR: '%s' is not visible" % parts[1]
	var at := target.get_global_transform_with_canvas() * (target.size / 2.0)
	Input.warp_mouse(at)
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return "ERROR: hover did not register at %s (over %s)" % [at, parts[1]]
	if hovered != target and not target.is_ancestor_of(hovered):
		return "ERROR: hover landed on '%s', wanted '%s' at %s" % [hovered.name, parts[1], at]
	return ""


## Reads the tooltip the Control would show, without waiting for the
## engine's popup: deterministic, no dwell, and it answers headless. A game
## that draws hints in its own overlay asserts on that overlay instead.
func _assert_tooltip(parts: PackedStringArray) -> String:
	if parts.size() < 3:
		return "ERROR: usage: assert_tooltip <NodeName> <text>"
	var target := _find_control(parts[1])
	if target == null:
		return _lookup_error
	var wanted := " ".join(parts.slice(2))
	var text := target.get_tooltip(target.size / 2.0)
	if text.is_empty():
		return "ERROR: '%s' carries no tooltip" % parts[1]
	if not text.contains(wanted):
		return "ERROR: '%s' tooltip says '%s', wanted '%s'" % [parts[1], text, wanted]
	return ""


## Average frame time over a window, with vsync and the FPS cap OFF for the
## measurement (with vsync on every scene measures 16.7 ms and the gate can
## never fail). Read it as a REGRESSION tripwire on this machine's renderer,
## not a device target: the number is printed even on pass, because a gate
## you only see when it goes red says nothing about the change that used
## half the remaining headroom.
func _frame_budget(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "ERROR: usage: frame_budget <ms> [frames]"
	var budget := float(parts[1])
	var frames := maxi(8, int(parts[2]) if parts.size() > 2 else 60)
	var previous_fps := Engine.max_fps
	var previous_vsync := DisplayServer.window_get_vsync_mode()
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Warm up: the first frames after a scene is built pay for shader
	# compilation and texture upload, a one-off the budget is not about.
	for i in 10:
		await get_tree().process_frame
	var worst := 0.0
	var total := 0.0
	for i in frames:
		var began := Time.get_ticks_usec()
		await get_tree().process_frame
		var elapsed := (Time.get_ticks_usec() - began) / 1000.0
		total += elapsed
		worst = maxf(worst, elapsed)
	Engine.max_fps = previous_fps
	DisplayServer.window_set_vsync_mode(previous_vsync)
	var average := total / frames
	var report := "%.1f ms average, %.1f ms worst over %d frames (%s)" % [
		average, worst, frames, RenderingServer.get_video_adapter_name()]
	if average > budget:
		return "ERROR: frame budget %.1f ms exceeded — %s" % [budget, report]
	print("  frames: %s, budget %.1f ms" % [report, budget])
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
	var found := _find_named(parts[1])
	if found == null:
		return _lookup_error
	var view := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var control := found as Control
	if control != null:
		var rect := control.get_global_rect()
		if not view.encloses(rect):
			return "ERROR: '%s' at %s escapes the view %s" % [parts[1], rect, view]
		return ""
	var spatial := found as Node3D
	if spatial == null:
		return "ERROR: '%s' is neither a Control nor a Node3D" % parts[1]
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return "ERROR: no 3D camera to check '%s' against" % parts[1]
	# A mesh's ORIGIN is not where its geometry is: an area-sized mesh has
	# its origin at a corner, so asking about the origin answers a question
	# nobody asked. The middle of its bounds is the honest one.
	var visual := found as VisualInstance3D
	var point := spatial.global_position if visual == null \
		else visual.global_transform * visual.get_aabb().get_center()
	if camera.is_position_behind(point):
		return "ERROR: '%s' at %s is behind the camera" % [parts[1], point]
	var screen := camera.unproject_position(point)
	if not view.has_point(screen):
		return "ERROR: '%s' at %s lands at %s, outside the view %s" % [parts[1],
			point, screen, view]
	return ""


## Every node with this name, not just the first — so an ambiguous name is
## reported as ambiguous rather than answered about arbitrarily.
func _find_all(from: Node, node_name: String) -> Array[Node]:
	var found: Array[Node] = []
	if str(from.name) == node_name:
		found.append(from)
	for child in from.get_children():
		found.append_array(_find_all(child, node_name))
	return found


## The one node with this name, or null with _lookup_error set.
func _find_named(node_name: String) -> Node:
	var matches := _find_all(get_tree().root, node_name)
	if matches.is_empty():
		_lookup_error = "ERROR: no node named '%s'" % node_name
		return null
	if matches.size() > 1:
		_lookup_error = "ERROR: '%s' is ambiguous — %d nodes have that name" % [
			node_name, matches.size()]
		return null
	return matches[0]


func _find_control(node_name: String) -> Control:
	var found := _find_named(node_name)
	if found == null:
		return null
	var control := found as Control
	if control == null:
		_lookup_error = "ERROR: '%s' is not a Control" % node_name
	return control


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
