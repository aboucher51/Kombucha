extends Node
## Debug command line, toggled with F12. Autoloaded as "DebugConsole"; the
## UI is built lazily on first toggle, so a shipped build that never opens
## it pays nothing.
##
## data/console_commands.json owns the SURFACE of each command — name,
## aliases, usage text, and the shape of its arguments (which drives both
## validation and Tab autocomplete). GDScript owns the BEHAVIOUR, via a
## "handler" id in the closed match in _dispatch. That split is deliberate:
## data-driven handlers would mean inventing a scripting language. Both
## halves are required when adding a command.
##
## execute(line) -> String is public and side-effect-complete so the
## screenshot harness and tests can drive the console with no input events —
## this seam is why the console is testable. Errors are "ERROR:"-prefixed;
## the harness fails a scenario on exactly that shape, so an assertion-like
## handler must return an error, never a "false" answer that passes
## silently.

const COMMANDS_PATH := "res://data/console_commands.json"
const SCROLLBACK := 200

var _commands: Array = []
var _layer: CanvasLayer = null
var _output: RichTextLabel = null
var _input: LineEdit = null
var _history: Array[String] = []
var _history_index := -1
var _lines: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var text := FileAccess.get_file_as_string(COMMANDS_PATH)
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if data is Array:
		_commands = data
	else:
		push_error("DebugConsole: cannot parse %s" % COMMANDS_PATH)


func _input_event_toggle(event: InputEvent) -> bool:
	# F12 directly, not an InputMap action: debug chrome is not rebindable
	# and must work even if the InputMap is mid-rebind or broken.
	return event is InputEventKey and event.pressed and not event.echo \
		and (event as InputEventKey).physical_keycode == KEY_F12


func _unhandled_input(event: InputEvent) -> void:
	if _input_event_toggle(event):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _layer == null:
		_build_ui()
	_layer.visible = not _layer.visible
	if _layer.visible:
		_input.grab_focus()


# ── Execution ────────────────────────────────────────────────────────────

## Runs one command line and returns its output ("" for silent success,
## "ERROR: ..." for failure).
func execute(line: String) -> String:
	var trimmed := line.strip_edges()
	if trimmed.is_empty():
		return ""
	var tokens := trimmed.split(" ", false)
	var command := _find_command(tokens[0])
	if command.is_empty():
		return "ERROR: unknown command '%s'. Try 'help'." % tokens[0]
	var parsed := _parse_args(command, tokens.slice(1))
	if parsed.has("error"):
		return "ERROR: %s\nUsage: %s" % [parsed["error"], command.get("usage", command["id"])]
	return _dispatch(command, parsed["args"])


