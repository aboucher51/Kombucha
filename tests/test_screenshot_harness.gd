extends GutTest
## The harness's capture seam. GUT runs under --headless, which is exactly
## the environment where a viewport has no rendered image: the harness must
## answer null (and turn that into an ERROR-shaped reply) rather than crash
## on a null texture image.

const Harness := preload("res://scripts/dev/screenshot_harness.gd")


func test_capture_is_null_without_a_rasterizer() -> void:
	assert_eq(DisplayServer.get_name(), "headless", "GUT is expected to run headless")
	assert_null(Harness.capture(get_viewport()),
		"headless capture must be null, not an empty or garbage image")


func test_sandbox_runs_the_project_hook() -> void:
	# The harness frees itself without --scenario, so drive a fresh one.
	var harness: Node = Harness.new()
	add_child_autofree(harness)
	DebugConsole.execute("note leak")
	harness._sandbox()
	assert_eq(DebugConsole.execute("notes"), "No notes.",
		"_sandbox() must call dev_hooks.sandbox(), or project state leaks between scenarios")
	harness._restore()


# ── expect_shot: the comparison is pure Image work, so it is pinned here ──

func _solid(width: int, height: int, colour: Color) -> Image:
	var image := Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	return image


func test_identical_frames_do_not_differ() -> void:
	var result := Harness.compare(_solid(8, 8, Color.BLUE), _solid(8, 8, Color.BLUE), [])
	assert_eq(result["differing"], 0)
	assert_eq(result["total"], 64)
	assert_null(result["diff"], "the equal case must not pay for a diff image")


func test_a_changed_pixel_is_counted_and_painted_red() -> void:
	var actual := _solid(8, 8, Color.BLUE)
	actual.set_pixel(3, 4, Color.WHITE)
	var result := Harness.compare(actual, _solid(8, 8, Color.BLUE), [])
	assert_eq(result["differing"], 1)
	var diff: Image = result["diff"]
	assert_eq(diff.get_pixel(3, 4), Color.RED, "the differing pixel is red in the diff")
	assert_ne(diff.get_pixel(0, 0), Color.RED, "an equal pixel is not")


func test_a_mask_hides_a_change_but_nothing_else() -> void:
	var actual := _solid(8, 8, Color.BLUE)
	actual.set_pixel(1, 1, Color.WHITE)
	actual.set_pixel(6, 6, Color.WHITE)
	var masks: Array[Rect2i] = [Rect2i(0, 0, 4, 4)]
	var result := Harness.compare(actual, _solid(8, 8, Color.BLUE), masks)
	assert_eq(result["differing"], 1, "the masked change is ignored, the other is not")


func test_a_size_mismatch_is_an_error_not_a_count() -> void:
	var result := Harness.compare(_solid(8, 8, Color.BLUE), _solid(4, 4, Color.BLUE), [])
	assert_true(result.has("error"))
	assert_true(str(result["error"]).begins_with("ERROR"))


func test_renderer_slug_is_the_adapter_family() -> void:
	assert_eq(Harness.renderer_slug("llvmpipe (LLVM 21.1.8, 256 bits)"), "llvmpipe")
	assert_eq(Harness.renderer_slug("NVIDIA GeForce RTX 3080/PCIe/SSE2"), "nvidia")
	assert_eq(Harness.renderer_slug("AMD Radeon RX 6800 XT (RADV NAVI21)"), "amd")
	assert_eq(Harness.renderer_slug(""), "unknown")
	assert_eq(Harness.renderer_slug("D3D12 (NVIDIA GeForce RTX 3080)"), "nvidia",
		"Mesa's d3d12 wrapper names the GPU inside it")


func test_a_missing_baseline_loads_as_null_without_an_engine_error() -> void:
	assert_null(Harness.load_png("res://scenarios/baselines/nowhere/none.png"))


func test_a_baseline_round_trips_through_png_bytes() -> void:
	var image := _solid(4, 4, Color.GREEN)
	var path := "user://harness_roundtrip.png"
	assert_eq(image.save_png(path), OK)
	var back := Harness.load_png(path)
	DirAccess.remove_absolute(path)
	assert_not_null(back)
	assert_eq(Harness.compare(image, back, [])["differing"], 0)


## The same first refusal for scenario lines: a project may take over a
## built-in; null falls through to it.
class ClaimingHooks extends Node:
	func scenario_command(parts: PackedStringArray, _line: String) -> Variant:
		return "ERROR: wait is mine" if parts[0] == "wait" else null


func test_project_hooks_may_override_a_builtin_scenario_command() -> void:
	# Without --scenario the harness frees itself at the end of the frame
	# (cancel_free() does not hold), and an await across that frame would
	# never resume: the seam keeps it for the test.
	Harness.keep_alive_for_tests = true
	var harness: Node = Harness.new()
	add_child_autofree(harness)
	Harness.keep_alive_for_tests = false
	var previous: Object = DebugConsole.hooks
	var mine := ClaimingHooks.new()
	DebugConsole.hooks = mine
	assert_eq(await harness._execute("wait 1"), "ERROR: wait is mine")
	assert_eq(await harness._execute("ticks 1"), "", "null from the hook falls through to the built-in")
	DebugConsole.hooks = previous
	mine.free()


