extends Node
## Controller support's impure half: the ONE reader of raw joypad input.
## Everything a pad does becomes a synthesized ui_* action event, so
## Godot's focus navigation, every menu, a board cursor and the harness's
## `press` command all speak the same vocabulary — and device gating (which
## pad may act right now) lives here and nowhere else.
##
## Load-bearing detail: Godot's BUILT-IN ui_* actions ship with joypad
## events of their own. Those are STRIPPED at startup — if they stayed, a
## pad would drive menus directly past the router and any seat gating
## would be a fiction. Keyboard events on ui_* stay: keyboard and mouse are
## never gated (a pad assignment must not lock anyone out of their own
## game).
##
## Gating is opt-in: a node in the "pad_gate" group answering
## `pad_allowed(device) -> bool` decides; with none present every pad acts.
## Reached by group, because an autoload must not name a scene class.
##
## The pure half (deadzone, dominant-axis quantise, repeat clocks) is
## PadRouter, testable without a controller.

const UI_ACTIONS := ["ui_up", "ui_down", "ui_left", "ui_right",
	"ui_accept", "ui_cancel", "ui_focus_next", "ui_focus_prev"]
const SETTINGS_SECTION := "input"
const DEADZONE_KEY := "pad_deadzone"

var router := PadRouter.new()
## True once the last input came from a controller — hint strips and focus
## fallbacks read it; any mouse or key press flips it back.
var using_pad := false


func _ready() -> void:
	# the pause menu navigates while the tree is paused, so this must too
	process_mode = Node.PROCESS_MODE_ALWAYS
	for action in UI_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				InputMap.action_erase_event(action, event)
	Input.joy_connection_changed.connect(_on_joy_changed)
	_refresh_settings("", "")
	# a METHOD, not a lambda: an autoload signal outlives any scene
	EventBus.settings_changed.connect(_refresh_settings)


func _refresh_settings(_section: String, _key: String) -> void:
	router.deadzone = clampf(float(SaveManager.get_setting(SETTINGS_SECTION, DEADZONE_KEY,
		PadRouter.DEFAULT_DEADZONE)), 0.05, 0.9)


func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		using_pad = false
		return
	if not (event is InputEventJoypadButton):
		return
	using_pad = true
	var pad := event as InputEventJoypadButton
	if not pad.pressed or Keybinds.capturing:
		return
	if not _allowed(pad.device):
		get_viewport().set_input_as_handled()
		return
	var action := PadRouter.button_action(pad.button_index)
	if action != "":
		fire(action)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	# directions POLL (stick and dpad merged), so a held direction repeats
	# like a held arrow key — button events alone would step exactly once
	if Keybinds.capturing:
		return
	for device: int in Input.get_connected_joypads():
		var raw := Vector2(
			Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT):
			raw.x = -1.0
		elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT):
			raw.x = 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP):
			raw.y = -1.0
		elif Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN):
			raw.y = 1.0
		var steps := router.tick(device, raw, delta)
		if steps.is_empty():
			continue
		using_pad = true
		if not _allowed(device):
			continue
		for action in steps:
			fire(action)


## May this device act right now? With no gate present, yes.
func _allowed(device: int) -> bool:
	for gate in get_tree().get_nodes_in_group("pad_gate"):
		if gate.has_method("pad_allowed") and not bool(gate.pad_allowed(device)):
			return false
	return true


## A press+release of a ui_* action, the same events the harness's `press`
## fires — so a scenario written with `press ui_down` IS the pad path.
func fire(action: String) -> void:
	for pressed in [true, false]:
		var synth := InputEventAction.new()
		synth.action = action
		synth.pressed = pressed
		Input.parse_input_event(synth)


func _on_joy_changed(_device: int, _connected: bool) -> void:
	router.reset()
