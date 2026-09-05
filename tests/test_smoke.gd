extends GutTest
## Proves the autoload set is wired up and the main scene parses. If this
## fails, fix it before anything else — every other test runs in the same
## process and depends on the same boot.


func test_autoloads_exist() -> void:
	for autoload_name in ["EventBus", "GameManager", "AudioManager", "SaveManager"]:
		assert_not_null(get_node_or_null("/root/%s" % autoload_name),
			"autoload '%s' missing — check project.godot" % autoload_name)


func test_main_scene_instantiates() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	assert_not_null(scene, "main.tscn failed to load")
	var instance := scene.instantiate()
	assert_not_null(instance, "main.tscn failed to instantiate")
	if instance != null:
		instance.free()


func test_audio_buses_exist() -> void:
	for bus_name in ["Master", "Music", "SFX"]:
		assert_gte(AudioServer.get_bus_index(bus_name), 0,
			"audio bus '%s' missing — check default_bus_layout.tres" % bus_name)
