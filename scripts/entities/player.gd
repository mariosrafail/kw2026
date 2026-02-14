extends CharacterBody2D
class_name NetPlayer

const SPEED := 245.0
const JUMP_VELOCITY := -650.0
const GRAVITY := 1450.0
const FALL_GRAVITY_MULTIPLIER := 1.35
const MAX_FALL_SPEED := 1300.0
const JUMP_RELEASE_DAMP := 0.55
const COYOTE_TIME := 0.16
const SNAP_LERP_SPEED_X := 14.0
const SNAP_LERP_SPEED_Y := 10.0
const AIM_LERP_SPEED := 20.0
const REMOTE_SNAP_DISTANCE := 150.0
const REMOTE_VELOCITY_BLEND := 0.45
const MAX_HEALTH := 100
const HIT_RADIUS := 12.0
const GUN_VISUAL_ANGLE_OFFSET := 0.0
const GUN_RECOIL_SCALE_Y := 1.08
const GUN_RECOIL_OUT_TIME := 0.035
const GUN_RECOIL_BACK_TIME := 0.085

@onready var body: Polygon2D = $Body
@onready var feet: Polygon2D = $Feet
@onready var player_sprite: Node2D = $Sprite2D
@onready var gun_pivot: Node2D = $GunPivot
@onready var gun: Node2D = $GunPivot/Gun
@onready var muzzle: Marker2D = $GunPivot/Muzzle
@onready var health_label: Label = $HealthLabel

var peer_id: int = 0
var use_network_smoothing := false
var target_position := Vector2.ZERO
var target_velocity := Vector2.ZERO
var target_aim_angle := 0.0
var health := MAX_HEALTH
var target_health := MAX_HEALTH
var coyote_time_left := 0.0
var gun_recoil_tween: Tween

func _ready() -> void:
	target_position = global_position
	target_velocity = velocity
	target_aim_angle = 0.0
	target_health = health
	_apply_player_facing_from_angle(target_aim_angle)
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)
	_update_health_label()

func configure(new_peer_id: int, color: Color) -> void:
	peer_id = new_peer_id
	if body == null:
		body = get_node_or_null("Body") as Polygon2D
	if feet == null:
		feet = get_node_or_null("Feet") as Polygon2D

	if body != null:
		body.color = color
	if feet != null:
		feet.color = color.darkened(0.25)
	if gun != null:
		gun.modulate = color.lightened(0.15)
	set_health(MAX_HEALTH)

func set_health(value: int) -> void:
	health = clampi(value, 0, MAX_HEALTH)
	target_health = health
	_update_health_label()

func get_health() -> int:
	return health

func apply_damage(amount: int) -> int:
	set_health(health - max(0, amount))
	return health

func get_hit_radius() -> float:
	return HIT_RADIUS

func _update_health_label() -> void:
	if health_label != null:
		health_label.text = str(health)

func force_respawn(spawn_position: Vector2) -> void:
	global_position = spawn_position
	target_position = spawn_position
	velocity = Vector2.ZERO
	target_velocity = Vector2.ZERO
	coyote_time_left = 0.0

func set_aim_world(target_world: Vector2) -> void:
	set_aim_angle((target_world - global_position).angle())

func set_aim_angle(angle: float) -> void:
	target_aim_angle = angle
	if not use_network_smoothing and gun_pivot != null:
		gun_pivot.rotation = angle + GUN_VISUAL_ANGLE_OFFSET
	_apply_player_facing_from_angle(angle)
	_apply_gun_horizontal_flip_from_angle(angle)

func _apply_player_facing_from_angle(angle: float) -> void:
	if player_sprite == null:
		return
	var looking_left := cos(angle) < 0.0
	var current_scale := player_sprite.scale
	current_scale.x = -absf(current_scale.x) if looking_left else absf(current_scale.x)
	player_sprite.scale = current_scale

func _apply_gun_horizontal_flip_from_angle(angle: float) -> void:
	if gun == null:
		return
	var looking_left := cos(angle) < 0.0
	var current_scale := gun.scale
	current_scale.x = absf(current_scale.x)
	current_scale.y = -absf(current_scale.y) if looking_left else absf(current_scale.y)
	gun.scale = current_scale

