extends Node
## Music and SFX playback, and bus volume control.
##
## Buses come from default_bus_layout.tres: Master, Music, SFX. SFX play from
## a round-robin pool (overlapping sounds don't cut each other off, and each
## play gets its own pitch — a shared player bleeds one play's pitch into the
## next). Music crossfades between two players using UNSCALED time and
## PROCESS_MODE_ALWAYS, so a fade keeps running while the tree is paused or
## time-scaled. Volume changes persist through SaveManager, debounced so a
## slider drag writes once, not per-pixel.

const SFX_POOL_SIZE := 8
const SETTINGS_SECTION := "audio"
const BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]

## Semantic UI sounds: event name -> AudioStream. Fill per project (e.g. in
## main.gd: AudioManager.ui_sounds["click"] = preload(...)). A missing event
## is silence, never an error — see "Missing assets degrade" in CLAUDE.md.
var ui_sounds: Dictionary = {}

var _sfx_players: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_active := 0
var _current_music: AudioStream = null
var _fade_time := 0.0
var _fade_duration := 0.0
var _save_timer: SceneTreeTimer = null
## Seconds a volume change waits before it is written. A variable, not a
## constant, so a test can shorten it — sleeping half a second per case to
## watch a debounce is most of what that suite cost.
var save_debounce := 0.5


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		add_child(player)
		_sfx_players.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		_music_players.append(player)
	apply_saved_volumes()


## -- SFX --------------------------------------------------------------------

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_variance: float = 0.0) -> void:
	if stream == null:
		return
	var player := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % SFX_POOL_SIZE
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(0.05, 1.0 + randf_range(-pitch_variance, pitch_variance))
	player.play()


## Semantic UI event -> ui_sounds map -> stream, so sounds are re-skinnable
## without touching call sites.
func ui_event(event_name: String) -> void:
	play_sfx(ui_sounds.get(event_name))


## Wires click + hover sounds to any button in one line.
func bind_button(button: BaseButton, click_event: String = "click") -> void:
	button.pressed.connect(func() -> void: ui_event(click_event))
	button.mouse_entered.connect(func() -> void: ui_event("hover"))


## -- Music ------------------------------------------------------------------

func play_music(stream: AudioStream, fade_duration: float = 1.0) -> void:
	if stream == _current_music:
		return
	_current_music = stream
	var outgoing := _music_players[_music_active]
	_music_active = 1 - _music_active
	var incoming := _music_players[_music_active]
	_fade_duration = maxf(fade_duration, 0.1)
	_fade_time = 0.0
	incoming.stop()
	if stream != null:
		incoming.stream = stream
		incoming.volume_db = linear_to_db(0.0001)
		incoming.play()
	if not outgoing.playing:
		_fade_duration = 0.0
		if incoming.playing:
			incoming.volume_db = 0.0


func stop_music(fade_duration: float = 1.0) -> void:
	play_music(null, fade_duration)


func _process(delta: float) -> void:
	if _fade_duration <= 0.0:
		return
	# Unscaled time: the crossfade keeps moving while the tree is paused or
	# Engine.time_scale is not 1.
	var unscaled := delta / maxf(Engine.time_scale, 0.001)
	_fade_time = minf(_fade_time + unscaled, _fade_duration)
	var t := _fade_time / _fade_duration
	var incoming := _music_players[_music_active]
	var outgoing := _music_players[1 - _music_active]
	if incoming.playing:
		incoming.volume_db = linear_to_db(maxf(t, 0.0001))
	if outgoing.playing:
		outgoing.volume_db = linear_to_db(maxf(1.0 - t, 0.0001))
		if t >= 1.0:
			outgoing.stop()
	if t >= 1.0:
		_fade_duration = 0.0


## -- Volumes ----------------------------------------------------------------

## `linear` is 0.0–1.0 (the way a slider thinks); stored on the bus as dB.
## Applies live and persists debounced.
func set_bus_volume(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_error("AudioManager: no bus named '%s'" % bus_name)
		return
	linear = clampf(linear, 0.0, 1.0)
	# Floor before the dB conversion — linear_to_db(0) is -inf, which must
	# never reach the bus or the settings file. Mute carries the real zero.
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.0)
	_schedule_save()


func get_bus_volume(bus_name: StringName) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 1.0
	if AudioServer.is_bus_mute(index):
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


func apply_saved_volumes() -> void:
	for bus_name in BUSES:
		var saved: Variant = SaveManager.get_setting(SETTINGS_SECTION, bus_name)
		if saved == null:
			continue
		var index := AudioServer.get_bus_index(bus_name)
		if index < 0:
			continue
		var linear := clampf(float(saved), 0.0, 1.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(index, linear <= 0.0)


## Coalesces a slider drag's stream of set_bus_volume calls into one write.
func _schedule_save() -> void:
	if _save_timer != null:
		return
	_save_timer = get_tree().create_timer(save_debounce, true, false, true)
	_save_timer.timeout.connect(_write_volumes)


## Write any pending volume change NOW. The debounce coalesces a drag into
## one write; it must not swallow the change of somebody who quits within
## half a second of moving the slider.
func flush_volumes() -> void:
	if _save_timer == null:
		return
	_save_timer = null
	_write_volumes()


func _write_volumes() -> void:
	_save_timer = null
	for bus_name in BUSES:
		SaveManager.set_setting(SETTINGS_SECTION, bus_name, get_bus_volume(bus_name))
