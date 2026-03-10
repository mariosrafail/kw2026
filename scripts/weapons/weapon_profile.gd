extends RefCounted
class_name WeaponProfile

func weapon_id() -> String:
	return weapon_name().to_lower()

func weapon_name() -> String:
	return "Weapon"

func fire_interval() -> float:
	return 0.15

func base_damage() -> int:
	return 1

func magazine_size() -> int:
	return 25

func reload_duration() -> float:
	return 1.0

func boost_damage_cap() -> int:
	return 0

func camera_shake_per_shot() -> float:
	return 0.0

func projectile_hit_radius() -> float:
	return 8.0

func projectile_lifetime() -> float:
	return 2.0

func explosion_radius() -> float:
	return 0.0

func projectile_visual_config() -> Dictionary:
	return {
		"show_head": true,
		"head_scale": 0.85,
		"head_alpha": 0.9,
		"trail_width": 3.6,
		"trail_alpha": 0.52
	}

func clamp_aim_world(_player_position: Vector2, desired_aim_world: Vector2) -> Vector2:
	return desired_aim_world

func damage_for_boost(boost_enabled: bool, boost_multiplier: float = 1.0) -> int:
	if not boost_enabled:
		return base_damage()
	var resolved_multiplier := maxf(1.0, boost_multiplier)
	var boosted_damage := maxi(base_damage(), int(round(float(base_damage()) * resolved_multiplier)))
	var boosted_cap := boost_damage_cap()
	if boosted_cap > 0:
		boosted_damage = mini(boosted_damage, boosted_cap)
	return boosted_damage

func visual_advance_ms(last_ping_ms: int, lag_comp_ms: int, owner_is_local: bool) -> int:
	var advance_ms := maxi(0, last_ping_ms >> 1)
	if owner_is_local:
		advance_ms += maxi(0, lag_comp_ms)
	return advance_ms

func build_server_shot(
	player: NetPlayer,
	_input_state: Dictionary,
	next_projectile_id: int,
	max_reported_rtt_ms: int,
	_world_2d: World2D
) -> Dictionary:
	var reported_rtt_ms := 0
	var lag_comp_ms := clampi(reported_rtt_ms >> 1, 0, max_reported_rtt_ms >> 1)
	return {
		"projectile_id": next_projectile_id,
		"spawn_position": player.global_position,
		"velocity": Vector2.ZERO,
		"lag_comp_ms": lag_comp_ms,
		"trail_origin": player.global_position,
		"shot_damage": base_damage()
	}

func build_server_shots(
	player: NetPlayer,
	input_state: Dictionary,
	next_projectile_id: int,
	max_reported_rtt_ms: int,
	world_2d: World2D
) -> Array:
	return [
		build_server_shot(
			player,
			input_state,
			next_projectile_id,
			max_reported_rtt_ms,
			world_2d
		)
	]
