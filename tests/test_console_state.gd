extends GutTest
## The console's state/assert seam: providers are found by group, an
## unknown key is passed to the next provider, mismatches are error-shaped.

var _main: Node


func before_each() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(_main)
	await get_tree().process_frame


func test_state_reports_the_provider() -> void:
	assert_string_contains(DebugConsole.execute("state"), "title=Template project")


func test_assert_matches_and_mismatches_are_error_shaped() -> void:
	assert_eq(DebugConsole.execute("assert title Template project"), "")
	assert_true(DebugConsole.execute("assert title Nope").begins_with("ERROR:"))
	assert_true(DebugConsole.execute("assert paused yes").begins_with("ERROR:"))


func test_unknown_key_is_an_error_naming_the_key() -> void:
	assert_string_contains(DebugConsole.execute("assert nope 1"), "nope")


func test_missing_value_is_a_usage_error() -> void:
	assert_true(DebugConsole.execute("assert title").begins_with("ERROR:"))
