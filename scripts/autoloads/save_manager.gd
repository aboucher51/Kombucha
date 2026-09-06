extends Node
## Save/load skeleton: machine settings in a ConfigFile, game saves as JSON
## in per-slot files.
##
## `save_root` and `config_path` are variables, not constants, so the test
## suite and the screenshot harness can redirect the whole save system at
## scratch storage and put it back afterwards — a suite run must never edit
## the player's real saves or settings. Keep any new persistence routed
## through these paths for the same reason.

const DEFAULT_SAVE_ROOT := "user://saves"
const DEFAULT_CONFIG_PATH := "user://settings.cfg"
const DEFAULT_MODS_ROOT := "user://mods"
const DEFAULT_SLOT := "slot_1"
## How many slots a browser offers. Saves outside this range still load —
## the number bounds the UI, not the format.
const SLOT_COUNT := 3
## Where a slot's own description lives, at the top level beside the
## providers' payloads, so a listing can read it without parsing the rest.
const META_KEY := "meta"
## Anything in this group that answers save_key() and save_payload() gets
## its slice written into the slot, and restore_payload(payload) on load.
## Group + has_method rather than a typed reference: this is an autoload,
## and naming a scene class here drags it into the pre-autoload load (see
## CLAUDE.md). Two projects converged on exactly this seam.
const PROVIDER_GROUP := "save_provider"

var save_root: String = DEFAULT_SAVE_ROOT
var config_path: String = DEFAULT_CONFIG_PATH
## Where mods are read from (ContentDB). Redirectable like the saves, and
## the harness sandbox redirects it, so a scenario's outcome never depends
## on the mods installed on the machine.
var mods_root: String = DEFAULT_MODS_ROOT
var current_slot: String = DEFAULT_SLOT
## Why the last load_game() failed, in words a console or a dialog can
## show — a bare Error code tells the player nothing. "" after a success.
var last_load_problem: String = ""


## Every provider's slice, keyed by its save_key(), stamped by SaveCompat.
## An empty payload writes no key — a blank slice is not worth a row.
func collect_save_data() -> Dictionary:
	var data := {}
	for node in get_tree().get_nodes_in_group(PROVIDER_GROUP):
		if node.is_queued_for_deletion():
			continue   # in the group until the frame ends, gone by the next
		if not node.has_method("save_key") or not node.has_method("save_payload"):
			continue
		var key := str(node.save_key())
		var payload: Variant = node.save_payload()
		if key != "" and payload is Dictionary and not (payload as Dictionary).is_empty():
			data[key] = payload
	return SaveCompat.stamp(data)


## Hands each provider its slice back. Migrated first; a save that cannot be
## migrated is refused with the reason in last_load_problem.
func apply_save_data(data: Dictionary) -> bool:
	var upgraded := SaveCompat.upgrade(data)
	if not bool(upgraded["ok"]):
		last_load_problem = str(upgraded["error"])
		return false
	var payload: Dictionary = upgraded["payload"]
	for node in get_tree().get_nodes_in_group(PROVIDER_GROUP):
		if node.is_queued_for_deletion():
			continue   # in the group until the frame ends, gone by the next
		if not node.has_method("save_key") or not node.has_method("restore_payload"):
			continue
		var key := str(node.save_key())
		if payload.has(key) and payload[key] is Dictionary:
			node.restore_payload(payload[key])
	return true


func save_game(slot: String = current_slot, meta: Dictionary = {}) -> Error:
	DirAccess.make_dir_recursive_absolute(save_root)
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var data := collect_save_data()
	# Stamped here rather than by the caller: a save's time is a fact about
	# the write, not about the game.
	var described := meta.duplicate()
	described["saved_at"] = int(Time.get_unix_time_from_system())
	described["slot"] = slot
	described["version"] = VersionUtil.game()
	data[META_KEY] = described
	# sort_keys FALSE: JSON.stringify sorts keys by default, and Dictionary
	# equality is order-sensitive, so a saved dictionary came back unequal
	# to itself — two projects found this independently.
	file.store_string(JSON.stringify(data, "\t", false))
	return OK


## What a slot says about itself, without the providers' payloads. Empty
## for a slot that does not exist or cannot be read — a browser has to cope
## with a half-written file, and refusing to list anything is not coping.
func slot_meta(slot: String) -> Dictionary:
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or json.data is not Dictionary:
		return {}
	var meta: Variant = (json.data as Dictionary).get(META_KEY, {})
	return meta if meta is Dictionary else {}


## Every slot a browser offers, in order, whether or not it holds anything:
## an empty entry is {"slot": ..., "empty": true}. The numbered slots always
## appear; anything else on disk is appended, because a save the listing
## does not mention is a save you cannot find again.
func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var numbered := {}
	for i in range(1, SLOT_COUNT + 1):
		var slot := "slot_%d" % i
		numbered[slot] = true
		out.append(_describe_slot(slot))
	for slot: String in _slots_on_disk():
		if not numbered.has(slot):
			out.append(_describe_slot(slot))
	return out


func _describe_slot(slot: String) -> Dictionary:
	var meta := slot_meta(slot)
	if meta.is_empty():
		return {"slot": slot, "empty": true}
	meta["empty"] = false
	return meta


func _slots_on_disk() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(save_root)
	if dir == null:
		return out
	for name: String in dir.get_files():
		if name.ends_with(".json"):
			out.append(name.trim_suffix(".json"))
	out.sort()
	return out


func load_game(slot: String = current_slot) -> Error:
	last_load_problem = ""
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		last_load_problem = "no save named '%s'" % slot
		return FileAccess.get_open_error()
	# A JSON instance, not JSON.parse_string: the static form logs an engine
	# error for a corrupt file, and a corrupt save is a reportable state,
	# not a crash.
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		last_load_problem = "'%s' is not a readable save file (line %d: %s)" % [
			slot, json.get_error_line() + 1, json.get_error_message()]
		return ERR_INVALID_DATA
	if json.data is not Dictionary:
		last_load_problem = "'%s' does not hold a save object" % slot
		return ERR_INVALID_DATA
	if not apply_save_data(json.data):
		return ERR_INVALID_DATA
	return OK


func has_save(slot: String = current_slot) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: String) -> void:
	DirAccess.remove_absolute(_slot_path(slot))


func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [save_root, slot]


## -- Machine settings (volumes, locale, …) ---------------------------------

## Every settings write announces itself on EventBus.settings_changed, so a
## live system re-applies from one seam instead of each panel poking it.
func set_setting(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(config_path)  # ignore error — a missing file is a fresh start
	config.set_value(section, key, value)
	config.save(config_path)
	EventBus.settings_changed.emit(section, key)


func get_setting(section: String, key: String, default: Variant = null) -> Variant:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return default
	return config.get_value(section, key, default)
