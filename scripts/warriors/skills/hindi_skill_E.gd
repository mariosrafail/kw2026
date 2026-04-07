extends Skill

const CHARACTER_ID_HINDI := "hindi"
const STATUS_TEXT := "Magic Bullets"
const STUN_TEXT := "Stunned"
const MAGIC_DURATION_SEC := 5.0
const STUN_DURATION_SEC := 0.5
const MAGIC_TRAIL_WIDTH := 6.6
const MAGIC_TRAIL_ALPHA := 0.9
const MAGIC_HEAD_ALPHA := 0.98

var character_id_for_peer_cb: Callable = Callable()
var skill_color_for_peer_cb: Callable = Callable()
var send_match_message_to_peer_cb: Callable = Callable()
var _magic_until_msec_by_peer: Dictionary = {}
var _stunned_until_msec_by_peer: Dictionary = {}
var _magic_projectiles: Dictionary = {}

func _init() -> void:
	super._init("hindi_magic_bullets", "Magic Bullets", 0.0, "Bullets become enchanted and micro-stun on hit")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skill_color_for_peer_cb = callbacks.get("skill_color_for_peer", Callable()) as Callable
	send_match_message_to_peer_cb = callbacks.get("send_match_message_to_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_HINDI:
		return
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	_magic_until_msec_by_peer[caster_peer_id] = Time.get_ticks_msec() + int(MAGIC_DURATION_SEC * 1000.0)
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, Vector2(MAGIC_DURATION_SEC, 0.0))

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	var duration_sec := maxf(0.05, target_world.x if absf(target_world.x) > 0.0001 else MAGIC_DURATION_SEC)
	_magic_until_msec_by_peer[caster_peer_id] = Time.get_ticks_msec() + int(duration_sec * 1000.0)
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player != null and player.has_method("start_ulti_duration_bar"):
		player.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)

func server_tick(_delta: float) -> void:
	var now_msec := Time.get_ticks_msec()
	_prune_expired(_magic_until_msec_by_peer, now_msec)
	_prune_expired(_stunned_until_msec_by_peer, now_msec)

func register_fired_projectiles(caster_peer_id: int, weapon_id: String, projectile_ids: Array[int]) -> void:
	if not _is_magic_weapon_active(caster_peer_id, weapon_id):
		return
	for projectile_id in projectile_ids:
		_magic_projectiles[int(projectile_id)] = caster_peer_id

func on_projectile_player_hit(projectile_id: int, attacker_peer_id: int, target_peer_id: int, _hit_position: Vector2, _impact_velocity: Vector2, _projectile_lobby_id: int) -> void:
	if not _magic_projectiles.has(projectile_id):
		return
	if attacker_peer_id <= 0 or target_peer_id == attacker_peer_id:
		return
	var target := players.get(target_peer_id, null) as NetPlayer
	if target == null or target.get_health() <= 0:
		_magic_projectiles.erase(projectile_id)
		return
	_stunned_until_msec_by_peer[target_peer_id] = Time.get_ticks_msec() + int(STUN_DURATION_SEC * 1000.0)
	if send_match_message_to_peer_cb.is_valid() and target_peer_id > 0:
		send_match_message_to_peer_cb.call(target_peer_id, STUN_TEXT)
	_magic_projectiles.erase(projectile_id)

func on_projectile_despawn(projectile_id: int) -> void:
	_magic_projectiles.erase(projectile_id)

func override_input_state_for_peer(peer_id: int, base_state: Dictionary) -> Dictionary:
	if not _is_peer_stunned(peer_id):
		return base_state
	var overridden := base_state.duplicate(true)
	overridden["axis"] = 0.0
	overridden["jump_pressed"] = false
	overridden["jump_held"] = false
	overridden["shoot_held"] = false
	return overridden

func is_action_locked_for_peer(peer_id: int) -> bool:
	return _is_peer_stunned(peer_id)

func projectile_color_for_peer(peer_id: int, weapon_id: String, base_color: Color) -> Color:
	if not _is_magic_weapon_active(peer_id, weapon_id):
		return base_color
	return base_color.lerp(_skill_color_for_peer(peer_id), 0.7)

func projectile_visual_config_for_peer(peer_id: int, weapon_id: String, base_visual_config: Dictionary) -> Dictionary:
	if not _is_magic_weapon_active(peer_id, weapon_id):
		return base_visual_config
	var visual := base_visual_config.duplicate(true)
	visual["trail_width"] = maxf(MAGIC_TRAIL_WIDTH, float(base_visual_config.get("trail_width", 0.0)))
	visual["trail_alpha"] = maxf(MAGIC_TRAIL_ALPHA, float(base_visual_config.get("trail_alpha", 0.0)))
	visual["head_alpha"] = MAGIC_HEAD_ALPHA
	return visual

func _is_peer_stunned(peer_id: int) -> bool:
	var until_msec := int(_stunned_until_msec_by_peer.get(peer_id, 0))
	if until_msec <= 0:
		return false
	if Time.get_ticks_msec() > until_msec:
		_stunned_until_msec_by_peer.erase(peer_id)
		return false
	var player := players.get(peer_id, null) as NetPlayer
	return player != null and player.get_health() > 0

func _is_magic_weapon_active(peer_id: int, weapon_id: String) -> bool:
	if _character_id_for_peer(peer_id) != CHARACTER_ID_HINDI:
		return false
	if str(weapon_id).strip_edges().to_lower() == "grenade":
		return false
	var until_msec := int(_magic_until_msec_by_peer.get(peer_id, 0))
	if until_msec <= 0:
		return false
	if Time.get_ticks_msec() > until_msec:
		_magic_until_msec_by_peer.erase(peer_id)
		return false
	return true

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_HINDI

func _skill_color_for_peer(peer_id: int) -> Color:
	if skill_color_for_peer_cb.is_valid():
		var value: Variant = skill_color_for_peer_cb.call(peer_id)
		if value is Color:
			return value as Color
	return Color(0.29, 0.83, 1.0, 1.0)

func _prune_expired(state: Dictionary, now_msec: int) -> void:
	var expired: Array = []
	for key in state.keys():
		if now_msec > int(state.get(key, 0)):
			expired.append(key)
	for key in expired:
		state.erase(key)
