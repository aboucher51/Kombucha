class_name ContentDB
extends RefCounted
## Loads a JSON content file with mod layering: res://data/<file> is the
## base, then every mod directory under `SaveManager.mods_root` may ship
## data/<file> that DataMerger PATCHes over it, in sorted (load) order.
## Content files are dictionaries keyed by id, which is what makes the
## merge natural: a mod redefines an id to override it, adds a new id to
## extend, or uses the $-operations to edit one field of a shipped entry.
##
## Missing files are the normal case, not an error — a mod that only adds
## rules ships only rules.json.
##
## The mods root is SaveManager's, not a static here, for the same reason
## saves are redirectable: tests and the screenshot harness point it at
## scratch, and the harness sandbox already knows SaveManager.


static func load_layered(file_name: String) -> Dictionary:
	var base := _read_json("res://data/%s" % file_name)
	for mod_name in mod_names():
		var overlay := _read_json("%s/%s/data/%s" % [SaveManager.mods_root, mod_name, file_name])
		if not overlay.is_empty():
			DataMerger.merge_dict(base, overlay, DataMerger.Mode.PATCH)
	return base


## Mod directories in deterministic (alphabetical) order — load order must
## not depend on how the filesystem happens to enumerate.
static func mod_names() -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(SaveManager.mods_root)
	if dir == null:
		return names
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and not name.begins_with("."):
			names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	names.sort()
	return names


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("ContentDB: %s line %d: %s — ignored" % [path, json.get_error_line() + 1, json.get_error_message()])
		return {}
	if json.data is not Dictionary:
		push_warning("ContentDB: %s is not a JSON object — ignored" % path)
		return {}
	return json.data
