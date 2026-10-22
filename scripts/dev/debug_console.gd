extends Node
## Developer console, for DEV builds only: F12 or ~ (the backtick key, or
## the project's own `console` InputMap action when it has one) toggles
## it. Autoloaded as "DebugConsole"; the UI is built lazily on first
## toggle, and a player build never builds it at all (`allowed()`).
##
## data/console_commands.json owns the SURFACE of each command — name,
## aliases, usage text, a one-line `description`, and the shape of its
## arguments (which drives validation, the suggestion list and the
## argument hint). GDScript owns the BEHAVIOUR, via a "handler" id in the
## closed match in _dispatch. That split is deliberate: data-driven
## handlers would mean inventing a scripting language. Both halves are
## required when adding a command.
##
## The same files carry the console's BUTTONS: a list entry holding a
## `buttons` array of {id, label, run, group, tip, fill}. `run` is a
## console line, so a button is a command a developer can also type; the
## tooltip says which. `fill: true` puts the line in the input to finish
## instead of running it.
##
## execute(line) -> String is public and side-effect-complete so the
## screenshot harness and tests can drive the console with no input events —
## this seam is why the console is testable, and it answers in every build.
## Errors are "ERROR:"-prefixed; the harness fails a scenario on exactly
## that shape, so an assertion-like handler must return an error, never a
## "false" answer that passes silently.
##
## The console (like the harness) is OWNED BY KOMBUCHA and overwritten by
## /sync-godot-tooling. Project commands do not go in this file: their
## surface goes in data/console_commands.project.json and their behaviour in
## scripts/dev/dev_hooks.gd (`console_dispatch(handler, args)`), which this
## file loads lazily and consults for any handler the closed match below
## does not know. The hooks may also answer `console_allowed()` (the dev
## gate) and `console_complete(source, prefix)` (argument values). See
## tools/seeds/dev_hooks.gd for the contract.

const COMMANDS_PATH := "res://data/console_commands.json"
const PROJECT_COMMANDS_PATH := "res://data/console_commands.project.json"
const HOOKS_PATH := "res://scripts/dev/dev_hooks.gd"
const SCROLLBACK := 1000
const HISTORY_MAX := 200
const SUGGEST_MAX := 40
const SUGGEST_ROWS := 8
const PREFS_FILE := "console.cfg"
const HEIGHT_DEFAULT := 320.0
const HEIGHT_MIN := 160.0
## The group a button lands in when its row names none: the core buttons'.
const CORE_GROUP := "Console"
## `-- --console-release` makes a debug run behave like a player build:
## the toggle does nothing and the UI is never built. It can only turn the
## console OFF, which is why it may ride every build.
const RELEASE_FLAG := "--console-release"
## `-- --console-check` prints the gate's verdict and quits: exit 0 when
## the console is allowed, 3 when it is not. The release check of an
## exported binary reads exactly this.
const CHECK_FLAG := "--console-check"
const CHECK_REFUSED_EXIT := 3

## The project's dev hooks (scripts/dev/dev_hooks.gd), or null when the
## project has none. Shared with the screenshot harness.
var hooks: Object = null
## True = behave as a player build (set by RELEASE_FLAG, or by a test).
var simulate_release := false

var _commands: Array = []
var _buttons: Array = []
var _layer: CanvasLayer = null
var _panel: PanelContainer = null
var _output: RichTextLabel = null
var _entry: LineEdit = null
var _suggest_list: ItemList = null
var _hint: Label = null
var _tabs: HBoxContainer = null
var _flows: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _history: Array[String] = []
var _history_index := -1
var _lines: Array[String] = []
var _suggestions: Dictionary = {"items": [], "hint": "", "replace": 0}
var _pick := -1
var _dismissed := false
var _searching := false
var _dragging := false
var _height := HEIGHT_DEFAULT
var _group := ""
var _prefs_loaded := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_all()
	hooks = _load_hooks()
	simulate_release = Cmdline.has_flag(RELEASE_FLAG)
	if not allowed():
		print("DebugConsole: off in this build (not a debug build, no \"dev\" feature).")
	if Cmdline.has_flag(CHECK_FLAG):
		_report_gate.call_deferred()


func _report_gate() -> void:
	var ok := allowed()
	print("DebugConsole: console_allowed=%s" % ok)
	get_tree().quit(0 if ok else CHECK_REFUSED_EXIT)


## Commands and buttons from both files. A list entry holding `buttons`
## is the buttons; every other entry is a command. The project's buttons
## come first, so a game's own tabs lead and the core "Console" tab trails.
func _load_all() -> void:
	_commands = []
	var core_buttons: Array = []
	var project_buttons: Array = []
	_absorb(_load_commands(COMMANDS_PATH, true), core_buttons)
	_absorb(_load_commands(PROJECT_COMMANDS_PATH, false), project_buttons)
	_buttons = project_buttons + core_buttons


func _absorb(entries: Array, buttons_out: Array) -> void:
	for entry: Variant in entries:
		if not (entry is Dictionary):
			continue
		if (entry as Dictionary).has("buttons"):
			for raw: Variant in (entry as Dictionary)["buttons"]:
				if raw is Dictionary:
					buttons_out.append(button_row(raw))
			continue
		_commands.append(entry)


## `required` files must parse; the project file may simply be absent.
func _load_commands(path: String, required: bool) -> Array:
	if not required and not FileAccess.file_exists(path):
		return []
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if data is Array:
		return data
	push_error("DebugConsole: cannot parse %s" % path)
	return []


