extends Control
## Entry scene. Replace with the real game's boot scene.
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


func _ready() -> void:
	theme = UITheme.get_theme()
	RenderingServer.set_default_clear_color(UITheme.BACKGROUND)
	AudioManager.ui_sounds.merge(UI_SOUNDS)
