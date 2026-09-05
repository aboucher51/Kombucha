extends GutTest
## The localization contract: every `ui.*` key a script asks for has a row
## in localization/game.csv, so a new string is a key plus a row in the same
## commit and never a bare literal. TranslationServer.translate() returns
## the key unchanged when untranslated, which is how a missing row shows.

var _key_pattern := RegEx.create_from_string(
	"tr_or_fallback\\(\\s*\"(ui\\.[a-z0-9_]+)\"")


func _scan_dir(path: String, found: Dictionary) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan_dir("%s/%s" % [path, sub], found)
	for file in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		for m in _key_pattern.search_all(FileAccess.get_file_as_string("%s/%s" % [path, file])):
			found[m.get_string(1)] = "%s/%s" % [path, file]


func _script_keys() -> Dictionary:
	var found := {}
	_scan_dir("res://scripts", found)
	return found


func test_every_ui_key_in_scripts_has_a_translation() -> void:
	var missing: Array[String] = []
	for key: String in _script_keys():
		if TranslationServer.translate(key) == key:
			missing.append("%s (%s)" % [key, _script_keys()[key]])
	assert_eq(missing, [], "ui keys without a row in localization/game.csv")


func test_the_scan_actually_finds_keys() -> void:
	# A stale regex would make the test above vacuously green. The fixture
	# has four keys; a game has dozens. The floor is the fixture's count.
	assert_gte(_script_keys().size(), 4, "the scanner found fewer keys than the fixture has")


func test_the_pseudo_locale_is_loaded() -> void:
	# tools/make_pseudo_locale.py fills the "xa" column; a scenario switches
	# to it so a hardcoded string shows in a screenshot as plain English.
	assert_has(TranslationServer.get_loaded_locales(), "xa")
	TranslationServer.set_locale("xa")
	assert_true(TranslationServer.translate("ui.resume").begins_with("["))
	TranslationServer.set_locale("en")
