class_name PadRouter
extends RefCounted
## The pure half of controller support: buttons and stick positions in,
## ui_* action names out. Holds the per-device repeat clocks (deadzone,
## initial delay, echo rate) and the seat-gating arithmetic — everything
## a test can pin without a controller plugged in. The Pads autoload owns
## the impure half: reading real devices and synthesizing the events.

## Held-direction echo: one step at once, the next after INITIAL_DELAY,
## then one per REPEAT_EVERY — the same feel as a held arrow key.
const INITIAL_DELAY := 0.35
const REPEAT_EVERY := 0.12
const DEFAULT_DEADZONE := 0.25

var deadzone := DEFAULT_DEADZONE

## device -> {"dir": Vector2i, "clock": float, "stepped": bool}
var _held: Dictionary = {}


## Face/system buttons -> the ui action they mean. Directions are absent
## on purpose: dpad AND stick both flow through tick() so a held dpad
## repeats exactly like a held stick.
static func button_action(button: int) -> String:
	match button:
		JOY_BUTTON_A:
			return "ui_accept"
		JOY_BUTTON_B:
			return "ui_cancel"
		_:
			return ""


## One frame of a device's merged direction (stick + dpad, each axis in
## -1..1). Returns the ui_* step actions to fire this frame — usually
## none, one on a fresh press, then echoes on the repeat clock.
func tick(device: int, raw: Vector2, delta: float) -> Array[String]:
	var out: Array[String] = []
	var dir := _quantise(raw)
	var held: Dictionary = _held.get(device, {"dir": Vector2i.ZERO,
		"clock": 0.0, "wait": INITIAL_DELAY, "stepped": false})
	if dir != held.dir:
		held = {"dir": dir, "clock": 0.0, "wait": INITIAL_DELAY, "stepped": false}
	if dir == Vector2i.ZERO:
		_held[device] = held
		return out
	if not held.stepped:
		held.stepped = true
		out.append_array(_steps(dir))
	else:
		held.clock = float(held.clock) + delta
		if float(held.clock) >= float(held.wait):
			held.clock = float(held.clock) - float(held.wait)
			held.wait = REPEAT_EVERY
			out.append_array(_steps(dir))
	_held[device] = held
	return out


func reset() -> void:
	_held.clear()


## May this device act right now? seat_devices is per-seat (-1 = any pad);
## active_seat < 0 means no seat is gating (menus, AI turns, replays).
## The empty/any cases fall open on purpose: gating is an OPT-IN per seat,
## and a device nobody claimed serves whoever holds it.
static func device_allowed(seat_devices: Array, active_seat: int,
		device: int) -> bool:
	if active_seat < 0 or active_seat >= seat_devices.size():
		return true
	var assigned := int(seat_devices[active_seat])
	if assigned < 0:
		return true
	if assigned == device:
		return true
	# a device assigned to NO seat may still act — only a pad that belongs
	# to another player is refused
	for seat in seat_devices.size():
		if seat != active_seat and int(seat_devices[seat]) == device:
			return false
	return true


func _quantise(raw: Vector2) -> Vector2i:
	## Dominant axis wins: diagonals are meaningless to focus navigation
	## and a grid cursor, and letting both fire makes the cursor skitter.
	if raw.length() < deadzone:
		return Vector2i.ZERO
	if absf(raw.x) >= absf(raw.y):
		return Vector2i(1 if raw.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if raw.y > 0.0 else -1)


static func _steps(dir: Vector2i) -> Array[String]:
	var out: Array[String] = []
	if dir.x < 0:
		out.append("ui_left")
	elif dir.x > 0:
		out.append("ui_right")
	if dir.y < 0:
		out.append("ui_up")
	elif dir.y > 0:
		out.append("ui_down")
	return out
