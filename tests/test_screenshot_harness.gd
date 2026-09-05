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
