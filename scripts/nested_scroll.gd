extends Control
## A FIXTURE scene with one ScrollContainer inside another, both with the
## target below their fold (KOMBU-37). The harness's `click` must scroll
## every ScrollContainer around a control, not only the nearest one: one
## project's editor had a list inside a properties panel, and the click
## scrolled the list but not the panel, so it landed on something else.
## Reached with `goto`, so the boot frame (a committed baseline) stays as is.

const NESTED_ROWS := 20

## The last nested button pressed (state key `nested_pick`).
var nested_pick := ""


func _ready() -> void:
	theme = UITheme.get_theme()
	add_to_group("state")
	var outer := ScrollContainer.new()
	outer.name = "OuterScroll"
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Anchors and offsets in one call, or a fresh control stays 0x0.
	outer.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	outer.offset_left = -160
	outer.offset_top = -100
	outer.offset_right = 160
	outer.offset_bottom = 100
	add_child(outer)
	var outer_box := VBoxContainer.new()
	outer_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(outer_box)
	outer_box.add_child(_button("OuterTop"))
	outer_box.add_child(_spacer())
	var inner := ScrollContainer.new()
	inner.name = "InnerScroll"
	inner.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inner.custom_minimum_size = Vector2(0, 120)
	outer_box.add_child(inner)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(rows)
	for i in range(1, NESTED_ROWS + 1):
		rows.add_child(_button("NestedRow%02d" % i))
	rows.add_child(_button("DeepRow"))
	outer_box.add_child(_spacer())


func _button(button_name: String) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = button_name
	button.custom_minimum_size = Vector2(0, 24)
	button.pressed.connect(_on_pressed.bind(button_name))
	return button


## Tall empty space, so the inner list starts below the outer fold.
static func _spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 400)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _on_pressed(button_name: String) -> void:
	nested_pick = button_name


func state_text() -> String:
	return "nested_pick=%s" % nested_pick


func assert_key(key: String, value: String) -> String:
	if key != "nested_pick":
		return "ERROR: unknown key '%s'" % key
	if nested_pick != value:
		return "ERROR: nested_pick is '%s', expected '%s'" % [nested_pick, value]
	return ""
