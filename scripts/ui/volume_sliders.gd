class_name VolumeSliders
extends RefCounted
## Master/Music/SFX slider rows wired to AudioManager — built by whoever
## needs them (pause menu, settings screen) so both stay in sync for free.
## Sliders get stable names (MasterSlider, MusicSlider, SFXSlider) so the
## screenshot harness and tests can find them.


static func make() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "VolumeSliders"
	box.add_theme_constant_override("separation", 8)
	for bus_name in AudioManager.BUSES:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var label := Label.new()
		label.text = String(bus_name)
		label.custom_minimum_size = Vector2(70, 0)
		line.add_child(label)
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
		line.add_child(slider)
		box.add_child(line)
	return box
