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
