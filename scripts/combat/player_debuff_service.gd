extends RefCounted

class_name PlayerDebuffService

const DEBUFF_STUN := "stun"
const DEBUFF_SILENCE := "silence"
const DEBUFF_ROOT := "root"
const DEBUFF_SLOW := "slow"
const DEBUFF_BURN := "burn"
const DEBUFF_INVERTED := "inverted"
const DEBUFF_VULNERABLE := "vulnerable"
const DEFAULT_BURN_TICK_DAMAGE := 4
const DEFAULT_BURN_TICK_SEC := 0.5
const DEFAULT_VULNERABLE_DAMAGE_MULTIPLIER := 1.5

var players: Dictionary = {}
var multiplayer: MultiplayerAPI
var hit_damage_resolver: HitDamageResolver

var get_peer_lobby_cb: Callable = Callable()
var get_lobby_members_cb: Callable = Callable()
var send_debuff_visual_cb: Callable = Callable()

var _effects_by_peer: Dictionary = {}
const ALL_DEBUFF_IDS := [
	DEBUFF_STUN,
	DEBUFF_SILENCE,
	DEBUFF_ROOT,
	DEBUFF_SLOW,
	DEBUFF_BURN,
	DEBUFF_INVERTED,
	DEBUFF_VULNERABLE,
]

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	players = state_refs.get("players", {}) as Dictionary
	multiplayer = state_refs.get("multiplayer", null) as MultiplayerAPI
	hit_damage_resolver = state_refs.get("hit_damage_resolver", null) as HitDamageResolver
	get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable()) as Callable
	get_lobby_members_cb = callbacks.get("get_lobby_members", Callable()) as Callable
	send_debuff_visual_cb = callbacks.get("send_debuff_visual", Callable()) as Callable

func server_tick() -> void:
	var now_msec := Time.get_ticks_msec()
	var expired_peers: Array[int] = []
	for peer_value in _effects_by_peer.keys():
		var peer_id := int(peer_value)
		var effect_map := _effects_by_peer.get(peer_id, {}) as Dictionary
		_tick_burn_effect(peer_id, effect_map, now_msec)
		var expired_ids: Array[String] = []
		for debuff_value in effect_map.keys():
			var debuff_id := str(debuff_value)
			var effect_state := effect_map.get(debuff_id, {}) as Dictionary
			var until_msec := int(effect_state.get("until_msec", 0))
			if until_msec <= now_msec:
				expired_ids.append(debuff_id)
		for debuff_id in expired_ids:
			effect_map.erase(debuff_id)
		if effect_map.is_empty():
			expired_peers.append(peer_id)
		else:
			_effects_by_peer[peer_id] = effect_map
		_apply_player_mobility_modifiers(peer_id)
	for peer_id in expired_peers:
		_effects_by_peer.erase(peer_id)
		_apply_player_mobility_modifiers(peer_id)

func apply_debuff(target_peer_id: int, debuff_id: String, duration_sec: float, source_peer_id: int = 0, params: Dictionary = {}) -> void:
	if multiplayer == null or not multiplayer.is_server():
		return
	if target_peer_id == 0:
		return
	var player := players.get(target_peer_id, null) as NetPlayer
	if player == null or player.get_health() <= 0:
		return
	var normalized_id := debuff_id.strip_edges().to_lower()
	if normalized_id.is_empty():
		return
	var resolved_duration := maxf(0.0, duration_sec)
	if resolved_duration <= 0.0:
		return
	var resolved_params := params.duplicate(true)
	resolved_params["source_peer_id"] = source_peer_id
	_store_effect_state(target_peer_id, normalized_id, resolved_duration, resolved_params)
	_apply_player_mobility_modifiers(target_peer_id)
	_broadcast_visual_to_lobby(target_peer_id, normalized_id, resolved_duration)

func can_cast_skill(peer_id: int) -> bool:
	return not (_has_effect(peer_id, DEBUFF_STUN) or _has_effect(peer_id, DEBUFF_SILENCE))

func can_shoot(peer_id: int) -> bool:
	return not (_has_effect(peer_id, DEBUFF_STUN) or _has_effect(peer_id, DEBUFF_SILENCE))