## A state that arrives on the third ask: `until` must keep asking past
## the first two errors, and give back the last error when it never comes.
class ArrivingHooks extends Node:
	var asks := 0
	func scenario_command(parts: PackedStringArray, line: String) -> Variant:
		match parts[0]:
			"arrives":
				asks += 1
				return "" if asks >= 3 else "ERROR: not yet (%d)" % asks
			"never":
				return "ERROR: still waiting"
			"echo":
				return "echo [%s]" % line
		return null


func test_until_watches_a_line_until_it_passes_and_names_the_last_error_when_it_never_does() -> void:
	Harness.keep_alive_for_tests = true
	var harness: Node = Harness.new()
	add_child_autofree(harness)
	Harness.keep_alive_for_tests = false
	var previous: Object = DebugConsole.hooks
	var mine := ArrivingHooks.new()
	DebugConsole.hooks = mine
	assert_eq(await harness._execute("until 5 arrives"), "", "passes once the state arrives")
	assert_eq(mine.asks, 3, "asked once a frame until it answered without an error")
	assert_eq(await harness._execute("until 0.05 never"), "ERROR: after 0.05s still: ERROR: still waiting")
	assert_eq(await harness._execute('until 1 echo "" x'), 'echo [echo "" x]', "the inner line keeps its quotes")
	assert_string_starts_with(await harness._execute("until soon never"), "ERROR: usage")
	DebugConsole.hooks = previous
	mine.free()


# ── name lookup: the visible namesake wins, two visible ones are an error ──

func _named(node_name: String, shown: bool) -> Control:
	var control := Control.new()
	control.name = node_name
	control.visible = shown
	add_child_autofree(control)
	return control


func test_a_hidden_namesake_does_not_make_a_name_ambiguous() -> void:
	var shown := _named("Twin", true)
	_named("Twin", false)
	var picked := Harness.pick_named([shown, get_child(get_child_count() - 1)] as Array[Node], "Twin")
	assert_eq(picked.get("node"), shown)


func test_two_visible_namesakes_are_ambiguous_and_none_is_not_visible() -> void:
	var a := _named("Pair", true)
	var b := _named("Pair", true)
	assert_string_contains(str(Harness.pick_named([a, b] as Array[Node], "Pair").get("error", "")), "ambiguous")
	a.visible = false
	b.visible = false
	assert_string_contains(str(Harness.pick_named([a, b] as Array[Node], "Pair").get("error", "")), "not visible")
	assert_string_contains(str(Harness.pick_named([] as Array[Node], "Nobody").get("error", "")), "no node named")


# ── drag arguments: a named start or a point, then the end and the steps ──

func test_drag_parses_a_named_start_or_a_point() -> void:
	var named := Harness.parse_drag(PackedStringArray(["drag", "MasterSlider", "10", "20"]))
	assert_eq(named, {"target": "MasterSlider", "from": Vector2.ZERO, "to": Vector2(10, 20),
		"steps": Harness.DEFAULT_DRAG_STEPS})
	var point := Harness.parse_drag(PackedStringArray(["drag", "1", "2", "3.5", "4", "5"]))
	assert_eq(point, {"target": "", "from": Vector2(1, 2), "to": Vector2(3.5, 4), "steps": 5})


func test_drag_refuses_a_missing_end_or_a_bad_step_count() -> void:
	for line in ["drag", "drag Slider", "drag Slider 10", "drag 1 2 3", "drag Slider x 10",
			"drag Slider 1 2 3 4"]:
		assert_eq(Harness.parse_drag(DebugConsole.tokenise(line)).get("error", ""),
			Harness.DRAG_USAGE, line)
	for line in ["drag Slider 1 2 0", "drag Slider 1 2 1.5"]:
		assert_string_contains(str(Harness.parse_drag(DebugConsole.tokenise(line)).get("error", "")),
			"whole number", line)


# ── scenario_started / scenario_finished reach the project's hooks ──

func _scenario_file(stem: String, lines: String) -> String:
	var path := "user://%s.txt" % stem
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(lines)
	file.close()
	return path


func test_the_hooks_hear_a_scenario_start_before_its_first_line_and_finish_with_its_verdict() -> void:
	Harness.keep_alive_for_tests = true
	var harness: Node = Harness.new()
	add_child_autofree(harness)
	Harness.keep_alive_for_tests = false
	harness._sandbox()
	# The first line asserts the started note exists: it fails unless the
	# hook ran before it.
	await harness._run(_scenario_file("hooks_started", "assert_note started: hooks_started\n"))
	assert_eq(harness._failures, 0, "scenario_started ran before the first line")
	assert_eq(DebugConsole.hooks.last_finished, "hooks_started ok")
	# A failing line logs its failure as an engine error: expected here.
	gut.error_tracker.treat_push_error_as = GutUtils.TREAT_AS.NOTHING
	await harness._run(_scenario_file("hooks_failed", "assert_note never written\n"))
	assert_eq(DebugConsole.hooks.last_finished, "hooks_failed fail",
		"scenario_finished runs after a failed line too, with ok false")
	harness._restore()
