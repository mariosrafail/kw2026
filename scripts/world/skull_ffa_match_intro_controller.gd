extends RefCounted
class_name SkullFfaMatchIntroController

const PLAYER_FOCUS_OFFSET := Vector2(0.0, -28.0)
const COUNTDOWN_SECONDS := 3.0
const GO_SECONDS := 0.75
const LOCAL_FOCUS_MOVE_SECONDS := 1.0
const COUNTDOWN_FONT := preload("res://assets/fonts/kwfont.ttf")
const COUNTDOWN_BASE_SIZE := Vector2(320.0, 180.0)
const COUNTDOWN_POP_SCALE := 1.32
const COUNTDOWN_WOBBLE_X := 18.0
const COUNTDOWN_FLOAT_Y := 22.0
const COUNTDOWN_BEEP_HZ := 880.0
const GO_BEEP_HZ := 1320.0
const COUNTDOWN_BEEP_SEC := 0.11
const GO_BEEP_SEC := 0.42
const BEEP_MIX_RATE := 44100.0

var _host: Node
var _main_camera: Camera2D
var _players: Dictionary = {}
var _countdown_label: Label
var _countdown_audio_player: AudioStreamPlayer
var _active := false
var _elapsed_sec := 0.0
var _duration_sec := 13.0
var _local_peer_id := 0
var _tour_peer_ids: Array[int] = []
var _last_countdown_cue := ""

func configure(host: Node, main_camera: Camera2D, players: Dictionary) -> void:
	_host = host
	_main_camera = main_camera
	_players = players
	_ensure_countdown_label()
	_ensure_countdown_audio_player()

func is_active() -> bool:
	return _active

func recommended_duration_sec(participant_count: int) -> float:
	var normalized_count := maxi(1, participant_count)
	return float(normalized_count * 2 + 3) + GO_SECONDS

func start(participant_peer_ids: Array, local_peer_id: int, duration_sec: float = 13.0) -> void:
	_ensure_countdown_label()
	_ensure_countdown_audio_player()
	_local_peer_id = local_peer_id
	_elapsed_sec = 0.0
	_active = true
	_tour_peer_ids.clear()
	_last_countdown_cue = ""

	var filtered_ids: Array[int] = []
	for peer_value in participant_peer_ids:
		var peer_id := int(peer_value)
		if peer_id == 0 or filtered_ids.has(peer_id):
			continue
		filtered_ids.append(peer_id)
	if filtered_ids.is_empty() and _local_peer_id != 0:
		filtered_ids.append(_local_peer_id)
	if filtered_ids.is_empty():
		_active = false
		_hide_countdown()
		return

	for peer_id in filtered_ids:
		_tour_peer_ids.append(int(peer_id))
	_duration_sec = maxf(recommended_duration_sec(_tour_peer_ids.size()), duration_sec)

	_hide_countdown()

func stop() -> void:
	_active = false
	_hide_countdown()

func visual_tick(_delta: float) -> void:
	if not _active or _main_camera == null:
		return
	_elapsed_sec += _delta
	if _elapsed_sec >= _duration_sec:
		_active = false
		_hide_countdown()
		return

	_main_camera.global_position = _camera_position_for_elapsed(_elapsed_sec)
	_update_countdown(_elapsed_sec)

func _camera_position_for_elapsed(elapsed_sec: float) -> Vector2:
	var slot_positions: Array[Vector2] = []
	var fallback := _main_camera.global_position if _main_camera != null else Vector2.ZERO
	for peer_id in _tour_peer_ids:
		var focus := _focus_position_for_peer(peer_id, fallback)
		slot_positions.append(focus)
		fallback = focus
	var local_focus := _focus_position_for_peer(_local_peer_id, fallback)

	if slot_positions.is_empty():
		return local_focus
	var segment_start := 0.0
	var current_focus := slot_positions[0]
	if elapsed_sec < 1.0:
		return current_focus
	segment_start = 1.0
	for index in range(1, slot_positions.size()):
		var next_focus := slot_positions[index]
		if elapsed_sec < segment_start + 1.0:
			return current_focus.lerp(next_focus, elapsed_sec - segment_start)
		segment_start += 1.0
		if elapsed_sec < segment_start + 1.0:
			return next_focus
		segment_start += 1.0
		current_focus = next_focus
	if elapsed_sec < segment_start + LOCAL_FOCUS_MOVE_SECONDS:
		return current_focus.lerp(local_focus, (elapsed_sec - segment_start) / LOCAL_FOCUS_MOVE_SECONDS)
	return local_focus

