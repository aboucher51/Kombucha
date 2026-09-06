extends Node
## The single registrar for every rebindable InputMap action: one owner for
## the catalog, the defaults, and the player's overrides — registered
## piecemeal beside their consumers, a settings panel would need every
## consumer's private constants.
##
## Each action has SLOTS binding slots: primary (the default key) and
## secondary (unbound by default, unless the catalog names a "pad" default,
## which lands there so a controller works out of the box). Overrides
## persist through SaveManager's settings file — a keybind describes this
## MACHINE, like the volumes, not any run or save.
##
## A binding is a key, a mouse button, a pad button OR HALF AN AXIS
## ("axis:1:-" is the left stick pushed up): a stick half is a binding
## like a key, so a game whose cursor moves on the stick rebinds it the
## same way. Without that, every pad-aware project grew its own axis
## table beside Keybinds.
##
## CAPTURE (begin_capture / capture_event / capture_text) is the rebinding
## rule set a settings screen feeds raw events into: a modifier alone
## waits, the wheel is ignored, Escape and a click away cancel, Backspace
## clears, a stick counts past 0.5, a taken key is refused and the holder
## named. The screen only displays; the rules live here so the next
## project does not rebuild them (one did, 500 lines).
##
## The catalog is code, not data: an action is only meaningful with a
## handler behind it, and handlers are code.

## Something rebound, cleared or reset — from a settings UI, the console's
## bind/unbind, or the scenario sandbox. A settings panel listens so a
## binding changed OUTSIDE it never shows stale on its rows.
signal bindings_changed

## A capture finished: `result` is "" (bound or cleared), "cancelled", or
## "ERROR: ..." (refused, naming the holder). A settings row listens to
## redraw itself — with a METHOD, this being an autoload signal.
signal capture_ended(action: String, slot: int, result: String)

## Ordered — a settings panel lists its rows in this order. "group" is the
## CONFLICT GROUP: actions in the same group are live in the same context,
## so a key can only mean one of them — see set_binding. Keys may repeat
## across groups. EXTEND THIS as the game grows actions.
## `pad` is the joypad default for the SECOND slot: a JOY_BUTTON_* index,
## or "axis:<n>:<+|->" for a stick or trigger half.
const ACTIONS := [
	{"action": "pause", "key": KEY_ESCAPE, "pad": JOY_BUTTON_START,
		"label": "Pause", "group": "game"},
	{"action": "save_game", "key": KEY_F5, "label": "Quick save", "group": "game"},
	{"action": "load_game", "key": KEY_F9, "label": "Quick load", "group": "game"},
]

const SLOTS := 2
const SETTINGS_SECTION := "keybinds"

## True while a settings UI is listening for a key to bind. Input POLLING
## (Input.get_vector / is_mouse_button_pressed) never sees events consumed
## by the capture UI, so pollers must check this flag themselves — or
## pressing W to rebind "pan up" also pans the camera.
var capturing := false
## {"action", "slot"} while a capture listens; empty otherwise.
var _capture: Dictionary = {}

## action -> Array of InputEvent-or-null, one per slot. The source of truth
## for which slot holds what: InputMap only keeps a flat event list, so an
## action whose primary is unbound but secondary is F could not be read back
## from InputMap alone.
var _slots: Dictionary = {}


func _ready() -> void:
	apply_saved()


## (Re-)reads the settings file and applies every action's bindings — also
## the restore path after the scenario sandbox flips SaveManager.config_path
## back, mirroring AudioManager.apply_saved_volumes().
func apply_saved() -> void:
	for entry in ACTIONS:
		var action: String = entry["action"]
		var slots := _default_slots(entry)
		var stored: Variant = SaveManager.get_setting(SETTINGS_SECTION, action, [])
		if stored is Array:
			for i in mini(stored.size(), SLOTS):
				slots[i] = _decode(str(stored[i]))
		_slots[action] = slots
		_sync(action)
	bindings_changed.emit()


## The event bound to a slot, or null when the slot is unbound.
func binding(action: String, slot: int) -> InputEvent:
	var slots: Array = _slots.get(action, [])
	if slot < 0 or slot >= slots.size():
		return null
	return slots[slot]


## Binds event (null to unbind) to a slot, applies it to InputMap and
## persists. Within a CONFLICT GROUP a key can only mean one thing, and the
## existing owner keeps it: binding a taken key is REFUSED (returns false)
## rather than stolen, so a slip of the finger never silently disarms some
## other control. The player unbinds the old owner first if they mean it.
func set_binding(action: String, slot: int, event: InputEvent) -> bool:
	if not _slots.has(action) or slot < 0 or slot >= SLOTS:
		return false
	if event != null:
		var encoded := _encode(event)
		var group := _group_of(action)
		for entry in ACTIONS:
			var other: String = entry["action"]
			if str(entry.get("group", "game")) != group:
				continue
			for i in SLOTS:
				if (other != action or i != slot) and _encode(binding(other, i)) == encoded:
					return false
	_slots[action][slot] = event
	_sync(action)
	_persist(action)
	bindings_changed.emit()
	return true


