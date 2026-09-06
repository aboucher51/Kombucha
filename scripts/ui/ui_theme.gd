class_name UITheme
extends RefCounted
## Whole-project look from one palette block, built in code — swap the nine
## constants and every themed control follows. Styling stays here, not in
## scattered .tres files or per-node overrides.
##
## Apply once at the top of the UI tree (main.tscn's root does):
##     theme = UITheme.get_theme()

const BACKGROUND := Color("191922")
const PANEL := Color("22222e")
const ROW := Color("2a2a3a")
const HOVER := Color("3a3a52")
const BUTTON := Color("38384a")
const ACCENT := Color("d4af37")
const MUTED := Color("888899")
const TEXT := Color("e8e8f0")
const DANGER := Color("d94040")

static var _cached: Theme = null


static func get_theme() -> Theme:
	if _cached != null:
		return _cached
	var theme := Theme.new()

	theme.set_stylebox("normal", "Button", _flat(BUTTON, 4))
	theme.set_stylebox("hover", "Button", _flat(HOVER, 4))
	theme.set_stylebox("pressed", "Button", _flat(ROW, 4))
	theme.set_stylebox("disabled", "Button", _flat(Color(BUTTON, 0.4), 4))
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", MUTED)

	theme.set_stylebox("panel", "PanelContainer", _flat(PANEL, 6, Color(ACCENT, 0.25)))
	theme.set_stylebox("panel", "Panel", _flat(PANEL, 6))
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "RichTextLabel", TEXT)

	theme.set_stylebox("slider", "HSlider", _flat(ROW, 3))
	theme.set_stylebox("grabber_area", "HSlider", _flat(ACCENT, 3))
	theme.set_stylebox("grabber_area_highlight", "HSlider", _flat(ACCENT, 3))

	theme.set_stylebox("panel", "ScrollContainer", _flat(BACKGROUND, 0))

	# Focus ring: pad and keyboard navigation are INVISIBLE without one —
	# every focusable class gets the same 2px accent outline, drawn as an
	# overlay (no fill) so it layers over each control's own state style.
	var ring := focus_ring()
	for cls in ["Button", "OptionButton", "CheckButton", "CheckBox",
			"HSlider", "LineEdit", "SpinBox", "TextEdit"]:
		theme.set_stylebox("focus", cls, ring)
	_cached = theme
	return theme


## The keyboard/pad focus outline: border only, no fill, slightly proud of
## the control so it reads on any background.
static func focus_ring() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.draw_center = false
	style.border_color = ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_expand_margin_all(2)
	return style


## Standard panel entrance: a quick fade + settle-up from 94% scale. Shared
## so every panel arrives the same way (hard pops read as prototype). Safe
## while the tree is paused; safe on a control whose layout hasn't settled
## (falls back to fade-only).
static func pop_in(control: Control) -> void:
	control.modulate.a = 0.0
	# Deferred by instance id: the control can be freed before the deferred
	# call lands (scene teardown), and a freed Object argument would error.
	_pop_in_deferred.call_deferred(control.get_instance_id())


static func _pop_in_deferred(control_id: int) -> void:
	var control := instance_from_id(control_id) as Control
	if control == null or not control.is_inside_tree() or not control.visible:
		if control != null:
			control.modulate.a = 1.0
		return
	var tween := control.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.16)
	# Motion on the VISUAL-ONLY offset transform, never `scale` or
	# `position`: a container lays its children out every frame, and a
	# tween on the laid-out properties fights it (a toast slid to the left
	# edge because its rest position was captured before the stack had
	# placed it). The offset transform is what the engine draws, not what
	# the layout reads.
	control.offset_transform_enabled = true
	control.offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	control.offset_transform_scale = Vector2(0.94, 0.94)
	tween.tween_property(control, "offset_transform_scale", Vector2.ONE, 0.22)


static func _flat(color: Color, corner_radius: int, border: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	if border.a > 0.0:
		style.border_color = border
		style.set_border_width_all(1)
	return style


## Accent-bordered variant for highlights (active tabs, selections).
static func accent_border(base_color: Color = PANEL) -> StyleBoxFlat:
	var style := _flat(base_color, 6, ACCENT)
	style.set_border_width_all(2)
	return style
