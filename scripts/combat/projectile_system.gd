extends RefCounted
class_name ProjectileSystem

var projectiles_root: Node2D
var projectile_scene: PackedScene
var resolve_owner_color: Callable = Callable()
var projectiles: Dictionary = {}
var projectile_lobby_by_id: Dictionary = {}
var projectile_damage_by_id: Dictionary = {}
var projectile_weapon_name_by_id: Dictionary = {}
var next_projectile_id: int = 1

func configure(root: Node2D, scene: PackedScene, color_callback: Callable) -> void:
	projectiles_root = root
	projectile_scene = scene
	resolve_owner_color = color_callback

func reset() -> void:
	clear()
	next_projectile_id = 1

func clear() -> void:
	for value in projectiles.values():
		var projectile := value as NetProjectile
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()
	projectile_lobby_by_id.clear()
	projectile_damage_by_id.clear()
	projectile_weapon_name_by_id.clear()

func fire_from_weapon(
	owner_peer_id: int,
	player: NetPlayer,
	input_state: Dictionary,
	weapon: WeaponProfile,
	max_reported_rtt_ms: int,
	world_2d: World2D,
	lobby_id: int
) -> Dictionary:
	if weapon == null:
		return {}
	var shot_data := weapon.build_server_shot(
		player,
		input_state,
		next_projectile_id,
		max_reported_rtt_ms,
		world_2d
	)
	var projectile_id := int(shot_data.get("projectile_id", next_projectile_id))
	next_projectile_id = maxi(next_projectile_id, projectile_id + 1)
	var spawn_position := shot_data.get("spawn_position", player.global_position) as Vector2
	var velocity := shot_data.get("velocity", Vector2.ZERO) as Vector2
	var lag_comp_ms := int(shot_data.get("lag_comp_ms", 0))
	var trail_origin := shot_data.get("trail_origin", spawn_position) as Vector2
	var shot_damage := int(shot_data.get("shot_damage", weapon.base_damage()))

	var projectile := spawn_projectile(
		projectile_id,
		owner_peer_id,
		spawn_position,
		velocity,
		lag_comp_ms,
		trail_origin,
		weapon
	)
	if projectile == null:
		return {}

	projectile_lobby_by_id[projectile_id] = lobby_id
	projectile_damage_by_id[projectile_id] = shot_damage
	projectile_weapon_name_by_id[projectile_id] = weapon.weapon_name()
	return {
		"projectile_id": projectile_id,
		"spawn_position": spawn_position,
		"velocity": velocity,
		"lag_comp_ms": lag_comp_ms,
		"trail_origin": trail_origin,
		"shot_damage": shot_damage
	}

func spawn_projectile(
	projectile_id: int,
	owner_peer_id: int,
	spawn_position: Vector2,
	velocity: Vector2,
	lag_comp_ms: int,
	trail_origin: Vector2,
	weapon: WeaponProfile = null
) -> NetProjectile:
	if projectiles.has(projectile_id):
		return projectiles[projectile_id] as NetProjectile
	if projectile_scene == null or projectiles_root == null:
		return null

	var projectile := projectile_scene.instantiate() as NetProjectile
	if projectile == null:
		return null

	projectile.global_position = spawn_position
	projectiles_root.add_child(projectile)
	var visual_config := {}
	var hit_radius := 8.0
	var life_time := 2.0
	if weapon != null:
		visual_config = weapon.projectile_visual_config()
		hit_radius = weapon.projectile_hit_radius()
		life_time = weapon.projectile_lifetime()
	projectile.configure(
		_owner_color(owner_peer_id),
		velocity,
		projectile_id,
		owner_peer_id,
		lag_comp_ms,
		trail_origin,
		visual_config,
		hit_radius,
		life_time
	)
	projectiles[projectile_id] = projectile
	return projectile

func get_projectile(projectile_id: int) -> NetProjectile:
	return projectiles.get(projectile_id, null) as NetProjectile

func get_projectile_lobby(projectile_id: int, fallback_lobby_id: int = 0) -> int:
	return int(projectile_lobby_by_id.get(projectile_id, fallback_lobby_id))

func get_projectile_damage(projectile_id: int, fallback_damage: int) -> int:
	return int(projectile_damage_by_id.get(projectile_id, fallback_damage))

func mark_impact(projectile_id: int, impact_position: Vector2) -> Dictionary:
	var projectile := get_projectile(projectile_id)
	if projectile == null:
		return {}
	var trail_start_position: Vector2 = projectile.get_trail_origin()
	projectile.mark_impact(impact_position, trail_start_position)
	return {"trail_start_position": trail_start_position}

func mark_impact_with_trail(projectile_id: int, impact_position: Vector2, trail_start_position: Vector2) -> bool:
	var projectile := get_projectile(projectile_id)
	if projectile == null:
		return false
	projectile.mark_impact(impact_position, trail_start_position)
	return true

