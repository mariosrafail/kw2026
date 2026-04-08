extends Skill

const VARN_COMPANION_VFX := preload("res://scripts/warriors/vfx/varn_companion_vfx.gd")
const VARN_SWARM_VFX := preload("res://scripts/warriors/vfx/varn_swarm_vfx.gd")
const VARN_SKILL_TEXTURE := preload("res://assets/warriors/varn_skill.png")

const CHARACTER_ID_VARN := "varn"
const STATUS_TEXT := "Fly Swarm"
const SWARM_DURATION_SEC := 5.0
const FLIES_PER_TARGET := 5
const RANDOM_AIM_RADIUS_PX := 260.0

var character_id_for_peer_cb: Callable = Callable()
var _active_swarms_by_caster: Dictionary = {}
var _affected_state_by_peer: Dictionary = {}

func _init() -> void:
	super._init("varn_swarm", "Fly Swarm", 0.0, "Release fly swarms that disorient enemy aiming")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_VARN:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var target_state := _build_target_state(caster_peer_id, lobby_id)
	if target_state.is_empty():
		return
	_active_swarms_by_caster[caster_peer_id] = {
		"remaining": SWARM_DURATION_SEC,
		"lobby_id": lobby_id,
		"targets": target_state,
	}
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, Vector2(SWARM_DURATION_SEC, float(FLIES_PER_TARGET)))

func _execute_client_visual(caster_peer_id: int, payload: Vector2) -> void:
	ensure_companion_visual(caster_peer_id)
	var duration_sec := maxf(0.1, payload.x if payload.x > 0.0 else SWARM_DURATION_SEC)
	var flies_count := maxi(1, int(round(payload.y if payload.y > 0.0 else float(FLIES_PER_TARGET))))
	var target_ids := _collect_visual_targets(caster_peer_id)
	var client_targets := {}
	for target_peer_id in target_ids:
		client_targets[target_peer_id] = _disorient_state_for_pair(caster_peer_id, target_peer_id)
	_active_swarms_by_caster[caster_peer_id] = {
		"until_msec": Time.get_ticks_msec() + int(duration_sec * 1000.0),
		"targets": client_targets,
	}
	if target_ids.is_empty():
		return
	var host := _vfx_host_node()
	if host == null:
		return
	var swarm := VARN_SWARM_VFX.new()
	swarm.name = "VarnSwarm_%d_%d" % [caster_peer_id, Time.get_ticks_msec()]
	swarm.players = players
	swarm.caster_peer_id = caster_peer_id
	swarm.target_peer_ids = target_ids
	swarm.duration_sec = duration_sec
	swarm.flies_per_target = flies_count
	swarm.fly_texture = VARN_SKILL_TEXTURE
	swarm.fly_color = _swarm_color_for_peer(caster_peer_id)
	host.add_child(swarm)
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster != null and caster.has_method("start_ulti_duration_bar"):
		caster.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _active_swarms_by_caster.is_empty():
		_affected_state_by_peer.clear()
		return
	var expired_casters: Array[int] = []
	var affected_now: Dictionary = {}
	for caster_value in _active_swarms_by_caster.keys():
		var caster_peer_id := int(caster_value)
		var swarm := _active_swarms_by_caster.get(caster_peer_id, {}) as Dictionary
		var remaining := maxf(0.0, float(swarm.get("remaining", 0.0)) - delta)
		if remaining <= 0.0:
			expired_casters.append(caster_peer_id)
			continue
		swarm["remaining"] = remaining
		_active_swarms_by_caster[caster_peer_id] = swarm
		var target_map := swarm.get("targets", {}) as Dictionary
		for target_value in target_map.keys():
			var target_peer_id := int(target_value)
			var target := players.get(target_peer_id, null) as NetPlayer
			if target == null or target.get_health() <= 0:
				continue
			affected_now[target_peer_id] = target_map.get(target_value, {})
	for caster_peer_id in expired_casters:
		_active_swarms_by_caster.erase(caster_peer_id)
	_affected_state_by_peer = affected_now

func ensure_companion_visual(peer_id: int) -> void:
	if _character_id_for_peer(peer_id) != CHARACTER_ID_VARN:
		return
	if projectile_system == null or projectile_system.projectiles_root == null:
		return
	var existing := _companion_for_peer(peer_id)
	if existing != null:
		if existing.has_method("set_companion_color"):
			existing.call("set_companion_color", _swarm_color_for_peer(peer_id))
		return
	var companion := VARN_COMPANION_VFX.new()
	companion.name = "VarnCompanion_%d" % peer_id
	companion.caster_peer_id = peer_id
	companion.players = players
	companion.texture = VARN_SKILL_TEXTURE
	companion.base_color = _swarm_color_for_peer(peer_id)
	projectile_system.projectiles_root.add_child(companion)

