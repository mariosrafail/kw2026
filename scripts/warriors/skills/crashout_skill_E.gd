extends Skill

const CHARACTER_ID_CRASHOUT := "crashout"
const STATUS_TEXT := "Bounce Bubble"
const BUBBLE_DURATION_SEC := 4.5
const BUBBLE_RADIUS_PX := 116.0
const BUBBLE_EDGE_PAD_PX := 10.0
const MAX_REFLECTS_PER_PROJECTILE := 1
const REFLECT_COLOR := Color(0.33, 0.93, 1.0, 1.0)

var character_id_for_peer_cb: Callable = Callable()
var skill_color_for_peer_cb: Callable = Callable()
var reflect_projectile_cb: Callable = Callable()
var _bubbles_by_caster: Dictionary = {}
var _projectile_reflect_counts: Dictionary = {}

func _init() -> void:
	super._init("crashout_bounce_bubble", "Bounce Bubble", 0.0, "Creates a bubble that sends enemy bullets back as CrashOut's own")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skill_color_for_peer_cb = callbacks.get("skill_color_for_peer", Callable()) as Callable
	reflect_projectile_cb = callbacks.get("reflect_projectile", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_CRASHOUT:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var center := caster.global_position
	_bubbles_by_caster[caster_peer_id] = {
		"remaining": BUBBLE_DURATION_SEC,
		"center": center,
		"lobby_id": lobby_id,
		"radius": BUBBLE_RADIUS_PX,
	}
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, center)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player != null:
		if player.has_method("set_crashout_belly_visual"):
			player.call("set_crashout_belly_visual", BUBBLE_DURATION_SEC)
		if player.has_method("start_ulti_duration_bar"):
			player.call("start_ulti_duration_bar", BUBBLE_DURATION_SEC, STATUS_TEXT)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	_prune_invalid_reflect_counts()
	if _bubbles_by_caster.is_empty() or projectile_system == null:
		return
	var expired_casters: Array[int] = []
	for caster_value in _bubbles_by_caster.keys():
		var caster_peer_id := int(caster_value)
		var bubble_data := _bubbles_by_caster.get(caster_peer_id, {}) as Dictionary
		var remaining := maxf(0.0, float(bubble_data.get("remaining", 0.0)) - maxf(0.0, delta))
		if remaining <= 0.0:
			expired_casters.append(caster_peer_id)
			continue
		var caster := players.get(caster_peer_id, null) as NetPlayer
		if caster == null or caster.get_health() <= 0:
			expired_casters.append(caster_peer_id)
			continue
		bubble_data["remaining"] = remaining
		bubble_data["center"] = caster.global_position
		_bubbles_by_caster[caster_peer_id] = bubble_data
		_reflect_projectiles_for_bubble(caster_peer_id, bubble_data)
	for caster_peer_id in expired_casters:
		_bubbles_by_caster.erase(caster_peer_id)

func on_projectile_despawn(projectile_id: int) -> void:
	_projectile_reflect_counts.erase(projectile_id)

func _reflect_projectiles_for_bubble(caster_peer_id: int, bubble_data: Dictionary) -> void:
	var center := bubble_data.get("center", Vector2.ZERO) as Vector2
	var lobby_id := int(bubble_data.get("lobby_id", 0))
	var radius := maxf(24.0, float(bubble_data.get("radius", BUBBLE_RADIUS_PX)))
	var projectile_ids := projectile_system.projectiles.keys()
	projectile_ids.sort()
	for projectile_value in projectile_ids:
		var projectile_id := int(projectile_value)
		var projectile := projectile_system.get_projectile(projectile_id)
		if projectile == null or not projectile.can_deal_damage():
			continue
		if projectile.owner_peer_id == caster_peer_id:
			continue
		if projectile_system.get_projectile_lobby(projectile_id, 0) != lobby_id:
			continue
		if projectile_system.get_projectile_weapon_id(projectile_id, "") == "grenade":
			continue
		if int(_projectile_reflect_counts.get(projectile_id, 0)) >= MAX_REFLECTS_PER_PROJECTILE:
			continue
		var to_center := center - projectile.global_position
		if to_center.length() > radius:
			continue
		if projectile.velocity.length_squared() <= 0.0001:
			continue
		if projectile.velocity.dot(to_center) <= 0.0:
			continue
		var reflected_velocity := -projectile.velocity
		var reflect_dir := reflected_velocity.normalized()
		var respawn_position := center + reflect_dir * (radius + BUBBLE_EDGE_PAD_PX)
		if reflect_projectile_cb.is_valid():
			var reflected: Variant = reflect_projectile_cb.call(
				projectile_id,
				caster_peer_id,
				respawn_position,
				reflected_velocity,
				respawn_position
			)
			if reflected == true:
				_projectile_reflect_counts[projectile_id] = int(_projectile_reflect_counts.get(projectile_id, 0)) + 1

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_CRASHOUT

func _skill_color_for_peer(peer_id: int) -> Color:
	if skill_color_for_peer_cb.is_valid():
		var value: Variant = skill_color_for_peer_cb.call(peer_id)
		if value is Color:
			return value as Color
	return REFLECT_COLOR

func _prune_invalid_reflect_counts() -> void:
	if projectile_system == null or _projectile_reflect_counts.is_empty():
		return
	var stale_ids: Array[int] = []
	for projectile_value in _projectile_reflect_counts.keys():
		var projectile_id := int(projectile_value)
		if projectile_system.get_projectile(projectile_id) == null:
			stale_ids.append(projectile_id)
	for projectile_id in stale_ids:
		_projectile_reflect_counts.erase(projectile_id)
