extends Skill

const CHARACTER_ID_LOKER := "loker"
const STATUS_TEXT := "Overclock"
const BUFF_DURATION_SEC := 5.0
const FIRE_RATE_MULTIPLIER := 1.8
const RELOAD_SPEED_MULTIPLIER := 1.8

var character_id_for_peer_cb: Callable = Callable()
var _buff_remaining_by_peer: Dictionary = {}
var _affected_peers_last_tick: Dictionary = {}
var _client_visual_nonce_by_peer: Dictionary = {}

func _init() -> void:
	super._init("loker_overclock", "Overclock", 0.0, "Gain increased fire rate and reload speed for 5 seconds")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_LOKER:
		return
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	_buff_remaining_by_peer[caster_peer_id] = {
		"remaining": BUFF_DURATION_SEC,
		"lobby_id": lobby_id
	}
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, Vector2(BUFF_DURATION_SEC, 0.0))

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	var duration_sec := maxf(0.05, target_world.x if absf(target_world.x) > 0.0001 else BUFF_DURATION_SEC)
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player == null:
		return
	if player.has_method("start_ulti_duration_bar"):
		player.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)
	if player.has_method("set_reload_animation_speed_multiplier"):
		player.call("set_reload_animation_speed_multiplier", RELOAD_SPEED_MULTIPLIER)
	var nonce := int(_client_visual_nonce_by_peer.get(caster_peer_id, 0)) + 1
	_client_visual_nonce_by_peer[caster_peer_id] = nonce
	var tree := player.get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(duration_sec)
	if timer == null:
		return
	timer.timeout.connect(Callable(self, "_on_client_buff_visual_timeout").bind(caster_peer_id, nonce))

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var fire_multiplier_by_peer: Dictionary = {}
	var reload_multiplier_by_peer: Dictionary = {}
	var touched_peers: Dictionary = {}
	var expired_peers: Array = []

	for peer_value in _buff_remaining_by_peer.keys():
		var peer_id := int(peer_value)
		var buff_data := _buff_remaining_by_peer.get(peer_id, {}) as Dictionary
		var remaining := maxf(0.0, float(buff_data.get("remaining", 0.0)) - delta)
		if remaining <= 0.0:
			expired_peers.append(peer_id)
			continue
		buff_data["remaining"] = remaining
		_buff_remaining_by_peer[peer_id] = buff_data
		var player := players.get(peer_id, null) as NetPlayer
		if player == null or player.get_health() <= 0:
			continue
		touched_peers[peer_id] = true
		fire_multiplier_by_peer[peer_id] = FIRE_RATE_MULTIPLIER
		reload_multiplier_by_peer[peer_id] = RELOAD_SPEED_MULTIPLIER

	for peer_id in expired_peers:
		_buff_remaining_by_peer.erase(peer_id)

	var peers_to_update: Dictionary = _affected_peers_last_tick.duplicate(true)
	for touched_peer_value in touched_peers.keys():
		peers_to_update[int(touched_peer_value)] = true

	for affected_peer_value in peers_to_update.keys():
		var peer_id := int(affected_peer_value)
		var player := players.get(peer_id, null) as NetPlayer
		if player == null:
			continue
		if player.has_method("set_external_fire_rate_multiplier"):
			player.call("set_external_fire_rate_multiplier", float(fire_multiplier_by_peer.get(peer_id, 1.0)))
		if player.has_method("set_external_reload_speed_multiplier"):
			player.call("set_external_reload_speed_multiplier", float(reload_multiplier_by_peer.get(peer_id, 1.0)))
		if player.has_method("set_reload_animation_speed_multiplier"):
			player.call("set_reload_animation_speed_multiplier", float(reload_multiplier_by_peer.get(peer_id, 1.0)))

	_affected_peers_last_tick = touched_peers

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_LOKER

func _on_client_buff_visual_timeout(peer_id: int, nonce: int) -> void:
	if int(_client_visual_nonce_by_peer.get(peer_id, 0)) != nonce:
		return
	var player := players.get(peer_id, null) as NetPlayer
	if player == null:
		return
	if player.has_method("set_reload_animation_speed_multiplier"):
		player.call("set_reload_animation_speed_multiplier", 1.0)