func override_input_state_for_peer(peer_id: int, base_state: Dictionary) -> Dictionary:
	var state := _affected_state_for_peer(peer_id)
	if state.is_empty():
		return base_state
	var target := players.get(peer_id, null) as NetPlayer
	if target == null or target.get_health() <= 0:
		return base_state
	var now := Time.get_ticks_msec() / 1000.0
	var phase := float(state.get("phase", 0.0))
	var speed := float(state.get("speed", 1.0))
	var wobble := float(state.get("wobble", 0.0))
	var angle := now * speed + phase + sin(now * (speed * 0.63 + 1.7)) * wobble
	var aim_world := target.global_position + Vector2.RIGHT.rotated(angle) * RANDOM_AIM_RADIUS_PX
	var overridden := base_state.duplicate(true)
	overridden["aim_world"] = aim_world
	return overridden

func _affected_state_for_peer(peer_id: int) -> Dictionary:
	if _affected_state_by_peer.has(peer_id):
		return _affected_state_by_peer.get(peer_id, {}) as Dictionary
	var now_msec := Time.get_ticks_msec()
	for caster_value in _active_swarms_by_caster.keys():
		var caster_peer_id := int(caster_value)
		var swarm := _active_swarms_by_caster.get(caster_peer_id, {}) as Dictionary
		var active := false
		if swarm.has("remaining"):
			active = float(swarm.get("remaining", 0.0)) > 0.0
		elif swarm.has("until_msec"):
			active = now_msec <= int(swarm.get("until_msec", 0))
		if not active:
			continue
		var target_map := swarm.get("targets", {}) as Dictionary
		if target_map.has(peer_id):
			return target_map.get(peer_id, {}) as Dictionary
	return {}

func _build_target_state(caster_peer_id: int, lobby_id: int) -> Dictionary:
	var out := {}
	for target_value in players.keys():
		var target_peer_id := int(target_value)
		if target_peer_id == caster_peer_id:
			continue
		if _get_peer_lobby(target_peer_id) != lobby_id:
			continue
		var target := players.get(target_peer_id, null) as NetPlayer
		if target == null or target.get_health() <= 0:
			continue
		if not _can_affect_target(caster_peer_id, target_peer_id):
			continue
		out[target_peer_id] = _disorient_state_for_pair(caster_peer_id, target_peer_id)
	return out

func _disorient_state_for_pair(caster_peer_id: int, target_peer_id: int) -> Dictionary:
	var seed := float((caster_peer_id * 811 + target_peer_id * 173) % 997)
	return {
		"phase": seed * 0.0123,
		"speed": 7.2 + fmod(seed, 3.9),
		"wobble": 0.35 + fmod(seed, 0.7),
	}

func _collect_visual_targets(caster_peer_id: int) -> Array[int]:
	var out: Array[int] = []
	var caster_lobby := _get_peer_lobby(caster_peer_id)
	if caster_lobby <= 0:
		return out
	for target_value in players.keys():
		var target_peer_id := int(target_value)
		if target_peer_id == caster_peer_id:
			continue
		if _get_peer_lobby(target_peer_id) != caster_lobby:
			continue
		if not _can_affect_target(caster_peer_id, target_peer_id):
			continue
		var target := players.get(target_peer_id, null) as NetPlayer
		if target == null or target.get_health() <= 0:
			continue
		out.append(target_peer_id)
	return out

func _can_affect_target(caster_peer_id: int, target_peer_id: int) -> bool:
	var tree := _scene_tree()
	var root := tree.current_scene if tree != null else null
	if root != null and root.has_method("_ctf_enabled") and bool(root.call("_ctf_enabled")):
		if root.has_method("_team_for_peer"):
			var caster_team := int(root.call("_team_for_peer", caster_peer_id))
			var target_team := int(root.call("_team_for_peer", target_peer_id))
			if caster_team >= 0 and target_team >= 0:
				return caster_team != target_team
	return true

func _companion_for_peer(peer_id: int) -> Node2D:
	if projectile_system == null or projectile_system.projectiles_root == null:
		return null
	return projectile_system.projectiles_root.get_node_or_null("VarnCompanion_%d" % peer_id) as Node2D

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

func _swarm_color_for_peer(peer_id: int) -> Color:
	var player := players.get(peer_id, null) as NetPlayer
	if player != null and player.has_method("get_torso_dominant_color"):
		var color_value: Variant = player.call("get_torso_dominant_color")
		if color_value is Color:
			var source := color_value as Color
			return source.lerp(Color(0.78, 0.88, 0.22, 1.0), 0.55)
	return Color(0.78, 0.88, 0.22, 1.0)

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_VARN
