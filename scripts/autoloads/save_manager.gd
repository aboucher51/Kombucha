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
const DEFAULT_SLOT := "slot_1"

var save_root: String = DEFAULT_SAVE_ROOT
var config_path: String = DEFAULT_CONFIG_PATH
var current_slot: String = DEFAULT_SLOT


## Collect state from game systems here (or have systems register providers).
## Returns whatever should be persisted for the current slot.
func collect_save_data() -> Dictionary:
	return {
		"version": 1,
	}


## Push loaded state back into game systems here.
func apply_save_data(_data: Dictionary) -> void:
	pass


func save_game(slot: String = current_slot) -> Error:
	DirAccess.make_dir_recursive_absolute(save_root)
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(collect_save_data(), "\t"))
	return OK


func load_game(slot: String = current_slot) -> Error:
	var file := FileAccess.open(_slot_path(slot), FileAccess.READ)
	if file == null:
		return FileAccess.get_open_error()
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is not Dictionary:
		return ERR_PARSE_ERROR
	apply_save_data(data)
	return OK


func has_save(slot: String = current_slot) -> bool:
	return FileAccess.file_exists(_slot_path(slot))


func delete_save(slot: String) -> void:
	DirAccess.remove_absolute(_slot_path(slot))


func _slot_path(slot: String) -> String:
	return "%s/%s.json" % [save_root, slot]


## -- Machine settings (volumes, locale, …) ---------------------------------

func set_setting(section: String, key: String, value: Variant) -> void:
	var config := ConfigFile.new()
	config.load(config_path)  # ignore error — a missing file is a fresh start
	config.set_value(section, key, value)
	config.save(config_path)


func get_setting(section: String, key: String, default: Variant = null) -> Variant:
	var config := ConfigFile.new()
	if config.load(config_path) != OK:
		return default
	return config.get_value(section, key, default)