func play_shot_recoil() -> void:
	if gun == null:
		return
	if gun_recoil_tween != null:
		gun_recoil_tween.kill()

	var current_scale := gun.scale
	var sign_x := -1.0 if current_scale.x < 0.0 else 1.0
	var sign_y := -1.0 if current_scale.y < 0.0 else 1.0
	var base_scale := Vector2(absf(current_scale.x), absf(current_scale.y))
	var recoil_scale := Vector2(base_scale.x, base_scale.y * GUN_RECOIL_SCALE_Y)

	gun_recoil_tween = create_tween()
	gun_recoil_tween.tween_property(gun, "scale", Vector2(sign_x * recoil_scale.x, sign_y * recoil_scale.y), GUN_RECOIL_OUT_TIME)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	gun_recoil_tween.tween_property(gun, "scale", Vector2(sign_x * base_scale.x, sign_y * base_scale.y), GUN_RECOIL_BACK_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func get_aim_angle() -> float:
	return target_aim_angle

func get_muzzle_world_position() -> Vector2:
	if muzzle == null:
		return global_position
	return muzzle.global_position

func simulate_authoritative(delta: float, axis: float, jump_pressed: bool, jump_held: bool) -> void:
	axis = clamp(axis, -1.0, 1.0)
	var on_floor := is_on_floor()
	if on_floor:
		coyote_time_left = COYOTE_TIME
	else:
		coyote_time_left = maxf(coyote_time_left - delta, 0.0)

	var target_speed := axis * SPEED
	if absf(axis) > 0.001:
		velocity.x = target_speed
	else:
		velocity.x = 0.0

	if not on_floor:
		var gravity_scale := FALL_GRAVITY_MULTIPLIER if velocity.y > 0.0 else 1.0
		velocity.y = min(velocity.y + GRAVITY * gravity_scale * delta, MAX_FALL_SPEED)
	elif velocity.y > 0.0:
		velocity.y = 0.0

	if jump_pressed and (on_floor or coyote_time_left > 0.0):
		velocity.y = JUMP_VELOCITY
		coyote_time_left = 0.0

	if not jump_held and velocity.y < 0.0:
		velocity.y *= JUMP_RELEASE_DAMP

	move_and_slide()
	if is_on_floor():
		coyote_time_left = COYOTE_TIME
	target_position = global_position
	target_velocity = velocity
	target_aim_angle = get_aim_angle()

func apply_snapshot(new_position: Vector2, new_velocity: Vector2, new_aim_angle: float, new_health: int) -> void:
	target_position = new_position
	target_velocity = new_velocity
	target_aim_angle = new_aim_angle
	target_health = clampi(new_health, 0, MAX_HEALTH)

	if not use_network_smoothing:
		global_position = target_position
		velocity = target_velocity
		if gun_pivot != null:
			gun_pivot.rotation = target_aim_angle + GUN_VISUAL_ANGLE_OFFSET
		_apply_player_facing_from_angle(target_aim_angle)
		_apply_gun_horizontal_flip_from_angle(target_aim_angle)
		health = target_health
		_update_health_label()

func _physics_process(delta: float) -> void:
	if not use_network_smoothing:
		return

	var position_error := target_position - global_position
	if position_error.length() > REMOTE_SNAP_DISTANCE:
		global_position = target_position
		velocity = target_velocity
	else:
		global_position.x = lerpf(global_position.x, target_position.x, min(1.0, delta * SNAP_LERP_SPEED_X))
		global_position.y = lerpf(global_position.y, target_position.y, min(1.0, delta * SNAP_LERP_SPEED_Y))
		velocity = velocity.lerp(target_velocity, REMOTE_VELOCITY_BLEND)
	if gun_pivot != null:
		gun_pivot.rotation = lerp_angle(gun_pivot.rotation, target_aim_angle + GUN_VISUAL_ANGLE_OFFSET, min(1.0, delta * AIM_LERP_SPEED))
	_apply_player_facing_from_angle(target_aim_angle)
	_apply_gun_horizontal_flip_from_angle(target_aim_angle)
	if health != target_health:
		health = target_health
		_update_health_label()
