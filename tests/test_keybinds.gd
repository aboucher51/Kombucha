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