## Loaded by path, not class_name, and after the autoloads are up: a hooks
## script names game classes, and naming it from an autoload's script body
## would pull those into the load that runs before autoloads finish.
func _load_hooks() -> Object:
	if not ResourceLoader.exists(HOOKS_PATH):
		return null
	var script: Script = load(HOOKS_PATH)
	if script == null:
		push_error("DebugConsole: %s failed to load" % HOOKS_PATH)
		return null
	var instance: Object = script.new()
	if instance is Node:
		(instance as Node).name = "DevHooks"
		add_child(instance)
	return instance


# ── The dev gate ─────────────────────────────────────────────────────────

## May the console open in this build? The project's `console_allowed()`
## hook is asked first (null = "not mine"); otherwise a debug build or an
## export carrying the `dev` custom feature. A player export has neither,
## so its toggle does nothing and its UI is never built — the cheats a
## console reaches must not ship. `execute()` is NOT gated: the harness
## and tests drive it, and they always run debug builds anyway.
func allowed() -> bool:
	if hooks != null and hooks.has_method("console_allowed"):
		var answer: Variant = hooks.console_allowed()
		if answer != null:
			return bool(answer)
	return default_allowed()


## The gate without the project's say, for a hook that only adds to it.
func default_allowed() -> bool:
	if simulate_release:
		return false
	return OS.is_debug_build() or OS.has_feature("dev")


func is_open() -> bool:
	return _layer != null and _layer.visible


## The toggle key: F12 always (debug chrome must work even if the
## InputMap is mid-rebind or broken), plus the project's `console` action
## when its InputMap has one — so a rebindable row in its settings keeps
## working and nothing toggles twice — else the physical ~ / ` key.
func is_toggle_event(event: InputEvent) -> bool:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return false
	if key.physical_keycode == KEY_F12 or key.keycode == KEY_F12:
		return true
	if InputMap.has_action("console"):
		return event.is_action_pressed("console")
	return key.physical_keycode == KEY_QUOTELEFT or key.keycode == KEY_QUOTELEFT


## In `_input`, not `_unhandled_input`: with the console open its own
## LineEdit has focus and would type the backtick before an unhandled pass
## saw it. Closed, the key is left alone while a text field is being typed
## into (a save name may carry a backtick) or a key is being bound.
func _input(event: InputEvent) -> void:
	if not is_toggle_event(event) or not allowed():
		return
	if not is_open() and (_typing_elsewhere() or _binding_a_key()):
		return
	toggle()
	get_viewport().set_input_as_handled()


func _typing_elsewhere() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or focused == _entry:
		return false
	return (focused is LineEdit and (focused as LineEdit).editable) \
		or (focused is TextEdit and (focused as TextEdit).editable)


func _binding_a_key() -> bool:
	var binds := get_node_or_null("/root/Keybinds")
	return binds != null and "capturing" in binds and bool(binds.capturing)


func toggle() -> void:
	if not allowed():
		return
	if _layer == null:
		_build_ui()
	_layer.visible = not _layer.visible
	if _layer.visible:
		_apply_height()
		_entry.grab_focus()
		_refresh_suggestions()
	else:
		_dragging = false


## Close the console and forget this session's in-memory state (lines,
## history, prefs), so the next read comes from whatever save root is set
## NOW. The harness calls it between scenarios: a console left open, or a
## history read from the developer's own files, is global state that
## outlives a scene reload.
func reset_session() -> void:
	if _layer != null:
		_layer.visible = false
	if _entry != null:
		_entry.clear()
	_lines.clear()
	if _output != null:
		_output.text = ""
	_history.clear()
	_history_index = -1
	_searching = false
	_dismissed = false
	_pick = -1
	_dragging = false
	_prefs_loaded = false
	simulate_release = Cmdline.has_flag(RELEASE_FLAG)
	_height = HEIGHT_DEFAULT
	_group = ""
	if _panel != null:
		_apply_height()
		_select_group(_first_group())
		_refresh_suggestions()


# ── Execution ────────────────────────────────────────────────────────────

## Runs one command line and returns its output ("" for silent success,
## "ERROR: ..." for failure).
func execute(line: String) -> String:
	var trimmed := line.strip_edges()
	if trimmed.is_empty():
		return ""
	var tokens := tokenise(trimmed)
	if tokens.is_empty():
		return ""
	var command := _find_command(tokens[0])
	if command.is_empty():
		return "ERROR: unknown command '%s'. Try 'help'." % tokens[0]
	var parsed := _parse_args(command, tokens.slice(1))
	if parsed.has("error"):
		return "ERROR: %s\nUsage: %s" % [parsed["error"], command.get("usage", command["id"])]
	return _dispatch(command, parsed["args"])


## A command line into tokens: spaces separate, and the token `""` is the
## EMPTY value. Without it an assertion that a field is UNSET cannot be
## written at all — a trailing space is trimmed and the argument reads as
## missing — so one project asserted a neighbouring fact instead, which is
## the weaker scenario.
##
## Every OTHER quote is left exactly where it is. A project's console
## command may take JSON, where `ed_set name "Shore War"` needs its quotes
## to reach the handler: a version of this that grouped quoted phrases and
## stripped the quotes broke thirteen scenario files in one project on the
## day it was tried. `""` is therefore reserved: a handler that wants a
## literal JSON empty string cannot be given one this way.
##
## The harness splits scenario lines through here too, because scenario
## lines and console lines are one vocabulary.
static func tokenise(line: String) -> PackedStringArray:
	var tokens := line.split(" ", false)
	for i in tokens.size():
		if tokens[i] == '""':
			tokens[i] = ""
	return tokens


