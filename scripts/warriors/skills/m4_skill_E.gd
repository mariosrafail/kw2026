extends Skill

const M4_ELECTRIC_FIELD_VFX := preload("res://scripts/warriors/vfx/m4_electric_field_vfx.gd")
const M4_LIGHTNING_STRIKE_VFX := preload("res://scripts/warriors/vfx/m4_lightning_strike_vfx.gd")

const CHARACTER_ID_M4 := "m4"
const STATUS_TEXT := "Shock Field"
const ACTIVE_DURATION_SEC := 5.0
const EFFECT_RADIUS_PX := 268.0
const STRIKE_INTERVAL_SEC := 0.32
const STRIKES_PER_TICK := 2
const BURN_DURATION_SEC := 2.2
const BURN_TICK_DAMAGE := 3
const BURN_TICK_SEC := 0.35
const STRIKE_VISUAL_SENTINEL := -77777.0
const STRIKE_TRAVEL_SPEED_PX_PER_SEC := 920.0
const STRIKE_MIN_TRAVEL_SEC := 0.05
const STRIKE_MAX_TRAVEL_SEC := 0.30

var character_id_for_peer_cb: Callable = Callable()
var skill_color_for_peer_cb: Callable = Callable()

var _active_until_msec_by_peer: Dictionary = {}
var _strike_tick_accumulator_by_peer: Dictionary = {}
var _client_vfx_by_caster: Dictionary = {}
var _pending_burn_events: Array = []

func _init() -> void:
	super._init("m4_shock_field", "Shock Field", 0.0, "Creates an electric field that chains lightning to nearby enemies and applies burn")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skill_color_for_peer_cb = callbacks.get("skill_color_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_M4:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var until_msec := Time.get_ticks_msec() + int(ACTIVE_DURATION_SEC * 1000.0)
	_active_until_msec_by_peer[caster_peer_id] = until_msec
	_strike_tick_accumulator_by_peer[caster_peer_id] = 0.0
	var payload := Vector2(ACTIVE_DURATION_SEC, EFFECT_RADIUS_PX)
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, payload)

func _execute_client_visual(caster_peer_id: int, payload: Vector2) -> void:
	if is_equal_approx(payload.x, STRIKE_VISUAL_SENTINEL):
		_spawn_client_strike_vfx(caster_peer_id, int(round(payload.y)))
		return
	var duration_sec := maxf(0.05, payload.x if absf(payload.x) > 0.0001 else ACTIVE_DURATION_SEC)
	var radius_px := maxf(12.0, payload.y if absf(payload.y) > 0.0001 else EFFECT_RADIUS_PX)
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster != null and caster.has_method("start_ulti_duration_bar"):
		caster.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)
	_spawn_or_refresh_client_field_vfx(caster_peer_id, duration_sec, radius_px)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_process_pending_burn_events(Time.get_ticks_msec())
	if _active_until_msec_by_peer.is_empty():
		return
	var now_msec := Time.get_ticks_msec()
	var expired: Array[int] = []
	for caster_value in _active_until_msec_by_peer.keys():
		var caster_peer_id := int(caster_value)
		var until_msec := int(_active_until_msec_by_peer.get(caster_peer_id, 0))
		if until_msec <= now_msec:
			expired.append(caster_peer_id)
			continue
		var caster := players.get(caster_peer_id, null) as NetPlayer
		if caster == null or caster.get_health() <= 0:
			expired.append(caster_peer_id)
			continue
		var tick_accumulator := float(_strike_tick_accumulator_by_peer.get(caster_peer_id, 0.0)) + maxf(0.0, delta)
		while tick_accumulator >= STRIKE_INTERVAL_SEC:
			tick_accumulator -= STRIKE_INTERVAL_SEC
			_apply_strike_tick(caster_peer_id)
		_strike_tick_accumulator_by_peer[caster_peer_id] = tick_accumulator
	for caster_peer_id in expired:
		_active_until_msec_by_peer.erase(caster_peer_id)
		_strike_tick_accumulator_by_peer.erase(caster_peer_id)

