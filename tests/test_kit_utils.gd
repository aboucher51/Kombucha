extends GutTest
## The small kit utilities: each is the codified form of a CLAUDE.md scar.


func test_truthy_reads_json_values_by_their_type() -> void:
	assert_false(JsonValue.truthy(null))
	assert_true(JsonValue.truthy(null, true), "fallback answers only for absent")
	assert_true(JsonValue.truthy("submerged"))
	assert_false(JsonValue.truthy(""))
	assert_false(JsonValue.truthy(0.0))
	assert_true(JsonValue.truthy(2))
	assert_false(JsonValue.truthy({}))
	assert_true(JsonValue.truthy([1]))


func test_typed_truthy_reads_the_word_false() -> void:
	assert_false(JsonValue.typed_truthy("false"))
	assert_true(JsonValue.truthy("false"), "a data string 'false' is still set")


func test_version_compare_and_malformed_reads_low() -> void:
	assert_eq(VersionUtil.compare("1.2.0", "1.10"), -1)
	assert_true(VersionUtil.at_least("2.0", "1.9.9"))
	assert_eq(VersionUtil.compare("1.0", "1.0.0"), 0)
	assert_true(VersionUtil.compare("garbage", "0.0.1") < 0, "junk compares low, never crashes")
	assert_eq(VersionUtil.game(), "0.1.0")


func test_bbcode_escape_and_sanitise() -> void:
	assert_eq(BBCode.escape("[b]x[/b]"), "[lb]b]x[lb]/b]")
	assert_eq(BBCode.sanitise("hi\nthere!", 100), "hi there!")
	assert_eq(BBCode.sanitise("x".repeat(500), 10).length(), 10)


func test_runtime_textures_placeholder_and_missing() -> void:
	assert_null(RuntimeTextures.from_path("user://no_such_file.png"))
	assert_null(RuntimeTextures.from_path(""))
	var placeholder := RuntimeTextures.placeholder()
	assert_not_null(placeholder)
	assert_eq(placeholder, RuntimeTextures.placeholder(), "one shared placeholder")
