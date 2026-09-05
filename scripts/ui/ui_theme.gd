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
	_cached = theme
	return theme


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
