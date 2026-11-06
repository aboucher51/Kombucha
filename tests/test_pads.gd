extends GutTest
## The Pads autoload's right-stick read: the test seam, the pad gate, and
## the rule that a rebind waiting for a key stops every input poll.
## Godot lists only real controllers as connected, so these tests set the
## axes of pads 3 and 4 through Input and hand right_stick_of() the list.

const PAD_A := 3
const PAD_B := 4


## A gate that lets only one pad act, the way a seat owns its controller.
class OnlyPad extends Node:
	var device := -1

	func pad_allowed(asked: int) -> bool:
		return asked == device


func before_each() -> void:
	Pads.stick_override = Vector2.ZERO
	Pads.router.deadzone = 0.25


func after_each() -> void:
	Pads.stick_override = Vector2.ZERO
	Keybinds.cancel_capture()
	for device in [PAD_A, PAD_B]:
		_push_right_stick(device, Vector2.ZERO)
	Pads._refresh_settings("", "")


func _push_right_stick(device: int, value: Vector2) -> void:
	for axis_value: Array in [[JOY_AXIS_RIGHT_X, value.x], [JOY_AXIS_RIGHT_Y, value.y]]:
		var motion := InputEventJoypadMotion.new()
		motion.device = device
		motion.axis = axis_value[0]
		motion.axis_value = axis_value[1]
		Input.parse_input_event(motion)
	# Godot may hold input events until the next frame; read them in now.
	Input.flush_buffered_events()


func test_the_override_pushes_the_stick_without_a_controller() -> void:
	assert_eq(Pads.right_stick(), Vector2.ZERO, "no controller, no override: still")
	Pads.stick_override = Vector2(0.5, -0.25)
	assert_eq(Pads.right_stick(), Vector2(0.5, -0.25))
	Pads.stick_override = Vector2(3.0, 4.0)
	assert_almost_eq(Pads.right_stick(), Vector2(0.6, 0.8), Vector2(0.001, 0.001),
		"the read never goes past the rim")


func test_the_stick_reads_zero_while_a_rebind_waits_for_a_key() -> void:
	_push_right_stick(PAD_A, Vector2(1.0, 0.0))
	assert_eq(Keybinds.begin_capture("save_game"), "")
	assert_eq(Pads.right_stick_of([PAD_A]), Vector2.ZERO,
		"pushing a stick to rebind it must not also pan the view")
	Keybinds.cancel_capture()
	assert_almost_eq(Pads.right_stick_of([PAD_A]), Vector2(1.0, 0.0), Vector2(0.001, 0.001),
		"and reads again once it ends")


func test_every_allowed_pad_adds_in_through_the_deadzone_curve() -> void:
	_push_right_stick(PAD_A, Vector2(0.625, 0.0))
	_push_right_stick(PAD_B, Vector2(0.0, 0.2))
	assert_almost_eq(Pads.right_stick_of([PAD_A, PAD_B]), Vector2(0.5, 0.0),
		Vector2(0.001, 0.001), "pad B sits inside the deadzone and adds nothing")
	_push_right_stick(PAD_B, Vector2(0.0, 0.625))
	assert_almost_eq(Pads.right_stick_of([PAD_A, PAD_B]), Vector2(0.5, 0.5),
		Vector2(0.001, 0.001))


func test_a_pad_the_gate_refuses_does_not_move_the_stick() -> void:
	_push_right_stick(PAD_A, Vector2(0.625, 0.0))
	_push_right_stick(PAD_B, Vector2(0.0, 1.0))
	var gate := OnlyPad.new()
	gate.device = PAD_A
	add_child_autofree(gate)
	gate.add_to_group("pad_gate")
	assert_almost_eq(Pads.right_stick_of([PAD_A, PAD_B]), Vector2(0.5, 0.0),
		Vector2(0.001, 0.001), "only the gate's own pad counts")
