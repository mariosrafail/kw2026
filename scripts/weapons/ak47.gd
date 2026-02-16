extends WeaponProfile
class_name AK47

const NAME := "AK47"
const PROJECTILE_SPEED := 5000
const BASE_DAMAGE := 5
const BOOST_DAMAGE := 100
const FIRE_INTERVAL := 0.10
const MAGAZINE_SIZE := 25
const RELOAD_DURATION := 1.0
const MAX_AIM_DISTANCE := 2600.0
const CLIENT_VISUAL_ADVANCE_MAX_MS := 220
const CAMERA_SHAKE_PER_SHOT_VALUE := 20

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
	return 8.2

func projectile_lifetime() -> float:
	return 2.0

func projectile_visual_config() -> Dictionary:
	return {
		"show_head": true,
		"head_scale": 0.95,
		"head_alpha": 0.95,
		"trail_width": 3.9,
		"trail_alpha": 0.56
	}

func damage_for_boost(boost_enabled: bool) -> int:
	return BOOST_DAMAGE if boost_enabled else BASE_DAMAGE

func clamp_aim_world(player_position: Vector2, desired_aim_world: Vector2) -> Vector2:
	var aim_delta := desired_aim_world - player_position
	if aim_delta.length() > MAX_AIM_DISTANCE:
		return player_position + aim_delta.normalized() * MAX_AIM_DISTANCE
	return desired_aim_world

func visual_advance_ms(last_ping_ms: int, lag_comp_ms: int, owner_is_local: bool) -> int:
	var advance_ms := clampi(last_ping_ms / 2, 0, CLIENT_VISUAL_ADVANCE_MAX_MS)
	if owner_is_local:
		advance_ms = clampi(advance_ms + lag_comp_ms, 0, CLIENT_VISUAL_ADVANCE_MAX_MS)
	return advance_ms

func build_server_shot(
	player: NetPlayer,
	input_state: Dictionary,
	next_projectile_id: int,
	max_reported_rtt_ms: int,
	world_2d: World2D
) -> Dictionary:
	var desired_spawn_position := player.get_muzzle_world_position()
	var shoot_direction := Vector2.RIGHT.rotated(player.get_aim_angle()).normalized()
	if shoot_direction.length_squared() <= 0.0001:
		shoot_direction = Vector2.RIGHT

	var spawn_position := _safe_spawn_position(player, desired_spawn_position, world_2d)
	var trail_origin := desired_spawn_position
	if spawn_position.distance_squared_to(player.global_position) <= 4.0:
		trail_origin = player.global_position

	var reported_rtt_ms := int(input_state.get("reported_rtt_ms", 0))
	var lag_comp_ms := int(clampi(reported_rtt_ms / 2, 0, max_reported_rtt_ms / 2))

	return {
		"projectile_id": next_projectile_id,
		"spawn_position": spawn_position,
		"velocity": shoot_direction * PROJECTILE_SPEED,
		"lag_comp_ms": lag_comp_ms,
		"trail_origin": trail_origin,
		"shot_damage": damage_for_boost(bool(input_state.get("boost_damage", false)))
	}

func _safe_spawn_position(player: NetPlayer, desired_spawn_position: Vector2, world_2d: World2D) -> Vector2:
	var base_position: Vector2 = player.global_position
	var toward_muzzle: Vector2 = desired_spawn_position - base_position
	if toward_muzzle.length_squared() <= 0.0001:
		return base_position

	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(base_position, desired_spawn_position, 1 | 2)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [player.get_rid()]
	var hit: Dictionary = world_2d.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_spawn_position

	return base_position
