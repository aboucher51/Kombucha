extends GutTest
## The console's execute() seam — the same surface scenarios drive. Failures
## must be "ERROR:"-shaped: the harness fails a scenario on exactly that
## prefix, so a handler that reports failure any other way passes silently.

const SCRATCH_SAVES := "user://test_console_saves"
const SCRATCH_CONFIG := "user://test_console.cfg"


func before_each() -> void:
	SaveManager.save_root = SCRATCH_SAVES
	SaveManager.config_path = SCRATCH_CONFIG
	SaveManager.current_slot = SaveManager.DEFAULT_SLOT


func after_each() -> void:
	Keybinds.reset_to_defaults()
	for save_name in ["slot_1", "other"]:
		SaveManager.delete_save(save_name)
	DirAccess.remove_absolute(SCRATCH_CONFIG)
	SaveManager.save_root = SaveManager.DEFAULT_SAVE_ROOT
	SaveManager.config_path = SaveManager.DEFAULT_CONFIG_PATH
	Keybinds.apply_saved()


func test_unknown_command_is_error_shaped() -> void:
	assert_string_starts_with(DebugConsole.execute("frobnicate"), "ERROR:")


func test_help_lists_commands() -> void:
	var reply := DebugConsole.execute("help")
	assert_string_contains(reply, "save")
	assert_string_contains(reply, "volume")


func test_missing_required_arg_is_error_with_usage() -> void:
	var reply := DebugConsole.execute("delete_save")
	assert_string_starts_with(reply, "ERROR:")
	assert_string_contains(reply, "Usage:")


func test_bad_enum_value_is_error() -> void:
	assert_string_starts_with(DebugConsole.execute("volume Ambience 50"), "ERROR:")


func test_save_load_round_trip_via_console() -> void:
	assert_string_contains(DebugConsole.execute("save other"), "Saved")
	assert_true(SaveManager.has_save("other"))
	assert_string_contains(DebugConsole.execute("saves"), "other")
	assert_string_contains(DebugConsole.execute("load other"), "Loaded")
	assert_string_contains(DebugConsole.execute("delete_save other"), "Deleted")
	assert_false(SaveManager.has_save("other"))


func test_load_missing_save_is_error() -> void:
	assert_string_starts_with(DebugConsole.execute("load nothing_here"), "ERROR:")


func test_volume_applies() -> void:
	DebugConsole.execute("volume Music 40")
	assert_almost_eq(AudioManager.get_bus_volume(&"Music"), 0.4, 0.01)
	DebugConsole.execute("volume Music 100")


func test_bind_and_refusal() -> void:
	assert_string_contains(DebugConsole.execute("bind pause P"), "Bound")
	assert_eq(Keybinds.describe("pause", 0), "P")
	# F5 is save_game's — the refusal must name the holder.
	var reply := DebugConsole.execute("bind pause F5")
	assert_string_starts_with(reply, "ERROR:")
	assert_string_contains(reply, "save_game")


func test_alias_resolves() -> void:
	assert_string_contains(DebugConsole.execute("?"), "help")
