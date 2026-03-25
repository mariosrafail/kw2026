extends RefCounted

const TYPEWRITER_SFX := preload("res://assets/sounds/sfx/menu_placeholders/keyboard_sound.mp3")
const EXPLOSION_SFX := preload("res://assets/sounds/sfx/menu_placeholders/explosion.mp3")
const EXPLOSION_LAYER_SFX := preload("res://assets/sounds/sfx/guns/grenade/launcher_boom.wav")
const MENU_PALETTE := preload("res://scripts/ui/main_menu/menu_palette.gd")
const MENU_SOUNDTRACK_PATH := "res://assets/sounds/soundtrack/menu_soundtrack.MP3"
const MENU_SOUNDTRACK_MP3_FALLBACK := preload("res://assets/sounds/soundtrack/menu_soundtrack.MP3")
const LOBBY_SOUNDTRACK_FALLBACK := preload("res://assets/sounds/soundtrack/lobby_soundratck.MP3")
const LOBBY_SOUNDTRACK_CANDIDATES := [
	"res://assets/sounds/soundtrack/lobby_soundratck.MP3",
	"res://assets/sounds/soundtrack/lobby_soundratck.mp3",
	"res://assets/sounds/soundtrack/lobby_soundtrack.MP3",
	"res://assets/sounds/soundtrack/lobby_soundtrack.mp3",
]
const INTRO_REVEAL_SHADER := preload("res://assets/shaders/intro_radial_reveal.gdshader")
const INTRO_TEXT_PHASE1 := "KEYBOARD WARRIORS"
const INTRO_TEXT_PHASE2 := " B*TCH"
var INTRO_OVERLAY_TINT := MENU_PALETTE.base(1.0)
const TYPEWRITER_BASE_DB := -13.0
const EXPLOSION_BASE_DB := -3.5
const EXPLOSION_LAYER_BASE_DB := -17.0
const MENU_MUSIC_START_DB := -18.0
const MENU_MUSIC_TARGET_DB := -9.5

var enable_intro_animation := true
var intro_timeout_sec := 6.0
var intro_fx_enabled := true

var _host: Node
var _intro: Control
var _intro_fade: ColorRect
var _intro_plate: CanvasItem
var _intro_label: Label
var _pixel_burst_at: Callable

var _intro_nonce := 0
var _intro_tween: Tween = null
var _typewriter_player: AudioStreamPlayer = null
var _explosion_player: AudioStreamPlayer = null
var _explosion_layer_player: AudioStreamPlayer = null
var _intro_reveal_material: ShaderMaterial = null
var _menu_music_player: AudioStreamPlayer = null
var _menu_music_fade_tween: Tween = null
var _lobby_music_player: AudioStreamPlayer = null
var _music_crossfade_tween: Tween = null
var _lobby_music_active := false
var _menu_music_volume_linear := 1.0
var _menu_sfx_volume_linear := 1.0
var _hidden_cursor_tex: Texture2D = null
var _cursor_hide_enforce_seq := 0
var _typewriter_last_visible_chars := 0
var _typewriter_last_tick_msec := 0

func configure(host: Node, intro: Control, intro_fade: ColorRect, intro_plate: CanvasItem, intro_label: Label, pixel_burst_at: Callable) -> void:
	_host = host
	_intro = intro
	_intro_fade = intro_fade
	_intro_plate = intro_plate
	_intro_label = intro_label
	_pixel_burst_at = pixel_burst_at
	_ensure_typewriter_player()
	_ensure_explosion_player()
	_ensure_explosion_layer_player()
	_ensure_intro_reveal_material()
	_ensure_menu_music_player()
	_ensure_lobby_music_player()

func play_intro_animation_safe() -> void:
	if not enable_intro_animation:
		return
	if _host == null:
		return
	if intro_timeout_sec > 0.0:
		_intro_nonce += 1
		var nonce := _intro_nonce
		var timer := _host.get_tree().create_timer(intro_timeout_sec)
		timer.timeout.connect(func() -> void:
			if nonce != _intro_nonce:
				return
			if not enable_intro_animation:
				return
			var still_visible := _intro != null and _intro.visible
			var still_running := _intro_tween != null and _intro_tween.is_running()
			if still_visible or still_running:
				push_error("Intro animation watchdog timeout (%.2fs). Aborting intro." % float(intro_timeout_sec))
				abort_intro_animation()
		)
	_play_intro_animation()

