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
