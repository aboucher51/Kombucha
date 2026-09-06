extends GutTest
## Volume API + debounced persistence. Redirects SaveManager.config_path so
## the debounce write cannot touch the player's real settings.

const SCRATCH_CONFIG := "user://test_audio_settings.cfg"


func before_each() -> void:
	SaveManager.config_path = SCRATCH_CONFIG
	AudioManager.save_debounce = 0.05   # the behaviour, without the wait


func after_each() -> void:
	# Restore the bus and land the pending write on the SCRATCH path before
	# pointing config_path back at the real file — restoring first would
	# hand the timer the player's actual settings.cfg to write. Flushed
	# rather than slept through: the wait was 0.7s per case, four cases.
	AudioManager.set_bus_volume(&"Music", 1.0)
	AudioManager.flush_volumes()
	DirAccess.remove_absolute(SCRATCH_CONFIG)
	SaveManager.config_path = SaveManager.DEFAULT_CONFIG_PATH
	AudioManager.save_debounce = 0.5


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
	await wait_seconds(AudioManager.save_debounce * 3.0)
	assert_almost_eq(float(SaveManager.get_setting("audio", "Music", -1.0)), 0.25, 0.01,
		"the timer lands it")


func test_a_quit_inside_the_debounce_still_writes() -> void:
	AudioManager.set_bus_volume(&"Music", 0.4)
	assert_eq(SaveManager.get_setting("audio", "Music"), null, "still waiting")
	AudioManager.flush_volumes()
	assert_almost_eq(float(SaveManager.get_setting("audio", "Music", -1.0)), 0.4, 0.01,
		"quitting a moment after moving the slider must not lose the move")
	AudioManager.flush_volumes()   # nothing pending: a no-op, never an error


func test_ui_event_with_no_sound_is_silence() -> void:
	# No error, no crash — a missing UI sound is a normal state.
	AudioManager.ui_event("nonexistent_event")
	pass_test("silence, not an error")


func test_a_sound_family_never_repeats_itself_and_a_bare_stream_still_plays() -> void:
	var a := AudioStreamWAV.new()
	var b := AudioStreamWAV.new()
	var c := AudioStreamWAV.new()
	AudioManager.ui_sounds["probe_family"] = [a, b, c]
	AudioManager.ui_sounds["probe_single"] = a
	AudioManager.ui_sounds["probe_empty"] = []
	var previous: AudioStream = null
	for i in 40:
		var chosen := AudioManager.pick("probe_family")
		assert_true(chosen in [a, b, c])
		assert_ne(chosen, previous, "never the same variant twice in a row")
		previous = chosen
	assert_eq(AudioManager.pick("probe_single"), a, "a single stream is accepted as is")
	assert_null(AudioManager.pick("probe_empty"), "an empty family is silence")
	assert_null(AudioManager.pick("none"), "and so is a kind nobody registered")
	AudioManager.ui_sounds.erase("probe_family")
	AudioManager.ui_sounds.erase("probe_single")
	AudioManager.ui_sounds.erase("probe_empty")


func test_a_bus_missing_from_the_settings_file_is_left_alone() -> void:
	# The file exists (Music was written) but SFX was never stored — the
	# shape of a bus added after the player's settings file existed. The
	# read must not log an engine error and must not touch the SFX bus.
	DirAccess.remove_absolute(SCRATCH_CONFIG)
	SaveManager.set_setting(AudioManager.SETTINGS_SECTION, "Music", 0.5)
	AudioManager.set_bus_volume(&"SFX", 0.25)   # live only: the debounce has not fired
	AudioManager.set_bus_volume(&"Music", 1.0)
	AudioManager.apply_saved_volumes()
	assert_almost_eq(AudioManager.get_bus_volume(&"Music"), 0.5, 0.01, "the stored bus is re-applied")
	assert_almost_eq(AudioManager.get_bus_volume(&"SFX"), 0.25, 0.01, "the missing bus keeps its live value")
	AudioManager.set_bus_volume(&"SFX", 1.0)