func _apply_strike_tick(caster_peer_id: int) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var candidates: Array = []
	var origin := caster.global_position
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
		var distance := target.global_position.distance_to(origin)
		if distance > EFFECT_RADIUS_PX:
			continue
		candidates.append({"peer_id": target_peer_id, "distance": distance})
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a: Variant, b: Variant) -> bool:
		return float((a as Dictionary).get("distance", 0.0)) < float((b as Dictionary).get("distance", 0.0))
	)
	var strikes := mini(STRIKES_PER_TICK, candidates.size())
	for index in range(strikes):
		var entry := candidates[index] as Dictionary
		var target_peer_id := int(entry.get("peer_id", 0))
		var target := players.get(target_peer_id, null) as NetPlayer
		if target == null:
			continue
		var travel_sec := _resolve_strike_travel_sec(caster.global_position, target.global_position)
		_queue_pending_burn_event(caster_peer_id, target_peer_id, travel_sec)
		var payload := Vector2(STRIKE_VISUAL_SENTINEL, float(target_peer_id))
		for member_value in _get_lobby_members(lobby_id):
			if send_skill_cast_cb.is_valid():
				send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, payload)

func _spawn_or_refresh_client_field_vfx(caster_peer_id: int, duration_sec: float, radius_px: float) -> void:
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
	var vfx := M4_ELECTRIC_FIELD_VFX.new()
	vfx.name = "M4ElectricField_%d" % caster_peer_id
	vfx.caster_peer_id = caster_peer_id
	vfx.duration_sec = duration_sec
	vfx.radius_px = radius_px
	vfx.players = players
	vfx.electric_color = _skill_color_for_peer(caster_peer_id)
	host.add_child(vfx)
	_client_vfx_by_caster[caster_peer_id] = vfx

func _spawn_client_strike_vfx(caster_peer_id: int, target_peer_id: int) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	var target := players.get(target_peer_id, null) as NetPlayer
	if caster == null or target == null:
		return
	var host := _vfx_host_node()
	if host == null:
		return
	var vfx := M4_LIGHTNING_STRIKE_VFX.new()
	vfx.name = "M4Strike_%d_%d_%d" % [caster_peer_id, target_peer_id, Time.get_ticks_msec()]
	vfx.from_world = caster.global_position + Vector2(0.0, -16.0)
	vfx.to_world = target.global_position + Vector2(0.0, -16.0)
	vfx.strike_color = _skill_color_for_peer(caster_peer_id)
	host.add_child(vfx)

func _queue_pending_burn_event(caster_peer_id: int, target_peer_id: int, travel_sec: float) -> void:
	var apply_at_msec := Time.get_ticks_msec() + int(round(travel_sec * 1000.0))
	_pending_burn_events.append({
		"caster_peer_id": caster_peer_id,
		"target_peer_id": target_peer_id,
		"apply_at_msec": apply_at_msec,
	})

func _process_pending_burn_events(now_msec: int) -> void:
	if _pending_burn_events.is_empty():
		return
	var keep: Array = []
	for event_value in _pending_burn_events:
		if not (event_value is Dictionary):
			continue
		var event := event_value as Dictionary
		var apply_at_msec := int(event.get("apply_at_msec", 0))
		if apply_at_msec > now_msec:
			keep.append(event)
			continue
		_apply_pending_burn_event(
			int(event.get("caster_peer_id", 0)),
			int(event.get("target_peer_id", 0))
		)
	_pending_burn_events = keep

func _apply_pending_burn_event(caster_peer_id: int, target_peer_id: int) -> void:
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
		debuff_service.call(
			"apply_debuff",
			target_peer_id,
			"burn",
			BURN_DURATION_SEC,
			caster_peer_id,
			{"tick_damage": BURN_TICK_DAMAGE, "tick_sec": BURN_TICK_SEC}
		)

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

func _resolve_strike_travel_sec(from_position: Vector2, to_position: Vector2) -> float:
	var distance := from_position.distance_to(to_position)
	var travel_sec := distance / maxf(1.0, STRIKE_TRAVEL_SPEED_PX_PER_SEC)
	return clampf(travel_sec, STRIKE_MIN_TRAVEL_SEC, STRIKE_MAX_TRAVEL_SEC)

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
	return CHARACTER_ID_M4

func _skill_color_for_peer(peer_id: int) -> Color:
	if skill_color_for_peer_cb.is_valid():
		var value: Variant = skill_color_for_peer_cb.call(peer_id)
		if value is Color:
			return value as Color
	return Color(0.40, 0.92, 1.0, 1.0)
