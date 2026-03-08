extends WeaponProfile
class_name Shotgun

const WEAPON_ID := "shotgun"
const NAME := "Shotgun"
const PELLET_COUNT := 10
const PROJECTILE_SPEED_MIN := 1350.0
const PROJECTILE_SPEED_MAX := 3000.0
const BASE_DAMAGE := 5
const BOOST_DAMAGE := 22
const FIRE_INTERVAL := 0.2
const MAGAZINE_SIZE := 2
const RELOAD_DURATION := 1.2
const MAX_AIM_DISTANCE := 500.0
const CLIENT_VISUAL_ADVANCE_MAX_MS := 70
const CAMERA_SHAKE_PER_SHOT_VALUE := 135.0
const PROJECTILE_HIT_RADIUS := 7.0
const PROJECTILE_LIFETIME := 0.6
const MAX_SPREAD_DEGREES := 11.0
const PROJECTILE_GRAVITY := Vector2(0.0, 1450.0)
const GRAVITY_ACTIVATION_SPEED := 110.0
const EXPONENTIAL_DRAG := 8.5

func weapon_id() -> String:
	return WEAPON_ID

func weapon_name() -> String:
	return NAME

func fire_interval() -> float:
	return FIRE_INTERVAL

func base_damage() -> int:
	return BASE_DAMAGE

func magazine_size() -> int:
	return MAGAZINE_SIZE

func reload_duration() -> float:
	return RELOAD_DURATION

func boost_damage() -> int:
	return BOOST_DAMAGE

func camera_shake_per_shot() -> float:
	return CAMERA_SHAKE_PER_SHOT_VALUE

func projectile_hit_radius() -> float:
	return PROJECTILE_HIT_RADIUS

func projectile_lifetime() -> float:
	return PROJECTILE_LIFETIME

func projectile_visual_config() -> Dictionary:
	return {
		"show_head": true,
		"head_scale": 0.34,
		"head_alpha": 0.92,
		"trail_width": 2.8,
		"trail_alpha": 0.32,
		"gravity": PROJECTILE_GRAVITY,
		"gravity_activation_speed": GRAVITY_ACTIVATION_SPEED,
		"exponential_drag": EXPONENTIAL_DRAG
	}

func damage_for_boost(boost_enabled: bool) -> int:
	return BOOST_DAMAGE if boost_enabled else BASE_DAMAGE

func clamp_aim_world(player_position: Vector2, desired_aim_world: Vector2) -> Vector2:
	var aim_delta := desired_aim_world - player_position
	if aim_delta.length() > MAX_AIM_DISTANCE:
		return player_position + aim_delta.normalized() * MAX_AIM_DISTANCE
	return desired_aim_world

func visual_advance_ms(last_ping_ms: int, lag_comp_ms: int, owner_is_local: bool) -> int:
	var advance_ms := clampi(last_ping_ms >> 1, 0, CLIENT_VISUAL_ADVANCE_MAX_MS)
	if owner_is_local:
		advance_ms = clampi(advance_ms + lag_comp_ms, 0, CLIENT_VISUAL_ADVANCE_MAX_MS)
	return advance_ms

func build_server_shots(
	player: NetPlayer,
	input_state: Dictionary,
	next_projectile_id: int,
	max_reported_rtt_ms: int,
	world_2d: World2D
) -> Array:
	var desired_spawn_position := player.get_muzzle_world_position()
	var desired_aim_world := clamp_aim_world(player.global_position, input_state.get("aim_world", desired_spawn_position) as Vector2)
	var base_direction := (desired_aim_world - player.global_position).normalized()
	if base_direction.length_squared() <= 0.0001:
		base_direction = Vector2.RIGHT

	var spawn_position := _safe_spawn_position(player, desired_spawn_position, world_2d)
	var trail_origin := desired_spawn_position
	if spawn_position.distance_squared_to(player.global_position) <= 4.0:
		trail_origin = player.global_position

	var reported_rtt_ms := int(input_state.get("reported_rtt_ms", 0))
	var lag_comp_ms := clampi(reported_rtt_ms >> 1, 0, max_reported_rtt_ms >> 1)
	var pellets: Array = []
	var pellet_damage := damage_for_boost(bool(input_state.get("boost_damage", false)))
	for pellet_index in range(PELLET_COUNT):
		var spread_angle := deg_to_rad(randf_range(-MAX_SPREAD_DEGREES, MAX_SPREAD_DEGREES))
		var shoot_direction := base_direction.rotated(spread_angle).normalized()
		var pellet_speed := randf_range(PROJECTILE_SPEED_MIN, PROJECTILE_SPEED_MAX)
		pellets.append({
			"projectile_id": next_projectile_id + pellet_index,
			"spawn_position": spawn_position,
			"velocity": shoot_direction * pellet_speed,
			"lag_comp_ms": lag_comp_ms,
			"trail_origin": trail_origin,
			"shot_damage": pellet_damage
		})
	return pellets

func _safe_spawn_position(player: NetPlayer, desired_spawn_position: Vector2, world_2d: World2D) -> Vector2:
	var base_position: Vector2 = player.global_position
	var toward_muzzle: Vector2 = desired_spawn_position - base_position
	if toward_muzzle.length_squared() <= 0.0001:
		return base_position

	var shoot_direction := toward_muzzle.normalized()
	var query_from := base_position + shoot_direction * maxf(4.0, player.get_hit_radius() * 0.55)
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(query_from, desired_spawn_position, 1 | 2)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var hit: Dictionary = world_2d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_spawn_position

	var hit_position: Variant = hit.get("position", desired_spawn_position)
	if not (hit_position is Vector2):
		return desired_spawn_position
	var clipped_position := hit_position as Vector2
	if clipped_position.distance_squared_to(desired_spawn_position) <= 16.0:
		return desired_spawn_position
	return clipped_position - shoot_direction * 2.0
