extends GutTest
## The UI kit's testable halves: the chrome scale ramp, the integer canvas
## snap, first-focus, and a pop_in that survives its control being freed.


func test_fit_for_takes_the_tighter_axis() -> void:
	assert_almost_eq(UiScaleRoot.fit_for(Vector2(1920, 1080), Vector2(1280, 720)), 1.5, 0.001)
	assert_almost_eq(UiScaleRoot.fit_for(Vector2(1280, 1000), Vector2(1280, 720)), 1.0, 0.001)
	assert_almost_eq(UiScaleRoot.fit_for(Vector2(640, 360), Vector2(1280, 720)), 0.5, 0.001)
	assert_eq(UiScaleRoot.fit_for(Vector2(640, 360), Vector2.ZERO), 1.0, "no reference: no scaling")


func test_snapped_factor_floors_above_design_and_keeps_below() -> void:
	var design := Vector2(1280, 720)
	# 1920x1080 is 1.5x: snap to 1x, so the factor is 1/1.5
	assert_almost_eq(GameManager.snapped_factor(Vector2(1920, 1080), design), 1.0 / 1.5, 0.001)
	# 2560x1440 is exactly 2x: no correction
	assert_almost_eq(GameManager.snapped_factor(Vector2(2560, 1440), design), 1.0, 0.001)
	# a Steam Deck (1280x800) is 1x on the tighter axis: untouched
	assert_almost_eq(GameManager.snapped_factor(Vector2(1280, 800), design), 1.0, 0.001)
	# below design size the fractional shrink stays
	assert_almost_eq(GameManager.snapped_factor(Vector2(960, 540), design), 1.0, 0.001)


func test_first_focus_skips_disabled_and_finds_a_button() -> void:
	var root := VBoxContainer.new()
	add_child_autofree(root)
	var dead := Button.new()
	dead.disabled = true
	root.add_child(dead)
	var live := Button.new()
	live.name = "Live"
	root.add_child(live)
	assert_true(UIFocus.first(root))
	await get_tree().process_frame
	assert_true(live.has_focus(), "the first ENABLED focusable gets focus")


func test_first_focus_with_nothing_focusable_is_false() -> void:
	var root := VBoxContainer.new()
	add_child_autofree(root)
	root.add_child(Label.new())
	assert_false(UIFocus.first(root))


func test_pop_in_survives_the_control_being_freed_first() -> void:
	var panel := PanelContainer.new()
	add_child(panel)
	UITheme.pop_in(panel)
	panel.free()
	await get_tree().process_frame
	pass_test("the deferred call found no instance and did nothing")


func test_pop_in_lands_at_full_alpha() -> void:
	var panel := PanelContainer.new()
	add_child_autofree(panel)
	panel.size = Vector2(100, 50)
	UITheme.pop_in(panel)
	await wait_seconds(0.4)
	assert_almost_eq(panel.modulate.a, 1.0, 0.01)
	assert_almost_eq(panel.scale.x, 1.0, 0.01)
