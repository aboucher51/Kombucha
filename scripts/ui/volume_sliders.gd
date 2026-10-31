class_name VolumeSliders
extends RefCounted
## Master/Music/SFX slider rows wired to AudioManager — built by whoever
## needs them (pause menu, settings screen) so both stay in sync for free.
## Sliders get stable names (MasterSlider, MusicSlider, SFXSlider) so the
## screenshot harness and tests can find them.

## The English label for each bus when the translation has no row. A bus not
## listed here shows its own name.
const FALLBACK_LABELS := {
	&"Master": "All sound",
	&"Music": "Music",
	&"SFX": "Sound effects",
}


static func make() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "VolumeSliders"
	# A two-column grid makes the label column as wide as the longest label,
	# so every slider starts at the same x in every language.
	var grid := GridContainer.new()
	grid.name = "VolumeGrid"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for bus_name in AudioManager.BUSES:
		var label := Label.new()
		label.text = L10n.tr_or_fallback("ui.bus_%s" % String(bus_name).to_lower(),
				str(FALLBACK_LABELS.get(bus_name, String(bus_name))))
		label.custom_minimum_size = Vector2(70, 0)
		grid.add_child(label)
		var slider := HSlider.new()
		slider.name = "%sSlider" % bus_name
		slider.min_value = 0
		slider.max_value = 100
		slider.value = AudioManager.get_bus_volume(bus_name) * 100.0
		slider.custom_minimum_size = Vector2(180, 20)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var captured: StringName = bus_name
		slider.value_changed.connect(func(value: float) -> void:
			AudioManager.set_bus_volume(captured, value / 100.0))
		grid.add_child(slider)
	return box