## The handler registry — a closed match, so a typo in the JSON warns
## instead of reaching something arbitrary. ADD PROJECT HANDLERS HERE, with
## their surface in data/console_commands.json.
func _dispatch(command: Dictionary, args: Dictionary) -> String:
	match command.get("handler", ""):
		"help":
			return _handle_help(args)
		"clear":
			_lines.clear()
			if _output != null:
				_output.text = ""
			return ""
		"save":
			var slot := str(args.get("slot", "")) if not str(args.get("slot", "")).is_empty() else SaveManager.current_slot
			var err := SaveManager.save_game(slot)
			return "Saved '%s'." % slot if err == OK else "ERROR: save failed (%d)" % err
		"load":
			var slot := str(args.get("slot", "")) if not str(args.get("slot", "")).is_empty() else SaveManager.current_slot
			var err := SaveManager.load_game(slot)
			return "Loaded '%s'." % slot if err == OK else "ERROR: load failed (%d)" % err
		"saves":
			var names := _save_names()
			return "No saves." if names.is_empty() else ", ".join(names)
		"delete_save":
			var slot := str(args["slot"])
			if not SaveManager.has_save(slot):
				return "ERROR: no save named '%s'" % slot
			SaveManager.delete_save(slot)
			return "Deleted '%s'." % slot
		"volume":
			AudioManager.set_bus_volume(StringName(str(args["bus"])), int(args["percent"]) / 100.0)
			return "%s = %d%%" % [args["bus"], int(args["percent"])]
		"bind":
			return _handle_bind(args)
		"unbind":
			if not Keybinds.has_action(str(args["action"])):
				return "ERROR: no rebindable action '%s'" % args["action"]
			Keybinds.clear_binding(str(args["action"]), int(args["slot"]))
			return "Unbound %s[%d]." % [args["action"], int(args["slot"])]
		"binds":
			var rows: Array[String] = []
			for entry in Keybinds.ACTIONS:
				var action: String = entry["action"]
				var keys: Array[String] = []
				for i in Keybinds.SLOTS:
					var text := Keybinds.describe(action, i)
					if not text.is_empty():
						keys.append(text)
				rows.append("%s: %s" % [action, ", ".join(keys) if not keys.is_empty() else "unbound"])
			return "\n".join(rows)
		"seed":
			seed(int(args["n"]))
			return "Seeded %d." % int(args["n"])
		"restart":
			get_tree().reload_current_scene()
			return "Restarted."
		"report":
			var path := BugReport.write(str(args.get("note", "")))
			return "Report: %s" % path if not path.is_empty() else "ERROR: report failed"
		"quit":
			get_tree().quit()
			return "Quitting."
		_:
			return "ERROR: command '%s' names unknown handler '%s'" % [command["id"], command.get("handler", "")]


func _handle_help(args: Dictionary) -> String:
	var topic := str(args.get("command", ""))
	if not topic.is_empty():
		var command := _find_command(topic)
		if command.is_empty():
			return "ERROR: unknown command '%s'" % topic
		return str(command.get("usage", command["id"]))
	var names: Array[String] = []
	for command in _commands:
		names.append(str(command["id"]))
	names.sort()
	return " ".join(names)


func _handle_bind(args: Dictionary) -> String:
	var action := str(args["action"])
	if not Keybinds.has_action(action):
		return "ERROR: no rebindable action '%s'" % action
	var event := Keybinds.parse_binding_text(str(args["key"]))
	if event == null:
		return "ERROR: '%s' names no key (try F5, W, mouse:3)" % args["key"]
	if not Keybinds.set_binding(action, int(args["slot"]), event):
		var holder := Keybinds.holder_of(event, Keybinds.group_of(action))
		return "ERROR: %s is already bound to %s — unbind it first" % [
			Keybinds.describe_event(event), holder]
	return "Bound %s[%d] = %s." % [action, int(args["slot"]), Keybinds.describe_event(event)]


func _save_names() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(SaveManager.save_root)
	if dir == null:
		return names
	for file_name in dir.get_files():
		if file_name.ends_with(".json"):
			names.append(file_name.get_basename())
	names.sort()
	return names


# ── Parsing ──────────────────────────────────────────────────────────────

func _find_command(name: String) -> Dictionary:
	for command in _commands:
		if command.get("id", "") == name or (command.get("aliases", []) as Array).has(name):
			return command
	return {}


## Returns { "args": { name: value } } or { "error": String }. A "rest"
## argument swallows the remainder of the line, which is what lets a
## multi-word note work without quoting.
func _parse_args(command: Dictionary, tokens: Array) -> Dictionary:
	var args: Dictionary = {}
	var specs: Array = command.get("args", [])
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var name: String = spec.get("name", "arg%d" % i)
		var kind: String = spec.get("kind", "string")

		if kind == "rest":
			var rest := " ".join(PackedStringArray(tokens.slice(i)))
			if rest.is_empty() and spec.get("required", false):
				return {"error": "Missing <%s>." % name}
			args[name] = rest
			return {"args": args}

		if i >= tokens.size():
			if spec.get("required", false):
				return {"error": "Missing <%s>." % name}
			if spec.has("default"):
				args[name] = spec["default"]
			continue

		var raw: String = tokens[i]
		match kind:
			"int":
				if not raw.is_valid_int():
					return {"error": "<%s> must be a whole number." % name}
				args[name] = clampi(int(raw), int(spec.get("min", -99999)), int(spec.get("max", 99999)))
			"float":
				if not raw.is_valid_float():
					return {"error": "<%s> must be a number." % name}
				args[name] = float(raw)
			"enum":
				if not (spec.get("values", []) as Array).has(raw):
					return {"error": "<%s> must be one of: %s" % [name, ", ".join(PackedStringArray(spec.get("values", [])))]}
				args[name] = raw
			_:
				args[name] = raw
	return {"args": args}