func despawn_local(projectile_id: int) -> void:
	if not projectiles.has(projectile_id):
		projectile_lobby_by_id.erase(projectile_id)
		projectile_damage_by_id.erase(projectile_id)
		projectile_weapon_name_by_id.erase(projectile_id)
		return
	var projectile := projectiles[projectile_id] as NetProjectile
	if is_instance_valid(projectile):
		projectile.queue_free()
	projectiles.erase(projectile_id)
	projectile_lobby_by_id.erase(projectile_id)
	projectile_damage_by_id.erase(projectile_id)
	projectile_weapon_name_by_id.erase(projectile_id)

func request_despawn(projectile_id: int, on_despawn: Callable = Callable()) -> void:
	var lobby_id := get_projectile_lobby(projectile_id, 0)
	if on_despawn.is_valid():
		on_despawn.call(projectile_id, lobby_id)
	despawn_local(projectile_id)

func server_tick(
	delta: float,
	get_owner_lobby_cb: Callable,
	world_hit_cb: Callable,
	player_hit_cb: Callable,
	on_player_hit_cb: Callable,
	on_wall_hit_cb: Callable,
	on_impact_cb: Callable,
	on_despawn_cb: Callable
) -> void:
	var ids := projectiles.keys()
	ids.sort()
	for id_value in ids:
		var projectile_id := int(id_value)
		var projectile := get_projectile(projectile_id)
		if projectile == null:
			continue

		var previous_position := projectile.global_position
		projectile.step(delta)
		if not projectile.can_deal_damage():
			if projectile.is_expired():
				request_despawn(projectile_id, on_despawn_cb)
			continue

		var fallback_lobby := 0
		if get_owner_lobby_cb.is_valid():
			fallback_lobby = int(get_owner_lobby_cb.call(projectile.owner_peer_id))
		var projectile_lobby_id := get_projectile_lobby(projectile_id, fallback_lobby)
		var to_position := projectile.global_position
		var wall_hit: Dictionary = {}
		var player_hit: Dictionary = {}
		if world_hit_cb.is_valid():
			wall_hit = world_hit_cb.call(previous_position, to_position) as Dictionary
		if player_hit_cb.is_valid():
			player_hit = player_hit_cb.call(projectile, previous_position, to_position, projectile_lobby_id) as Dictionary

		var wall_t := 2.0
		var player_t := 2.0
		if not wall_hit.is_empty():
			wall_t = float(wall_hit.get("t", 2.0))
		if not player_hit.is_empty():
			player_t = float(player_hit.get("t", 2.0))

		if not player_hit.is_empty() and player_t <= wall_t:
			var hit_position: Vector2 = player_hit.get("position", to_position) as Vector2
			projectile.global_position = hit_position
			var impact_velocity := projectile.velocity
			var target_peer_id := int(player_hit.get("peer_id", -1))
			if on_player_hit_cb.is_valid():
				on_player_hit_cb.call(projectile_id, target_peer_id, hit_position, impact_velocity, projectile_lobby_id)
			_mark_impact_and_emit(projectile_id, projectile_lobby_id, hit_position, on_impact_cb)
			continue

		if not wall_hit.is_empty():
			var wall_position: Vector2 = wall_hit.get("position", to_position) as Vector2
			var wall_impact_velocity := projectile.velocity
			projectile.global_position = wall_position
			if on_wall_hit_cb.is_valid():
				on_wall_hit_cb.call(projectile_id, wall_position, wall_impact_velocity, projectile_lobby_id)
			_mark_impact_and_emit(projectile_id, projectile_lobby_id, wall_position, on_impact_cb)
			continue

		if projectile.is_expired():
			request_despawn(projectile_id, on_despawn_cb)

func client_tick(delta: float) -> void:
	var expired_ids: Array = []
	for value in projectiles.values():
		var projectile := value as NetProjectile
		if projectile == null:
			continue
		projectile.step(delta)
		if projectile.is_expired():
			expired_ids.append(projectile.projectile_id)

	for id_value in expired_ids:
		despawn_local(int(id_value))

func _mark_impact_and_emit(projectile_id: int, lobby_id: int, impact_position: Vector2, on_impact_cb: Callable) -> void:
	var impact_data := mark_impact(projectile_id, impact_position)
	if impact_data.is_empty():
		return
	if on_impact_cb.is_valid():
		on_impact_cb.call(
			projectile_id,
			lobby_id,
			impact_position,
			impact_data.get("trail_start_position", impact_position) as Vector2
		)

func _owner_color(owner_peer_id: int) -> Color:
	if resolve_owner_color.is_valid():
		return resolve_owner_color.call(owner_peer_id) as Color
	return Color.WHITE