## The handler registry — a closed match, so a typo in the JSON warns
## instead of reaching something arbitrary. Project handlers live in
## dev_hooks.gd, NOT here: this file is overwritten on every tooling sync.
func _dispatch(command: Dictionary, args: Dictionary) -> String:
	var handler: String = command.get("handler", "")
	# The project's hooks are asked FIRST, so a project may take over a
	# core command (one project's `saves` prints the browser's own row
	# text; another's `locale` persists through its settings): null from
	# the hook means "not mine" and the core handler below answers.
	if hooks != null and hooks.has_method("console_dispatch"):
		var claimed: Variant = hooks.console_dispatch(handler, args)
		if claimed != null:
			return str(claimed)
	match handler:
		"help":
			return _handle_help(args)
		"clear":
			_lines.clear()
			if _output != null:
				_output.text = ""
			return ""
		"copy_log":
			DisplayServer.clipboard_set(plain_log())
			return "Copied %d lines." % _lines.size()
		"save":
			var slot := str(args.get("slot", "")) if not str(args.get("slot", "")).is_empty() else SaveManager.current_slot
			var err := SaveManager.save_game(slot)
			return "Saved '%s'." % slot if err == OK else "ERROR: save failed (%d)" % err
		"load":
			var slot := str(args.get("slot", "")) if not str(args.get("slot", "")).is_empty() else SaveManager.current_slot
			var err := SaveManager.load_game(slot)
			if err == OK:
				return "Loaded '%s'." % slot
			# The kit's SaveManager says WHY (a save from the future, a
			# missing mod, a corrupt file); duck-typed so a project on older
			# kit still gets the code.
			if "last_load_problem" in SaveManager \
					and not str(SaveManager.last_load_problem).is_empty():
				return "ERROR: " + str(SaveManager.last_load_problem)
			return "ERROR: load failed (%d)" % err
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
		"locale":
			var code := str(args.get("code", ""))
			if code.is_empty():
				return "%s (loaded: %s)" % [TranslationServer.get_locale(),
					", ".join(TranslationServer.get_loaded_locales())]
			if not TranslationServer.get_loaded_locales().has(code) and code != "en":
				return "ERROR: no translation loaded for '%s'" % code
			TranslationServer.set_locale(code)
			return "Locale %s (restart to rebuild UI built at boot)." % code
		"console_assert":
			return _console_assert(str(args["key"]), str(args["value"]))
		"console_release":
			simulate_release = bool(args["on"])
			if simulate_release and is_open():
				_layer.visible = false
			return "The console now acts as in a %s build." % ("player" if simulate_release else "dev")
		"state":
			return _handle_state()
		"assert":
			return _handle_assert(str(args["key"]), str(args["value"]))
		_:
			return "ERROR: command '%s' names unknown handler '%s'" % [command["id"], handler]


## State readback before pixels. Any node in the "state" group that
## implements state_text() -> String and assert_key(key, value) -> String
## is a provider; the console owns only the lookup and the error contract.
## assert_key answers "" on match, "ERROR: ..." on mismatch, and exactly
## "ERROR: unknown key '<key>'" for a key it does not own, so several
## providers can be consulted in turn. A `prefix:` key is the way to expose
## an open namespace (flag:<name>) without touching the console.
func _state_providers(method: String) -> Array[Node]:
	var providers: Array[Node] = []
	for node in get_tree().get_nodes_in_group("state"):
		# a freed provider is in the group until the frame ends
		if node.has_method(method) and not node.is_queued_for_deletion():
			providers.append(node)
	return providers


func _handle_state() -> String:
	var providers := _state_providers("state_text")
	if providers.is_empty():
		return "ERROR: nothing in the 'state' group answers state_text()"
	var lines: Array[String] = []
	for node in providers:
		lines.append(str(node.state_text()))
	return "\n".join(lines)


func _handle_assert(key: String, value: String) -> String:
	var providers := _state_providers("assert_key")
	if providers.is_empty():
		return "ERROR: nothing in the 'state' group answers assert_key()"
	var unknown := "ERROR: unknown key '%s'" % key
	for node in providers:
		var reply := str(node.assert_key(key, value))
		if reply != unknown:
			return reply
	return "ERROR: no state provider knows key '%s'" % key


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


## The console's own UI, read back for scenarios: `open` true/false,
## `input` (the line, trailing space trimmed), `suggests` (a showing row contains the
## value), `hint` (the hint contains it), `tab`, `button` (a button by id
## is on the showing tab), `history` (a past line equals it).
func _console_assert(key: String, value: String) -> String:
	var have := ""
	var ok := false
	match key:
		"open":
			have = str(is_open())
			ok = have == value
		"input":
			# trailing spaces trimmed: a scenario line cannot end in one
			have = input_text()
			ok = have.strip_edges() == value
		"suggests":
			have = " | ".join(shown_suggestions())
			for row in shown_suggestions():
				ok = ok or row.contains(value)
		"hint":
			have = _hint.text if _hint != null and _hint.visible else ""
			ok = not value.is_empty() and have.contains(value)
		"tab":
			have = _group
			ok = have == value
		"button":
			var node: Control = null
			if _flows.has(_group):
				node = (_flows[_group] as Node).get_node_or_null("ConsoleButton_%s" % value)
			have = "on tab %s" % _group
			ok = node != null and is_open()
		"history":
			have = " | ".join(history())
			ok = history().has(value)
		_:
			return "ERROR: unknown key '%s' (try open, input, suggests, hint, tab, button, history)" % key
	return "" if ok else "ERROR: console %s is \"%s\", expected \"%s\"" % [key, have, value]


