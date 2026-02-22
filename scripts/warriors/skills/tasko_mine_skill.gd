## Tasko Skill 2 (E): Mine
## Drops a mine on the ground (persists forever). If an enemy touches it, it explodes and deals 50 damage.
##
## Networking:
## - Cast broadcasts skill2 with the mine world position (clients spawn).
## - Explosion broadcasts skill2 again with same position (clients interpret as explode if mine exists).

extends Skill

const MINE_DAMAGE := 50
const TRIGGER_RADIUS_PX := 22.0
const MINE_DROP_RAY_LEN := 2500.0
const MINE_GROUND_MASK := 1

const MINE_COLOR := Color(1.0, 0.35, 0.85, 0.95)

var _mines: Array = []
var _client_mines_by_key: Dictionary = {}

func _init() -> void:
	super._init("tasko_mine", "Mine", 7.0, "Drop a persistent mine that explodes on contact")

func _execute_cast(caster_peer_id: int, target_world: Vector2) -> void:
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var mine_pos := _drop_position(caster)

	_mines.append({
		"caster_peer_id": caster_peer_id,
		"lobby_id": lobby_id,
		"pos": mine_pos
	})

	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, mine_pos)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	# If mine at this position exists, explode it. Otherwise, spawn it.
	var key := _mine_key(target_world)
	if _client_mines_by_key.has(key):
		var node := _client_mines_by_key.get(key, null) as TaskoMineVfx
		_client_mines_by_key.erase(key)
		if node != null and is_instance_valid(node):
			node.explode()
		return
	_spawn_mine_vfx(target_world, key)

func server_tick(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _mines.is_empty():
		return

	for idx in range(_mines.size() - 1, -1, -1):
		var mine := _mines[idx] as Dictionary
		var caster_peer_id := int(mine.get("caster_peer_id", 0))
		var lobby_id := int(mine.get("lobby_id", 0))
		var pos := mine.get("pos", Vector2.ZERO) as Vector2
		if lobby_id <= 0:
			_mines.remove_at(idx)
			continue

		for member_value in _get_lobby_members(lobby_id):
			var target_peer_id := int(member_value)
			if target_peer_id <= 0 or target_peer_id == caster_peer_id:
				continue
			var target := players.get(target_peer_id, null) as NetPlayer
			if target == null:
				continue
			if target.get_health() <= 0:
				continue
			if target.global_position.distance_to(pos) > TRIGGER_RADIUS_PX:
				continue

			if hit_damage_resolver != null and hit_damage_resolver.has_method("server_apply_direct_damage"):
				hit_damage_resolver.server_apply_direct_damage(caster_peer_id, target_peer_id, target, MINE_DAMAGE)

			_mines.remove_at(idx)
			for notify_value in _get_lobby_members(lobby_id):
				if send_skill_cast_cb.is_valid():
					send_skill_cast_cb.call(int(notify_value), 2, caster_peer_id, pos)
			break

func _spawn_mine_vfx(world_position: Vector2, key: Vector2i) -> void:
	if projectile_system == null or projectile_system.projectiles_root == null:
		return
	var node := TaskoMineVfx.new()
	node.name = "TaskoMine_%d_%d" % [key.x, key.y]
	node.color = MINE_COLOR
	node.global_position = world_position
	projectile_system.projectiles_root.add_child(node)
	_client_mines_by_key[key] = node

func _mine_key(world_position: Vector2) -> Vector2i:
	return Vector2i(roundi(world_position.x), roundi(world_position.y))

func _drop_position(caster: NetPlayer) -> Vector2:
	if caster == null:
		return Vector2.ZERO
	var world := caster.get_world_2d()
	if world == null:
		return caster.global_position
	var state := world.direct_space_state
	var from := caster.global_position
	var to := from + Vector2.DOWN * MINE_DROP_RAY_LEN
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.collision_mask = MINE_GROUND_MASK
	params.collide_with_areas = false
	params.collide_with_bodies = true
	var hit: Dictionary = state.intersect_ray(params)
	if hit.is_empty():
		return caster.global_position
	var hit_pos := hit.get("position", caster.global_position) as Vector2
	return hit_pos + Vector2(0.0, -10.0)