func is_hard_action_locked(peer_id: int) -> bool:
	return _has_effect(peer_id, DEBUFF_STUN)

func has_debuff(peer_id: int, debuff_id: String) -> bool:
	return _has_effect(peer_id, debuff_id.strip_edges().to_lower())

func incoming_damage_multiplier(peer_id: int) -> float:
	var multiplier := 1.0
	var vulnerable_state := _effect_state(peer_id, DEBUFF_VULNERABLE)
	if not vulnerable_state.is_empty():
		multiplier *= maxf(1.0, float(vulnerable_state.get("damage_multiplier", DEFAULT_VULNERABLE_DAMAGE_MULTIPLIER)))
	return multiplier

func debuff_remaining_sec(peer_id: int, debuff_id: String) -> float:
	var effect_state := _effect_state(peer_id, debuff_id.strip_edges().to_lower())
	if effect_state.is_empty():
		return 0.0
	var remaining_msec := int(effect_state.get("until_msec", 0)) - Time.get_ticks_msec()
	return maxf(0.0, float(remaining_msec) / 1000.0)

func override_input_state(peer_id: int, base_state: Dictionary) -> Dictionary:
	var resolved := base_state.duplicate(true)
	if _has_effect(peer_id, DEBUFF_STUN):
		resolved["axis"] = 0.0
		resolved["jump_pressed"] = false
		resolved["jump_held"] = false
		resolved["shoot_held"] = false
		resolved["boost_damage"] = false
		return resolved
	if _has_effect(peer_id, DEBUFF_ROOT):
		resolved["axis"] = 0.0
		resolved["jump_pressed"] = false
		resolved["jump_held"] = false
	if _has_effect(peer_id, DEBUFF_SILENCE):
		resolved["shoot_held"] = false
	if _has_effect(peer_id, DEBUFF_INVERTED):
		resolved["axis"] = -float(resolved.get("axis", 0.0))
	return resolved

func client_receive_visual(target_peer_id: int, debuff_id: String, duration_sec: float) -> void:
	_store_effect_state(target_peer_id, debuff_id.strip_edges().to_lower(), duration_sec, {})
	var player := players.get(target_peer_id, null) as NetPlayer
	if player == null:
		return
	if player.has_method("set_public_debuff_visual"):
		player.call("set_public_debuff_visual", debuff_id, duration_sec)
	if debuff_id == DEBUFF_STUN and player.has_method("set_petrified_visual"):
		player.call("set_petrified_visual", duration_sec)

func clear_all_debuffs_for_peer(target_peer_id: int, broadcast_clear_visual: bool = true) -> void:
	if target_peer_id == 0:
		return
	_effects_by_peer.erase(target_peer_id)
	_apply_player_mobility_modifiers(target_peer_id)
	if not broadcast_clear_visual:
		return
	for debuff_value in ALL_DEBUFF_IDS:
		_broadcast_visual_to_lobby(target_peer_id, str(debuff_value), 0.0)

func _store_effect_state(target_peer_id: int, debuff_id: String, duration_sec: float, params: Dictionary) -> void:
	if target_peer_id == 0 or debuff_id.is_empty():
		return
	var effect_map := _effects_by_peer.get(target_peer_id, {}) as Dictionary
	var current_state := effect_map.get(debuff_id, {}) as Dictionary
	var until_msec := Time.get_ticks_msec() + int(maxf(0.0, duration_sec) * 1000.0)
	current_state["until_msec"] = max(int(current_state.get("until_msec", 0)), until_msec)
	if debuff_id == DEBUFF_SLOW:
		current_state["move_multiplier"] = clampf(float(params.get("move_multiplier", 0.55)), 0.05, 1.0)
		current_state["jump_multiplier"] = clampf(float(params.get("jump_multiplier", 0.7)), 0.05, 1.0)
	elif debuff_id == DEBUFF_BURN:
		current_state["tick_damage"] = maxi(1, int(params.get("tick_damage", DEFAULT_BURN_TICK_DAMAGE)))
		current_state["tick_sec"] = maxf(0.1, float(params.get("tick_sec", DEFAULT_BURN_TICK_SEC)))
		if not current_state.has("next_tick_msec"):
			current_state["next_tick_msec"] = Time.get_ticks_msec() + int(float(current_state.get("tick_sec", DEFAULT_BURN_TICK_SEC)) * 1000.0)
		current_state["source_peer_id"] = int(params.get("source_peer_id", 0))
	elif debuff_id == DEBUFF_VULNERABLE:
		current_state["damage_multiplier"] = maxf(1.0, float(params.get("damage_multiplier", DEFAULT_VULNERABLE_DAMAGE_MULTIPLIER)))
	effect_map[debuff_id] = current_state
	_effects_by_peer[target_peer_id] = effect_map