## The scrollback as plain text (BBCode tags dropped), for `copy_log`.
func plain_log() -> String:
	var tags := RegEx.create_from_string("\\[/?[a-z_]+[^\\]]*\\]")
	var out: Array[String] = []
	for line in _lines:
		out.append(tags.sub(line, "", true))
	return "\n".join(out)


# ── Parsing ──────────────────────────────────────────────────────────────

func _find_command(name: String) -> Dictionary:
	for command in _commands:
		if command.get("id", "") == name or (command.get("aliases", []) as Array).has(name):
			return command
	return {}


## Returns { "args": { name: value } } or { "error": String }. A "rest"
## argument swallows the remainder of the line, which is what lets a
## multi-word note work without quoting. A spec with `"flag": true` is
## NAMED, not positional: `--name=value` (or bare `--name` for true)
## anywhere on the line, pulled out before the positional pass. It is how
## an optional argument can precede a rest one: positions cannot express
## that, and one project forked a command per field instead.
func _parse_args(command: Dictionary, tokens: Array) -> Dictionary:
	var args: Dictionary = {}
	var specs: Array = command.get("args", [])
	var positional: Array = []
	for token in tokens:
		var text := str(token)
		if not text.begins_with("--") or text.length() < 3:
			positional.append(token)
			continue
		var eq := text.find("=")
		var flag_name := text.substr(2, (eq - 2) if eq > 0 else -1)
		var found := false
		for spec in specs:
			if spec.get("flag", false) and spec.get("name", "") == flag_name:
				var value: String = text.substr(eq + 1) if eq > 0 else "true"
				var parsed := _parse_value(spec, value)
				if parsed.has("error"):
					return parsed
				args[flag_name] = parsed["value"]
				found = true
				break
		if not found:
			return {"error": "Unknown flag --%s." % flag_name}
	tokens = positional
	var specs_positional: Array = []
	for spec in specs:
		if spec.get("flag", false):
			if not args.has(spec.get("name", "")):
				if spec.get("required", false):
					return {"error": "Missing --%s." % spec.get("name", "")}
				if spec.has("default"):
					args[spec.get("name", "")] = spec["default"]
		else:
			specs_positional.append(spec)
	specs = specs_positional
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var name: String = spec.get("name", "arg%d" % i)
		var kind: String = spec.get("kind", "string")

		if kind == "rest":
			var rest := " ".join(PackedStringArray(tokens.slice(i)))
			# ABSENT, not empty: `assert key ""` is a legitimate assertion
			# that a field is unset, and refusing it left one project
			# asserting a neighbouring fact instead.
			if i >= tokens.size() and spec.get("required", false):
				return {"error": "Missing <%s>." % name}
			args[name] = rest
			return {"args": args}

		if i >= tokens.size():
			if spec.get("required", false):
				return {"error": "Missing <%s>." % name}
			if spec.has("default"):
				args[name] = spec["default"]
			continue

		var parsed := _parse_value(spec, str(tokens[i]))
		if parsed.has("error"):
			return parsed
		args[name] = parsed["value"]
	return {"args": args}


## One value against one spec's kind: { "value": ... } or { "error": ... }.
static func _parse_value(spec: Dictionary, raw: String) -> Dictionary:
	var name: String = spec.get("name", "arg")
	match str(spec.get("kind", "string")):
		"int":
			if not raw.is_valid_int():
				return {"error": "<%s> must be a whole number." % name}
			return {"value": clampi(int(raw), int(spec.get("min", -99999)), int(spec.get("max", 99999)))}
		"float":
			if not raw.is_valid_float():
				return {"error": "<%s> must be a number." % name}
			return {"value": float(raw)}
		"enum":
			if not (spec.get("values", []) as Array).has(raw):
				return {"error": "<%s> must be one of: %s" % [name, ", ".join(PackedStringArray(spec.get("values", [])))]}
			return {"value": raw}
		"bool":
			return {"value": raw.to_lower() in ["true", "1", "yes", "on"]}
	return {"value": raw}


# ── Suggestions (pure: the UI only shows what these answer) ──────────────

