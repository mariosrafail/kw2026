extends Skill

const KROG_LASER_VFX := preload("res://scripts/warriors/vfx/krog_laser_vfx.gd")

const CHARACTER_ID_KROG := "krog"
const STATUS_TEXT := "Laser"
const LASER_DURATION_SEC := 5.0
const LASER_RANGE_PX := 3400.0
const LASER_WIDTH_PX := 13.5
const LASER_DAMAGE_PER_SECOND := 38.0
const LASER_DAMAGE_TICK_SEC := 0.1
const LASER_IMPACT_VELOCITY := 240.0
const EPSILON := 0.0001

var character_id_for_peer_cb: Callable = Callable()
var skill_color_for_peer_cb: Callable = Callable()

var _active_by_caster: Dictionary = {}
var _client_vfx_by_caster: Dictionary = {}

func _init() -> void:
	super._init("krog_laser", "Laser", 0.0, "Fires a continuous wall-stopping beam in the aim direction")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skill_color_for_peer_cb = callbacks.get("skill_color_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_KROG:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	_active_by_caster[caster_peer_id] = {
		"remaining": LASER_DURATION_SEC,
		"tick_accumulator": 0.0,
		"lobby_id": lobby_id
	}
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, target_world)

func _execute_client_visual(caster_peer_id: int, _target_world: Vector2) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster != null and caster.has_method("start_ulti_duration_bar"):
		caster.call("start_ulti_duration_bar", LASER_DURATION_SEC, STATUS_TEXT)
	_spawn_or_refresh_client_vfx(caster_peer_id)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _active_by_caster.is_empty():
		return

	var finished_casters: Array[int] = []
	for caster_value in _active_by_caster.keys():
		var caster_peer_id := int(caster_value)
		var state := _active_by_caster.get(caster_peer_id, {}) as Dictionary
		var remaining := maxf(0.0, float(state.get("remaining", 0.0)) - delta)
		if remaining <= 0.0:
			finished_casters.append(caster_peer_id)
			continue
		var tick_accumulator := float(state.get("tick_accumulator", 0.0)) + delta
		while tick_accumulator >= LASER_DAMAGE_TICK_SEC:
			tick_accumulator -= LASER_DAMAGE_TICK_SEC
			_apply_laser_damage_tick(caster_peer_id, int(state.get("lobby_id", 0)), LASER_DAMAGE_TICK_SEC)
		state["remaining"] = remaining
		state["tick_accumulator"] = tick_accumulator
		_active_by_caster[caster_peer_id] = state

	for caster_peer_id in finished_casters:
		_active_by_caster.erase(caster_peer_id)

func _apply_laser_damage_tick(caster_peer_id: int, lobby_id: int, tick_sec: float) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null or caster.get_health() <= 0:
		return
	if lobby_id <= 0:
		lobby_id = _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return

	var start_pos := _beam_start_for_player(caster)
	var aim_dir := _aim_direction_for_caster(caster_peer_id, caster, start_pos)
	if aim_dir.length_squared() <= EPSILON:
		return
	var trace := _trace_laser_hit(caster_peer_id, lobby_id, caster, start_pos, aim_dir)
	var end_pos := trace.get("end_pos", start_pos) as Vector2
	if end_pos.distance_squared_to(start_pos) <= EPSILON:
		return

	var base_damage := maxi(1, int(round(LASER_DAMAGE_PER_SECOND * tick_sec)))
	var hit_peer_id := int(trace.get("hit_peer_id", 0))
	if hit_peer_id <= 0:
		return
	var target := players.get(hit_peer_id, null) as NetPlayer
	if target == null or target.get_health() <= 0:
		return
	if hit_damage_resolver != null:
		hit_damage_resolver.server_apply_direct_damage(
			caster_peer_id,
			hit_peer_id,
			target,
			base_damage,
			aim_dir * LASER_IMPACT_VELOCITY
		)

func _spawn_or_refresh_client_vfx(caster_peer_id: int) -> void:
	var host := _vfx_host_node()
	if host == null:
		return
	var existing_value: Variant = _client_vfx_by_caster.get(caster_peer_id, null)
	if typeof(existing_value) == TYPE_OBJECT and is_instance_valid(existing_value):
		var existing := existing_value as Node
		if existing != null:
			existing.queue_free()
	else:
		_client_vfx_by_caster.erase(caster_peer_id)
	var vfx := KROG_LASER_VFX.new()
	vfx.name = "KrogLaser_%d" % caster_peer_id
	vfx.players = players
	vfx.caster_peer_id = caster_peer_id
	vfx.duration_sec = LASER_DURATION_SEC
	vfx.beam_color = _skill_color_for_peer(caster_peer_id)
	host.add_child(vfx)
	_client_vfx_by_caster[caster_peer_id] = vfx

