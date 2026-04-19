extends Skill

const AGELIKOULA_BLOCKS_VFX := preload("res://scripts/warriors/vfx/agelikoula_blocks_vfx.gd")

const CHARACTER_ID_AGELIKOULA := "agelikoula"
const STATUS_TEXT := "Block Burst"
const ACTIVE_DURATION_SEC := 5.0
const EMIT_INTERVAL_SEC := 0.095
const BLOCKS_PER_TICK := 3
const BLOCK_RANGE_PX := 304.0
const BLOCK_HIT_RADIUS_PX := 20.0
const BLOCK_DAMAGE := 6
const STUN_DURATION_SEC := 0.36
const HIT_VISUAL_EVENT_SENTINEL := -66666.0
const SAME_TARGET_HIT_COOLDOWN_MSEC := 220
const BLOCK_PROJECTILE_SPEED_MIN := 220.0
const BLOCK_PROJECTILE_SPEED_MAX := 420.0
const BLOCK_PROJECTILE_GRAVITY := 980.0
const BLOCK_PROJECTILE_LIFETIME_SEC := 0.85
const BLOCK_SPAWN_OFFSET := Vector2(0.0, -16.0)

var character_id_for_peer_cb: Callable = Callable()
var skill_color_for_peer_cb: Callable = Callable()

var _active_until_msec_by_peer: Dictionary = {}
var _emit_tick_accumulator_by_peer: Dictionary = {}
var _recent_hit_msec_by_pair: Dictionary = {}
var _client_vfx_by_caster: Dictionary = {}
var _server_projectiles: Array = []
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	super._init("agelikoula_block_burst", "Block Burst", 0.0, "Throws pixel blocks in all directions for 5 seconds, dealing damage and short stun")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skill_color_for_peer_cb = callbacks.get("skill_color_for_peer", Callable()) as Callable
	_rng.seed = int(Time.get_ticks_usec()) ^ 0xA6319

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_AGELIKOULA:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var until_msec := Time.get_ticks_msec() + int(ACTIVE_DURATION_SEC * 1000.0)
	_active_until_msec_by_peer[caster_peer_id] = until_msec
	_emit_tick_accumulator_by_peer[caster_peer_id] = 0.0
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, Vector2(ACTIVE_DURATION_SEC, BLOCK_RANGE_PX))

func _execute_client_visual(caster_peer_id: int, payload: Vector2) -> void:
	if is_equal_approx(payload.x, HIT_VISUAL_EVENT_SENTINEL):
		_apply_client_hit_visual(caster_peer_id, payload)
		return
	var duration_sec := maxf(0.05, payload.x if absf(payload.x) > 0.0001 else ACTIVE_DURATION_SEC)
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster != null and caster.has_method("start_ulti_duration_bar"):
		caster.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)
	_spawn_or_refresh_client_vfx(caster_peer_id, duration_sec)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now_msec := Time.get_ticks_msec()
	_prune_recent_hits(now_msec)
	_tick_server_projectiles(maxf(0.0, delta), now_msec)
	if _active_until_msec_by_peer.is_empty():
		return
	var expired_casters: Array[int] = []
	for caster_value in _active_until_msec_by_peer.keys():
		var caster_peer_id := int(caster_value)
		var until_msec := int(_active_until_msec_by_peer.get(caster_peer_id, 0))
		if until_msec <= now_msec:
			expired_casters.append(caster_peer_id)
			continue
		var caster := players.get(caster_peer_id, null) as NetPlayer
		if caster == null or caster.get_health() <= 0:
			expired_casters.append(caster_peer_id)
			continue
		var accumulator := float(_emit_tick_accumulator_by_peer.get(caster_peer_id, 0.0)) + maxf(0.0, delta)
		while accumulator >= EMIT_INTERVAL_SEC:
			accumulator -= EMIT_INTERVAL_SEC
			_emit_block_burst(caster_peer_id)
		_emit_tick_accumulator_by_peer[caster_peer_id] = accumulator
	for caster_peer_id in expired_casters:
		_active_until_msec_by_peer.erase(caster_peer_id)
		_emit_tick_accumulator_by_peer.erase(caster_peer_id)

