extends GutTest
## Volume API + debounced persistence. Redirects SaveManager.config_path so
## the debounce write cannot touch the player's real settings.

const SCRATCH_CONFIG := "user://test_audio_settings.cfg"


func before_each() -> void:
	SaveManager.config_path = SCRATCH_CONFIG


func after_each() -> void:
	# Restore the bus and let the pending debounce land on the SCRATCH path
	# before pointing config_path back at the real file — restoring first
	# would hand the timer the player's actual settings.cfg to write.
	AudioManager.set_bus_volume(&"Music", 1.0)
	await wait_seconds(0.7)
	DirAccess.remove_absolute(SCRATCH_CONFIG)
	SaveManager.config_path = SaveManager.DEFAULT_CONFIG_PATH


func test_volume_round_trip() -> void:
	AudioManager.set_bus_volume(&"Music", 0.5)
	assert_almost_eq(AudioManager.get_bus_volume(&"Music"), 0.5, 0.01)


func test_zero_is_mute_not_negative_infinity() -> void:
	AudioManager.set_bus_volume(&"Music", 0.0)
	assert_eq(AudioManager.get_bus_volume(&"Music"), 0.0)
	var index := AudioServer.get_bus_index(&"Music")
	assert_true(AudioServer.is_bus_mute(index))
	assert_gt(AudioServer.get_bus_volume_db(index), -100.0,
		"-inf must never reach the bus")


func test_save_is_debounced_then_written() -> void:
	AudioManager.set_bus_volume(&"Music", 0.25)
	assert_eq(SaveManager.get_setting("audio", "Music"), null,
		"not written immediately")
	await wait_seconds(0.7)
	assert_almost_eq(float(SaveManager.get_setting("audio", "Music", -1.0)), 0.25, 0.01)


func test_ui_event_with_no_sound_is_silence() -> void:
	# No error, no crash — a missing UI sound is a normal state.
	AudioManager.ui_event("nonexistent_event")
	pass_test("silence, not an error")
