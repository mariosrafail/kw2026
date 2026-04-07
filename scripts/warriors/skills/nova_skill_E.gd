extends Skill

const NOVA_COMPANION_VFX := preload("res://scripts/warriors/vfx/nova_companion_vfx.gd")
const NOVA_COMPANION_TEXTURE := preload("res://assets/warriors/nova_skill.png")

const CHARACTER_ID_NOVA := "nova"
const RADAR_DURATION_SEC := 5.0
const RADAR_RADIUS_PX := 248.0
const STATUS_TEXT := "Echo Inversion"

var character_id_for_peer_cb: Callable = Callable()
var skin_index_for_peer_cb: Callable = Callable()
var _active_fields_by_caster: Dictionary = {}
var _affected_peers_last_tick: Dictionary = {}

func _init() -> void:
	super._init("nova_echo_field", "Echo Field", 0.0, "Deploy a radar field that inverts horizontal movement inside its radius")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skin_index_for_peer_cb = callbacks.get("skin_index_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_NOVA:
		return
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	_active_fields_by_caster[caster_peer_id] = {
		"remaining": RADAR_DURATION_SEC,
		"lobby_id": lobby_id,
		"radius": RADAR_RADIUS_PX
	}
	var payload := Vector2(RADAR_DURATION_SEC, RADAR_RADIUS_PX)
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, payload)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	var duration_sec := maxf(0.05, target_world.x if absf(target_world.x) > 0.0001 else RADAR_DURATION_SEC)
	var radius_px := maxf(48.0, target_world.y if absf(target_world.y) > 0.0001 else RADAR_RADIUS_PX)
	_active_fields_by_caster[caster_peer_id] = {
		"until_msec": Time.get_ticks_msec() + int(duration_sec * 1000.0),
		"radius": radius_px
	}
	ensure_companion_visual(caster_peer_id)
	var companion := _companion_for_peer(caster_peer_id)
	if companion != null and companion.has_method("activate_radar"):
		companion.call("activate_radar", duration_sec, radius_px, _companion_color_for_peer(caster_peer_id))
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player != null and player.has_method("start_ulti_duration_bar"):
		player.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _active_fields_by_caster.is_empty():
		_affected_peers_last_tick.clear()
		return

	var affected_peers: Dictionary = {}
	var expired_casters: Array[int] = []
	for peer_value in _active_fields_by_caster.keys():
		var caster_peer_id := int(peer_value)
		var field_data := _active_fields_by_caster.get(caster_peer_id, {}) as Dictionary
		var remaining := maxf(0.0, float(field_data.get("remaining", 0.0)) - delta)
		if remaining <= 0.0:
			expired_casters.append(caster_peer_id)
			continue
		field_data["remaining"] = remaining
		_active_fields_by_caster[caster_peer_id] = field_data
		var center := _field_center_for_peer(caster_peer_id)
		if center == Vector2.ZERO:
			continue
		var radius_px := maxf(48.0, float(field_data.get("radius", RADAR_RADIUS_PX)))
		var lobby_id := int(field_data.get("lobby_id", _get_peer_lobby(caster_peer_id)))
		if lobby_id <= 0:
			continue
		for target_peer_value in players.keys():
			var target_peer_id := int(target_peer_value)
			if target_peer_id == caster_peer_id:
				continue
			if _get_peer_lobby(target_peer_id) != lobby_id:
				continue
			var target := players.get(target_peer_id, null) as NetPlayer
			if target == null or target.get_health() <= 0:
				continue
			if target.global_position.distance_to(center) > radius_px:
				continue
			affected_peers[target_peer_id] = true
	for caster_peer_id in expired_casters:
		_active_fields_by_caster.erase(caster_peer_id)
	_affected_peers_last_tick = affected_peers

func ensure_companion_visual(peer_id: int) -> void:
	if _character_id_for_peer(peer_id) != CHARACTER_ID_NOVA:
		return
	if projectile_system == null or projectile_system.projectiles_root == null:
		return
	var existing := _companion_for_peer(peer_id)
	if existing != null:
		if existing.has_method("set_companion_color"):
			existing.call("set_companion_color", _companion_color_for_peer(peer_id))
		if existing.has_method("set_skin_index"):
			existing.call("set_skin_index", _skin_index_for_peer(peer_id))
		return
	var companion := NOVA_COMPANION_VFX.new()
	companion.name = "NovaCompanion_%d" % peer_id
	companion.caster_peer_id = peer_id
	companion.players = players
	companion.texture = NOVA_COMPANION_TEXTURE
	companion.base_color = _companion_color_for_peer(peer_id)
	companion.skin_index = _skin_index_for_peer(peer_id)
	projectile_system.projectiles_root.add_child(companion)

func override_input_state_for_peer(peer_id: int, base_state: Dictionary) -> Dictionary:
	if not _is_peer_inverted(peer_id):
		return base_state
	var overridden := base_state.duplicate(true)
	overridden["axis"] = -float(base_state.get("axis", 0.0))
	return overridden

func _is_peer_inverted(peer_id: int) -> bool:
	if _affected_peers_last_tick.has(peer_id):
		return true
	var player := players.get(peer_id, null) as NetPlayer
	if player == null or player.get_health() <= 0:
		return false
	for peer_value in _active_fields_by_caster.keys():
		var caster_peer_id := int(peer_value)
		if caster_peer_id == peer_id:
			continue
		var center := _field_center_for_peer(caster_peer_id)
		if center == Vector2.ZERO:
			continue
		var field_data := _active_fields_by_caster.get(caster_peer_id, {}) as Dictionary
		var active := false
		if field_data.has("remaining"):
			active = float(field_data.get("remaining", 0.0)) > 0.0
		elif field_data.has("until_msec"):
			active = Time.get_ticks_msec() <= int(field_data.get("until_msec", 0))
		if not active:
			continue
		var radius_px := maxf(48.0, float(field_data.get("radius", RADAR_RADIUS_PX)))
		if player.global_position.distance_to(center) <= radius_px:
			return true
	return false

func _field_center_for_peer(peer_id: int) -> Vector2:
	var player := players.get(peer_id, null) as NetPlayer
	if player == null:
		return Vector2.ZERO
	return player.global_position + Vector2(-18.0, -26.0)

func _companion_for_peer(peer_id: int) -> Node2D:
	if projectile_system == null or projectile_system.projectiles_root == null:
		return null
	return projectile_system.projectiles_root.get_node_or_null("NovaCompanion_%d" % peer_id) as Node2D

func _companion_color_for_peer(peer_id: int) -> Color:
	var player := players.get(peer_id, null) as NetPlayer
	if player != null and player.has_method("get_torso_dominant_color"):
		var color_value: Variant = player.call("get_torso_dominant_color")
		if color_value is Color:
			var source := color_value as Color
			var boosted := source.lerp(Color(0.72, 0.28, 0.92, 1.0), 0.55)
			return Color(
				clampf(boosted.r, 0.0, 1.0),
				clampf(boosted.g, 0.0, 1.0),
				clampf(boosted.b, 0.0, 1.0),
				1.0
			)
	return Color(0.62, 0.25, 0.82, 1.0)

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_NOVA

func _skin_index_for_peer(peer_id: int) -> int:
	if skin_index_for_peer_cb.is_valid():
		return maxi(0, int(skin_index_for_peer_cb.call(peer_id)))
	return 0
