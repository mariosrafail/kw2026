extends Skill

const SINK_TOXIC_TRAIL_VFX := preload("res://scripts/warriors/vfx/sink_toxic_trail_vfx.gd")

const CHARACTER_ID_SINK := "sink"
const STATUS_TEXT := "Toxic Wake"
const START_VISUAL_SENTINEL_X := -88001.0
const ACTIVE_DURATION_SEC := 4.8
const CLOUD_LIFETIME_SEC := 1.65
const CLOUD_EMIT_INTERVAL_SEC := 0.18
const CLOUD_RADIUS_PX := 44.0
const BURN_DURATION_SEC := 2.6
const BURN_TICK_DAMAGE := 2
const BURN_TICK_SEC := 0.42
const CLOUD_TARGET_REAPPLY_SEC := 0.55
const DEFAULT_TOXIC_COLOR := Color(0.41, 1.0, 0.38, 1.0)

var character_id_for_peer_cb: Callable = Callable()
var skill_color_for_peer_cb: Callable = Callable()

var _active_until_msec_by_peer: Dictionary = {}
var _emit_accumulator_by_peer: Dictionary = {}
var _clouds: Array = []

func _init() -> void:
	super._init("sink_toxic_wake", "Toxic Wake", 0.0, "Leaves behind a toxic gas trail that burns enemies over time")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skill_color_for_peer_cb = callbacks.get("skill_color_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_SINK:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	_active_until_msec_by_peer[caster_peer_id] = Time.get_ticks_msec() + int(ACTIVE_DURATION_SEC * 1000.0)
	_emit_accumulator_by_peer[caster_peer_id] = 0.0
	_spawn_cloud(caster_peer_id, lobby_id, caster.global_position)
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, Vector2(START_VISUAL_SENTINEL_X, ACTIVE_DURATION_SEC))

func _execute_client_visual(caster_peer_id: int, payload: Vector2) -> void:
	if is_equal_approx(payload.x, START_VISUAL_SENTINEL_X):
		var player := players.get(caster_peer_id, null) as NetPlayer
		if player != null and player.has_method("start_ulti_duration_bar"):
			player.call("start_ulti_duration_bar", maxf(0.05, payload.y), STATUS_TEXT)
		return
	_spawn_client_cloud_vfx(caster_peer_id, payload)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now_msec := Time.get_ticks_msec()
	_prune_expired_clouds(now_msec)
	if not _active_until_msec_by_peer.is_empty():
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
			var accumulator := float(_emit_accumulator_by_peer.get(caster_peer_id, 0.0)) + maxf(0.0, delta)
			while accumulator >= CLOUD_EMIT_INTERVAL_SEC:
				accumulator -= CLOUD_EMIT_INTERVAL_SEC
				_spawn_cloud(caster_peer_id, lobby_id, caster.global_position)
			_emit_accumulator_by_peer[caster_peer_id] = accumulator
		for caster_peer_id in expired_casters:
			_active_until_msec_by_peer.erase(caster_peer_id)
			_emit_accumulator_by_peer.erase(caster_peer_id)
	_apply_cloud_burns(now_msec)

func _spawn_cloud(caster_peer_id: int, lobby_id: int, world_position: Vector2) -> void:
	var cloud := {
		"caster_peer_id": caster_peer_id,
		"lobby_id": lobby_id,
		"position": world_position,
		"radius": CLOUD_RADIUS_PX,
		"expire_msec": Time.get_ticks_msec() + int(CLOUD_LIFETIME_SEC * 1000.0),
		"next_apply_by_target": {},
	}
	_clouds.append(cloud)
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, world_position)

func _prune_expired_clouds(now_msec: int) -> void:
	if _clouds.is_empty():
		return
	var keep: Array = []
	for cloud_value in _clouds:
		if not (cloud_value is Dictionary):
			continue
		var cloud := cloud_value as Dictionary
		if int(cloud.get("expire_msec", 0)) > now_msec:
			keep.append(cloud)
	_clouds = keep

func _apply_cloud_burns(now_msec: int) -> void:
	if _clouds.is_empty():
		return
	for cloud_value in _clouds:
		if not (cloud_value is Dictionary):
			continue
		var cloud := cloud_value as Dictionary
		var caster_peer_id := int(cloud.get("caster_peer_id", 0))
		var lobby_id := int(cloud.get("lobby_id", 0))
		var center := cloud.get("position", Vector2.ZERO) as Vector2
		var radius := maxf(12.0, float(cloud.get("radius", CLOUD_RADIUS_PX)))
		var next_apply_by_target := cloud.get("next_apply_by_target", {}) as Dictionary
		for peer_value in players.keys():
			var target_peer_id := int(peer_value)
			if target_peer_id == caster_peer_id:
				continue
			if _get_peer_lobby(target_peer_id) != lobby_id:
				continue
			if not _can_affect_target(caster_peer_id, target_peer_id):
				continue
			var target := players.get(target_peer_id, null) as NetPlayer
			if target == null or target.get_health() <= 0:
				continue
			if target.global_position.distance_to(center) > radius:
				continue
			var next_apply_msec := int(next_apply_by_target.get(target_peer_id, 0))
			if next_apply_msec > now_msec:
				continue
			if debuff_service != null and debuff_service.has_method("apply_debuff"):
				debuff_service.call(
					"apply_debuff",
					target_peer_id,
					"burn",
					BURN_DURATION_SEC,
					caster_peer_id,
					{"tick_damage": BURN_TICK_DAMAGE, "tick_sec": BURN_TICK_SEC}
				)
			next_apply_by_target[target_peer_id] = now_msec + int(CLOUD_TARGET_REAPPLY_SEC * 1000.0)
		cloud["next_apply_by_target"] = next_apply_by_target

func _spawn_client_cloud_vfx(caster_peer_id: int, world_position: Vector2) -> void:
	var host := _vfx_host_node()
	if host == null:
		return
	var vfx := SINK_TOXIC_TRAIL_VFX.new()
	vfx.name = "SinkToxicTrail_%d_%d" % [caster_peer_id, Time.get_ticks_msec()]
	vfx.global_position = world_position
	vfx.duration_sec = CLOUD_LIFETIME_SEC
	vfx.base_radius_px = CLOUD_RADIUS_PX
	vfx.toxic_color = _skill_color_for_peer(caster_peer_id)
	host.add_child(vfx)

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
	return CHARACTER_ID_SINK

func _skill_color_for_peer(peer_id: int) -> Color:
	if skill_color_for_peer_cb.is_valid():
		var value: Variant = skill_color_for_peer_cb.call(peer_id)
		if value is Color:
			return value as Color
	return DEFAULT_TOXIC_COLOR