func _tick_burn_effect(peer_id: int, effect_map: Dictionary, now_msec: int) -> void:
	var burn_state := effect_map.get(DEBUFF_BURN, {}) as Dictionary
	if burn_state.is_empty():
		return
	var until_msec := int(burn_state.get("until_msec", 0))
	if until_msec <= now_msec:
		return
	var next_tick_msec := int(burn_state.get("next_tick_msec", 0))
	if next_tick_msec <= 0 or now_msec < next_tick_msec:
		return
	var player := players.get(peer_id, null) as NetPlayer
	if player == null or player.get_health() <= 0:
		return
	if hit_damage_resolver != null:
		var tick_damage := maxi(1, int(burn_state.get("tick_damage", DEFAULT_BURN_TICK_DAMAGE)))
		var source_peer_id := int(burn_state.get("source_peer_id", 0))
		hit_damage_resolver.server_apply_direct_damage(source_peer_id, peer_id, player, tick_damage, Vector2(0.0, -36.0))
	var tick_sec := maxf(0.1, float(burn_state.get("tick_sec", DEFAULT_BURN_TICK_SEC)))
	burn_state["next_tick_msec"] = now_msec + int(tick_sec * 1000.0)
	effect_map[DEBUFF_BURN] = burn_state

func _broadcast_visual_to_lobby(target_peer_id: int, debuff_id: String, duration_sec: float) -> void:
	if not send_debuff_visual_cb.is_valid():
		return
	var lobby_id := _peer_lobby(target_peer_id)
	if lobby_id <= 0:
		return
	for member_value in _lobby_members(lobby_id):
		send_debuff_visual_cb.call(int(member_value), target_peer_id, debuff_id, duration_sec)

func _apply_player_mobility_modifiers(peer_id: int) -> void:
	var player := players.get(peer_id, null) as NetPlayer
	if player == null:
		return
	var move_multiplier := 1.0
	var jump_multiplier := 1.0
	if _has_effect(peer_id, DEBUFF_STUN):
		move_multiplier = 0.0
		jump_multiplier = 0.25
	elif _has_effect(peer_id, DEBUFF_ROOT):
		move_multiplier = 0.0
		jump_multiplier = 0.25
	else:
		var slow_state := _effect_state(peer_id, DEBUFF_SLOW)
		if not slow_state.is_empty():
			move_multiplier = clampf(float(slow_state.get("move_multiplier", 0.55)), 0.05, 1.0)
			jump_multiplier = clampf(float(slow_state.get("jump_multiplier", 0.7)), 0.05, 1.0)
	if player.has_method("set_external_status_movement_speed_multiplier"):
		player.call("set_external_status_movement_speed_multiplier", move_multiplier)
	if player.has_method("set_external_status_jump_velocity_multiplier"):
		player.call("set_external_status_jump_velocity_multiplier", jump_multiplier)

func _has_effect(peer_id: int, debuff_id: String) -> bool:
	var effect_state := _effect_state(peer_id, debuff_id)
	if effect_state.is_empty():
		return false
	return int(effect_state.get("until_msec", 0)) > Time.get_ticks_msec()

func _effect_state(peer_id: int, debuff_id: String) -> Dictionary:
	var effect_map := _effects_by_peer.get(peer_id, {}) as Dictionary
	return effect_map.get(debuff_id, {}) as Dictionary

func _peer_lobby(peer_id: int) -> int:
	if get_peer_lobby_cb.is_valid():
		return int(get_peer_lobby_cb.call(peer_id))
	return 0

func _lobby_members(lobby_id: int) -> Array:
	if get_lobby_members_cb.is_valid():
		var value: Variant = get_lobby_members_cb.call(lobby_id)
		if value is Array:
			return value as Array
	return []
