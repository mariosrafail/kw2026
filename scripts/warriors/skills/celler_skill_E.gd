extends Skill

const CELLER_MOON_VFX := preload("res://scripts/warriors/vfx/celler_moon_vfx.gd")

const CHARACTER_ID_CELLER := "celler"
const MOON_DURATION_SEC := 5.0
const EXPLOSION_RADIUS_PX := 124.0
const EXPLOSION_DAMAGE := 55
const STATUS_TEXT := "Moonfall"
const BASE_MOON_COLOR := Color(0.68, 0.8, 1.0, 0.96)

var character_id_for_peer_cb: Callable = Callable()
var _active_moons_by_peer: Dictionary = {}

func _init() -> void:
	super._init("celler_moonfall", "Moonfall", 0.0, "Grow a moon above yourself that explodes after 5 seconds")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_CELLER:
		return
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	_active_moons_by_peer[caster_peer_id] = {
		"remaining": MOON_DURATION_SEC,
		"lobby_id": lobby_id
	}
	var payload := Vector2(MOON_DURATION_SEC, EXPLOSION_RADIUS_PX)
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, payload)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	var duration_sec := maxf(0.05, target_world.x if absf(target_world.x) > 0.0001 else MOON_DURATION_SEC)
	var radius_px := maxf(24.0, target_world.y if absf(target_world.y) > 0.0001 else EXPLOSION_RADIUS_PX)
	_spawn_moon_vfx(caster_peer_id, duration_sec, radius_px)
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player != null and player.has_method("start_ulti_duration_bar"):
		player.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _active_moons_by_peer.is_empty():
		return

	var detonated_peers: Array[int] = []
	for peer_value in _active_moons_by_peer.keys():
		var caster_peer_id := int(peer_value)
		var moon_data := _active_moons_by_peer.get(caster_peer_id, {}) as Dictionary
		var remaining := maxf(0.0, float(moon_data.get("remaining", 0.0)) - delta)
		moon_data["remaining"] = remaining
		_active_moons_by_peer[caster_peer_id] = moon_data
		if remaining <= 0.0:
			detonated_peers.append(caster_peer_id)

	for caster_peer_id in detonated_peers:
		_detonate_moon(caster_peer_id)
		_active_moons_by_peer.erase(caster_peer_id)

func _detonate_moon(caster_peer_id: int) -> void:
	var moon_data := _active_moons_by_peer.get(caster_peer_id, {}) as Dictionary
	var lobby_id := int(moon_data.get("lobby_id", _get_peer_lobby(caster_peer_id)))
	if lobby_id <= 0:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var explosion_center := caster.global_position
	for peer_value in players.keys():
		var target_peer_id := int(peer_value)
		if target_peer_id == caster_peer_id:
			continue
		if _get_peer_lobby(target_peer_id) != lobby_id:
			continue
		var target := players.get(target_peer_id, null) as NetPlayer
		if target == null:
			continue
		if target.get_health() <= 0:
			continue
		var to_target := target.global_position - explosion_center
		if to_target.length() > EXPLOSION_RADIUS_PX:
			continue
		if hit_damage_resolver != null and hit_damage_resolver.has_method("server_apply_direct_damage"):
			hit_damage_resolver.server_apply_direct_damage(caster_peer_id, target_peer_id, target, EXPLOSION_DAMAGE, to_target)

func _spawn_moon_vfx(caster_peer_id: int, duration_sec: float, radius_px: float) -> void:
	if projectile_system == null or projectile_system.projectiles_root == null:
		return
	var existing := projectile_system.projectiles_root.get_node_or_null("CellerMoon_%d" % caster_peer_id) as Node
	if existing != null:
		existing.queue_free()
	var vfx := CELLER_MOON_VFX.new()
	vfx.name = "CellerMoon_%d" % caster_peer_id
	vfx.caster_peer_id = caster_peer_id
	vfx.duration_sec = duration_sec
	vfx.explosion_radius = radius_px
	vfx.players = players
	vfx.color = _moon_color_for_peer(caster_peer_id)
	projectile_system.projectiles_root.add_child(vfx)

func _moon_color_for_peer(caster_peer_id: int) -> Color:
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player != null and player.has_method("get_torso_dominant_color"):
		var color_value: Variant = player.call("get_torso_dominant_color")
		if color_value is Color:
			var source := color_value as Color
			var blended := source.lerp(BASE_MOON_COLOR, 0.72)
			return Color(
				clampf(blended.r, 0.0, 1.0),
				clampf(blended.g, 0.0, 1.0),
				clampf(blended.b, 0.0, 1.0),
				0.96
			)
	return BASE_MOON_COLOR

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_CELLER
