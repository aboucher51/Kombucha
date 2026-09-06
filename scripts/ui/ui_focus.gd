class_name UIFocus
extends RefCounted
## The two pad-reachability chores every code-built screen owes, in one
## place. They were three private duplicates in one project before they
## were extracted, so "remember to call it" was never going to hold.


## Focus the first focusable Control under `root`, depth first.
##
## A menu that opens without grabbing focus is unreachable by pad. Always
## deferred: the control has usually just been added and cannot take focus
## until it has been laid out. Deferred BY INSTANCE ID, like pop_in: a
## screen that opens on a scenario's last line is torn down before the
## deferred call lands, and a bare `grab_focus.call_deferred()` then
## logs `Condition "!is_inside_tree()" is true` — an engine error under a
## green batch, once per scenario that ended on a menu.
static func first(root: Node) -> bool:
	if root == null:
		return false
	for child in root.get_children():
		if child is Control:
			var control: Control = child
			# a disabled Button still reports FOCUS_ALL, so focusing it
			# parks the cursor on something that cannot be pressed
			var dead: bool = control is BaseButton and (control as BaseButton).disabled
			if control.focus_mode == Control.FOCUS_ALL and control.visible \
					and not dead and not control.is_queued_for_deletion():
				return grab(control)
		if first(child):
			return true
	return false


## Focus ONE control the caller already has, under the same rule as
## first(): deferred BY INSTANCE ID. A screen that knows which control it
## wants (a modal's Close, a dialogue's Advance, a pause sheet's Resume)
## wrote `control.grab_focus.call_deferred()` directly — eight of them in
## one project — and the one on a screen a scenario ended on landed after
## the harness tore the scene down: `Condition "!is_inside_tree()" is
## true`, an engine error under a green batch. Never defer grab_focus on
## the control itself.
static func grab(control: Control) -> bool:
	if control == null or control.is_queued_for_deletion():
		return false
	_grab_deferred.call_deferred(control.get_instance_id())
	return true


static func _grab_deferred(control_id: int) -> void:
	var control := instance_from_id(control_id) as Control
	if control != null and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()


## A SpinBox does not answer ui_up / ui_down on its own — focus lands in
## its inner LineEdit, which consumes them. Without this a pad cannot
## change a single number in the whole editor.
static func pad_spin(spin: SpinBox) -> void:
	if spin == null:
		return
	spin.get_line_edit().gui_input.connect(func(event: InputEvent) -> void:
		if not spin.editable:
			return
		if event.is_action_pressed("ui_up"):
			spin.value += spin.step
			spin.get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_down"):
			spin.value -= spin.step
			spin.get_viewport().set_input_as_handled())