func abort_intro_animation() -> void:
	_intro_nonce += 1
	enable_intro_animation = false
	if _intro_tween != null:
		_intro_tween.kill()
		_intro_tween = null
	if _intro != null:
		_intro.top_level = false
		_intro.visible = false
		_intro.modulate = Color(1, 1, 1, 0)
	_restore_menu_cursor_after_intro()
	_notify_host_intro_visibility_changed()

func _play_intro_animation() -> void:
	if _intro == null or _intro_fade == null or _intro_plate == null or _intro_label == null:
		return
	if _intro_tween != null and _intro_tween.is_running():
		return

	_intro.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_intro_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro.top_level = true
	_intro.z_index = 4095
	_hide_menu_cursor_for_intro()
	_intro.visible = true
	_intro.modulate = Color(1, 1, 1, 1)
	_notify_host_intro_visibility_changed()
	_intro_fade.color = INTRO_OVERLAY_TINT
	_set_intro_reveal_radius(0.0)

	var base_label_pos := _intro_label.position
	var base_plate_pos := Vector2.ZERO
	if _intro_plate is Control:
		var plate_ctrl := _intro_plate as Control
		base_plate_pos = plate_ctrl.position
		if plate_ctrl.size.y > 0.0:
			plate_ctrl.pivot_offset = plate_ctrl.size * 0.5
	elif _intro_plate is Node2D:
		base_plate_pos = (_intro_plate as Node2D).position
	var plate_line_scale_y := 0.02
	if _intro_plate is Control:
		var h := maxf(1.0, (_intro_plate as Control).size.y)
		plate_line_scale_y = maxf(1.0 / h, 0.01)
	_intro_plate.modulate = Color(1, 1, 1, 0)
	_intro_plate.scale = Vector2(1.0, plate_line_scale_y)
	_intro_plate.rotation = -0.05

	_intro_label.visible_characters = 0
	_typewriter_last_visible_chars = 0
	_typewriter_last_tick_msec = 0
	_intro_label.text = INTRO_TEXT_PHASE1
	_intro_label.modulate = Color(1, 1, 1, 0)
	_intro_label.scale = Vector2(1.28, 1.28)
	_intro_label.position = base_label_pos + Vector2(0, -16)

	var t := _host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_intro_tween = t
	t.parallel().tween_property(_intro_fade, "color:a", 1.0, 0.26)
	t.parallel().tween_property(_intro_plate, "modulate:a", 1.0, 0.20)
	t.parallel().tween_property(_intro_plate, "scale", Vector2(1.04, 1.04), 0.58).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_intro_plate, "rotation", 0.0, 0.34)
	t.parallel().tween_property(_intro_label, "modulate:a", 1.0, 0.24)
	t.parallel().tween_property(_intro_label, "scale", Vector2.ONE, 0.52).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_intro_label, "position", base_label_pos, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	t.tween_property(_intro_plate, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(_intro_label, "scale", Vector2(1.01, 1.01), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var phase1_len := INTRO_TEXT_PHASE1.length()
	var full_text := "%s%s" % [INTRO_TEXT_PHASE1, INTRO_TEXT_PHASE2]
	var full_len := full_text.length()
	t.tween_method(Callable(self, "_set_intro_chars"), 0.0, float(phase1_len), 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_interval(1.0)
	t.tween_callback(func() -> void:
		_intro_label.text = full_text
		_intro_label.visible_characters = phase1_len
		_typewriter_last_visible_chars = phase1_len
	)
	t.tween_method(Callable(self, "_set_intro_chars"), float(phase1_len), float(full_len), 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_interval(0.35)
	t.tween_callback(func() -> void:
		_play_intro_explosion()
	)
	# Replace old blue/pop phase with a "box break" right after the explosion.
	var break_pos := base_plate_pos + Vector2(randf_range(-160.0, 160.0), randf_range(-60.0, 60.0))
	var break_rot := randf_range(-0.5, 0.5)
	t.parallel().tween_property(_intro_plate, "position", break_pos, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_intro_plate, "rotation", break_rot, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_intro_plate, "scale", Vector2(0.72, 0.72), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_intro_label, "position", base_label_pos + Vector2(randf_range(-90.0, 90.0), -34.0), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_intro_label, "rotation", randf_range(-0.14, 0.14), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_intro_label, "modulate:a", 0.0, 0.30)
	t.parallel().tween_property(_intro_plate, "modulate:a", 0.0, 0.30)
	t.parallel().tween_method(Callable(self, "_set_intro_reveal_radius"), 0.0, 1.25, 0.92).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func() -> void:
		_start_menu_soundtrack_fade_in()
		_intro.top_level = false
		_intro.visible = false
		_intro_label.position = base_label_pos
		_intro_label.scale = Vector2.ONE
		_intro_label.rotation = 0.0
		_intro_label.modulate = Color(1, 1, 1, 1)
		if _intro_plate is Control:
			(_intro_plate as Control).position = base_plate_pos
		elif _intro_plate is Node2D:
			(_intro_plate as Node2D).position = base_plate_pos
		_intro_plate.scale = Vector2.ONE
		_intro_plate.rotation = 0.0
		_intro_plate.modulate = Color(1, 1, 1, 1)
		_set_intro_reveal_radius(0.0)
		_restore_menu_cursor_after_intro()
		_notify_host_intro_visibility_changed()
	)

func _notify_host_intro_visibility_changed() -> void:
	if _host != null and _host.has_method("_refresh_global_overlay_ui_state"):
		_host.call("_refresh_global_overlay_ui_state")

func _set_intro_chars(v: float) -> void:
	if _intro_label == null:
		return
	var next_chars := int(v)
	if next_chars > _typewriter_last_visible_chars:
		var delta := next_chars - _typewriter_last_visible_chars
		for _i in range(delta):
			_play_typewriter_tick()
	_typewriter_last_visible_chars = next_chars
	_intro_label.visible_characters = next_chars

func _ensure_typewriter_player() -> void:
	if _host == null:
		return
	if _typewriter_player != null and is_instance_valid(_typewriter_player):
		return
	var p := _host.get_node_or_null("IntroTypewriterSfx") as AudioStreamPlayer
	if p == null:
		p = AudioStreamPlayer.new()
		p.name = "IntroTypewriterSfx"
		_host.add_child(p)
	p.stream = TYPEWRITER_SFX
	p.bus = "SFX"
	p.volume_db = _scaled_sfx_db(TYPEWRITER_BASE_DB)
	_typewriter_player = p

func _ensure_explosion_player() -> void:
	if _host == null:
		return
	if _explosion_player != null and is_instance_valid(_explosion_player):
		return
	var p := _host.get_node_or_null("IntroExplosionSfx") as AudioStreamPlayer
	if p == null:
		p = AudioStreamPlayer.new()
		p.name = "IntroExplosionSfx"
		_host.add_child(p)
	p.stream = EXPLOSION_SFX
	p.bus = "SFX"
	p.volume_db = _scaled_sfx_db(EXPLOSION_BASE_DB)
	_explosion_player = p

func _ensure_explosion_layer_player() -> void:
	if _host == null:
		return
	if _explosion_layer_player != null and is_instance_valid(_explosion_layer_player):
		return
	var p := _host.get_node_or_null("IntroExplosionLayerSfx") as AudioStreamPlayer
	if p == null:
		p = AudioStreamPlayer.new()
		p.name = "IntroExplosionLayerSfx"
		_host.add_child(p)
	p.stream = EXPLOSION_LAYER_SFX
	p.bus = "SFX"
	p.volume_db = _scaled_sfx_db(EXPLOSION_LAYER_BASE_DB)
	_explosion_layer_player = p

func _ensure_menu_music_player() -> void:
	if _host == null:
		return
	if _menu_music_player != null and is_instance_valid(_menu_music_player):
		return
	var p := _host.get_node_or_null("MenuSoundtrackPlayer") as AudioStreamPlayer
	if p == null:
		p = AudioStreamPlayer.new()
		p.name = "MenuSoundtrackPlayer"
		_host.add_child(p)
	if p.stream == null:
		p.stream = _load_menu_soundtrack_stream()
	p.bus = "Master"
	p.max_polyphony = 1
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.stream_paused = false
	p.autoplay = false
	if p.stream is AudioStreamWAV:
		(p.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif p.stream is AudioStreamMP3:
		(p.stream as AudioStreamMP3).loop = true
	if not p.finished.is_connected(_on_menu_music_finished):
		p.finished.connect(_on_menu_music_finished)
	p.volume_db = -18.0
	_menu_music_player = p

func _ensure_lobby_music_player() -> void:
	if _host == null:
		return
	if _lobby_music_player != null and is_instance_valid(_lobby_music_player):
		return
	var p := _host.get_node_or_null("LobbySoundtrackPlayer") as AudioStreamPlayer
	if p == null:
		p = AudioStreamPlayer.new()
		p.name = "LobbySoundtrackPlayer"
		_host.add_child(p)
	if p.stream == null:
		p.stream = _load_lobby_soundtrack_stream()
	p.bus = "Master"
	p.max_polyphony = 1
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	p.stream_paused = false
	p.autoplay = false
	if p.stream is AudioStreamWAV:
		(p.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif p.stream is AudioStreamMP3:
		(p.stream as AudioStreamMP3).loop = true
	p.volume_db = -80.0
	_lobby_music_player = p

func _start_menu_soundtrack_fade_in() -> void:
	if _menu_music_player == null or not is_instance_valid(_menu_music_player):
		_ensure_menu_music_player()
	if _menu_music_player == null:
		return
	if _menu_music_player.stream == null:
		_menu_music_player.stream = _load_menu_soundtrack_stream()
	if _menu_music_player.stream is AudioStreamWAV:
		(_menu_music_player.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif _menu_music_player.stream is AudioStreamMP3:
		(_menu_music_player.stream as AudioStreamMP3).loop = true
	_menu_music_player.stream_paused = false
	if _menu_music_fade_tween != null:
		_menu_music_fade_tween.kill()
	_menu_music_player.volume_db = _scaled_menu_music_db(MENU_MUSIC_START_DB)
	_menu_music_player.stop()
	_menu_music_player.play(0.0)
	var watchdog_seq := _intro_nonce
	var tree := _host.get_tree()
	if tree != null:
		var retry_timer := tree.create_timer(0.2)
		retry_timer.timeout.connect(func() -> void:
			if _menu_music_player == null or not is_instance_valid(_menu_music_player):
				return
			if watchdog_seq != _intro_nonce:
				return
			if not _menu_music_player.playing:
				_menu_music_player.play(0.0)
		)
	_menu_music_fade_tween = _host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_menu_music_fade_tween.tween_property(_menu_music_player, "volume_db", _scaled_menu_music_db(MENU_MUSIC_TARGET_DB), 1.8)

func _load_menu_soundtrack_stream() -> AudioStream:
	var imported := load(MENU_SOUNDTRACK_PATH) as AudioStream
	if imported != null:
		return imported
	if FileAccess.file_exists(MENU_SOUNDTRACK_PATH):
		var data := FileAccess.get_file_as_bytes(MENU_SOUNDTRACK_PATH)
		if data.size() > 0:
			var mp3 := AudioStreamMP3.new()
			mp3.data = data
			mp3.loop = true
			return mp3
	return MENU_SOUNDTRACK_MP3_FALLBACK

func _load_lobby_soundtrack_stream() -> AudioStream:
	for path in LOBBY_SOUNDTRACK_CANDIDATES:
		var imported := load(path) as AudioStream
		if imported != null:
			return imported
		if FileAccess.file_exists(path):
			var data := FileAccess.get_file_as_bytes(path)
			if data.size() > 0:
				var mp3 := AudioStreamMP3.new()
				mp3.data = data
				mp3.loop = true
				return mp3
	var fallback := LOBBY_SOUNDTRACK_FALLBACK.duplicate(true) as AudioStream
	if fallback is AudioStreamMP3:
		(fallback as AudioStreamMP3).loop = true
	elif fallback is AudioStreamWAV:
		(fallback as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return fallback

func _on_menu_music_finished() -> void:
	if _menu_music_player == null or not is_instance_valid(_menu_music_player):
		return
	_menu_music_player.stream_paused = false
	_menu_music_player.play(0.0)

func set_menu_music_volume_linear(value: float) -> void:
	_menu_music_volume_linear = clampf(value, 0.0, 1.0)
	_apply_menu_music_volume_from_slider()

func set_lobby_music_active(active: bool, smooth_sec: float = 0.55) -> void:
	_lobby_music_active = active
	if _menu_music_player == null or not is_instance_valid(_menu_music_player):
		_ensure_menu_music_player()
	if _lobby_music_player == null or not is_instance_valid(_lobby_music_player):
		_ensure_lobby_music_player()
	if _menu_music_player == null:
		return
	if _lobby_music_player == null:
		if not active:
			if not _menu_music_player.playing:
				_menu_music_player.play(0.0)
			_menu_music_player.stream_paused = false
			_menu_music_player.volume_db = _scaled_menu_music_db(MENU_MUSIC_TARGET_DB)
		return

	var target_db := _scaled_menu_music_db(MENU_MUSIC_TARGET_DB)
	var fade_sec := maxf(0.08, smooth_sec)
	if _music_crossfade_tween != null and _music_crossfade_tween.is_running():
		_music_crossfade_tween.kill()

	if active:
		if _lobby_music_player.stream == null:
			_lobby_music_player.stream = _load_lobby_soundtrack_stream()
		if _lobby_music_player.stream is AudioStreamWAV:
			(_lobby_music_player.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		elif _lobby_music_player.stream is AudioStreamMP3:
			(_lobby_music_player.stream as AudioStreamMP3).loop = true
		if _lobby_music_player.stream != null and not _lobby_music_player.playing:
			_lobby_music_player.volume_db = -80.0
			_lobby_music_player.play(0.0)
		_lobby_music_player.stream_paused = false
		_music_crossfade_tween = _host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_music_crossfade_tween.parallel().tween_property(_menu_music_player, "volume_db", -80.0, fade_sec)
		_music_crossfade_tween.parallel().tween_property(_lobby_music_player, "volume_db", target_db, fade_sec)
		_music_crossfade_tween.finished.connect(func() -> void:
			if _menu_music_player != null and is_instance_valid(_menu_music_player):
				_menu_music_player.stop()
		)
		return

	if _menu_music_player.stream == null:
		_menu_music_player.stream = _load_menu_soundtrack_stream()
	if _menu_music_player.stream is AudioStreamWAV:
		(_menu_music_player.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	elif _menu_music_player.stream is AudioStreamMP3:
		(_menu_music_player.stream as AudioStreamMP3).loop = true
	if not _menu_music_player.playing:
		_menu_music_player.volume_db = -80.0
		_menu_music_player.play(0.0)
	_menu_music_player.stream_paused = false
	_music_crossfade_tween = _host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_music_crossfade_tween.parallel().tween_property(_menu_music_player, "volume_db", target_db, fade_sec)
	_music_crossfade_tween.parallel().tween_property(_lobby_music_player, "volume_db", -80.0, fade_sec)
	_music_crossfade_tween.finished.connect(func() -> void:
		if _lobby_music_player != null and is_instance_valid(_lobby_music_player):
			_lobby_music_player.stop()
	)

func set_menu_sfx_volume_linear(value: float) -> void:
	_menu_sfx_volume_linear = clampf(value, 0.0, 1.0)
	if _typewriter_player != null and is_instance_valid(_typewriter_player):
		_typewriter_player.volume_db = _scaled_sfx_db(TYPEWRITER_BASE_DB)
	if _explosion_player != null and is_instance_valid(_explosion_player):
		_explosion_player.volume_db = _scaled_sfx_db(EXPLOSION_BASE_DB)
	if _explosion_layer_player != null and is_instance_valid(_explosion_layer_player):
		_explosion_layer_player.volume_db = _scaled_sfx_db(EXPLOSION_LAYER_BASE_DB)

func _apply_menu_music_volume_from_slider() -> void:
	if _menu_music_player == null or not is_instance_valid(_menu_music_player):
		return
	if _lobby_music_player == null or not is_instance_valid(_lobby_music_player):
		_ensure_lobby_music_player()
	var target_db := _scaled_menu_music_db(MENU_MUSIC_TARGET_DB)
	var menu_target_db := target_db
	var lobby_target_db := -80.0
	if _lobby_music_active:
		menu_target_db = -80.0
		lobby_target_db = target_db
	if _menu_music_fade_tween != null and _menu_music_fade_tween.is_running():
		_menu_music_fade_tween.kill()
		_menu_music_fade_tween = _host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_menu_music_fade_tween.parallel().tween_property(_menu_music_player, "volume_db", menu_target_db, 0.16)
		if _lobby_music_player != null and is_instance_valid(_lobby_music_player):
			_menu_music_fade_tween.parallel().tween_property(_lobby_music_player, "volume_db", lobby_target_db, 0.16)
	else:
		_menu_music_player.volume_db = menu_target_db
		if _lobby_music_player != null and is_instance_valid(_lobby_music_player):
			_lobby_music_player.volume_db = lobby_target_db

func _scaled_menu_music_db(base_db: float) -> float:
	var vol := clampf(_menu_music_volume_linear, 0.0, 1.0)
	if vol <= 0.001:
		return -80.0
	return clampf(base_db + linear_to_db(vol), -80.0, 12.0)

func _scaled_sfx_db(base_db: float) -> float:
	var vol := clampf(_menu_sfx_volume_linear, 0.0, 1.0)
	if vol <= 0.001:
		return -80.0
	return clampf(base_db + linear_to_db(vol), -80.0, 12.0)

func _transparent_cursor_texture() -> Texture2D:
	if _hidden_cursor_tex != null:
		return _hidden_cursor_tex
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0, 0, 0, 0))
	_hidden_cursor_tex = ImageTexture.create_from_image(img)
	return _hidden_cursor_tex

func _hide_menu_cursor_for_intro() -> void:
	_cursor_hide_enforce_seq += 1
	var seq := _cursor_hide_enforce_seq
	_apply_intro_cursor_hidden_state()
	_schedule_cursor_hide_enforcement(seq, 8)

func _restore_menu_cursor_after_intro() -> void:
	_cursor_hide_enforce_seq += 1
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
	Input.set_custom_mouse_cursor(null, Input.CURSOR_IBEAM)
	var cm := _cursor_manager_node() as CanvasLayer
	if cm != null:
		cm.set_process(true)
		cm.visible = true
		if cm.has_method("set_cursor_context"):
			cm.call("set_cursor_context", "menu")
	if _host != null and _host.has_method("_apply_menu_cursor_context"):
		_host.call("_apply_menu_cursor_context")

func _cursor_manager_node() -> Node:
	if _host == null:
		return null
	var tree := _host.get_tree()
	if tree == null:
		return null
	var root := tree.get_root()
	if root == null:
		return null
	return root.get_node_or_null("CursorManager")

func _apply_intro_cursor_hidden_state() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	var transparent := _transparent_cursor_texture()
	Input.set_custom_mouse_cursor(transparent, Input.CURSOR_ARROW, Vector2.ZERO)
	Input.set_custom_mouse_cursor(transparent, Input.CURSOR_POINTING_HAND, Vector2.ZERO)
	Input.set_custom_mouse_cursor(transparent, Input.CURSOR_IBEAM, Vector2.ZERO)
	var cm := _cursor_manager_node() as CanvasLayer
	if cm != null:
		if cm.has_method("set_cursor_context"):
			cm.call("set_cursor_context", "game")
		cm.set_process(false)
		cm.visible = false

func _schedule_cursor_hide_enforcement(seq: int, frames_left: int) -> void:
	if _host == null or frames_left <= 0:
		return
	var tree := _host.get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(0.04)
	timer.timeout.connect(func() -> void:
		if seq != _cursor_hide_enforce_seq:
			return
		if _intro == null or not _intro.visible:
			return
		_apply_intro_cursor_hidden_state()
		_schedule_cursor_hide_enforcement(seq, frames_left - 1)
	)

func _ensure_intro_reveal_material() -> void:
	if _intro_fade == null:
		return
	var mat := _intro_fade.material as ShaderMaterial
	if mat == null or mat.shader != INTRO_REVEAL_SHADER:
		mat = ShaderMaterial.new()
		mat.shader = INTRO_REVEAL_SHADER
		_intro_fade.material = mat
	_intro_reveal_material = mat
	_intro_reveal_material.set_shader_parameter("overlay_tint", INTRO_OVERLAY_TINT)
	_set_intro_reveal_radius(0.0)

func _set_intro_reveal_radius(value: float) -> void:
	if _intro_reveal_material == null:
		_ensure_intro_reveal_material()
	if _intro_reveal_material == null:
		return
	_intro_reveal_material.set_shader_parameter("reveal_radius", clampf(value, 0.0, 1.6))

func _play_typewriter_tick() -> void:
	if _typewriter_player == null or not is_instance_valid(_typewriter_player):
		_ensure_typewriter_player()
	if _typewriter_player == null:
		return
	var now := Time.get_ticks_msec()
	if now - _typewriter_last_tick_msec < 38:
		return
	_typewriter_last_tick_msec = now
	_typewriter_player.pitch_scale = randf_range(0.72, 0.84)
	_typewriter_player.play()

func _play_intro_explosion() -> void:
	if intro_fx_enabled and _pixel_burst_at.is_valid() and _host != null:
		var vp: Rect2 = (_host as CanvasItem).get_viewport_rect()
		var c := vp.position + vp.size * 0.5
		var colors: Array[Color] = [
			MENU_PALETTE.text_primary(1.0),
			MENU_PALETTE.highlight(1.0),
			MENU_PALETTE.hot(1.0),
			MENU_PALETTE.highlight(1.0),
		]
		# Build a massive center-focused explosion, then cap calls by available FX budget.
		var points: Array[Vector2] = []
		# Dense hot core at center.
		for i in range(34):
			points.append(c)
		for i in range(22):
			points.append(c + Vector2(randf_range(-26.0, 26.0), randf_range(-20.0, 20.0)))
		for i in range(16):
			points.append(c + Vector2(randf_range(-52.0, 52.0), randf_range(-44.0, 44.0)))
		# Full-screen outer scatter so particles occupy all screen.
		for i in range(28):
			points.append(Vector2(randf_range(vp.position.x, vp.position.x + vp.size.x), randf_range(vp.position.y, vp.position.y + vp.size.y)))

		var fx_layer := _host.get("_fx_layer") as Control
		var current_children := fx_layer.get_child_count() if fx_layer != null else 0
		var particles_per_call := maxi(1, int(_host.get("intro_fx_particles_per_burst")))
		var budget_particles := maxi(120, 395 - current_children)
		var max_calls := maxi(6, budget_particles / particles_per_call)
		var calls := mini(points.size(), max_calls)

		for i in range(calls):
			var p := points[i]
			var col: Color = colors[i % colors.size()]
			if i < int(float(calls) * 0.45):
				col = MENU_PALETTE.text_primary(1.0)
			elif i >= calls - 6:
				col = MENU_PALETTE.highlight(1.0)
			_pixel_burst_at.call(p, col)
	if _explosion_player == null or not is_instance_valid(_explosion_player):
		_ensure_explosion_player()
	if _explosion_player == null:
		return
	_explosion_player.pitch_scale = randf_range(0.95, 1.04)
	_explosion_player.play()
	if _explosion_layer_player == null or not is_instance_valid(_explosion_layer_player):
		_ensure_explosion_layer_player()
	if _explosion_layer_player != null:
		_explosion_layer_player.pitch_scale = randf_range(0.9, 1.0)
		_explosion_layer_player.play()
