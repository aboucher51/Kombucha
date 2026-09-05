extends GutTest
## Mod layering over base data through SaveManager's redirectable mods_root.

const SCRATCH_MODS := "user://test_mods"


func before_each() -> void:
	SaveManager.mods_root = SCRATCH_MODS
	_write("%s/b_second/data/things.json" % SCRATCH_MODS, '{"sword": {"damage": 9}, "shield": {"block": 1}}')
	_write("%s/a_first/data/things.json" % SCRATCH_MODS, '{"sword": {"damage": 5, "rare": true}}')


func after_each() -> void:
	for mod in ["a_first", "b_second"]:
		DirAccess.remove_absolute("%s/%s/data/things.json" % [SCRATCH_MODS, mod])
		DirAccess.remove_absolute("%s/%s/data" % [SCRATCH_MODS, mod])
		DirAccess.remove_absolute("%s/%s" % [SCRATCH_MODS, mod])
	DirAccess.remove_absolute(SCRATCH_MODS)
	SaveManager.mods_root = SaveManager.DEFAULT_MODS_ROOT


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_mods_layer_in_sorted_order_over_a_missing_base() -> void:
	var things := ContentDB.load_layered("things.json")
	assert_eq(ContentDB.mod_names(), ["a_first", "b_second"])
	assert_eq(things["sword"]["damage"], 9.0, "the later mod wins the field")
	assert_eq(things["sword"]["rare"], true, "the earlier mod's other field survives the patch")
	assert_true(things.has("shield"))


func test_no_mods_root_is_a_normal_empty_answer() -> void:
	SaveManager.mods_root = "user://definitely_absent"
	assert_eq(ContentDB.mod_names(), [])
	assert_eq(ContentDB.load_layered("things.json"), {})
