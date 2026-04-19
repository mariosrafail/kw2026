extends Skill

const LALOU_HEARTS_VFX := preload("res://scripts/warriors/vfx/lalou_hearts_vfx.gd")

const CHARACTER_ID_LALOU := "lalou"
const STATUS_TEXT := "Heart Storm"
const STUN_TEXT := "Charmed"
const ACTIVE_DURATION_SEC := 5.0
const STUN_DURATION_SEC := 1.0
const HEART_TICK_SEC := 0.22
const EFFECT_RADIUS_PX := 176.0
const STUN_VISUAL_EVENT_SENTINEL := -99999.0
const HEART_HOMING_SPEED_PX_PER_SEC := 460.0
const HEART_HOMING_MIN_TRAVEL_SEC := 0.08
const HEART_HOMING_MAX_TRAVEL_SEC := 0.46

var character_id_for_peer_cb: Callable = Callable()
var skill_color_for_peer_cb: Callable = Callable()

var _active_until_msec_by_peer: Dictionary = {}
var _heart_tick_accumulator_by_peer: Dictionary = {}
var _client_vfx_by_caster: Dictionary = {}
var _pending_stun_events: Array = []
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	super._init("lalou_heart_storm", "Heart Storm", 0.0, "Sprays heart pixels that repeatedly stun nearby enemies")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skill_color_for_peer_cb = callbacks.get("skill_color_for_peer", Callable()) as Callable
	_rng.seed = int(Time.get_ticks_usec()) ^ 0x51A10

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_LALOU:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var until_msec := Time.get_ticks_msec() + int(ACTIVE_DURATION_SEC * 1000.0)
	_active_until_msec_by_peer[caster_peer_id] = until_msec
	_heart_tick_accumulator_by_peer[caster_peer_id] = 0.0
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, Vector2(ACTIVE_DURATION_SEC, EFFECT_RADIUS_PX))

func _execute_client_visual(caster_peer_id: int, payload: Vector2) -> void:
	if is_equal_approx(payload.x, STUN_VISUAL_EVENT_SENTINEL):
		_apply_client_stun_visual(caster_peer_id, payload)
		return
	var duration_sec := maxf(0.05, payload.x if absf(payload.x) > 0.0001 else ACTIVE_DURATION_SEC)
	var radius_px := maxf(8.0, payload.y if absf(payload.y) > 0.0001 else EFFECT_RADIUS_PX)
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster != null and caster.has_method("start_ulti_duration_bar"):
		caster.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)
	_spawn_or_refresh_client_vfx(caster_peer_id, duration_sec, radius_px)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now_msec := Time.get_ticks_msec()
	_process_pending_stun_events(now_msec)
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
		var accumulator := float(_heart_tick_accumulator_by_peer.get(caster_peer_id, 0.0)) + maxf(0.0, delta)
		while accumulator >= HEART_TICK_SEC:
			accumulator -= HEART_TICK_SEC
			_apply_heart_tick(caster_peer_id)
		_heart_tick_accumulator_by_peer[caster_peer_id] = accumulator
	for caster_peer_id in expired_casters:
		_active_until_msec_by_peer.erase(caster_peer_id)
		_heart_tick_accumulator_by_peer.erase(caster_peer_id)

func _apply_heart_tick(caster_peer_id: int) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var candidates: Array[int] = []
	var center := caster.global_position
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
		if target.global_position.distance_to(center) > EFFECT_RADIUS_PX:
			continue
		candidates.append(target_peer_id)
	if candidates.is_empty():
		return
	var picked_index := _rng.randi_range(0, candidates.size() - 1)
	var target_peer_id := int(candidates[picked_index])
	var target := players.get(target_peer_id, null) as NetPlayer
	if target == null:
		return
	var travel_sec := _resolve_heart_travel_sec(center, target.global_position)
	_queue_pending_stun(target_peer_id, caster_peer_id, travel_sec)
	var target_payload := Vector2(STUN_VISUAL_EVENT_SENTINEL, float(target_peer_id))
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, target_payload)