func _emit_block_burst(caster_peer_id: int) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var origin := caster.global_position + BLOCK_SPAWN_OFFSET
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	for _i in range(BLOCKS_PER_TICK):
		var angle := _rng.randf_range(-PI, PI)
		var speed := _rng.randf_range(BLOCK_PROJECTILE_SPEED_MIN, BLOCK_PROJECTILE_SPEED_MAX)
		var velocity := Vector2.RIGHT.rotated(angle) * speed
		_server_projectiles.append({
			"caster_peer_id": caster_peer_id,
			"lobby_id": lobby_id,
			"origin": origin,
			"position": origin,
			"prev_position": origin,
			"velocity": velocity,
			"age": 0.0,
			"life": BLOCK_PROJECTILE_LIFETIME_SEC,
		})

func _tick_server_projectiles(delta: float, now_msec: int) -> void:
	if _server_projectiles.is_empty():
		return
	var remaining: Array = []
	for projectile_value in _server_projectiles:
		if not (projectile_value is Dictionary):
			continue
		var projectile := projectile_value as Dictionary
		var caster_peer_id := int(projectile.get("caster_peer_id", 0))
		var lobby_id := int(projectile.get("lobby_id", 0))
		var caster := players.get(caster_peer_id, null) as NetPlayer
		if caster == null or caster.get_health() <= 0:
			continue

		var age := float(projectile.get("age", 0.0)) + delta
		var life := float(projectile.get("life", BLOCK_PROJECTILE_LIFETIME_SEC))
		if age >= life:
			continue

		var prev_position := projectile.get("position", Vector2.ZERO) as Vector2
		var velocity := projectile.get("velocity", Vector2.ZERO) as Vector2
		velocity.y += BLOCK_PROJECTILE_GRAVITY * delta
		var position := prev_position + velocity * delta
		var origin := projectile.get("origin", position) as Vector2
		if origin.distance_to(position) > BLOCK_RANGE_PX:
			continue

		projectile["prev_position"] = prev_position
		projectile["position"] = position
		projectile["velocity"] = velocity
		projectile["age"] = age

		var hit_target_peer_id := _find_projectile_hit_target(projectile, caster_peer_id, lobby_id, now_msec)
		if hit_target_peer_id != 0:
			_apply_block_hit(caster_peer_id, hit_target_peer_id, lobby_id, now_msec)
			continue

		remaining.append(projectile)
	_server_projectiles = remaining

func _find_projectile_hit_target(projectile: Dictionary, caster_peer_id: int, lobby_id: int, now_msec: int) -> int:
	var from_pos := projectile.get("prev_position", Vector2.ZERO) as Vector2
	var to_pos := projectile.get("position", from_pos) as Vector2
	var best_peer_id := 0
	var best_distance := INF
	for peer_value in players.keys():
		var target_peer_id := int(peer_value)
		if not _is_valid_target(caster_peer_id, target_peer_id, lobby_id):
			continue
		var pair_key := "%d:%d" % [caster_peer_id, target_peer_id]
		var last_hit_msec := int(_recent_hit_msec_by_pair.get(pair_key, 0))
		if now_msec - last_hit_msec < SAME_TARGET_HIT_COOLDOWN_MSEC:
			continue
		var target := players.get(target_peer_id, null) as NetPlayer
		if target == null:
			continue
		var target_pos := target.global_position + Vector2(0.0, -10.0)
		var distance := _distance_point_to_segment(target_pos, from_pos, to_pos)
		if distance <= BLOCK_HIT_RADIUS_PX and distance < best_distance:
			best_distance = distance
			best_peer_id = target_peer_id
	return best_peer_id

func _apply_block_hit(caster_peer_id: int, target_peer_id: int, lobby_id: int, now_msec: int) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	var target := players.get(target_peer_id, null) as NetPlayer
	if caster == null or target == null:
		return
	if caster.get_health() <= 0 or target.get_health() <= 0:
		return
	if not _is_valid_target(caster_peer_id, target_peer_id, lobby_id):
		return
	var pair_key := "%d:%d" % [caster_peer_id, target_peer_id]
	_recent_hit_msec_by_pair[pair_key] = now_msec
	if hit_damage_resolver != null and hit_damage_resolver.has_method("server_apply_direct_damage"):
		hit_damage_resolver.server_apply_direct_damage(caster_peer_id, target_peer_id, target, BLOCK_DAMAGE, target.global_position - caster.global_position)
	if debuff_service != null and debuff_service.has_method("apply_debuff"):
		debuff_service.call("apply_debuff", target_peer_id, "stun", STUN_DURATION_SEC, caster_peer_id)
	var payload := Vector2(HIT_VISUAL_EVENT_SENTINEL, float(target_peer_id))
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, payload)