## What the suggestion list shows for a half-typed line: {items, hint,
## replace}. Each item is {text, insert}: `text` is the row, `insert`
## replaces the last `replace` characters of the line when it is taken.
## The first word suggests commands (usage + description); after it, the
## current argument's hint and its values, from an `enum`'s `values`, a
## `bool`, and a `"complete": "<source>"` field answered by
## `complete_values`. Ctrl+R swaps the whole list for past lines.
func suggest(text: String) -> Dictionary:
	if _searching:
		return _suggest_history(text)
	var line := text.lstrip(" ")
	var tokens := line.split(" ", false)
	if tokens.is_empty():
		return {"items": [], "hint": "", "replace": 0}
	var ends_open := line.ends_with(" ")
	if tokens.size() == 1 and not ends_open:
		return {"items": _command_matches(tokens[0]), "hint": "", "replace": tokens[0].length()}
	var command := _find_command(tokens[0])
	if command.is_empty():
		return {"items": [], "replace": 0,
			"hint": "No command is called '%s'. Type help to see them all." % tokens[0]}
	var done: Array = Array(tokens.slice(1))
	var partial := ""
	if not ends_open and not done.is_empty():
		partial = str(done.pop_back())
	var specs: Array = command.get("args", [])
	var usage := str(command.get("usage", command.get("id", "")))
	if partial.begins_with("--"):
		return _suggest_flag(specs, partial, usage)
	var positional: Array = []
	var flags: Array = []
	for spec: Variant in specs:
		if not (spec is Dictionary):
			continue
		if bool(spec.get("flag", false)):
			flags.append(spec)
		else:
			positional.append(spec)
	var index := 0
	for token: Variant in done:
		if not str(token).begins_with("--"):
			index += 1
	var spec: Dictionary = {}
	if index < positional.size():
		spec = positional[index]
	elif not positional.is_empty() and str((positional[-1] as Dictionary).get("kind", "")) == "rest":
		spec = positional[-1]
	if spec.is_empty():
		return {"items": [], "replace": partial.length(),
			"hint": "%s  ·  nothing more to type. Press Enter to run it." % usage}
	var hint := "%s  ·  %s" % [usage, arg_hint(spec, mini(index, positional.size() - 1), positional.size())]
	var items: Array = []
	for value: String in values_for(spec, partial):
		items.append({"text": value, "insert": value + " "})
	if partial.is_empty():
		for flag: Dictionary in flags:
			items.append({"text": "--%s=<%s>  (optional, named)" % [flag.get("name", ""),
				_kind_words(flag)], "insert": "--%s=" % flag.get("name", "")})
	return {"items": items, "hint": hint, "replace": partial.length()}


## Commands for a first word: ids starting with it, then aliases, then ids
## that merely contain it (so `endturn` still finds `x_endturn`).
func _command_matches(word: String) -> Array:
	var starts: Array = []
	var aliases: Array = []
	var inside: Array = []
	var low := word.to_lower()
	for command: Dictionary in _commands:
		var id := str(command.get("id", ""))
		var row := {"text": _command_row(command), "insert": id + " ", "id": id}
		if id.to_lower().begins_with(low):
			starts.append(row)
			continue
		var by_alias := false
		for alias: Variant in command.get("aliases", []):
			if str(alias).to_lower().begins_with(low):
				by_alias = true
		if by_alias:
			aliases.append(row)
		elif id.to_lower().contains(low):
			inside.append(row)
	var by_id := func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"])
	starts.sort_custom(by_id)
	aliases.sort_custom(by_id)
	inside.sort_custom(by_id)
	return (starts + aliases + inside).slice(0, SUGGEST_MAX)


func _command_row(command: Dictionary) -> String:
	var usage := str(command.get("usage", command.get("id", "")))
	var about := str(command.get("description", ""))
	return usage if about.is_empty() else "%s  —  %s" % [usage, about]


func _suggest_flag(specs: Array, partial: String, usage: String) -> Dictionary:
	var eq := partial.find("=")
	var items: Array = []
	var hint := usage
	for spec: Variant in specs:
		if not (spec is Dictionary) or not bool(spec.get("flag", false)):
			continue
		var name := str(spec.get("name", ""))
		if eq < 0:
			if ("--" + name).begins_with(partial):
				items.append({"text": "--%s=<%s>" % [name, _kind_words(spec)], "insert": "--%s=" % name})
		elif partial.substr(2, eq - 2) == name:
			hint = "%s  ·  --%s: %s" % [usage, name, _spec_words(spec)]
			for value: String in values_for(spec, partial.substr(eq + 1)):
				items.append({"text": value, "insert": "--%s=%s " % [name, value]})
	return {"items": items, "hint": hint, "replace": partial.length()}


func _suggest_history(text: String) -> Dictionary:
	var items: Array = []
	for line: String in search_history(text):
		items.append({"text": line, "insert": line})
	return {"items": items, "replace": text.length(),
		"hint": "Searching past commands. Enter or Tab puts one in the line. Esc stops."}


## One argument in plain words: "argument 2 of 2, percent: a whole number
## from 0 to 100, needed".
static func arg_hint(spec: Dictionary, index: int, count: int) -> String:
	return "argument %d of %d, %s: %s" % [index + 1, count, spec.get("name", "arg"), _spec_words(spec)]


static func _spec_words(spec: Dictionary) -> String:
	var words := _kind_words(spec)
	if spec.has("min") and spec.has("max"):
		words += " from %s to %s" % [_number(spec["min"]), _number(spec["max"])]
	if bool(spec.get("required", false)):
		words += ", needed"
	elif spec.has("default"):
		words += ", optional (default %s)" % str(spec["default"])
	else:
		words += ", optional"
	return words


## JSON has no integers: 100 arrives as 100.0, which reads as a fraction.
static func _number(value: Variant) -> String:
	var number := float(value)
	return str(int(number)) if is_equal_approx(number, roundf(number)) else str(number)


static func _kind_words(spec: Dictionary) -> String:
	match str(spec.get("kind", "string")):
		"int":
			return "a whole number"
		"float":
			return "a number"
		"enum":
			return "one of the listed words"
		"bool":
			return "true or false"
		"rest":
			return "words to the end of the line"
	return "a name from the list" if spec.has("complete") else "a word"


## The values offered for one argument and a half-typed prefix: those that
## start with it first, then those that contain it, case ignored.
func values_for(spec: Dictionary, prefix: String) -> Array[String]:
	var pool: Array[String] = []
	for value: Variant in spec.get("values", []):
		pool.append(str(value))
	if str(spec.get("kind", "")) == "bool":
		pool.append_array(["true", "false"])
	if spec.has("complete"):
		pool.append_array(complete_values(str(spec["complete"]), prefix))
	var low := prefix.to_lower()
	var starts: Array[String] = []
	var inside: Array[String] = []
	for value in pool:
		if starts.has(value) or inside.has(value):
			continue
		var have := value.to_lower()
		if have.begins_with(low):
			starts.append(value)
		elif have.contains(low):
			inside.append(value)
	starts.sort()
	inside.sort()
	var out: Array[String] = starts + inside
	return out.slice(0, SUGGEST_MAX)


