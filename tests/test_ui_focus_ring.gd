extends GutTest
## UIFocus.keep_inside: a modal panel's focus walks its own controls and
## wraps. Without it, ui_down from a pause menu's last button found the
## screen behind the dim (KOMBU-33). scenarios/pause_focus.txt proves the
## real menu; this pins the wiring.


func _panel() -> VBoxContainer:
	var box := VBoxContainer.new()
	var slider := HSlider.new()
	slider.name = "Slider"
	box.add_child(slider)
	var label := Label.new()
	label.name = "Label"
	box.add_child(label)
	for button_name in ["First", "Hidden", "Last"]:
		var button := Button.new()
		button.name = button_name
		box.add_child(button)
	(box.get_node("Hidden") as Control).visible = false
	add_child_autofree(box)
	return box


func test_focus_wraps_through_the_visible_controls_only() -> void:
	var box := _panel()
	UIFocus.keep_inside(box)
	var slider: Control = box.get_node("Slider")
	var first: Control = box.get_node("First")
	var last: Control = box.get_node("Last")
	assert_eq(slider.get_node(slider.focus_neighbor_bottom), first, "down from the slider skips the label")
	assert_eq(first.get_node(first.focus_neighbor_bottom), last, "down skips the hidden button")
	assert_eq(last.get_node(last.focus_neighbor_bottom), slider, "down from the last control wraps to the first")
	assert_eq(slider.get_node(slider.focus_neighbor_top), last, "up from the first control wraps to the last")
	assert_eq(last.get_node(last.focus_next), slider, "Tab wraps the same way")
	assert_eq(slider.get_node(slider.focus_previous), last)


func test_left_and_right_stay_on_a_button_but_not_on_a_slider() -> void:
	var box := _panel()
	UIFocus.keep_inside(box)
	var last: Control = box.get_node("Last")
	var slider: Control = box.get_node("Slider")
	assert_eq(last.get_node(last.focus_neighbor_left), last)
	assert_eq(last.get_node(last.focus_neighbor_right), last)
	assert_eq(slider.focus_neighbor_left, NodePath(), "a slider keeps left and right for its value")