## The action already holding `event` within `group`, or "" — what a
## refusal can name when explaining itself.
func holder_of(event: InputEvent, group: String) -> String:
	var encoded := _encode(event)
	for entry in ACTIONS:
		if str(entry.get("group", "game")) != group:
			continue
		var other: String = entry["action"]
		for i in SLOTS:
			if _encode(binding(other, i)) == encoded:
				return other
	return ""


func group_of(action: String) -> String:
	return _group_of(action)


func clear_binding(action: String, slot: int) -> void:
	set_binding(action, slot, null)


## Every action back to its default keys — persisted, so it is also how the
## scenario sandbox pins a known keyboard whatever the previous scenario did.
func reset_to_defaults() -> void:
	for entry in ACTIONS:
		var action: String = entry["action"]
		_slots[action] = _default_slots(entry)
		_sync(action)
		_persist(action)
	bindings_changed.emit()


func has_action(action: String) -> bool:
	return _slots.has(action)


## What to print on a bind button or in the console: "F5", "Middle click" —
## or "" for an unbound slot, so the caller chooses its own "Unbound" text.
func describe(action: String, slot: int) -> String:
	return describe_event(binding(action, slot))


func describe_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key_name := OS.get_keycode_string((event as InputEventKey).physical_keycode)
		# a few OS names nobody's keyboard uses
		return {"QuoteLeft": "`", "Escape": "Esc"}.get(key_name, key_name)
	if event is InputEventMouseButton:
		var index := (event as InputEventMouseButton).button_index
		match index:
			MOUSE_BUTTON_LEFT: return "Left click"
			MOUSE_BUTTON_RIGHT: return "Right click"
			MOUSE_BUTTON_MIDDLE: return "Middle click"
			_: return "Mouse %d" % index
	if event is InputEventJoypadButton:
		var button := (event as InputEventJoypadButton).button_index
		if button >= 0 and button < PAD_NAMES.size():
			return "Pad %s" % PAD_NAMES[button]
		return "Pad button %d" % button
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var half := 1 if motion.axis_value >= 0.0 else 0
		if AXIS_NAMES.has(motion.axis):
			return AXIS_NAMES[motion.axis][half]
		return "Axis %d %s" % [motion.axis, "+" if half == 1 else "-"]
	return ""


## Index = JoyButton value; xbox-style names, the lingua franca of prompts.
const PAD_NAMES := ["A", "B", "X", "Y", "Back", "Guide", "Start",
	"L-stick", "R-stick", "LB", "RB", "D-up", "D-down", "D-left", "D-right"]
## Axis -> [negative half, positive half]; a trigger only has a positive one.
const AXIS_NAMES := {
	JOY_AXIS_LEFT_X: ["Left stick left", "Left stick right"],
	JOY_AXIS_LEFT_Y: ["Left stick up", "Left stick down"],
	JOY_AXIS_RIGHT_X: ["Right stick left", "Right stick right"],
	JOY_AXIS_RIGHT_Y: ["Right stick up", "Right stick down"],
	JOY_AXIS_TRIGGER_LEFT: ["LT", "LT"],
	JOY_AXIS_TRIGGER_RIGHT: ["RT", "RT"],
}


# ── capture: the rebinding rules, UI-free ──────────────────────────────────

## Start listening for the event that will fill this action's slot. The
## settings screen calls this from its key button, then routes `_input`
## events to capture_event while is_capturing().
func begin_capture(action: String, slot: int = 0) -> String:
	if not _slots.has(action):
		return "ERROR: no action '%s'" % action
	if slot < 0 or slot >= SLOTS:
		return "ERROR: slot must be 0..%d" % (SLOTS - 1)
	_capture = {"action": action, "slot": slot}
	capturing = true
	return ""


func is_capturing() -> bool:
	return not _capture.is_empty()


func cancel_capture() -> String:
	if _capture.is_empty():
		return ""
	var action := str(_capture["action"])
	var slot := int(_capture["slot"])
	_capture = {}
	capturing = false
	capture_ended.emit(action, slot, "cancelled")
	return ""


## Feed a raw event from the screen's `_input` (which runs before the GUI,
## so the key never also presses the button under it). Returns true when
## the event was CONSUMED — the caller then set_input_as_handled(). A
## modifier alone waits for the real key, the wheel is never a binding,
## Escape and a click away keep the old binding, Backspace/Delete clear
## the slot, a stick counts once pushed past 0.5.
func capture_event(event: InputEvent) -> bool:
	if _capture.is_empty():
		return false
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo:
			return false
		if key.physical_keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return true
		if key.physical_keycode == KEY_ESCAPE:
			cancel_capture()
		elif key.physical_keycode == KEY_BACKSPACE or key.physical_keycode == KEY_DELETE:
			_apply_capture(null)
		else:
			var clean := InputEventKey.new()
			clean.physical_keycode = key.physical_keycode
			_apply_capture(clean)
		return true
	if event is InputEventJoypadButton:
		if not (event as InputEventJoypadButton).pressed:
			return false
		var pad := InputEventJoypadButton.new()
		pad.button_index = (event as InputEventJoypadButton).button_index
		_apply_capture(pad)
		return true
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) < 0.5:
			return false
		var axis := InputEventJoypadMotion.new()
		axis.axis = motion.axis
		axis.axis_value = 1.0 if motion.axis_value > 0.0 else -1.0
		_apply_capture(axis)
		return true
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if not mouse.pressed:
			return false
		match mouse.button_index:
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT:
				cancel_capture()
				return true
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT:
				return false
			_:
				var clean := InputEventMouseButton.new()
				clean.button_index = mouse.button_index
				_apply_capture(clean)
				return true
	return false