func _focus_position_for_peer(peer_id: int, fallback: Vector2) -> Vector2:
	var player := _players.get(peer_id, null) as NetPlayer
	if player == null:
		return fallback
	return player.global_position + PLAYER_FOCUS_OFFSET

func _update_countdown(elapsed_sec: float) -> void:
	if _countdown_label == null:
		return
	var countdown_total_sec := COUNTDOWN_SECONDS + GO_SECONDS
	var countdown_start_sec := _duration_sec - countdown_total_sec
	if elapsed_sec < countdown_start_sec or elapsed_sec >= _duration_sec:
		_hide_countdown()
		return
	var local_elapsed := elapsed_sec - countdown_start_sec
	_countdown_label.visible = true
	var is_go := local_elapsed >= COUNTDOWN_SECONDS
	var digit_time := 0.0
	var scale_boost := 1.0
	var wobble := 0.0
	var flash := 0.0
	var alpha := 1.0
	var font_color := Color.WHITE
	var outline_color := Color(0.05, 0.03, 0.02, 1.0)
	var pop_t := 0.0

	if is_go:
		_play_countdown_cue("go")
		digit_time = clampf((local_elapsed - COUNTDOWN_SECONDS) / GO_SECONDS, 0.0, 0.999)
		_countdown_label.text = "GO!"
		pop_t = 1.0 - pow(1.0 - digit_time, 2.4)
		scale_boost = lerpf(1.52, 1.0, clampf(digit_time * 1.35, 0.0, 1.0))
		wobble = sin(digit_time * TAU * 2.0) * (1.0 - digit_time) * 0.75
		flash = 1.0 - clampf(digit_time * 1.15, 0.0, 1.0)
		alpha = 1.0 - clampf(maxf(0.0, digit_time - 0.52) / 0.48, 0.0, 1.0)
		font_color = Color(lerpf(1.0, 0.98, digit_time), lerpf(0.92, 0.98, flash), lerpf(0.18, 0.42, flash), alpha)
		outline_color = Color(0.09, 0.04, 0.01, alpha)
	else:
		var digit_index := clampi(int(floor(local_elapsed)), 0, 2)
		_play_countdown_cue(str(3 - digit_index))
		digit_time = clampf(local_elapsed - float(digit_index), 0.0, 0.999)
		_countdown_label.text = str(3 - digit_index)

		pop_t = 1.0 - pow(1.0 - digit_time, 3.0)
		var settle_t := clampf(digit_time * 1.6, 0.0, 1.0)
		scale_boost = lerpf(COUNTDOWN_POP_SCALE, 1.0, settle_t)
		wobble = sin(digit_time * TAU * 1.5) * (1.0 - digit_time)
		flash = 1.0 - clampf(digit_time * 1.4, 0.0, 1.0)
		alpha = 1.0 - clampf(maxf(0.0, digit_time - 0.72) / 0.28, 0.0, 1.0)
		var warm_mix := clampf(0.35 + flash * 0.65, 0.0, 1.0)
		font_color = Color(1.0, lerpf(0.78, 0.96, warm_mix), lerpf(0.18, 0.92, flash), alpha)
		outline_color = Color(0.05, 0.03, 0.02, alpha)

	_countdown_label.scale = Vector2.ONE * scale_boost
	_countdown_label.rotation_degrees = wobble * 5.0
	_countdown_label.offset_top = -COUNTDOWN_BASE_SIZE.y * 0.5 - COUNTDOWN_FLOAT_Y * pop_t
	_countdown_label.offset_bottom = COUNTDOWN_BASE_SIZE.y * 0.5 - COUNTDOWN_FLOAT_Y * pop_t
	_countdown_label.pivot_offset = COUNTDOWN_BASE_SIZE * 0.5 + Vector2(wobble * COUNTDOWN_WOBBLE_X, 0.0)
	_countdown_label.modulate = Color(1.0, 1.0, 1.0, alpha)
	_countdown_label.add_theme_color_override("font_color", font_color)
	_countdown_label.add_theme_color_override("font_outline_color", outline_color)
	_countdown_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, alpha * 0.75))

