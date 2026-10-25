class_name PauseMenu
extends Control
## Pause overlay: dim + centered panel with volume sliders, resume and quit.
## Toggled by the "pause" input action (Escape by default).
##
## PROCESS_MODE_ALWAYS is what lets it receive input while the tree it just
## paused stands still. If other UI should claim Escape first (close a dialog
## before opening the pause menu), handle the action there and
## set_input_as_handled() — that precedence chain lives at the call sites,
## not here.
##
## Built in code so UITheme drives the look. Every interactive node gets a
## stable name — the harness cannot click an auto-named `@Button@3`.
##
## open() grabs focus (UIFocus.first): a menu that opens without focus is
## unreachable by keyboard and pad, and the focus ring in UITheme is what
## makes that navigation visible.

var _panel: PanelContainer
## The hand-made lever's value, 0 to 100 (main.gd's `lever` state key).
var lever := 50
var _lever_held := false
var _lever_track: Panel
var _lever_fill: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	center.add_child(panel)
	_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var title := Label.new()
	title.name = "PausedLabel"
	title.text = L10n.tr_or_fallback("ui.paused", "Paused")
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", UITheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(VolumeSliders.make())
	box.add_child(_make_lever())

	var resume := Button.new()
	resume.name = "ResumeButton"
	resume.text = L10n.tr_or_fallback("ui.resume", "Resume")
	resume.tooltip_text = L10n.tr_or_fallback("ui.resume_hint", "Resume the game")
	resume.pressed.connect(close)
	AudioManager.bind_button(resume)
	box.add_child(resume)

	var quit := Button.new()
	quit.name = "QuitButton"
	quit.text = L10n.tr_or_fallback("ui.quit", "Quit")
	quit.pressed.connect(GameManager.quit_game)
	AudioManager.bind_button(quit)
	box.add_child(quit)


## A hand-made lever, like most sliders a game draws itself: it lets go on
## any motion with no button held, the way a real mouse released outside
## the window reads. An HSlider ignores the button mask, so it cannot
## catch a drag whose motions arrive without the button (KOMBU-6). It
## lives here, not on the boot screen, so the boot baseline stays as is.
func _make_lever() -> Panel:
	var track := Panel.new()
	track.name = "Lever"
	track.custom_minimum_size = Vector2(180, 20)
	var fill := ColorRect.new()
	fill.name = "LeverFill"
	fill.color = UITheme.ACCENT
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	track.add_child(fill)
	track.gui_input.connect(_on_lever_input)
	track.resized.connect(_show_lever)
	_lever_track = track
	_lever_fill = fill
	return track


func _on_lever_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_lever_held = button.pressed
		if button.pressed:
			_move_lever(button.position.x)
		return
	var motion := event as InputEventMouseMotion
	if motion == null or not _lever_held:
		return
	if motion.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
		_lever_held = false
		return
	_move_lever(motion.position.x)


func _move_lever(local_x: float) -> void:
	lever = roundi(clampf(local_x / _lever_track.size.x, 0.0, 1.0) * 100.0)
	_show_lever()


func _show_lever() -> void:
	_lever_fill.offset_right = _lever_track.size.x * lever / 100.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	GameManager.set_paused(true)
	UITheme.pop_in(_panel)
	UIFocus.first(_panel)
	AudioManager.ui_event("menu_open")


func close() -> void:
	visible = false
	GameManager.set_paused(false)
	AudioManager.ui_event("menu_close")