## The values a `"complete": "<source>"` names. The project's
## `console_complete(source, prefix)` hook is asked FIRST (null = "not
## mine"), so a game can offer its registry's ids; the core sources are
## `commands`, `saves`, `actions` (Keybinds) and `locales`. `prefix` is a
## hint a hook may use to cut a long list; this file filters again.
func complete_values(source: String, prefix: String) -> Array[String]:
	var out: Array[String] = []
	if hooks != null and hooks.has_method("console_complete"):
		var got: Variant = hooks.console_complete(source, prefix)
		if got != null:
			for value: Variant in got:
				out.append(str(value))
			return out
	match source:
		"commands":
			for command: Dictionary in _commands:
				out.append(str(command.get("id", "")))
		"saves":
			out = _save_names()
		"actions":
			for entry: Variant in Keybinds.ACTIONS:
				out.append(str(entry["action"]))
		"locales":
			out.append("en")
			for code in TranslationServer.get_loaded_locales():
				if not out.has(code):
					out.append(code)
	return out


# ── History (kept between runs, under the redirectable save root) ────────

## Where the history, the height and the last tab live: beside the saves,
## so the harness and tests (which point `SaveManager.save_root` at
## scratch) never read or write the developer's own; `user://` when there
## is no SaveManager. Not a .json, so no save listing counts it.
func prefs_path() -> String:
	var root := "user://"
	var saves := get_node_or_null("/root/SaveManager")
	if saves != null and "save_root" in saves:
		root = str(saves.save_root)
	return root.path_join(PREFS_FILE)


func _ensure_prefs() -> void:
	if _prefs_loaded:
		return
	_prefs_loaded = true
	var file := ConfigFile.new()
	if file.load(prefs_path()) != OK:
		return
	_history.clear()
	for line: Variant in file.get_value("console", "history", []):
		_history.append(str(line))
	_history_index = _history.size()
	_height = float(file.get_value("console", "height", HEIGHT_DEFAULT))
	_group = str(file.get_value("console", "tab", ""))


func _save_prefs() -> void:
	var file := ConfigFile.new()
	file.set_value("console", "history", _history)
	file.set_value("console", "height", _height)
	file.set_value("console", "tab", _group)
	DirAccess.make_dir_recursive_absolute(prefs_path().get_base_dir())
	file.save(prefs_path())


func history() -> Array[String]:
	_ensure_prefs()
	return _history.duplicate()


## Add one line to the history and write it out. A repeat of the last line
## is not stored twice.
func remember(line: String) -> void:
	_ensure_prefs()
	var trimmed := line.strip_edges()
	if trimmed.is_empty():
		return
	if _history.is_empty() or _history[-1] != trimmed:
		_history.append(trimmed)
	while _history.size() > HISTORY_MAX:
		_history.pop_front()
	_history_index = _history.size()
	_save_prefs()


## Past lines containing `fragment`, newest first, each once (Ctrl+R).
func search_history(fragment: String) -> Array[String]:
	_ensure_prefs()
	var out: Array[String] = []
	var low := fragment.to_lower()
	for i in range(_history.size() - 1, -1, -1):
		var line := _history[i]
		if line.to_lower().contains(low) and not out.has(line):
			out.append(line)
	return out.slice(0, SUGGEST_MAX)


# ── Buttons ──────────────────────────────────────────────────────────────

## One button row, normalised: {id, label, run, group, tip, fill}. A row
## with no id takes one from its label ("Copy log" → copy_log).
static func button_row(raw: Dictionary) -> Dictionary:
	var label := str(raw.get("label", ""))
	var id := str(raw.get("id", ""))
	if id.is_empty():
		id = RegEx.create_from_string("[^a-z0-9]+").sub(label.to_lower(), "_", true) \
			.trim_prefix("_").trim_suffix("_")
	var fill: Variant = raw.get("fill", false)
	return {"id": id, "label": label, "run": str(raw.get("run", "")),
		"group": str(raw.get("group", CORE_GROUP)), "tip": str(raw.get("tip", "")),
		"fill": fill is bool and fill}


func buttons() -> Array:
	return _buttons.duplicate(true)


## The tabs, in the order their first button appears.
func button_groups() -> Array[String]:
	var out: Array[String] = []
	for row: Dictionary in _buttons:
		if not out.has(str(row["group"])):
			out.append(str(row["group"]))
	return out


## Every button's problems: no label, a repeated id, or a `run` whose first
## word is no command. A test asserts this is empty, so a renamed command
## cannot leave a button that only answers "unknown command".
func button_problems() -> Array[String]:
	var out: Array[String] = []
	var seen := {}
	for row: Dictionary in _buttons:
		var id := str(row["id"])
		if str(row["label"]).is_empty():
			out.append("button '%s' has no label" % id)
		if seen.has(id):
			out.append("button id '%s' is used twice" % id)
		seen[id] = true
		var words := tokenise(str(row["run"]))
		if words.is_empty() or _find_command(words[0]).is_empty():
			out.append("button '%s' runs '%s', which is no command" % [id, row["run"]])
	return out


