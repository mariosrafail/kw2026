extends Skill

const RP_RAIN_VFX := preload("res://scripts/warriors/vfx/rp_rain_vfx.gd")

const CHARACTER_ID_RP := "rp"
const STATUS_TEXT := "Rainfall"
const ACTIVE_DURATION_SEC := 5.0
const RAIN_TICK_SEC := 0.25
const VULNERABLE_DURATION_SEC := 0.65
const VULNERABLE_MULTIPLIER := 1.5

var character_id_for_peer_cb: Callable = Callable()
var skill_color_for_peer_cb: Callable = Callable()

var _active_until_msec_by_peer: Dictionary = {}
var _rain_tick_accumulator_by_peer: Dictionary = {}
var _client_vfx_by_caster: Dictionary = {}

func _init() -> void:
	super._init("rp_rainfall", "Rainfall", 0.0, "Makes it rain for 5 seconds and applies vulnerable to enemies across the map")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skill_color_for_peer_cb = callbacks.get("skill_color_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_RP:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var until_msec := Time.get_ticks_msec() + int(ACTIVE_DURATION_SEC * 1000.0)
	_active_until_msec_by_peer[caster_peer_id] = until_msec
	_rain_tick_accumulator_by_peer[caster_peer_id] = 0.0
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, Vector2(ACTIVE_DURATION_SEC, 0.0))

func _execute_client_visual(caster_peer_id: int, payload: Vector2) -> void:
	var duration_sec := maxf(0.05, payload.x if absf(payload.x) > 0.0001 else ACTIVE_DURATION_SEC)
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster != null and caster.has_method("start_ulti_duration_bar"):
		caster.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)
	_spawn_or_refresh_client_vfx(caster_peer_id, duration_sec)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _active_until_msec_by_peer.is_empty():
		return
	var now_msec := Time.get_ticks_msec()
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
		var tick_accumulator := float(_rain_tick_accumulator_by_peer.get(caster_peer_id, 0.0)) + maxf(0.0, delta)
		while tick_accumulator >= RAIN_TICK_SEC:
			tick_accumulator -= RAIN_TICK_SEC
			_apply_rain_tick(caster_peer_id)
		_rain_tick_accumulator_by_peer[caster_peer_id] = tick_accumulator
	for caster_peer_id in expired_casters:
		_active_until_msec_by_peer.erase(caster_peer_id)
		_rain_tick_accumulator_by_peer.erase(caster_peer_id)

func _apply_rain_tick(caster_peer_id: int) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var affected_peer_ids: Dictionary = {}
	for member_value in _get_lobby_members(lobby_id):
		var target_peer_id := int(member_value)
		if not _is_valid_target_for_tick(caster_peer_id, target_peer_id, lobby_id):
			continue
		affected_peer_ids[target_peer_id] = true
	for peer_value in players.keys():
		var target_peer_id := int(peer_value)
		if target_peer_id >= 0:
			continue
		if affected_peer_ids.has(target_peer_id):
			continue
		if not _is_valid_target_for_tick(caster_peer_id, target_peer_id, lobby_id):
			continue
		affected_peer_ids[target_peer_id] = true
	for target_peer_value in affected_peer_ids.keys():
		var target_peer_id := int(target_peer_value)
		if debuff_service != null and debuff_service.has_method("apply_debuff"):
			debuff_service.call(
				"apply_debuff",
				target_peer_id,
				"vulnerable",
				VULNERABLE_DURATION_SEC,
				caster_peer_id,
				{"damage_multiplier": VULNERABLE_MULTIPLIER}
			)

func _is_valid_target_for_tick(caster_peer_id: int, target_peer_id: int, lobby_id: int) -> bool:
	if target_peer_id == caster_peer_id:
		return false
	if _get_peer_lobby(target_peer_id) != lobby_id:
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
	var vfx := RP_RAIN_VFX.new()
	vfx.name = "RPRain_%d" % caster_peer_id
	vfx.duration_sec = duration_sec
	vfx.rain_color = _skill_color_for_peer(caster_peer_id)
	host.add_child(vfx)
	_client_vfx_by_caster[caster_peer_id] = vfx

func _vfx_host_node() -> Node:
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
	return CHARACTER_ID_RP

func _skill_color_for_peer(peer_id: int) -> Color:
	if skill_color_for_peer_cb.is_valid():
		var value: Variant = skill_color_for_peer_cb.call(peer_id)
		if value is Color:
			return value as Color
	return Color(0.32, 0.68, 1.0, 1.0)
