extends Skill

const MADAM_AURA_VFX := preload("res://scripts/warriors/vfx/madam_aura_vfx.gd")

const CHARACTER_ID_MADAM := "madam"
const AURA_DURATION_SEC := 5.0
const AURA_RADIUS_PX := 178.0
const MOVE_SPEED_MULTIPLIER := 0.28
const FIRE_RATE_MULTIPLIER := 0.33
const STATUS_TEXT := "Dread Aura"
const VFX_COLOR := Color(0.86, 0.48, 0.42, 0.88)

var character_id_for_peer_cb: Callable = Callable()
var _auras_by_peer: Dictionary = {}
var _affected_peers_last_tick: Dictionary = {}

func _init() -> void:
	super._init("madam_dread_aura", "Dread Aura", 0.0, "Create a slow aura around yourself for 5 seconds")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_MADAM:
		return
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	_auras_by_peer[caster_peer_id] = {
		"remaining": AURA_DURATION_SEC,
		"lobby_id": lobby_id
	}
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, Vector2(AURA_DURATION_SEC, AURA_RADIUS_PX))

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	var duration_sec := maxf(0.05, target_world.x if absf(target_world.x) > 0.0001 else AURA_DURATION_SEC)
	var radius_px := maxf(24.0, target_world.y if absf(target_world.y) > 0.0001 else AURA_RADIUS_PX)
	_spawn_aura_vfx(caster_peer_id, duration_sec, radius_px)
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player != null and player.has_method("start_ulti_duration_bar"):
		player.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return

	var move_multiplier_by_peer: Dictionary = {}
	var fire_multiplier_by_peer: Dictionary = {}
	var touched_peers: Dictionary = {}
	var expired_casters: Array = []

	for peer_value in _auras_by_peer.keys():
		var caster_peer_id := int(peer_value)
		var aura_data := _auras_by_peer.get(caster_peer_id, {}) as Dictionary
		var remaining := maxf(0.0, float(aura_data.get("remaining", 0.0)) - delta)
		if remaining <= 0.0:
			expired_casters.append(caster_peer_id)
			continue
		aura_data["remaining"] = remaining
		_auras_by_peer[caster_peer_id] = aura_data

		var caster := players.get(caster_peer_id, null) as NetPlayer
		if caster == null:
			continue
		var lobby_id := int(aura_data.get("lobby_id", _get_peer_lobby(caster_peer_id)))
		if lobby_id <= 0:
			lobby_id = _get_peer_lobby(caster_peer_id)
		if lobby_id <= 0:
			continue

		for target_peer_value in players.keys():
			var target_peer_id := int(target_peer_value)
			if target_peer_id == caster_peer_id:
				continue
			if _get_peer_lobby(target_peer_id) != lobby_id:
				continue
			touched_peers[target_peer_id] = true
			var target := players.get(target_peer_id, null) as NetPlayer
			if target == null:
				continue
			if target.global_position.distance_to(caster.global_position) > AURA_RADIUS_PX:
				continue
			var existing_move := float(move_multiplier_by_peer.get(target_peer_id, 1.0))
			var existing_fire := float(fire_multiplier_by_peer.get(target_peer_id, 1.0))
			move_multiplier_by_peer[target_peer_id] = minf(existing_move, MOVE_SPEED_MULTIPLIER)
			fire_multiplier_by_peer[target_peer_id] = minf(existing_fire, FIRE_RATE_MULTIPLIER)

	for caster_peer_id in expired_casters:
		_auras_by_peer.erase(caster_peer_id)

	var peers_to_update: Dictionary = _affected_peers_last_tick.duplicate(true)
	for touched_peer_value in touched_peers.keys():
		peers_to_update[int(touched_peer_value)] = true

	for affected_peer_value in peers_to_update.keys():
		var peer_id := int(affected_peer_value)
		var player := players.get(peer_id, null) as NetPlayer
		if player == null:
			continue
		if player.has_method("set_external_status_movement_speed_multiplier"):
			player.call("set_external_status_movement_speed_multiplier", float(move_multiplier_by_peer.get(peer_id, 1.0)))
		if player.has_method("set_external_fire_rate_multiplier"):
			player.call("set_external_fire_rate_multiplier", float(fire_multiplier_by_peer.get(peer_id, 1.0)))

	_affected_peers_last_tick = touched_peers

func _spawn_aura_vfx(caster_peer_id: int, duration_sec: float, radius_px: float) -> void:
	if projectile_system == null or projectile_system.projectiles_root == null:
		return
	var existing := projectile_system.projectiles_root.get_node_or_null("MadamAura_%d" % caster_peer_id) as Node
	if existing != null:
		existing.queue_free()
	var vfx := MADAM_AURA_VFX.new()
	vfx.name = "MadamAura_%d" % caster_peer_id
	vfx.caster_peer_id = caster_peer_id
	vfx.duration_sec = duration_sec
	vfx.radius = radius_px
	vfx.color = VFX_COLOR
	vfx.players = players
	projectile_system.projectiles_root.add_child(vfx)

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_MADAM