## The tooltip: the row's tip, then the line it runs, so the buttons teach
## the text commands.
static func button_tip(row: Dictionary) -> String:
	var line := str(row["run"]).strip_edges()
	var how := ("Puts \"%s\" in the line for you to finish." % line) if bool(row["fill"]) \
		else ("Runs: %s" % line)
	var tip := str(row["tip"])
	return how if tip.is_empty() else "%s\n%s" % [tip, how]


## Press a button by id, with or without the UI: runs its line (echoed and
## remembered, like a typed one) or, for a `fill` button, puts the line in
## the input. Returns the command's reply.
func press_button(id: String) -> String:
	var row := {}
	for candidate: Dictionary in _buttons:
		if str(candidate["id"]) == id:
			row = candidate
	if row.is_empty():
		return "ERROR: no console button '%s'" % id
	var line := str(row["run"])
	if bool(row["fill"]):
		if _entry != null:
			_entry.text = line if line.ends_with(" ") else line + " "
			_entry.caret_column = _entry.text.length()
			_entry.grab_focus()
			_dismissed = false
			_pick = -1
			_refresh_suggestions()
		return ""
	return run_line(line)


## A line as if typed and submitted: echoed, remembered, run, answered.
func run_line(line: String) -> String:
	remember(line)
	print_line("[b]> %s[/b]" % line)
	var result := execute(line)
	if not result.is_empty():
		print_line(result)
	return result


## What the input line holds now ("" before the UI is built): a seam for
## scenarios and tests that type into it.
func input_text() -> String:
	return _entry.text if _entry != null else ""


# ── UI (built lazily) ────────────────────────────────────────────────────

func _build_ui() -> void:
	_ensure_prefs()
	_layer = CanvasLayer.new()
	_layer.name = "ConsoleLayer"
	_layer.layer = 100
	_layer.visible = false
	add_child(_layer)
	_panel = PanelContainer.new()
	_panel.name = "ConsolePanel"
	_panel.theme = UITheme.get_theme()
	_panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_layer.add_child(_panel)
	var box := VBoxContainer.new()
	box.name = "ConsoleBox"
	_panel.add_child(box)
	_output = RichTextLabel.new()
	_output.name = "ConsoleOutput"
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.text = "\n".join(_lines)
	box.add_child(_output)
	_entry = LineEdit.new()
	_entry.name = "ConsoleInput"
	_entry.placeholder_text = "Type a command. Tab takes a suggestion. Ctrl+R searches past commands."
	_entry.text_submitted.connect(_on_submitted)
	_entry.text_changed.connect(_on_text_changed)
	_entry.gui_input.connect(_on_input_key)
	box.add_child(_entry)
	_suggest_list = ItemList.new()
	_suggest_list.name = "ConsoleSuggestions"
	_suggest_list.focus_mode = Control.FOCUS_NONE
	_suggest_list.select_mode = ItemList.SELECT_SINGLE
	_suggest_list.visible = false
	_suggest_list.item_clicked.connect(_on_suggestion_clicked)
	box.add_child(_suggest_list)
	_hint = Label.new()
	_hint.name = "ConsoleHint"
	_hint.clip_text = true
	_hint.modulate.a = 0.75
	_hint.visible = false
	box.add_child(_hint)
	_tabs = HBoxContainer.new()
	_tabs.name = "ConsoleTabs"
	box.add_child(_tabs)
	_build_buttons(box)
	var grip := HSeparator.new()
	grip.name = "ConsoleResize"
	grip.tooltip_text = "Drag to make the console taller or shorter."
	grip.custom_minimum_size = Vector2(0, 12)
	grip.mouse_filter = Control.MOUSE_FILTER_STOP
	grip.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	grip.gui_input.connect(_on_grip_input)
	box.add_child(grip)
	_apply_height()
	if _lines.is_empty():
		print_line("[i]Type help to see the commands, or press a button below.[/i]")


func _build_buttons(box: VBoxContainer) -> void:
	_flows.clear()
	_tab_buttons.clear()
	var tab_group := ButtonGroup.new()
	for group in button_groups():
		var tab := Button.new()
		tab.name = "ConsoleTab_%s" % group.validate_node_name()
		tab.text = group
		tab.toggle_mode = true
		tab.button_group = tab_group
		tab.focus_mode = Control.FOCUS_NONE
		tab.pressed.connect(_select_group.bind(group))
		_tabs.add_child(tab)
		_tab_buttons[group] = tab
		var flow := HFlowContainer.new()
		flow.name = "ConsoleButtons_%s" % group.validate_node_name()
		box.add_child(flow)
		_flows[group] = flow
	for row: Dictionary in _buttons:
		var button := Button.new()
		button.name = "ConsoleButton_%s" % str(row["id"]).validate_node_name()
		button.text = str(row["label"]) + ("…" if bool(row["fill"]) else "")
		button.tooltip_text = button_tip(row)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_button_pressed.bind(str(row["id"])))
		(_flows[str(row["group"])] as HFlowContainer).add_child(button)
	_tabs.visible = not _flows.is_empty()
	_select_group(_group if _flows.has(_group) else _first_group())


func _first_group() -> String:
	var groups := button_groups()
	return groups[0] if not groups.is_empty() else ""


## Show one tab's buttons (the harness clicks `ConsoleTab_<group>`).
func _select_group(group: String) -> void:
	if not _flows.has(group):
		return
	var changed := group != _group
	_group = group
	for name: String in _flows:
		(_flows[name] as Control).visible = name == group
		(_tab_buttons[name] as Button).set_pressed_no_signal(name == group)
	if changed and _prefs_loaded:
		_save_prefs()


