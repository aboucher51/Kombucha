extends GutTest
## The project extension seams of the shared console and harness. The
## fixture's dev_hooks.gd (notes) is the subject; what is really under test
## is that DebugConsole loads hooks + the project command file and defers
## unknown handlers to them, and that the harness's hook calls have
## somewhere to land.

var _hooks: Object


func before_each() -> void:
	_hooks = DebugConsole.hooks
	_hooks.sandbox()


func after_each() -> void:
	_hooks.sandbox()


func test_hooks_are_loaded_and_parented_to_the_console() -> void:
	assert_not_null(_hooks, "DebugConsole.hooks is null — dev_hooks.gd not loaded")
	assert_eq((_hooks as Node).get_parent(), DebugConsole)


func test_project_command_surface_is_merged_into_help() -> void:
	assert_string_contains(DebugConsole.execute("help"), "note")


func test_project_handler_is_dispatched_through_hooks() -> void:
	assert_eq(DebugConsole.execute("note hello there"), "Noted.")
	assert_string_contains(DebugConsole.execute("notes"), "hello there")


func test_unknown_handler_is_still_an_error() -> void:
	# A handler id nobody owns must not slip through the hooks as a pass.
	var reply: Variant = _hooks.console_dispatch("frobnicate", {})
	assert_null(reply, "hooks must answer null for a handler they do not own")


func test_scenario_command_is_error_shaped_and_passes_through_unknowns() -> void:
	assert_null(_hooks.scenario_command(PackedStringArray(["click", "X"]), "click X"))
	assert_true(str(_hooks.scenario_command(PackedStringArray(["assert_note", "x"]), "assert_note x")).begins_with("ERROR:"))
	DebugConsole.execute("note x")
	assert_eq(_hooks.scenario_command(PackedStringArray(["assert_note", "x"]), "assert_note x"), "")


func test_sandbox_hook_clears_project_state() -> void:
	DebugConsole.execute("note leak")
	_hooks.sandbox()
	assert_eq(DebugConsole.execute("notes"), "No notes.")
