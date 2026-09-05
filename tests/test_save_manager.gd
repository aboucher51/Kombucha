extends GutTest
## SaveManager round-trip against scratch storage. Redirecting save_root /
## config_path (and putting them back in after_each) is the pattern every
## persistence test here must follow — a test must never touch the player's
## real saves. Writes real files rather than mocking FileAccess: the disk
## path is the thing under test.

const SCRATCH_SAVES := "user://test_saves"
const SCRATCH_CONFIG := "user://test_settings.cfg"


func before_each() -> void:
	SaveManager.save_root = SCRATCH_SAVES
	SaveManager.config_path = SCRATCH_CONFIG
	SaveManager.delete_save("slot_test")


func after_each() -> void:
	SaveManager.delete_save("slot_test")
	DirAccess.remove_absolute(SCRATCH_CONFIG)
	SaveManager.save_root = SaveManager.DEFAULT_SAVE_ROOT
	SaveManager.config_path = SaveManager.DEFAULT_CONFIG_PATH
	SaveManager.current_slot = SaveManager.DEFAULT_SLOT


func test_save_then_has_save() -> void:
	assert_false(SaveManager.has_save("slot_test"))
	assert_eq(SaveManager.save_game("slot_test"), OK)
	assert_true(SaveManager.has_save("slot_test"))


func test_load_missing_slot_errors() -> void:
	assert_ne(SaveManager.load_game("slot_test"), OK)


func test_save_load_round_trip() -> void:
	assert_eq(SaveManager.save_game("slot_test"), OK)
	assert_eq(SaveManager.load_game("slot_test"), OK)


func test_delete_save() -> void:
	SaveManager.save_game("slot_test")
	SaveManager.delete_save("slot_test")
	assert_false(SaveManager.has_save("slot_test"))


func test_setting_round_trip() -> void:
	SaveManager.set_setting("audio", "music_volume", 0.5)
	assert_eq(SaveManager.get_setting("audio", "music_volume"), 0.5)
	assert_eq(SaveManager.get_setting("audio", "missing", 1.0), 1.0)


func test_a_saved_dictionary_equals_itself_key_order_included() -> void:
	# JSON.stringify sorts keys by default and Dictionary equality is
	# order-sensitive; two projects found a saved dictionary coming back
	# unequal to the one that was saved.
	var path := "%s/slot_test.json" % SaveManager.save_root
	DirAccess.make_dir_recursive_absolute(SaveManager.save_root)
	# Floats on purpose: JSON has no int type, so 1 comes back as 1.0 — the
	# other thing JSON quietly breaks, and not what this test is about.
	var original := {"zeta": 1.0, "alpha": 2.0, "mid": {"y": 1.0, "x": 2.0}}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(original, "\t", false))
	file.close()
	var back: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_eq(back, original, "round trip must preserve key order")
	assert_eq((back as Dictionary).keys(), original.keys(), "keys in insertion order, not sorted")
	assert_eq(JSON.stringify(SaveManager.collect_save_data(), "\t", false),
		JSON.stringify(SaveManager.collect_save_data(), "\t", false))


func test_a_corrupt_save_loads_with_a_reason() -> void:
	var path := "%s/slot_test.json" % SaveManager.save_root
	DirAccess.make_dir_recursive_absolute(SaveManager.save_root)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("this is not json")
	file.close()
	assert_eq(SaveManager.load_game("slot_test"), ERR_INVALID_DATA)
	assert_false(SaveManager.last_load_problem.is_empty(), "the failure names itself")
	assert_ne(SaveManager.load_game("slot_missing"), OK)
	assert_string_contains(SaveManager.last_load_problem, "slot_missing")


func test_set_setting_announces_itself() -> void:
	watch_signals(EventBus)
	SaveManager.set_setting("audio", "music_volume", 0.5)
	assert_signal_emitted_with_parameters(EventBus, "settings_changed", ["audio", "music_volume"])