## The tab showing now ("" before the UI is built or with no buttons).
func current_group() -> String:
	return _group


func _on_button_pressed(id: String) -> void:
	press_button(id)
	if _entry != null and is_open():
		_entry.grab_focus()


func _apply_height() -> void:
	if _panel == null:
		return
	var view_h := get_viewport().get_visible_rect().size.y
	_height = clampf(_height, HEIGHT_MIN, maxf(HEIGHT_MIN, view_h * 0.95))
	_panel.custom_minimum_size = Vector2(0, _height)
	_panel.offset_bottom = _height


## The console's height in canvas pixels; a test or scenario may set it.
## Kept between runs like the history.
func set_height(pixels: float) -> void:
	_ensure_prefs()
	_height = pixels
	_apply_height()
	_save_prefs()


func height() -> float:
	_ensure_prefs()
	return _height


func _on_grip_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		if not button.pressed:
			_save_prefs()
		return
	if _dragging and event is InputEventMouseMotion:
		_height = _panel.get_local_mouse_position().y
		_apply_height()


func print_line(text: String) -> void:
	_lines.append(text)
	while _lines.size() > SCROLLBACK:
		_lines.pop_front()
	if _output != null:
		_output.text = "\n".join(_lines)


func _on_submitted(line: String) -> void:
	_searching = false
	run_line(line)
	_entry.clear()
	_refresh_suggestions()
	# Some themes drop focus on submit; a console you have to re-click after
	# every command is useless.
	_entry.grab_focus()


func _on_text_changed(_text: String) -> void:
	_dismissed = false
	_pick = -1
	_refresh_suggestions()


## Keys in the input. With the list showing: Up/Down move through it, Tab
## takes the marked row (or the first), Enter takes a row only once you
## have moved into the list, Esc hides it. Without it: Up/Down walk the
## history and Esc closes the console. Ctrl+R searches past commands.
func _on_input_key(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	var listing := _list_showing()
	var count: int = (_suggestions["items"] as Array).size()
	if key.keycode == KEY_R and key.ctrl_pressed:
		_searching = not _searching
		_dismissed = false
		_pick = -1
		_refresh_suggestions()
	elif key.keycode == KEY_UP:
		if listing:
			_pick = count - 1 if _pick <= 0 else _pick - 1
			_show_pick()
		else:
			_recall(-1)
	elif key.keycode == KEY_DOWN:
		if listing:
			_pick = (_pick + 1) % count
			_show_pick()
		else:
			_recall(1)
	elif key.keycode == KEY_TAB:
		if listing:
			accept_suggestion(maxi(_pick, 0))
	elif (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) and listing and _pick >= 0:
		accept_suggestion(_pick)
	elif key.keycode == KEY_ESCAPE:
		if listing or _searching:
			_dismissed = true
			_searching = false
			_refresh_suggestions()
		else:
			toggle()
	else:
		return
	_entry.accept_event()


func _list_showing() -> bool:
	return _suggest_list != null and _suggest_list.visible


## Take suggestion `index` into the line (the seam behind Tab, Enter and a
## click).
func accept_suggestion(index: int) -> void:
	var items: Array = _suggestions["items"]
	if index < 0 or index >= items.size() or _entry == null:
		return
	var row: Dictionary = items[index]
	var text := _entry.text
	var keep := text.length() - int(_suggestions["replace"])
	_entry.text = text.substr(0, maxi(keep, 0)) + str(row["insert"])
	_entry.caret_column = _entry.text.length()
	_searching = false
	_dismissed = false
	_pick = -1
	_refresh_suggestions()


func _on_suggestion_clicked(index: int, _at: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT:
		accept_suggestion(index)
		_entry.grab_focus()


func _refresh_suggestions() -> void:
	if _suggest_list == null:
		return
	_suggestions = suggest(_entry.text)
	var items: Array = _suggestions["items"]
	_suggest_list.clear()
	for row: Dictionary in items:
		_suggest_list.add_item(str(row["text"]), null, true)
	var rows := mini(items.size(), SUGGEST_ROWS)
	var font := _suggest_list.get_theme_font("font")
	var font_size := _suggest_list.get_theme_font_size("font_size")
	var row_h := font.get_height(font_size) + _suggest_list.get_theme_constant("v_separation") + 2.0
	_suggest_list.custom_minimum_size = Vector2(0, rows * row_h + 8.0)
	_suggest_list.visible = not items.is_empty() and not _dismissed
	_show_pick()
	var hint := str(_suggestions["hint"])
	_hint.text = hint
	_hint.visible = not hint.is_empty() and not _dismissed


func _show_pick() -> void:
	_suggest_list.deselect_all()
	if _pick >= 0 and _pick < _suggest_list.item_count:
		_suggest_list.select(_pick)
		_suggest_list.ensure_current_is_visible()


## The suggestion rows showing now (empty while the list is hidden): the
## seam a scenario asserts on.
func shown_suggestions() -> Array[String]:
	var out: Array[String] = []
	if not _list_showing():
		return out
	for row: Dictionary in _suggestions["items"]:
		out.append(str(row["text"]))
	return out


func _recall(direction: int) -> void:
	_ensure_prefs()
	if _history.is_empty():
		return
	_history_index = clampi(_history_index + direction, 0, _history.size())
	_entry.text = _history[_history_index] if _history_index < _history.size() else ""
	_entry.caret_column = _entry.text.length()
	_dismissed = true
	_refresh_suggestions()
