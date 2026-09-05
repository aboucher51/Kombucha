class_name UiScaleRoot
extends Control
## Lays its children out in a fixed DESIGN space and scales the result to the
## window, so interface chrome grows and shrinks with the window instead of
## staying a fixed pixel size that looks cramped at 4K and oversized at 720p.
##
## Only for non-diegetic UI (HUD, drawers, tooltips) — world content the
## player pans and zooms themselves should NOT scale: a bigger window is
## meant to show MORE world, not the same world bigger.
##
## Why a node rather than CanvasLayer.scale: a Control parented directly to a
## CanvasLayer resolves its anchors against the viewport rect and ignores the
## layer's transform, so scaling the layer alone leaves a full-rect child
## covering scale x the screen. Sizing this node to viewport / scale gives the
## children a design-space rect to anchor against, and the scale then maps it
## back onto the window exactly.
##
## Insert between a UI CanvasLayer and its contents; children need no changes.

## Design space the children are laid out against. Zero = the project's own
## viewport resolution, which is the size scenes are authored at.
@export var reference := Vector2.ZERO
@export var min_scale := 0.75
@export var max_scale := 2.5

const SETTINGS_SECTION := "ui"
const SETTINGS_KEY := "scale"

## The user's preference multiplier, cached so a window resize does not
## re-read the settings file — refresh_scale() is the only path that
## re-reads it. A settings UI applies a change with:
##     SaveManager.set_setting("ui", "scale", value)
##     get_tree().call_group(&"ui_scale_root", "refresh_scale")
var _user_scale := 1.0
## Setting oversampling_override emits the viewport's size_changed
## SYNCHRONOUSLY, which is connected right back to _apply_scale — the cycle
## must be broken explicitly.
var _applying := false


func _ready() -> void:
	# Top-left with no stretch: this node's rect is set explicitly in
	# _apply_scale, so anchors must not fight it.
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# Chrome must not swallow clicks meant for whatever is underneath; the
	# actual widgets inside re-enable hit-testing for themselves.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# How settings code reaches every instance without an autoload naming
	# this class (see the autoload/UI rule in CLAUDE.md).
	add_to_group(&"ui_scale_root")
	if reference == Vector2.ZERO:
		reference = Vector2(
			float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280)),
			float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
		)
	_user_scale = clampf(float(SaveManager.get_setting(SETTINGS_SECTION, SETTINGS_KEY, 1.0)), 0.25, 4.0)
	get_viewport().size_changed.connect(_apply_scale)
	_apply_scale()


## The settings-changed path: re-reads the user multiplier, then rescales.
func refresh_scale() -> void:
	_user_scale = clampf(float(SaveManager.get_setting(SETTINGS_SECTION, SETTINGS_KEY, 1.0)), 0.25, 4.0)
	_apply_scale()


func _apply_scale() -> void:
	if _applying:
		return
	var viewport := get_viewport_rect().size
	if reference.x <= 0.0 or reference.y <= 0.0 or viewport.x <= 0.0:
		return
	_applying = true
	# The smaller axis ratio wins, so chrome never outgrows the window on the
	# tighter dimension. The user's multiplier rides on top of the window fit
	# and inside the same clamp. It flows into the oversampling below with
	# everything else — ANY scaling path must, or text goes soft.
	var factor := clampf(
		minf(viewport.x / reference.x, viewport.y / reference.y) * _user_scale,
		min_scale,
		max_scale
	)
	scale = Vector2(factor, factor)
	_apply_font_oversampling(factor)
	position = Vector2.ZERO
	# Design-space rect: what the children believe the screen is. Dividing by
	# the factor is what keeps a full-rect child exactly filling the window
	# after the scale is applied.
	size = viewport / factor
	_applying = false


## Re-rasterises fonts at the size they are actually DRAWN, rather than the
## size they are laid out at. Godot's automatic oversampling follows the
## viewport's content scale and knows nothing about a Control scaling itself
## — without this, glyphs rasterised at design size are stretched and text
## goes soft as the window grows. Judge the result with a 1:1 crop
## (`shot <name> <x> <y> <w> <h>`) — a downscaled full-window view hides
## exactly this detail.
func _apply_font_oversampling(factor: float) -> void:
	var window := get_window()
	if window == null:
		return
	var wanted := maxf(1.0, factor)
	# Same-value writes still cost a synchronous size_changed round trip, so
	# only genuine changes go through.
	if is_equal_approx(window.oversampling_override, wanted):
		return
	window.oversampling_override = wanted
