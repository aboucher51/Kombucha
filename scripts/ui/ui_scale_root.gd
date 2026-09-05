class_name UiScaleRoot
extends Node
## Scales the Control it hangs under, so interface chrome grows and shrinks
## with the WINDOW instead of staying a fixed pixel size that looks cramped
## at 4K and oversized at 720p.
##
## It exists because of the canvas policy: above design size
## `GameManager._apply_scale_policy` snaps the canvas to an INTEGER scale so
## pixel art stays 1:1, which means the viewport grows and everything laid
## out in authored pixels shrinks into a corner of the window. That is right
## for the board — a bigger window should show more world — and wrong for
## chrome. This puts the chrome back on a smooth ramp: at 1920x1080 the
## canvas is 1x and this is 1.5x; at 2560x1440 the canvas is 2x and this is
## 1x. The product is continuous across the jump.
##
## Attach it to the OUTERMOST full-screen Control of a layer — a Control
## parented to a CanvasLayer or to the viewport. Nested UI inherits the
## scale and must not be attached again, or it scales twice.
##
## Why a child node rather than a wrapper Control: a wrapper has to reparent
## everything, which breaks every `$Path` in the screen's own script. This
## drives its parent in place and touches nothing else.
##
## World content the player pans and zooms must NOT be attached — the board,
## the curtain, the atmosphere and the crowd all stay in canvas space.

## Design space the chrome is laid out against. Zero = the project's own
## viewport resolution, which is the size scenes are authored at.
@export var reference := Vector2.ZERO
@export var min_scale := 0.75
@export var max_scale := 2.5

const SETTINGS_SECTION := "ui"
const SETTINGS_KEY := "scale"
const GROUP := &"ui_scale_root"

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
var _target: Control


## Scale `target` from now on. Returns the node, so a caller can hold it.
static func attach(target: Control) -> UiScaleRoot:
	var node := UiScaleRoot.new()
	node.name = "UiScale"
	target.add_child(node)
	return node


## Attach only when `control` is the outermost UI in its layer. A pause menu
## or a settings sheet lives inside a scaled screen in one scene and
## directly on a CanvasLayer in another; asking here is what stops it
## scaling twice in the first case.
static func attach_if_outermost(control: Control) -> UiScaleRoot:
	var parent := control.get_parent()
	if parent is CanvasLayer or parent == control.get_viewport():
		return attach(control)
	return null


func _ready() -> void:
	_target = get_parent() as Control
	if _target == null:
		push_warning("UiScaleRoot: nothing to scale — its parent is not a Control")
		return
	# Top-left with no stretch: the parent's rect is written explicitly in
	# _apply_scale, so anchors must not fight it.
	_target.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	# How settings code reaches every instance without an autoload naming
	# this class (see the autoload/UI rule in CLAUDE.md).
	add_to_group(GROUP)
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


## What the chrome is scaled by right now (1.0 before it is in a tree).
func factor() -> float:
	return _target.scale.x if _target != null else 1.0


## The fit for a viewport of `size` against `reference`, before the user's
## multiplier and the clamp. Static so a test can pin the ramp without a
## window.
static func fit_for(viewport: Vector2, reference_size: Vector2) -> float:
	if reference_size.x <= 0.0 or reference_size.y <= 0.0:
		return 1.0
	return minf(viewport.x / reference_size.x, viewport.y / reference_size.y)


func _apply_scale() -> void:
	if _applying or _target == null or not is_instance_valid(_target):
		return
	var viewport := _target.get_viewport_rect().size
	if reference.x <= 0.0 or reference.y <= 0.0 or viewport.x <= 0.0:
		return
	_applying = true
	# The smaller axis ratio wins, so chrome never outgrows the window on the
	# tighter dimension. The user's multiplier rides on top of the window fit
	# and inside the same clamp. It flows into the oversampling below with
	# everything else — ANY scaling path must, or text goes soft.
	var factor_now := clampf(fit_for(viewport, reference) * _user_scale, min_scale, max_scale)
	_target.scale = Vector2(factor_now, factor_now)
	_apply_font_oversampling(factor_now)
	_target.position = Vector2.ZERO
	# Design-space rect: what the children believe the screen is. Dividing by
	# the factor is what keeps a full-rect child exactly filling the window
	# after the scale is applied.
	_target.size = viewport / factor_now
	_applying = false


## Re-rasterises fonts at the size they are actually DRAWN, rather than the
## size they are laid out at. Godot's automatic oversampling follows the
## viewport's content scale and knows nothing about a Control scaling itself
## — without this, glyphs rasterised at design size are stretched and text
## goes soft as the window grows. Judge the result with a 1:1 crop
## (`shot <name> <x> <y> <w> <h>`) — a downscaled full-window view hides
## exactly this detail.
func _apply_font_oversampling(factor_now: float) -> void:
	var window := get_window()
	if window == null:
		return
	var wanted := maxf(1.0, factor_now)
	# Same-value writes still cost a synchronous size_changed round trip, so
	# only genuine changes go through.
	if is_equal_approx(window.oversampling_override, wanted):
		return
	window.oversampling_override = wanted
