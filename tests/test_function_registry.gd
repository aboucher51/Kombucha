extends GutTest


var registry: FunctionRegistry


func before_each() -> void:
	registry = FunctionRegistry.new()


func test_register_and_invoke() -> void:
	registry.register("math.double", func(x: int) -> int: return x * 2, "core")
	assert_true(registry.has_function("math.double"))
	assert_eq(registry.invoke("math.double", [21]), 42)
	assert_eq(registry.source_of("math.double"), "core")


func test_last_registration_wins() -> void:
	registry.register("greet", func() -> String: return "core", "core")
	registry.register("greet", func() -> String: return "mod", "mod")
	assert_eq(registry.invoke("greet"), "mod")
	assert_eq(registry.source_of("greet"), "mod")


func test_registered_signal_reports_override() -> void:
	watch_signals(registry)
	registry.register("a", func() -> void: pass, "core")
	assert_signal_emitted_with_parameters(registry, "registered", ["a", "core", false])
	registry.register("a", func() -> void: pass, "mod")
	assert_signal_emitted_with_parameters(registry, "registered", ["a", "mod", true])


func test_missing_id_returns_default_not_crash() -> void:
	# The logged error IS the behaviour under test.
	gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.NOTHING
	assert_eq(registry.invoke("nope", [], -1), -1)
