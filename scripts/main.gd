extends Control
## The FIXTURE's boot scene. In a game this is replaced; here it exists to
## give every harness and console command something to exercise, so a
## change to the tooling is proven before it is synced anywhere.
##
## Temporary debug code goes here and is ALWAYS reverted before finishing —
## and prefer a test over temporary debug entirely (see CLAUDE.md).

## Placeholder sounds from tools/generate_placeholder_audio.py — replace the
## files with authored assets; the event names are the stable surface.
const UI_SOUNDS := {
	"click": preload("res://assets/audio/sfx/click.wav"),
	"hover": preload("res://assets/audio/sfx/hover.wav"),
	"menu_open": preload("res://assets/audio/sfx/menu_open.wav"),
	"menu_close": preload("res://assets/audio/sfx/menu_close.wav"),
	"confirm": preload("res://assets/audio/sfx/confirm.wav"),
	"error": preload("res://assets/audio/sfx/error.wav"),
}
const ROW_COUNT := 30

## The frame until which is_busy() answers true (console `busy <frames>`).
var _busy_until := 0
## The last left click seen anywhere, as viewport coordinates.
var last_click := Vector2(-1, -1)
## The last row button pressed in the scrolling list.
var last_row := ""


func _ready() -> void:
	theme = UITheme.get_theme()
	RenderingServer.set_default_clear_color(UITheme.BACKGROUND)
	AudioManager.ui_sounds.merge(UI_SOUNDS)
	add_to_group("state")
	add_to_group("settle")
	_build_rows()


## A long list whose tail is below the fold: the harness's scroll_to seam.
## Built in code with stable names, as the harness rules require.
func _build_rows() -> void:
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	for i in range(1, ROW_COUNT + 1):
		var row := Button.new()
		row.name = "Row%02d" % i
		row.text = "Row %d" % i
		row.custom_minimum_size = Vector2(0, 24)
		row.pressed.connect(func() -> void: last_row = str(row.name))
		rows.add_child(row)
	%RowList.add_child(rows)


func _input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		last_click = button.position


# ── seams for the harness ────────────────────────────────────────────────

func set_busy(frames: int) -> void:
	_busy_until = Engine.get_process_frames() + frames


func is_busy() -> bool:
	return Engine.get_process_frames() < _busy_until


func state_text() -> String:
	return "title=%s paused=%s busy=%s last_click=%s last_row=%s" % [
		%TitleLabel.text, _yes_no(get_tree().paused), _yes_no(is_busy()),
		_point(last_click), last_row]


func assert_key(key: String, value: String) -> String:
	var actual: String
	match key:
		"title": actual = %TitleLabel.text
		"paused": actual = _yes_no(get_tree().paused)
		"busy": actual = _yes_no(is_busy())
		"last_click": actual = _point(last_click)
		"last_row": actual = last_row
		_: return "ERROR: unknown key '%s'" % key
	if actual != value:
		return "ERROR: %s is '%s', expected '%s'" % [key, actual, value]
	return ""


static func _yes_no(flag: bool) -> String:
	return "yes" if flag else "no"


static func _point(at: Vector2) -> String:
	return "%d,%d" % [int(at.x), int(at.y)]
