extends Node2D
class_name NovaCompanionVfx

var caster_peer_id := 0
var players: Dictionary = {}
var texture: Texture2D
var base_color := Color(0.62, 0.25, 0.82, 1.0)
var skin_index := 0

var _follow_offset := Vector2(-18.0, -26.0)
var _follow_speed := 10.0
var _sprite: Sprite2D
var _pulses: Array = []
var _pulse_emit_accumulator := 0.0
var _radar_remaining := 0.0
var _radar_duration := 0.0
var _radar_radius := 0.0

func _ready() -> void:
	z_index = 47
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	_update_sprite_frame()
	_update_follow_position(true)

func _process(delta: float) -> void:
	_update_follow_position(false)
	_update_pulses(delta)
	queue_redraw()

func activate_radar(duration_sec: float, radius_px: float, color: Color) -> void:
	_radar_duration = maxf(_radar_duration, maxf(0.05, duration_sec))
	_radar_remaining = maxf(_radar_remaining, maxf(0.05, duration_sec))
	_radar_radius = maxf(_radar_radius, maxf(32.0, radius_px))
	base_color = color
	_emit_pulse()

func set_companion_color(color: Color) -> void:
	base_color = color
	if _sprite != null:
		_sprite.modulate = base_color

func set_skin_index(value: int) -> void:
	skin_index = maxi(0, value)
	_update_sprite_frame()

func _update_follow_position(snap: bool) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		queue_free()
		return
	var desired := caster.global_position + _follow_offset
	if snap:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, minf(1.0, _follow_speed * get_process_delta_time()))

func _update_sprite_frame() -> void:
	if _sprite == null:
		return
	if texture == null:
		return
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(float(skin_index * 64), 0.0, 64.0, 64.0)
	_sprite.texture = atlas
	_sprite.modulate = base_color
	_sprite.scale = Vector2.ONE

func _update_pulses(delta: float) -> void:
	if _radar_remaining > 0.0:
		_radar_remaining = maxf(0.0, _radar_remaining - delta)
		_pulse_emit_accumulator += delta
		while _pulse_emit_accumulator >= 0.55:
			_pulse_emit_accumulator -= 0.55
			_emit_pulse()
	else:
		_pulse_emit_accumulator = 0.0
	for index in range(_pulses.size() - 1, -1, -1):
		var pulse := _pulses[index] as Dictionary
		var progress := float(pulse.get("progress", 0.0)) + delta / 0.9
		if progress >= 1.0:
			_pulses.remove_at(index)
			continue
		pulse["progress"] = progress
		_pulses[index] = pulse

func _emit_pulse() -> void:
	_pulses.append({
		"progress": 0.0
	})

func _draw() -> void:
	var aura_color := Color(base_color.r, base_color.g, base_color.b, 0.18)
	draw_circle(Vector2.ZERO, 18.0, aura_color)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 48, Color(base_color.r, base_color.g, base_color.b, 0.45), 2.0)
	for pulse_value in _pulses:
		if not (pulse_value is Dictionary):
			continue
		var pulse := pulse_value as Dictionary
		var progress := clampf(float(pulse.get("progress", 0.0)), 0.0, 1.0)
		var radius := lerpf(14.0, _radar_radius, progress)
		var alpha := (1.0 - progress) * 0.85
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 80, Color(base_color.r, base_color.g, base_color.b, alpha), 3.0)
		draw_arc(Vector2.ZERO, radius * 0.7, 0.0, TAU, 60, Color(base_color.r, base_color.g, base_color.b, alpha * 0.35), 1.0)