# ── UI (built lazily) ────────────────────────────────────────────────────

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)
	var panel := PanelContainer.new()
	panel.name = "ConsolePanel"
	panel.theme = UITheme.get_theme()
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size = Vector2(0, 260)
	_layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_output = RichTextLabel.new()
	_output.name = "ConsoleOutput"
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.text = "\n".join(_lines)
	box.add_child(_output)
	_input = LineEdit.new()
	_input.name = "ConsoleInput"
	_input.placeholder_text = "help"
	_input.text_submitted.connect(_on_submitted)
	_input.gui_input.connect(_on_input_key)
	box.add_child(_input)
	print_line("[i]Type 'help' for commands.[/i]")


func print_line(text: String) -> void:
	_lines.append(text)
	while _lines.size() > SCROLLBACK:
		_lines.pop_front()
	if _output != null:
		_output.text = "\n".join(_lines)


func _on_submitted(line: String) -> void:
	if not line.strip_edges().is_empty():
		_history.append(line)
	_history_index = _history.size()
	print_line("[b]> %s[/b]" % line)
	var result := execute(line)
	if not result.is_empty():
		print_line(result)
	_input.clear()
	# Some themes drop focus on submit; a console you have to re-click after
	# every command is useless.
	_input.grab_focus()


## Up/Down walk the command history; Tab completes names and enum values.
func _on_input_key(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return
	if event.keycode == KEY_UP:
		_recall(-1)
		_input.accept_event()
	elif event.keycode == KEY_DOWN:
		_recall(1)
		_input.accept_event()
	elif event.keycode == KEY_TAB:
		_autocomplete()
		_input.accept_event()


func _recall(direction: int) -> void:
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + direction, 0, _history.size())
	_input.text = _history[_history_index] if _history_index < _history.size() else ""
	_input.caret_column = _input.text.length()


func _autocomplete() -> void:
	var tokens := _input.text.split(" ", false)
	if tokens.is_empty():
		return
	var command := _find_command(tokens[0])
	if command.is_empty():
		var names: Array[String] = []
		for entry in _commands:
			names.append(str(entry["id"]))
		var matches := _completions_from(names, tokens[0])
		if matches.size() == 1:
			_input.text = matches[0] + " "
			_input.caret_column = _input.text.length()
		elif matches.size() > 1:
			print_line(" ".join(matches))
		return
	var specs: Array = command.get("args", [])
	var arg_index := tokens.size() - 2
	var partial := ""
	if _input.text.ends_with(" "):
		arg_index += 1
	else:
		partial = tokens[-1] if tokens.size() > 1 else ""
	if arg_index < 0 or arg_index >= specs.size():
		return
	var spec: Dictionary = specs[arg_index]
	if spec.get("kind", "") != "enum":
		return
	var pool: Array[String] = []
	pool.assign(spec.get("values", []))
	var matches := _completions_from(pool, partial)
	if matches.size() == 1:
		var head := tokens.slice(0, tokens.size() - (0 if partial.is_empty() else 1))
		_input.text = " ".join(head) + " " + matches[0] + " "
		_input.caret_column = _input.text.length()
	elif matches.size() > 1:
		print_line(" ".join(matches))


func _completions_from(pool: Array, partial: String) -> Array[String]:
	var matches: Array[String] = []
	for candidate in pool:
		if String(candidate).begins_with(partial):
			matches.append(String(candidate))
	matches.sort()
	return matches
