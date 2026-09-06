extends GutTest
## Keybinds contract: conflict refusal, persistence round trip, legible
## encoding. Bindings and settings are global state — every test runs against
## a scratch config and puts the defaults back.

const SCRATCH_CONFIG := "user://test_keybinds.cfg"


func before_each() -> void:
	SaveManager.config_path = SCRATCH_CONFIG
	Keybinds.reset_to_defaults()


func after_each() -> void:
	Keybinds.reset_to_defaults()
	DirAccess.remove_absolute(SCRATCH_CONFIG)
	SaveManager.config_path = SaveManager.DEFAULT_CONFIG_PATH
	Keybinds.apply_saved()


func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	return event


func test_defaults_reach_input_map() -> void:
	var events := InputMap.action_get_events("pause")
	assert_eq(events.size(), 2, "the key and the catalog's pad button")
	assert_eq((events[0] as InputEventKey).physical_keycode, KEY_ESCAPE)
	assert_eq(InputMap.action_get_events("save_game").size(), 1, "no pad named: key only")


func test_rebind_and_persist_round_trip() -> void:
	assert_true(Keybinds.set_binding("pause", 0, _key(KEY_P)))
	# Wipe the live state and re-read from disk — the override must survive.
	Keybinds.apply_saved()
	assert_eq(Keybinds.describe("pause", 0), "P")
	var events := InputMap.action_get_events("pause")
	assert_eq((events[0] as InputEventKey).physical_keycode, KEY_P)


func test_secondary_slot_defaults_unbound_without_a_pad_entry() -> void:
	assert_null(Keybinds.binding("save_game", 1))
	assert_eq(Keybinds.describe("save_game", 1), "")


func test_conflict_within_group_is_refused_not_stolen() -> void:
	# F5 belongs to save_game; pause may not take it.
	assert_false(Keybinds.set_binding("pause", 0, _key(KEY_F5)))
	assert_eq(Keybinds.describe("save_game", 0), "F5", "owner keeps the key")
	assert_eq(Keybinds.describe("pause", 0), "Esc", "loser keeps its old key")
	assert_eq(Keybinds.holder_of(_key(KEY_F5), "game"), "save_game")


func test_unbind_then_rebind_frees_the_key() -> void:
	Keybinds.clear_binding("save_game", 0)
	assert_true(Keybinds.set_binding("pause", 0, _key(KEY_F5)))


func test_reset_restores_defaults() -> void:
	Keybinds.set_binding("pause", 0, _key(KEY_P))
	Keybinds.reset_to_defaults()
	assert_eq(Keybinds.describe("pause", 0), "Esc")


func test_parse_binding_text() -> void:
	var key := Keybinds.parse_binding_text("F5")
	assert_eq((key as InputEventKey).physical_keycode, KEY_F5)
	var mouse := Keybinds.parse_binding_text("mouse:3")
	assert_eq((mouse as InputEventMouseButton).button_index, MOUSE_BUTTON_MIDDLE)
	assert_null(Keybinds.parse_binding_text("key:NotAKey"))


func test_describe_uses_friendly_names_for_odd_os_names() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	assert_eq(Keybinds.describe_event(event), "Esc")
	event.physical_keycode = KEY_QUOTELEFT
	assert_eq(Keybinds.describe_event(event), "`")


func test_a_catalog_pad_button_lands_in_the_secondary_slot() -> void:
	Keybinds.reset_to_defaults()
	var pad := Keybinds.binding("pause", 1)
	assert_true(pad is InputEventJoypadButton, "pause carries a pad default")
	assert_eq((pad as InputEventJoypadButton).button_index, JOY_BUTTON_START)
	assert_eq(Keybinds.describe("pause", 1), "Pad Start")
	assert_true(InputMap.action_has_event("pause", pad), "and it reached the InputMap")


func test_joy_bindings_round_trip_as_text() -> void:
	var event := Keybinds.parse_binding_text("joy:%d" % JOY_BUTTON_Y)
	assert_true(event is InputEventJoypadButton)
	assert_eq(Keybinds.describe_event(event), "Pad Y")
	assert_null(Keybinds.parse_binding_text("joy:-3"))


