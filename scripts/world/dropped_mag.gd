extends RigidBody2D
class_name DroppedMag

const LIFETIME_SEC := 10.0
const FADE_OUT_SEC := 0.7
const KICK_SPEED_THRESHOLD := 36.0
const KICK_COOLDOWN_SEC := 0.1
const PLAYER_KICK_SPEED_MULT := 0.78
const PLAYER_KICK_UPWARD_BIAS := -34.0
const REPLICA_POSITION_BLEND := 0.26
const REPLICA_ROTATION_BLEND := 0.22
const REPLICA_VELOCITY_BLEND := 0.18
const REPLICA_SNAP_DISTANCE := 36.0
const BODY_FRICTION := 0.16
const BODY_BOUNCE := 0.06
const BODY_LINEAR_DAMP := 0.32
const BODY_ANGULAR_DAMP := 0.18

var mag_id := 0
var age_sec := 0.0
var replica_mode := false
var _replica_target_position := Vector2.ZERO
var _replica_target_rotation := 0.0
var _replica_target_linear_velocity := Vector2.ZERO
var _replica_target_angular_velocity := 0.0
var _replica_state_initialized := false

var _sprite: Sprite2D
var _collision_shape: CollisionShape2D
var _kick_area: Area2D
var _kick_shape: CollisionShape2D
var _recent_kick_time_by_peer: Dictionary = {}
var _base_modulate := Color.WHITE

func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 4
	sleeping = false
	can_sleep = true
	linear_damp = BODY_LINEAR_DAMP
	angular_damp = BODY_ANGULAR_DAMP
	var body_material := PhysicsMaterial.new()
	body_material.friction = BODY_FRICTION
	body_material.bounce = BODY_BOUNCE
	physics_material_override = body_material
	_apply_visual_alpha(1.0)

func setup(new_mag_id: int, texture: Texture2D, collision_size: Vector2, tint: Color = Color.WHITE) -> void:
	mag_id = new_mag_id
	_ensure_nodes(texture, collision_size)
	set_tint(tint)
	_replica_target_position = global_position
	_replica_target_rotation = rotation
	_replica_target_linear_velocity = linear_velocity
	_replica_target_angular_velocity = angular_velocity
	_apply_replica_mode_settings()

func set_tint(tint: Color) -> void:
	_base_modulate = Color(tint.r, tint.g, tint.b, 1.0)
	_apply_visual_alpha(_sprite.modulate.a if _sprite != null else 1.0)

func set_replica_mode(enabled: bool) -> void:
	replica_mode = enabled
	_apply_replica_mode_settings()

func authoritative_state() -> Dictionary:
	return {
		"position": global_position,
		"rotation": rotation,
		"linear_velocity": linear_velocity,
		"angular_velocity": angular_velocity
	}

func apply_network_state(world_position: Vector2, world_rotation: float, new_linear_velocity: Vector2, new_angular_velocity: float) -> void:
	if not replica_mode:
		global_position = world_position
		rotation = world_rotation
		linear_velocity = new_linear_velocity
		angular_velocity = new_angular_velocity
		return
	_replica_target_position = world_position
	_replica_target_rotation = world_rotation
	_replica_target_linear_velocity = new_linear_velocity
	_replica_target_angular_velocity = new_angular_velocity
	if not _replica_state_initialized:
		global_position = world_position
		rotation = world_rotation
		linear_velocity = new_linear_velocity
		angular_velocity = new_angular_velocity
		_replica_state_initialized = true

func is_expired() -> bool:
	return age_sec >= LIFETIME_SEC

func _physics_process(delta: float) -> void:
	age_sec += delta
	_update_lifetime_visuals()
	if replica_mode:
		_tick_replica_smoothing(delta)
		return
	_tick_player_kicks()

