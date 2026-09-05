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
