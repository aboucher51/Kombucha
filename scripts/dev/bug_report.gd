class_name BugReport
extends RefCounted
## Bundles everything a bug report needs into one zip the player can attach:
## report.txt (context + note), the current save, the settings file, and the
## tail of the engine log.
##
## Degrade, never error: a report about a broken game must not itself refuse
## to build because the game is broken. Every missing piece becomes a line
## in report.txt instead of a failure.

const REPORT_DIR := "user://reports"
const LOG_PATH := "user://logs/godot.log"
const LOG_TAIL_BYTES := 64 * 1024


## Writes user://reports/report_<stamp>.zip and returns its path ("" only
## if even the zip itself cannot be created).
static func write(note: String = "") -> String:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var path := "%s/report_%s.zip" % [REPORT_DIR, stamp]
	var zip := ZIPPacker.new()
	if zip.open(path) != OK:
		return ""

	var lines: Array[String] = []
	lines.append("Report %s" % stamp)
	if not note.is_empty():
		lines.append("Note: %s" % note)
	lines.append("Godot %s" % Engine.get_version_info().get("string", "?"))
	lines.append("OS: %s" % OS.get_name())
	lines.append("Project: %s" % ProjectSettings.get_setting("application/config/name", "?"))

	var save_path := "%s/%s.json" % [SaveManager.save_root, SaveManager.current_slot]
	_pack_or_note(zip, "save.json", save_path, lines)
	_pack_or_note(zip, "settings.cfg", SaveManager.config_path, lines)
	_pack_tail_or_note(zip, "godot.log", LOG_PATH, lines)

	zip.start_file("report.txt")
	zip.write_file(("\n".join(lines) + "\n").to_utf8_buffer())
	zip.close_file()
	zip.close()
	return path


static func _pack_or_note(zip: ZIPPacker, name: String, source: String, lines: Array[String]) -> void:
	if not FileAccess.file_exists(source):
		lines.append("(no %s — %s does not exist)" % [name, source])
		return
	zip.start_file(name)
	zip.write_file(FileAccess.get_file_as_bytes(source))
	zip.close_file()


static func _pack_tail_or_note(zip: ZIPPacker, name: String, source: String, lines: Array[String]) -> void:
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		lines.append("(no %s — %s does not exist)" % [name, source])
		return
	if file.get_length() > LOG_TAIL_BYTES:
		file.seek(file.get_length() - LOG_TAIL_BYTES)
	zip.start_file(name)
	zip.write_file(file.get_buffer(LOG_TAIL_BYTES))
	zip.close_file()