## The input-free answer to a capture: "F7", "mouse:3", "joy:0",
## "axis:0:-", "escape" or "clear" — what a test or a scenario presses.
## Error-shaped on a refusal so a scenario that expects one can say so.
func capture_text(text: String) -> String:
	if _capture.is_empty():
		return "ERROR: not listening for a key (begin_capture first)"
	match text.to_lower():
		"escape", "esc": return cancel_capture()
		"clear", "backspace": return _apply_capture(null)
	var event := parse_binding_text(text)
	if event == null:
		return "ERROR: '%s' names no key" % text
	return _apply_capture(event)


## Bind (or clear, for null) into the listening slot and stop listening.
## A refusal names the holder instead of stealing the key.
func _apply_capture(event: InputEvent) -> String:
	var action := str(_capture["action"])
	var slot := int(_capture["slot"])
	_capture = {}
	capturing = false
	var result := ""
	if not set_binding(action, slot, event):
		var holder := holder_of(event, _group_of(action))
		if holder.is_empty():
			result = "ERROR: '%s' cannot be bound" % describe_event(event)
		else:
			result = "ERROR: %s already means %s" % [describe_event(event), holder]
	capture_ended.emit(action, slot, result)
	return result


## "F5", "W" (OS key names) or "mouse:4" into an event — a console bind
## command speaks this. Null when the text names nothing.
func parse_binding_text(text: String) -> InputEvent:
	return _decode(_normalise(text))


func _normalise(text: String) -> String:
	if text.begins_with("mouse:") or text.begins_with("key:") \
			or text.begins_with("joy:") or text.begins_with("axis:"):
		return text
	return "key:" + text


func _group_of(action: String) -> String:
	for entry in ACTIONS:
		if entry["action"] == action:
			return str(entry.get("group", "game"))
	return "game"


func _default_slots(entry: Dictionary) -> Array:
	var primary := InputEventKey.new()
	primary.physical_keycode = entry["key"]
	var slots: Array = [primary]
	slots.resize(SLOTS)  # secondary defaults unbound...
	if entry.has("pad") and SLOTS > 1:   # ...unless the catalog names a pad default
		var pad: Variant = entry["pad"]
		slots[1] = _decode(str(pad) if pad is String else "joy:%d" % int(pad))
	return slots


## Applies a single action's slots to InputMap, creating the action on
## first touch. InputMap itself is only ever written, never read back —
## see _slots.
func _sync(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	for event in _slots[action]:
		if event != null:
			InputMap.action_add_event(action, event)


func _persist(action: String) -> void:
	var encoded: Array[String] = []
	for event in _slots[action]:
		encoded.append(_encode(event))
	SaveManager.set_setting(SETTINGS_SECTION, action, encoded)


## A binding as a compact, hand-editable string — "key:F5", "mouse:3", ""
## for unbound. Chosen over var_to_str(event) so a settings.cfg keybind is
## legible and a support answer can say "put key:F5 back".
func _encode(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:" + OS.get_keycode_string((event as InputEventKey).physical_keycode)
	if event is InputEventMouseButton:
		return "mouse:%d" % (event as InputEventMouseButton).button_index
	if event is InputEventJoypadButton:
		return "joy:%d" % (event as InputEventJoypadButton).button_index
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		return "axis:%d:%s" % [motion.axis, "+" if motion.axis_value >= 0.0 else "-"]
	return ""


func _decode(text: String) -> InputEvent:
	if text.begins_with("key:"):
		var keycode := OS.find_keycode_from_string(text.trim_prefix("key:"))
		if keycode == KEY_NONE:
			return null
		var event := InputEventKey.new()
		event.physical_keycode = keycode
		return event
	if text.begins_with("mouse:"):
		var index := text.trim_prefix("mouse:").to_int()
		if index < 1:
			return null
		var event := InputEventMouseButton.new()
		event.button_index = index as MouseButton
		return event
	if text.begins_with("joy:"):
		var raw := text.trim_prefix("joy:")
		if not raw.is_valid_int() or raw.to_int() < 0:
			return null
		var event := InputEventJoypadButton.new()
		event.button_index = raw.to_int() as JoyButton
		return event
	if text.begins_with("axis:"):
		# axis:<n>:<+|->, the half of the axis that means the action
		var parts := text.split(":")
		if parts.size() != 3 or not parts[1].is_valid_int() or parts[1].to_int() < 0 \
				or parts[2] not in ["+", "-"]:
			return null
		var event := InputEventJoypadMotion.new()
		event.axis = parts[1].to_int() as JoyAxis
		event.axis_value = 1.0 if parts[2] == "+" else -1.0
		return event
	return null