func _spawn_or_refresh_client_vfx(caster_peer_id: int, duration_sec: float, radius_px: float) -> void:
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
	var vfx := LALOU_HEARTS_VFX.new()
	vfx.name = "LalouHearts_%d" % caster_peer_id
	vfx.source_player = caster
	vfx.duration_sec = duration_sec
	vfx.radius_px = radius_px
	vfx.effect_color = _skill_color_for_peer(caster_peer_id)
	host.add_child(vfx)
	_client_vfx_by_caster[caster_peer_id] = vfx

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
	return CHARACTER_ID_LALOU

func _skill_color_for_peer(peer_id: int) -> Color:
	if skill_color_for_peer_cb.is_valid():
		var value: Variant = skill_color_for_peer_cb.call(peer_id)
		if value is Color:
			return value as Color
	return Color(1.0, 0.41, 0.68, 1.0)

func _prune_expired(state: Dictionary, now_msec: int) -> void:
	var expired: Array = []
	for key in state.keys():
		if now_msec > int(state.get(key, 0)):
			expired.append(key)
	for key in expired:
		state.erase(key)

func _apply_client_stun_visual(caster_peer_id: int, payload: Vector2) -> void:
	var target_peer_id := _resolve_target_peer_id_from_payload(payload.y)
	var duration_sec := STUN_DURATION_SEC
	var player := players.get(target_peer_id, null) as NetPlayer
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if player == null or caster == null:
		return
	var vfx := _client_vfx_by_caster.get(caster_peer_id, null) as LalouHeartsVfx
	if vfx == null or not is_instance_valid(vfx):
		_spawn_or_refresh_client_vfx(caster_peer_id, ACTIVE_DURATION_SEC, EFFECT_RADIUS_PX)
		vfx = _client_vfx_by_caster.get(caster_peer_id, null) as LalouHeartsVfx
	if vfx != null and is_instance_valid(vfx):
		vfx.spawn_targeted_heart(player, duration_sec)
	elif player.has_method("set_petrified_visual"):
		player.call("set_petrified_visual", duration_sec)

func _resolve_target_peer_id_from_payload(encoded_peer_value: float) -> int:
	var rounded_peer_id := int(round(encoded_peer_value))
	if players.has(rounded_peer_id):
		return rounded_peer_id
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if is_equal_approx(float(peer_id), encoded_peer_value):
			return peer_id
	return rounded_peer_id

func _queue_pending_stun(target_peer_id: int, caster_peer_id: int, travel_sec: float) -> void:
	var apply_at_msec := Time.get_ticks_msec() + int(travel_sec * 1000.0)
	_pending_stun_events.append({
		"target_peer_id": target_peer_id,
		"caster_peer_id": caster_peer_id,
		"apply_at_msec": apply_at_msec,
	})

func _process_pending_stun_events(now_msec: int) -> void:
	if _pending_stun_events.is_empty():
		return
	var remaining: Array = []
	for event_value in _pending_stun_events:
		if not (event_value is Dictionary):
			continue
		var event := event_value as Dictionary
		var apply_at_msec := int(event.get("apply_at_msec", 0))
		if apply_at_msec > now_msec:
			remaining.append(event)
			continue
		var target_peer_id := int(event.get("target_peer_id", 0))
		var caster_peer_id := int(event.get("caster_peer_id", 0))
		_apply_pending_stun_event(caster_peer_id, target_peer_id)
	_pending_stun_events = remaining

func _apply_pending_stun_event(caster_peer_id: int, target_peer_id: int) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	var target := players.get(target_peer_id, null) as NetPlayer
	if caster == null or target == null:
		return
	if caster.get_health() <= 0 or target.get_health() <= 0:
		return
	if not _can_affect_target(caster_peer_id, target_peer_id):
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0 or _get_peer_lobby(target_peer_id) != lobby_id:
		return
	if debuff_service != null and debuff_service.has_method("apply_debuff"):
		debuff_service.call("apply_debuff", target_peer_id, "stun", STUN_DURATION_SEC, caster_peer_id)

func _resolve_heart_travel_sec(from_position: Vector2, to_position: Vector2) -> float:
	var distance_px := from_position.distance_to(to_position)
	var travel_sec := distance_px / maxf(1.0, HEART_HOMING_SPEED_PX_PER_SEC)
	return clampf(travel_sec, HEART_HOMING_MIN_TRAVEL_SEC, HEART_HOMING_MAX_TRAVEL_SEC)
