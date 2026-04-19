extends Skill

const WOMAN_HEEL_ORBIT_VFX := preload("res://scripts/warriors/vfx/woman_heel_orbit_vfx.gd")

const CHARACTER_ID_WOMAN := "woman"
const STATUS_TEXT := "Heel Halo"
const ACTIVE_DURATION_SEC := 5.0
const ORBIT_HEEL_COUNT := 3
const ORBIT_RADIUS_PX := 54.0
const HEEL_HIT_RADIUS_PX := 24.0
const ORBIT_ANGULAR_SPEED := TAU * 1.18
const ORBIT_START_OFFSET := -PI * 0.5
const HEEL_DAMAGE := 5
const STUN_DURATION_SEC := 1.0
const SAME_TARGET_HIT_COOLDOWN_MSEC := 420
const VISUAL_PAYLOAD_SENTINEL := -77123.0
const DEFAULT_SKILL_COLOR := Color(1.0, 0.31, 0.73, 1.0)

var character_id_for_peer_cb: Callable = Callable()
var skill_color_for_peer_cb: Callable = Callable()

var _active_until_msec_by_peer: Dictionary = {}
var _recent_hit_msec_by_pair: Dictionary = {}
var _client_vfx_by_caster: Dictionary = {}

func _init() -> void:
	super._init("woman_heel_halo", "Heel Halo", 0.0, "Her heel orbits around her for 5 seconds, stunning and damaging enemies it touches")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skill_color_for_peer_cb = callbacks.get("skill_color_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_WOMAN:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null or caster.get_health() <= 0:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	_active_until_msec_by_peer[caster_peer_id] = Time.get_ticks_msec() + int(ACTIVE_DURATION_SEC * 1000.0)
	var payload := Vector2(VISUAL_PAYLOAD_SENTINEL, ACTIVE_DURATION_SEC)
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, payload)

func _execute_client_visual(caster_peer_id: int, payload: Vector2) -> void:
	if not is_equal_approx(payload.x, VISUAL_PAYLOAD_SENTINEL):
		return
	var duration_sec := maxf(0.05, payload.y)
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster != null and caster.has_method("start_ulti_duration_bar"):
		caster.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)
	_spawn_or_refresh_client_vfx(caster_peer_id, duration_sec)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now_msec := Time.get_ticks_msec()
	_prune_recent_hits(now_msec)
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
		var lobby_id := _get_peer_lobby(caster_peer_id)
		if lobby_id <= 0:
			expired_casters.append(caster_peer_id)
			continue
		var heel_positions := _heel_world_positions(caster_peer_id, now_msec)
		_apply_orbit_hits(caster_peer_id, lobby_id, heel_positions, now_msec)
	for caster_peer_id in expired_casters:
		_active_until_msec_by_peer.erase(caster_peer_id)

func _apply_orbit_hits(caster_peer_id: int, lobby_id: int, heel_positions: Array[Vector2], now_msec: int) -> void:
	if heel_positions.is_empty():
		return
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
		var target_center := target.global_position + Vector2(0.0, -10.0)
		var hit_origin := Vector2.ZERO
		var was_hit := false
		for heel_position in heel_positions:
			if target_center.distance_to(heel_position) <= HEEL_HIT_RADIUS_PX:
				hit_origin = heel_position
				was_hit = true
				break
		if not was_hit:
			continue
		_recent_hit_msec_by_pair[pair_key] = now_msec
		if hit_damage_resolver != null and hit_damage_resolver.has_method("server_apply_direct_damage"):
			hit_damage_resolver.server_apply_direct_damage(caster_peer_id, target_peer_id, target, HEEL_DAMAGE, target_center - hit_origin)
		if debuff_service != null and debuff_service.has_method("apply_debuff"):
			debuff_service.call("apply_debuff", target_peer_id, "stun", STUN_DURATION_SEC, caster_peer_id)

func _heel_world_positions(caster_peer_id: int, now_msec: int) -> Array[Vector2]:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return []
	var until_msec := int(_active_until_msec_by_peer.get(caster_peer_id, now_msec))
	var elapsed_sec := ACTIVE_DURATION_SEC - maxf(0.0, float(until_msec - now_msec) / 1000.0)
	var orbit_center := caster.global_position + Vector2(0.0, -20.0)
	var base_orbit_angle := ORBIT_START_OFFSET + elapsed_sec * ORBIT_ANGULAR_SPEED
	var positions: Array[Vector2] = []
	for i in range(ORBIT_HEEL_COUNT):
		var phase := float(i) * TAU / float(ORBIT_HEEL_COUNT)
		positions.append(orbit_center + Vector2.RIGHT.rotated(base_orbit_angle + phase) * ORBIT_RADIUS_PX)
	return positions

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
	if root != null and root.has_method("_can_damage_peer"):
		return bool(root.call("_can_damage_peer", caster_peer_id, target_peer_id))
	if root != null and root.has_method("_is_enemy_target"):
		return bool(root.call("_is_enemy_target", caster_peer_id, target_peer_id))
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
	var vfx := WOMAN_HEEL_ORBIT_VFX.new()
	vfx.name = "WomanHeelOrbit_%d" % caster_peer_id
	vfx.source_player = caster
	vfx.duration_sec = duration_sec
	vfx.orbit_radius_px = ORBIT_RADIUS_PX
	vfx.angular_speed = ORBIT_ANGULAR_SPEED
	vfx.effect_color = _skill_color_for_peer(caster_peer_id)
	host.add_child(vfx)
	_client_vfx_by_caster[caster_peer_id] = vfx

func _prune_recent_hits(now_msec: int) -> void:
	if _recent_hit_msec_by_pair.is_empty():
		return
	var expired: Array = []
	for key in _recent_hit_msec_by_pair.keys():
		var at_msec := int(_recent_hit_msec_by_pair.get(key, 0))
		if now_msec - at_msec > 1600:
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
	return CHARACTER_ID_WOMAN

func _skill_color_for_peer(peer_id: int) -> Color:
	if skill_color_for_peer_cb.is_valid():
		var value: Variant = skill_color_for_peer_cb.call(peer_id)
		if value is Color:
			return value as Color
	return DEFAULT_SKILL_COLOR