func _tick_replica_smoothing(delta: float) -> void:
	if not _replica_state_initialized:
		return
	var to_target := _replica_target_position - global_position
	if to_target.length() > REPLICA_SNAP_DISTANCE:
		global_position = _replica_target_position
	else:
		global_position = global_position.lerp(_replica_target_position, 1.0 - pow(1.0 - REPLICA_POSITION_BLEND, maxf(delta * 60.0, 1.0)))
	rotation = lerp_angle(rotation, _replica_target_rotation, 1.0 - pow(1.0 - REPLICA_ROTATION_BLEND, maxf(delta * 60.0, 1.0)))
	linear_velocity = linear_velocity.lerp(_replica_target_linear_velocity, 1.0 - pow(1.0 - REPLICA_VELOCITY_BLEND, maxf(delta * 60.0, 1.0)))
	angular_velocity = lerpf(angular_velocity, _replica_target_angular_velocity, 1.0 - pow(1.0 - REPLICA_VELOCITY_BLEND, maxf(delta * 60.0, 1.0)))

func _tick_player_kicks() -> void:
	if _kick_area == null:
		return
	var now_sec := Time.get_ticks_msec() / 1000.0
	for body in _kick_area.get_overlapping_bodies():
		var player := body as NetPlayer
		if player == null:
			continue
		var peer_id := int(player.peer_id)
		var last_kick_sec := float(_recent_kick_time_by_peer.get(peer_id, -1000.0))
		if now_sec - last_kick_sec < KICK_COOLDOWN_SEC:
			continue
		var player_velocity := player.velocity
		if player_velocity.length() < KICK_SPEED_THRESHOLD and player.target_velocity.length() >= KICK_SPEED_THRESHOLD:
			player_velocity = player.target_velocity
		if player_velocity.length() < KICK_SPEED_THRESHOLD:
			continue
		_recent_kick_time_by_peer[peer_id] = now_sec
		var relative := global_position - player.global_position
		var side_sign := signf(relative.x)
		if is_zero_approx(side_sign):
			side_sign = signf(player_velocity.x)
			if is_zero_approx(side_sign):
				side_sign = 1.0
		var kick_velocity := player_velocity * PLAYER_KICK_SPEED_MULT
		kick_velocity.y += PLAYER_KICK_UPWARD_BIAS
		kick_velocity.x += side_sign * 22.0
		apply_central_impulse(kick_velocity * mass)
		apply_torque_impulse(side_sign * 9.0)

func _update_lifetime_visuals() -> void:
	if age_sec < LIFETIME_SEC - FADE_OUT_SEC:
		_apply_visual_alpha(1.0)
		return
	var fade_t := inverse_lerp(LIFETIME_SEC, LIFETIME_SEC - FADE_OUT_SEC, age_sec)
	_apply_visual_alpha(clampf(fade_t, 0.0, 1.0))

func _apply_visual_alpha(alpha: float) -> void:
	if _sprite == null:
		_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite != null:
		_sprite.modulate = Color(_base_modulate.r, _base_modulate.g, _base_modulate.b, clampf(alpha, 0.0, 1.0))

func _apply_replica_mode_settings() -> void:
	freeze = false
	if replica_mode:
		collision_layer = 4
		collision_mask = 1
		if _kick_area != null:
			_kick_area.monitoring = false
	else:
		collision_layer = 4
		collision_mask = 1
		if _kick_area != null:
			_kick_area.monitoring = true

func _ensure_nodes(texture: Texture2D, collision_size: Vector2) -> void:
	if _sprite == null:
		_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite2D"
		_sprite.texture_filter = CanvasItem.TextureFilter.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
	_sprite.texture = texture
	_sprite.centered = true

	if _collision_shape == null:
		_collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
	var body_shape := CapsuleShape2D.new()
	body_shape.radius = maxf(1.0, collision_size.y * 0.5)
	body_shape.height = maxf(collision_size.x, body_shape.radius * 2.0)
	_collision_shape.shape = body_shape
	_collision_shape.rotation = PI * 0.5

	if _kick_area == null:
		_kick_area = get_node_or_null("KickArea") as Area2D
	if _kick_area == null:
		_kick_area = Area2D.new()
		_kick_area.name = "KickArea"
		_kick_area.monitorable = false
		_kick_area.collision_layer = 0
		_kick_area.collision_mask = 2
		add_child(_kick_area)
	if _kick_shape == null:
		_kick_shape = _kick_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if _kick_shape == null:
		_kick_shape = CollisionShape2D.new()
		_kick_shape.name = "CollisionShape2D"
		_kick_area.add_child(_kick_shape)
	var area_shape := CircleShape2D.new()
	area_shape.radius = maxf(collision_size.x, collision_size.y) * 0.8
	_kick_shape.shape = area_shape