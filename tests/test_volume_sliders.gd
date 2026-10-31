extends GutTest
## Proves each volume slider has a plain English label, even when the
## translation has no row for its bus.


func test_every_bus_has_a_plain_fallback_label() -> void:
	for bus_name in AudioManager.BUSES:
		assert_true(VolumeSliders.FALLBACK_LABELS.has(bus_name),
			"bus '%s' has no fallback label in VolumeSliders" % bus_name)
	assert_eq(VolumeSliders.FALLBACK_LABELS[&"SFX"], "Sound effects",
		"the SFX bus falls back to plain words, not the bus name")


func test_the_english_rows_match_the_fallbacks() -> void:
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	for bus_name in AudioManager.BUSES:
		var shown := L10n.tr_or_fallback("ui.bus_%s" % String(bus_name).to_lower(), "")
		assert_eq(shown, VolumeSliders.FALLBACK_LABELS[bus_name],
			"the en row and the code fallback for '%s' say the same thing" % bus_name)
	TranslationServer.set_locale(previous)


func test_every_slider_starts_at_the_same_x() -> void:
	var box := VolumeSliders.make()
	add_child_autofree(box)
	await get_tree().process_frame
	var xs: Array[float] = []
	for bus_name in AudioManager.BUSES:
		var slider := box.find_child("%sSlider" % bus_name, true, false) as HSlider
		assert_not_null(slider, "the %s slider is built" % bus_name)
		if slider != null:
			xs.append(slider.global_position.x)
	for x in xs:
		assert_eq(x, xs[0], "a longer label does not push one slider right")
