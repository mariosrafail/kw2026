extends Skill

const CTRLALT_CLONE_CONTROLLER_SCRIPT := preload("res://scripts/world/ctrlalt_clone_bot_controller.gd")

const CHARACTER_ID_CTRLALT := "ctrlalt"
const STATUS_TEXT := "Fork Parade"
const CLONE_DURATION_SEC := 7.0
const CLONE_BASE_PEER_ID := -9100
const CLONE_PROJECTILE_DAMAGE := 2

var character_id_for_peer_cb: Callable = Callable()
var skill_color_for_peer_cb: Callable = Callable()
var spawn_temporary_bot_cb: Callable = Callable()
var despawn_temporary_bot_cb: Callable = Callable()
var _clone_state_by_caster: Dictionary = {}
var _clone_projectiles: Dictionary = {}

func _init() -> void:
	super._init("ctrlalt_fork_parade", "Fork Parade", 4.5, "Summons fake hostile clones that walk and spray light random fire")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skill_color_for_peer_cb = callbacks.get("skill_color_for_peer", Callable()) as Callable
	spawn_temporary_bot_cb = callbacks.get("spawn_temporary_bot", Callable()) as Callable
	despawn_temporary_bot_cb = callbacks.get("despawn_temporary_bot", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_CTRLALT:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	_clear_clones_for_caster(caster_peer_id)
	var clone_peer_id := _primary_clone_peer_id(caster_peer_id)
	var spawned := false
	if spawn_temporary_bot_cb.is_valid():
		var spawn_result: Variant = spawn_temporary_bot_cb.call({
			"controller_script": CTRLALT_CLONE_CONTROLLER_SCRIPT,
			"bot_peer_id": clone_peer_id,
			"bot_name": "Ctrlalt Clone",
			"bot_color": _skill_color_for_peer(caster_peer_id),
			"spawn_position": caster.global_position,
			"lobby_id": lobby_id,
			"owner_peer_id": caster_peer_id,
			"character_id": CHARACTER_ID_CTRLALT,
			"skin_index": 0,
			"think_rate_hz": 14.0
		})
		spawned = spawn_result == true
	if not spawned:
		return
	_clone_state_by_caster[caster_peer_id] = {
		"peer_id": clone_peer_id,
		"expire_msec": Time.get_ticks_msec() + int(CLONE_DURATION_SEC * 1000.0),
	}
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, Vector2(CLONE_DURATION_SEC, 1.0))

func _execute_client_visual(caster_peer_id: int, payload: Vector2) -> void:
	var duration_sec := maxf(0.05, payload.x if absf(payload.x) > 0.0001 else CLONE_DURATION_SEC)
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player != null and player.has_method("start_ulti_duration_bar"):
		player.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)

func server_tick(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	_update_clone_projectile_damage()
	var now_msec := Time.get_ticks_msec()
	var expired_casters: Array[int] = []
	for caster_value in _clone_state_by_caster.keys():
		var caster_peer_id := int(caster_value)
		var state := _clone_state_by_caster.get(caster_peer_id, {}) as Dictionary
		var clone_peer_id := int(state.get("peer_id", 0))
		var clone_player := players.get(clone_peer_id, null) as NetPlayer
		var clone_alive := clone_player != null and clone_player.get_health() > 0
		if now_msec >= int(state.get("expire_msec", 0)) or not clone_alive:
			expired_casters.append(caster_peer_id)
			continue
		_clone_state_by_caster[caster_peer_id] = state
	for caster_peer_id in expired_casters:
		_clear_clones_for_caster(caster_peer_id)

func on_projectile_despawn(projectile_id: int) -> void:
	_clone_projectiles.erase(projectile_id)

func _update_clone_projectile_damage() -> void:
	if projectile_system == null:
		return
	for projectile_value in projectile_system.projectiles.keys():
		var projectile_id := int(projectile_value)
		if _clone_projectiles.has(projectile_id):
			continue
		var projectile := projectile_system.get_projectile(projectile_id)
		if projectile == null:
			continue
		if not _is_clone_peer(projectile.owner_peer_id):
			continue
		projectile_system.projectile_damage_by_id[projectile_id] = CLONE_PROJECTILE_DAMAGE
		_clone_projectiles[projectile_id] = projectile.owner_peer_id

func _clear_clones_for_caster(caster_peer_id: int) -> void:
	for peer_id in _clone_peer_ids_for_caster(caster_peer_id):
		if despawn_temporary_bot_cb.is_valid() and peer_id != 0:
			despawn_temporary_bot_cb.call(peer_id)
	_clone_state_by_caster.erase(caster_peer_id)

func _is_clone_peer(peer_id: int) -> bool:
	for state_value in _clone_state_by_caster.values():
		var state := state_value as Dictionary
		if int(state.get("peer_id", 0)) == peer_id:
			return true
	return false

func _primary_clone_peer_id(caster_peer_id: int) -> int:
	return CLONE_BASE_PEER_ID - caster_peer_id * 10

func _legacy_clone_peer_ids(caster_peer_id: int) -> Array[int]:
	return [
		CLONE_BASE_PEER_ID - caster_peer_id * 10,
		CLONE_BASE_PEER_ID - caster_peer_id * 10 - 1
	]

func _clone_peer_ids_for_caster(caster_peer_id: int) -> Array[int]:
	var peer_ids: Array[int] = []
	var primary_peer_id := _primary_clone_peer_id(caster_peer_id)
	if primary_peer_id != 0:
		peer_ids.append(primary_peer_id)
	for legacy_peer_id in _legacy_clone_peer_ids(caster_peer_id):
		if not peer_ids.has(legacy_peer_id):
			peer_ids.append(legacy_peer_id)
	var state := _clone_state_by_caster.get(caster_peer_id, {}) as Dictionary
	var tracked_peer_id := int(state.get("peer_id", 0))
	if tracked_peer_id != 0 and not peer_ids.has(tracked_peer_id):
		peer_ids.append(tracked_peer_id)
	return peer_ids

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_CTRLALT

func _skill_color_for_peer(peer_id: int) -> Color:
	if skill_color_for_peer_cb.is_valid():
		var value: Variant = skill_color_for_peer_cb.call(peer_id)
		if value is Color:
			return value as Color
	return Color(0.48, 0.95, 0.62, 1.0)