func _distance_point_to_segment(point: Vector2, seg_a: Vector2, seg_b: Vector2) -> float:
	var ab := seg_b - seg_a
	var ab_len_sq := ab.length_squared()
	if ab_len_sq <= 0.00001:
		return point.distance_to(seg_a)
	var t := clampf((point - seg_a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest := seg_a + ab * t
	return point.distance_to(closest)

func _is_valid_target(caster_peer_id: int, target_peer_id: int, lobby_id: int) -> bool:
	if target_peer_id == caster_peer_id:
		return false
	if lobby_id <= 0 or _get_peer_lobby(target_peer_id) != lobby_id:
		return false
	if not _can_affect_target(caster_peer_id, target_peer_id):
		return false
	var target := players.get(target_peer_id, null) as NetPlayer
	if target == null or target.get_health() <= 0:
		return false
	return true

func _can_affect_target(caster_peer_id: int, target_peer_id: int) -> bool:
	if target_peer_id == caster_peer_id:
		return false
	var tree := _scene_tree()
	var root := tree.current_scene if tree != null else null
	if root != null and root.has_method("_ctf_enabled") and bool(root.call("_ctf_enabled")):
		if root.has_method("_team_for_peer"):
			var caster_team := int(root.call("_team_for_peer", caster_peer_id))
			var target_team := int(root.call("_team_for_peer", target_peer_id))
			if caster_team >= 0 and caster_team == target_team:
				return false
	return true

func _spawn_or_refresh_client_vfx(caster_peer_id: int, duration_sec: float) -> void:
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
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var vfx := AGELIKOULA_BLOCKS_VFX.new()
	vfx.name = "AgelikoulaBlocks_%d" % caster_peer_id
	vfx.source_player = caster
	vfx.duration_sec = duration_sec
	vfx.effect_color = _skill_color_for_peer(caster_peer_id)
	host.add_child(vfx)
	_client_vfx_by_caster[caster_peer_id] = vfx

func _apply_client_hit_visual(caster_peer_id: int, payload: Vector2) -> void:
	var target_peer_id := _resolve_target_peer_id_from_payload(payload.y)
	var target := players.get(target_peer_id, null) as NetPlayer
	if target == null:
		return
	var vfx := _client_vfx_by_caster.get(caster_peer_id, null) as Node
	if vfx == null or not is_instance_valid(vfx):
		_spawn_or_refresh_client_vfx(caster_peer_id, ACTIVE_DURATION_SEC)
		vfx = _client_vfx_by_caster.get(caster_peer_id, null) as Node
	if vfx != null and is_instance_valid(vfx) and vfx.has_method("spawn_targeted_block"):
		vfx.call("spawn_targeted_block", target)
	if target.has_method("set_petrified_visual"):
		target.call("set_petrified_visual", STUN_DURATION_SEC)

func _resolve_target_peer_id_from_payload(encoded_peer_value: float) -> int:
	var rounded_peer_id := int(round(encoded_peer_value))
	if players.has(rounded_peer_id):
		return rounded_peer_id
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if is_equal_approx(float(peer_id), encoded_peer_value):
			return peer_id
	return rounded_peer_id

func _prune_recent_hits(now_msec: int) -> void:
	if _recent_hit_msec_by_pair.is_empty():
		return
	var expired: Array = []
	for key in _recent_hit_msec_by_pair.keys():
		var at_msec := int(_recent_hit_msec_by_pair.get(key, 0))
		if now_msec - at_msec > 1500:
			expired.append(key)
	for key in expired:
		_recent_hit_msec_by_pair.erase(key)

func _vfx_host_node() -> Node:
	if projectile_system != null and projectile_system.projectiles_root != null:
		return projectile_system.projectiles_root
	var tree := _scene_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root

func _scene_tree() -> SceneTree:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return loop as SceneTree
	return null

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_AGELIKOULA

func _skill_color_for_peer(peer_id: int) -> Color:
	if skill_color_for_peer_cb.is_valid():
		var value: Variant = skill_color_for_peer_cb.call(peer_id)
		if value is Color:
			return value as Color
	return Color(0.95, 0.74, 0.33, 1.0)