func _hide_countdown() -> void:
	if _countdown_label == null:
		return
	_countdown_label.visible = false
	_countdown_label.text = ""
	_countdown_label.scale = Vector2.ONE
	_countdown_label.rotation = 0.0
	_countdown_label.offset_top = -COUNTDOWN_BASE_SIZE.y * 0.5
	_countdown_label.offset_bottom = COUNTDOWN_BASE_SIZE.y * 0.5
	_countdown_label.pivot_offset = COUNTDOWN_BASE_SIZE * 0.5
	_countdown_label.modulate = Color.WHITE
	if _countdown_audio_player != null and is_instance_valid(_countdown_audio_player):
		_countdown_audio_player.stop()
	_last_countdown_cue = ""

func _ensure_countdown_label() -> void:
	if _host == null:
		return
	if _countdown_label != null and is_instance_valid(_countdown_label):
		return
	var hud_layer := _host.get_node_or_null("ClientHud") as CanvasLayer
	if hud_layer == null:
		return
	var existing := hud_layer.get_node_or_null("SkullMatchIntroCountdown") as Label
	if existing != null:
		_countdown_label = existing
		return
	var label := Label.new()
	label.name = "SkullMatchIntroCountdown"
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.anchor_right = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -COUNTDOWN_BASE_SIZE.x * 0.5
	label.offset_top = -COUNTDOWN_BASE_SIZE.y * 0.5
	label.offset_right = COUNTDOWN_BASE_SIZE.x * 0.5
	label.offset_bottom = COUNTDOWN_BASE_SIZE.y * 0.5
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_as_relative = false
	label.z_index = 3000
	label.add_theme_font_override("font", COUNTDOWN_FONT)
	label.add_theme_font_size_override("font_size", 118)
	label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.9, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("outline_size", 14)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 8)
	label.pivot_offset = COUNTDOWN_BASE_SIZE * 0.5
	hud_layer.add_child(label)
	_countdown_label = label

func _ensure_countdown_audio_player() -> void:
	if _host == null:
		return
	if _countdown_audio_player != null and is_instance_valid(_countdown_audio_player):
		return
	var existing := _host.get_node_or_null("SkullMatchIntroCountdownAudio") as AudioStreamPlayer
	if existing != null:
		_countdown_audio_player = existing
		return
	var player := AudioStreamPlayer.new()
	player.name = "SkullMatchIntroCountdownAudio"
	player.bus = "Master"
	player.volume_db = -10.0
	_host.add_child(player)
	_countdown_audio_player = player

func _play_countdown_cue(cue: String) -> void:
	if cue == _last_countdown_cue:
		return
	_last_countdown_cue = cue
	_ensure_countdown_audio_player()
	if _countdown_audio_player == null:
		return
	var duration_sec := GO_BEEP_SEC if cue == "go" else COUNTDOWN_BEEP_SEC
	var frequency_hz := GO_BEEP_HZ if cue == "go" else COUNTDOWN_BEEP_HZ
	_countdown_audio_player.stream = _build_beep_stream(frequency_hz, duration_sec)
	_countdown_audio_player.play()

func _build_beep_stream(frequency_hz: float, duration_sec: float) -> AudioStreamWAV:
	var sample_count := maxi(1, int(BEEP_MIX_RATE * duration_sec))
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in range(sample_count):
		var t := float(i) / BEEP_MIX_RATE
		var attack := clampf(t / 0.012, 0.0, 1.0)
		var release := clampf((duration_sec - t) / 0.045, 0.0, 1.0)
		var env := minf(attack, release)
		var overtone := sin(TAU * frequency_hz * 2.0 * t) * 0.16
		var sample := (sin(TAU * frequency_hz * t) + overtone) * env * 0.55
		var pcm := int(clampi(roundi(sample * 32767.0), -32768, 32767))
		data[i * 2] = pcm & 0xFF
		data[i * 2 + 1] = (pcm >> 8) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(BEEP_MIX_RATE)
	wav.stereo = false
	wav.data = data
	return wav
