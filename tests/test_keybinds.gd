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
	assert_eq(events.size(), 1)
	assert_eq((events[0] as InputEventKey).physical_keycode, KEY_ESCAPE)


func test_rebind_and_persist_round_trip() -> void:
	assert_true(Keybinds.set_binding("pause", 0, _key(KEY_P)))
	# Wipe the live state and re-read from disk — the override must survive.
	Keybinds.apply_saved()
	assert_eq(Keybinds.describe("pause", 0), "P")
	var events := InputMap.action_get_events("pause")
	assert_eq((events[0] as InputEventKey).physical_keycode, KEY_P)


func test_secondary_slot_defaults_unbound() -> void:
	assert_null(Keybinds.binding("pause", 1))
	assert_eq(Keybinds.describe("pause", 1), "")


func test_conflict_within_group_is_refused_not_stolen() -> void:
	# F5 belongs to save_game; pause may not take it.
	assert_false(Keybinds.set_binding("pause", 0, _key(KEY_F5)))
	assert_eq(Keybinds.describe("save_game", 0), "F5", "owner keeps the key")
	assert_eq(Keybinds.describe("pause", 0), "Escape", "loser keeps its old key")
	assert_eq(Keybinds.holder_of(_key(KEY_F5), "game"), "save_game")


func test_unbind_then_rebind_frees_the_key() -> void:
	Keybinds.clear_binding("save_game", 0)
	assert_true(Keybinds.set_binding("pause", 0, _key(KEY_F5)))


func test_reset_restores_defaults() -> void:
	Keybinds.set_binding("pause", 0, _key(KEY_P))
	Keybinds.reset_to_defaults()
	assert_eq(Keybinds.describe("pause", 0), "Escape")


func test_parse_binding_text() -> void:
	var key := Keybinds.parse_binding_text("F5")
	assert_eq((key as InputEventKey).physical_keycode, KEY_F5)
	var mouse := Keybinds.parse_binding_text("mouse:3")
	assert_eq((mouse as InputEventMouseButton).button_index, MOUSE_BUTTON_MIDDLE)
	assert_null(Keybinds.parse_binding_text("key:NotAKey"))
