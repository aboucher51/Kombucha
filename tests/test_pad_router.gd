extends GutTest
## The pure half of controller support, pinned without a controller: the
## button map, deadzone and dominant-axis quantise, the held-direction
## repeat clock, and seat gating.

var _router: PadRouter


func before_each() -> void:
	_router = PadRouter.new()


func test_face_buttons_map_to_accept_and_cancel() -> void:
	assert_eq(PadRouter.button_action(JOY_BUTTON_A), "ui_accept")
	assert_eq(PadRouter.button_action(JOY_BUTTON_B), "ui_cancel")
	assert_eq(PadRouter.button_action(JOY_BUTTON_DPAD_UP), "", "directions flow through tick()")


func test_inside_the_deadzone_nothing_fires() -> void:
	assert_eq(_router.tick(0, Vector2(0.1, 0.1), 0.016), [])


func test_dominant_axis_wins_and_a_fresh_press_steps_once() -> void:
	assert_eq(_router.tick(0, Vector2(0.3, 0.9), 0.016), ["ui_down"])
	assert_eq(_router.tick(0, Vector2(0.3, 0.9), 0.016), [], "held: no second step yet")


func test_a_held_direction_echoes_after_the_initial_delay_then_faster() -> void:
	_router.tick(0, Vector2(-1, 0), 0.016)
	var steps := 0
	var t := 0.0
	# stop one tick short of the delay: the clock accumulates per tick
	while t + 0.05 < PadRouter.INITIAL_DELAY:
		steps += _router.tick(0, Vector2(-1, 0), 0.05).size()
		t += 0.05
	assert_eq(steps, 0, "nothing before the initial delay")
	steps = 0
	for i in 10:
		steps += _router.tick(0, Vector2(-1, 0), 0.05).size()
	assert_gte(steps, 3, "then roughly one per REPEAT_EVERY")


func test_releasing_and_pressing_again_steps_at_once() -> void:
	_router.tick(0, Vector2(1, 0), 0.016)
	_router.tick(0, Vector2.ZERO, 0.016)
	assert_eq(_router.tick(0, Vector2(1, 0), 0.016), ["ui_right"])


func test_devices_keep_separate_clocks() -> void:
	assert_eq(_router.tick(0, Vector2(0, -1), 0.016), ["ui_up"])
	assert_eq(_router.tick(1, Vector2(0, -1), 0.016), ["ui_up"], "a second pad is not the first's echo")


func test_device_gating_falls_open_unless_another_seat_owns_the_pad() -> void:
	assert_true(PadRouter.device_allowed([], 0, 3), "no seats: anyone")
	assert_true(PadRouter.device_allowed([-1, -1], 0, 3), "unassigned seat: anyone")
	assert_true(PadRouter.device_allowed([3, -1], 0, 3), "own pad")
	assert_false(PadRouter.device_allowed([3, 4], 0, 4), "the other seat's pad is refused")
	assert_true(PadRouter.device_allowed([3, 4], 0, 5), "a pad nobody claimed still acts")
	assert_true(PadRouter.device_allowed([3, 4], -1, 4), "no active seat: no gating")
