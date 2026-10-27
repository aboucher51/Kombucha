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
	for save_name in ["slot_1", "other", "future"]:
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


func test_a_refused_load_names_the_reason() -> void:
	# A save from a newer schema is refused, and the console must say so
	# rather than answer with a bare error number: a scenario's `load`
	# failing on "load failed (20)" is unreadable, "newer version" is not.
	DirAccess.make_dir_recursive_absolute(SCRATCH_SAVES)
	var data := SaveCompat.stamp({})
	data[SaveCompat.KEY]["schema"] = SaveCompat.SCHEMA + 1
	var file := FileAccess.open("%s/future.json" % SCRATCH_SAVES, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var reply := DebugConsole.execute("load future")
	assert_string_starts_with(reply, "ERROR:")
	assert_string_contains(reply, "newer version")


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


## A project hook is asked before the core handler, so it may take a core
## command over; null hands it back.
class OverridingHooks extends Node:
	func console_dispatch(handler: String, _args: Dictionary) -> Variant:
		return "project cleared" if handler == "clear" else null


func test_project_hooks_may_override_a_core_command() -> void:
	var previous: Object = DebugConsole.hooks
	var mine := OverridingHooks.new()
	DebugConsole.hooks = mine
	assert_eq(DebugConsole.execute("clear"), "project cleared")
	assert_string_contains(DebugConsole.execute("help"), "save", "null from the hook falls through to the core handler")
	DebugConsole.hooks = previous
	mine.free()


## A project row with a core row's id replaces it: the fixture's
## console_commands.project.json declares `seed` again. Before, both rows
## were kept, `help seed` showed the core usage and `help` listed seed
## twice (NavalWar's `seed`).
func test_a_project_row_replaces_the_core_row_with_its_id() -> void:
	assert_string_contains(DebugConsole.execute("help seed"), "the fixture's own row")
	var names := DebugConsole.execute("help").split(" ")
	assert_eq(names.count("seed"), 1, "help lists seed once")
	var items: Array = DebugConsole.suggest("seed")["items"]
	assert_eq(items.size(), 1, "one suggestion row for seed")
	if not items.is_empty():
		assert_string_contains(str(items[0]["text"]), "the fixture's own row")
	assert_string_contains(DebugConsole.execute("seed"), "the fixture's own row",
		"a usage error quotes the project row")


## The replaced row keeps the core row's place in the list, and a project
## name that is a core ALIAS takes the alias away from the core row.
func test_merging_rows_keeps_the_place_and_drops_a_taken_alias() -> void:
	var core: Array = [
		{"id": "help", "aliases": ["?", "h"], "usage": "help"},
		{"id": "seed", "usage": "seed <n>"},
		{"id": "quit", "usage": "quit"},
	]
	var project: Array = [
		{"id": "seed", "usage": "seed <n> [mine]"},
		{"id": "hint", "aliases": ["h"], "usage": "hint"},
	]
	var merged: Array = DebugConsole.merge_commands(core, project)
	var ids: Array = merged.map(func(row: Dictionary) -> String: return str(row["id"]))
	assert_eq(ids, ["help", "seed", "quit", "hint"])
	assert_eq(merged[1]["usage"], "seed <n> [mine]")
	assert_eq(merged[0]["aliases"], ["?"], "the project's `h` took the alias from help")
	assert_eq(core[0]["aliases"], ["?", "h"], "the core list itself is not edited")


func test_quotes_survive_tokenising_and_only_the_empty_token_is_special() -> void:
	# A console command may take JSON, where the quotes ARE the value's
	# type; stripping them broke thirteen scenario files in one project.
	# (That the quotes then reach a real handler is pinned against the
	# fixture's `note` command in Kombucha's test_dev_hooks.gd — this
	# file travels to scaffolded projects, which have no `note`.)
	assert_eq(DebugConsole.tokenise('a "b c" d'), PackedStringArray(["a", '"b', 'c"', "d"]),
		"spaces separate; quotes are ordinary characters")
	assert_eq(DebugConsole.tokenise('assert key ""'), PackedStringArray(["assert", "key", ""]),
		"except the empty token")


# ── The upgraded console: gate, key, suggestions, history, buttons ───────
# Only core commands here: this file travels to scaffolded projects.

func _clean_console() -> void:
	DebugConsole.reset_session()
	DirAccess.remove_absolute(DebugConsole.prefs_path())
	DebugConsole.reset_session()


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func test_a_player_build_never_opens_the_console_but_execute_still_answers() -> void:
	_clean_console()
	DebugConsole.simulate_release = true
	assert_false(DebugConsole.allowed(), "a release-flavoured run refuses")
	DebugConsole.toggle()
	assert_false(DebugConsole.is_open(), "toggle does nothing")
	DebugConsole._input(_key(KEY_F12))
	assert_false(DebugConsole.is_open(), "the key is ignored")
	assert_string_contains(DebugConsole.execute("help"), "save", "the harness's seam still answers")
	DebugConsole.simulate_release = false
	assert_true(DebugConsole.allowed(), "a debug run allows it")
	_clean_console()


func test_the_gate_asks_the_project_hook_first() -> void:
	var previous: Object = DebugConsole.hooks
	var mine := GateHooks.new()
	DebugConsole.hooks = mine
	assert_false(DebugConsole.allowed(), "the hook's false wins in a debug run")
	mine.answer = null
	assert_true(DebugConsole.allowed(), "null hands it back to the build check")
	DebugConsole.hooks = previous
	mine.free()


class GateHooks extends Node:
	var answer: Variant = false
	func console_allowed() -> Variant:
		return answer


func test_the_toggle_key_is_tilde_and_f12_or_the_projects_console_action() -> void:
	var had_action := InputMap.has_action("console")
	var saved: Array = InputMap.action_get_events("console") if had_action else []
	if had_action:
		InputMap.erase_action("console")
	assert_true(DebugConsole.is_toggle_event(_key(KEY_QUOTELEFT)), "~ with no console action")
	assert_true(DebugConsole.is_toggle_event(_key(KEY_F12)), "F12 always")
	InputMap.add_action("console")
	InputMap.action_add_event("console", _key(KEY_F2))
	assert_false(DebugConsole.is_toggle_event(_key(KEY_QUOTELEFT)), "the project's action replaces ~")
	assert_true(DebugConsole.is_toggle_event(_key(KEY_F2)), "and is the key instead")
	assert_true(DebugConsole.is_toggle_event(_key(KEY_F12)), "F12 still works")
	InputMap.erase_action("console")
	if had_action:
		InputMap.add_action("console")
		for event in saved:
			InputMap.action_add_event("console", event)


func test_the_first_word_suggests_commands_with_usage_and_description() -> void:
	var got := DebugConsole.suggest("vol")
	assert_eq(str(got["items"][0]["insert"]), "volume ")
	assert_string_contains(str(got["items"][0]["text"]), "volume <bus> <0-100>")
	assert_string_contains(str(got["items"][0]["text"]), "Set a sound bus", "the description rides the row")
	var inside := DebugConsole.suggest("ave")
	var inserts: Array = []
	for row: Dictionary in inside["items"]:
		inserts.append(row["insert"])
	assert_has(inserts, "save ", "a word inside an id matches too")


func test_arguments_show_a_hint_and_their_values() -> void:
	var bus := DebugConsole.suggest("volume ")
	var values: Array = []
	for row: Dictionary in bus["items"]:
		values.append(row["text"])
	assert_eq(values, ["Master", "Music", "SFX"])
	assert_string_contains(str(bus["hint"]), "argument 1 of 2, bus")
	var percent := DebugConsole.suggest("volume Music ")
	assert_string_contains(str(percent["hint"]), "a whole number from 0 to 100, needed")
	var partial := DebugConsole.suggest("volume mu")
	assert_eq(str(partial["items"][0]["insert"]), "Music ")
	assert_eq(int(partial["replace"]), 2, "the half-typed word is what a pick replaces")
	var done := DebugConsole.suggest("volume Music 50 ")
	assert_string_contains(str(done["hint"]), "nothing more to type")
	assert_string_contains(str(DebugConsole.suggest("frobnicate x")["hint"]), "No command")


func test_a_complete_source_offers_live_names() -> void:
	var rows: Array = []
	for row: Dictionary in DebugConsole.suggest("help sav")["items"]:
		rows.append(row["text"])
	assert_has(rows, "save", "help's argument completes command names")
	assert_has(DebugConsole.complete_values("actions", ""), "pause")


func test_history_is_kept_under_the_redirected_save_root() -> void:
	_clean_console()
	assert_string_starts_with(DebugConsole.prefs_path(), SCRATCH_SAVES, "never the developer's own files")
	DebugConsole.remember("volume Music 80")
	DebugConsole.remember("volume Music 80")
	DebugConsole.remember("binds")
	assert_true(FileAccess.file_exists(DebugConsole.prefs_path()))
	DebugConsole.reset_session()
	assert_eq(DebugConsole.history(), ["volume Music 80", "binds"] as Array[String],
		"read back from the file, a repeat stored once")
	assert_eq(DebugConsole.search_history("mus"), ["volume Music 80"] as Array[String])
	_clean_console()


func test_core_buttons_run_known_commands_and_teach_their_line() -> void:
	assert_eq(DebugConsole.button_problems(), [] as Array[String])
	assert_has(DebugConsole.button_groups(), "Console")
	var ids: Array = []
	for row: Dictionary in DebugConsole.buttons():
		ids.append(row["id"])
	for id in ["help", "clear", "restart", "report", "copy_log"]:
		assert_has(ids, id)
	assert_string_contains(DebugConsole.press_button("help"), "volume")
	assert_string_starts_with(DebugConsole.press_button("nope"), "ERROR:")
	var tip := DebugConsole.button_tip(DebugConsole.button_row({"label": "Help", "run": "help", "tip": "Lists every command."}))
	assert_string_contains(tip, "Runs: help")
	assert_eq(str(DebugConsole.button_row({"label": "Copy log"})["id"]), "copy_log")
	_clean_console()


func test_the_ui_builds_named_buttons_and_keeps_its_height() -> void:
	_clean_console()
	DebugConsole.toggle()
	assert_true(DebugConsole.is_open())
	for id in ["help", "clear", "restart", "report", "copy_log"]:
		assert_not_null(DebugConsole.find_child("ConsoleButton_%s" % id, true, false), id)
	assert_not_null(DebugConsole.find_child("ConsoleTab_Console", true, false))
	DebugConsole.set_height(240.0)
	DebugConsole.reset_session()
	assert_false(DebugConsole.is_open(), "a reset closes it")
	assert_almost_eq(DebugConsole.height(), 240.0, 0.5, "the height comes back from the file")
	_clean_console()
