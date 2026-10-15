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


## The console's flag and quote rules need a command that declares a flag
## and a rest argument; only the fixture's `note` does, so the pins live
## here, not in test_debug_console.gd, which scaffolded projects carry.
func test_a_flag_may_precede_a_rest_argument() -> void:
	assert_eq(DebugConsole.execute("note --kind=todo buy milk"), "Noted.")
	assert_string_contains(DebugConsole.execute("notes"), "todo: buy milk", "the flag is named, the rest is the text")
	assert_eq(DebugConsole.execute("note buy --kind=todo eggs"), "Noted.", "anywhere on the line")
	assert_string_contains(DebugConsole.execute("notes"), "todo: buy eggs")
	assert_eq(DebugConsole.execute("note plain one"), "Noted.")
	assert_string_contains(DebugConsole.execute("notes"), "\nplain one", "no flag: the default kind adds nothing")
	assert_string_starts_with(DebugConsole.execute("note --kind=urgent x"), "ERROR", "a flag's value is checked like any argument")
	assert_string_starts_with(DebugConsole.execute("note --nope=1 x"), "ERROR", "an unknown flag is refused")


func test_quotes_reach_the_handler() -> void:
	# A console command may take JSON, where the quotes ARE the value's
	# type; the tokenise rule itself is pinned in test_debug_console.gd.
	assert_eq(DebugConsole.execute('note "Shore War"'), "Noted.")
	assert_string_contains(DebugConsole.execute("notes"), '"Shore War"', "the quotes reach the handler")


func test_sandbox_hook_clears_project_state() -> void:
	DebugConsole.execute("note leak")
	_hooks.sandbox()
	assert_eq(DebugConsole.execute("notes"), "No notes.")