func test_an_axis_half_is_a_binding_like_a_key() -> void:
	var up := Keybinds.parse_binding_text("axis:1:-")
	assert_true(up is InputEventJoypadMotion)
	assert_eq((up as InputEventJoypadMotion).axis, JOY_AXIS_LEFT_Y)
	assert_eq((up as InputEventJoypadMotion).axis_value, -1.0)
	assert_eq(Keybinds.describe_event(up), "Left stick up")
	assert_true(Keybinds.set_binding("save_game", 1, up))
	Keybinds.apply_saved()
	assert_eq(Keybinds.describe("save_game", 1), "Left stick up", "survives the settings round trip")
	assert_true(InputMap.action_has_event("save_game", up), "and reached the InputMap")
	assert_null(Keybinds.parse_binding_text("axis:1"), "a half is required")
	assert_null(Keybinds.parse_binding_text("axis:x:+"))
	assert_eq(Keybinds.describe_event(Keybinds.parse_binding_text("axis:5:+")), "RT")


func test_an_axis_conflicts_like_a_key_and_the_holder_is_named() -> void:
	var down := Keybinds.parse_binding_text("axis:1:+")
	assert_true(Keybinds.set_binding("save_game", 1, down))
	assert_false(Keybinds.set_binding("load_game", 1, Keybinds.parse_binding_text("axis:1:+")), "refused, not stolen")
	assert_eq(Keybinds.holder_of(down, "game"), "save_game")
	assert_true(Keybinds.set_binding("load_game", 1, Keybinds.parse_binding_text("axis:1:-")), "the other half is free")


func test_capture_binds_the_next_key_and_tells_pollers() -> void:
	var ended: Array = []
	Keybinds.capture_ended.connect(func(action: String, slot: int, result: String) -> void:
		ended.append([action, slot, result]))
	assert_eq(Keybinds.begin_capture("save_game"), "")
	assert_true(Keybinds.capturing, "pollers are told")
	assert_true(Keybinds.is_capturing())
	var shift := _key(KEY_SHIFT)
	shift.pressed = true
	assert_true(Keybinds.capture_event(shift), "consumed...")
	assert_true(Keybinds.is_capturing(), "...but a modifier alone waits for the real key")
	var f7 := _key(KEY_F7)
	f7.pressed = true
	assert_true(Keybinds.capture_event(f7))
	assert_false(Keybinds.capturing)
	assert_eq(Keybinds.describe("save_game", 0), "F7")
	assert_eq(ended, [["save_game", 0, ""]])
	assert_false(Keybinds.capture_event(f7), "nothing listening: not consumed")
	assert_string_starts_with(Keybinds.begin_capture("no_such_action"), "ERROR")
	assert_string_starts_with(Keybinds.begin_capture("pause", 9), "ERROR")


func test_capture_refuses_a_taken_key_and_names_the_holder() -> void:
	assert_eq(Keybinds.begin_capture("pause"), "")
	var result := Keybinds.capture_text("F5")
	assert_string_starts_with(result, "ERROR", "F5 is save_game's")
	assert_string_contains(result, "save_game")
	assert_eq(Keybinds.describe("pause", 0), "Esc", "nothing was stolen")
	assert_false(Keybinds.is_capturing(), "a refusal ends the capture")
	assert_string_starts_with(Keybinds.capture_text("F7"), "ERROR", "not listening any more")


func test_capture_escape_and_a_click_cancel_backspace_clears_the_wheel_waits() -> void:
	assert_eq(Keybinds.begin_capture("pause"), "")
	var escape := _key(KEY_ESCAPE)
	escape.pressed = true
	assert_true(Keybinds.capture_event(escape))
	assert_eq(Keybinds.describe("pause", 0), "Esc", "kept")
	assert_false(Keybinds.is_capturing())
	assert_eq(Keybinds.begin_capture("pause", 1), "")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	assert_false(Keybinds.capture_event(wheel), "the wheel is never a binding")
	assert_true(Keybinds.is_capturing())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	assert_true(Keybinds.capture_event(click), "a click away cancels")
	assert_eq(Keybinds.describe("pause", 1), "Pad Start")
	assert_eq(Keybinds.begin_capture("pause", 1), "")
	assert_eq(Keybinds.capture_text("clear"), "")
	assert_null(Keybinds.binding("pause", 1), "the slot is clear")
	assert_eq(Keybinds.begin_capture("pause", 1), "")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 0.2
	assert_false(Keybinds.capture_event(stick), "a stick at rest or on its way is not a push")
	stick.axis_value = 0.9
	assert_true(Keybinds.capture_event(stick))
	assert_eq(Keybinds.describe("pause", 1), "Right stick right")
	assert_eq(Keybinds.begin_capture("pause", 1), "")
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.pressed = true
	assert_true(Keybinds.capture_event(middle))
	assert_eq(Keybinds.describe("pause", 1), "Middle click")