func _vfx_host_node() -> Node:
	if projectile_system != null and projectile_system.projectiles_root != null:
		return projectile_system.projectiles_root
	var tree := _scene_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root

func _beam_start_for_player(player: NetPlayer) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var head_node := player.get_node_or_null("VisualRoot/head") as Node2D
	if head_node != null:
		return head_node.global_position
	return player.global_position + Vector2(0.0, -14.0)

func _aim_direction_for_caster(caster_peer_id: int, caster: NetPlayer, start_pos: Vector2) -> Vector2:
	var state := input_states.get(caster_peer_id, {}) as Dictionary
	if not state.is_empty() and state.has("aim_world"):
		var aim_world := state.get("aim_world", Vector2.ZERO) as Vector2
		var dir_from_state := aim_world - start_pos
		if dir_from_state.length_squared() > EPSILON:
			return dir_from_state.normalized()
	if caster != null and caster.has_method("get_aim_angle"):
		var angle := float(caster.call("get_aim_angle"))
		return Vector2.RIGHT.rotated(angle).normalized()
	return Vector2.RIGHT

func _trace_laser_endpoint(caster: NetPlayer, start_pos: Vector2, aim_dir: Vector2) -> Vector2:
	if caster == null:
		return start_pos + aim_dir * LASER_RANGE_PX
	var world := caster.get_world_2d()
	if world == null:
		return start_pos + aim_dir * LASER_RANGE_PX
	var end_pos := start_pos + aim_dir * LASER_RANGE_PX
	var query := PhysicsRayQueryParameters2D.create(start_pos, end_pos, 1)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = _ray_exclusions(caster)
	var hit := world.direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.get("position", end_pos) as Vector2
	return end_pos

func _trace_laser_hit(caster_peer_id: int, lobby_id: int, caster: NetPlayer, start_pos: Vector2, aim_dir: Vector2) -> Dictionary:
	var wall_end := _trace_laser_endpoint(caster, start_pos, aim_dir)
	var wall_dist := start_pos.distance_to(wall_end)
	var best_hit_dist := wall_dist + 1.0
	var hit_peer_id := 0
	for target_value in players.keys():
		var target_peer_id := int(target_value)
		if target_peer_id == caster_peer_id:
			continue
		if _get_peer_lobby(target_peer_id) != lobby_id:
			continue
		if not _can_damage_target(caster_peer_id, target_peer_id):
			continue
		var target := players.get(target_peer_id, null) as NetPlayer
		if target == null or target.get_health() <= 0:
			continue
		var target_center := target.global_position
		var along := (target_center - start_pos).dot(aim_dir)
		if along < 0.0 or along > wall_dist:
			continue
		var closest := start_pos + aim_dir * along
		var target_radius := target.get_hit_radius() if target.has_method("get_hit_radius") else 12.0
		var combined_radius := target_radius + LASER_WIDTH_PX
		var lateral := target_center.distance_to(closest)
		if lateral > combined_radius:
			continue
		var inside := maxf(0.0, combined_radius * combined_radius - lateral * lateral)
		var contact_dist := maxf(0.0, along - sqrt(inside))
		if contact_dist < best_hit_dist:
			best_hit_dist = contact_dist
			hit_peer_id = target_peer_id
	if hit_peer_id > 0:
		return {
			"end_pos": start_pos + aim_dir * best_hit_dist,
			"hit_peer_id": hit_peer_id,
		}
	return {
		"end_pos": wall_end,
		"hit_peer_id": 0,
	}

func _ray_exclusions(caster: NetPlayer) -> Array:
	var exclusions: Array = [caster]
	for player_value in players.values():
		var player := player_value as NetPlayer
		if player == null or player == caster:
			continue
		exclusions.append(player)
	return exclusions

func _can_damage_target(caster_peer_id: int, target_peer_id: int) -> bool:
	var tree := _scene_tree()
	var root := tree.current_scene if tree != null else null
	if root != null and root.has_method("_ctf_enabled") and bool(root.call("_ctf_enabled")):
		if root.has_method("_team_for_peer"):
			var caster_team := int(root.call("_team_for_peer", caster_peer_id))
			var target_team := int(root.call("_team_for_peer", target_peer_id))
			if caster_team >= 0 and target_team >= 0 and caster_team == target_team:
				return false
	return true

func _scene_tree() -> SceneTree:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return loop as SceneTree
	return null

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_KROG

func _skill_color_for_peer(peer_id: int) -> Color:
	if skill_color_for_peer_cb.is_valid():
		var value: Variant = skill_color_for_peer_cb.call(peer_id)
		if value is Color:
			return value as Color
	return Color(0.92, 0.28, 0.22, 1.0)
