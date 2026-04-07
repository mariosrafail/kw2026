extends Node2D

var caster_peer_id := 0
var players: Dictionary = {}
var multiplayer_api: MultiplayerAPI
var texture: Texture2D
var duration_sec := 5.0
var speed := 420.0
var turn_speed := 8.5
var hit_radius := 30.0
var spawn_offset := Vector2(0.0, -22.0)
var initial_target_world := Vector2.ZERO

var _remaining_sec := 0.0
var _velocity := Vector2.ZERO
var _exploding := false
var _explosion_remaining_sec := 0.0
var _sprite: Sprite2D

func _ready() -> void:
	_remaining_sec = maxf(0.05, duration_sec)
	z_index = 46
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * 1.2
	add_child(_sprite)
	var caster := players.get(caster_peer_id, null) as Node2D
	if caster != null:
		global_position = caster.global_position + spawn_offset
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if _exploding:
		_explosion_remaining_sec = maxf(0.0, _explosion_remaining_sec - delta)
		if _explosion_remaining_sec <= 0.0:
			queue_free()
			return
		queue_redraw()
		return

	_remaining_sec = maxf(0.0, _remaining_sec - delta)
	var desired_target := _desired_target_world()
	var to_target := desired_target - global_position
	var desired_velocity := Vector2.ZERO
	if to_target.length_squared() > 4.0:
		desired_velocity = to_target.normalized() * speed
	_velocity = _velocity.lerp(desired_velocity, min(1.0, delta * turn_speed))
	global_position += _velocity * delta
	if _velocity.length_squared() > 0.0001:
		rotation = _velocity.angle()
	var progress := 1.0 - (_remaining_sec / maxf(0.05, duration_sec))
	_sprite.scale = Vector2.ONE * lerpf(1.0, 1.35, clampf(progress, 0.0, 1.0))
	if _contact_player_found():
		_start_explosion()
		return
	if _remaining_sec <= 0.0:
		_start_explosion()
	queue_redraw()

func _draw() -> void:
	if not _exploding:
		var glow_alpha := lerpf(0.12, 0.22, 1.0 - (_remaining_sec / maxf(0.05, duration_sec)))
		draw_circle(Vector2.ZERO, 14.0, Color(1.0, 0.72, 0.18, glow_alpha))
		return
	var progress := 1.0 - (_explosion_remaining_sec / 0.28)
	var ring_radius := lerpf(8.0, 72.0, clampf(progress, 0.0, 1.0))
	var alpha := 1.0 - clampf(progress, 0.0, 1.0)
	draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, Color(1.0, 0.78, 0.24, 0.82 * alpha), 4.0)
	draw_circle(Vector2.ZERO, ring_radius * 0.4, Color(1.0, 0.5, 0.12, 0.18 * alpha))

func _desired_target_world() -> Vector2:
	var local_peer_id := multiplayer_api.get_unique_id() if multiplayer_api != null else 0
	if local_peer_id == caster_peer_id:
		var viewport := get_viewport()
		if viewport != null and viewport.get_camera_2d() != null:
			return viewport.get_camera_2d().get_global_mouse_position()
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster != null:
		return global_position + Vector2.RIGHT.rotated(caster.get_aim_angle()) * 120.0
	return initial_target_world

func _contact_player_found() -> bool:
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if peer_id == caster_peer_id:
			continue
		var player := players.get(peer_id, null) as NetPlayer
		if player == null or player.get_health() <= 0:
			continue
		if player.global_position.distance_to(global_position) <= hit_radius:
			return true
	return false

func _start_explosion() -> void:
	_exploding = true
	_explosion_remaining_sec = 0.28
	if _sprite != null:
		_sprite.visible = false
	queue_redraw()
