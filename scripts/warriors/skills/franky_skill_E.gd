extends Skill

const FRANKY_HEAL_CIRCLE_VFX := preload("res://scripts/warriors/vfx/franky_heal_circle_vfx.gd")

const CHARACTER_ID_FRANKY := "franky"
const STATUS_TEXT := "Healing Circle"
const HEAL_DURATION_SEC := 5.0
const HEAL_RADIUS_PX := 165.0
const HEAL_PER_SECOND := 20.0
const HEAL_TICK_SEC := 0.1
const EPSILON := 0.0001

var character_id_for_peer_cb: Callable = Callable()
var skill_color_for_peer_cb: Callable = Callable()

var _active_zones_by_caster: Dictionary = {}
var _client_vfx_by_caster: Dictionary = {}

func _init() -> void:
	super._init("franky_heal_circle", "Healing Circle", 0.0, "Create a stationary healing field that restores allies")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skill_color_for_peer_cb = callbacks.get("skill_color_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_FRANKY:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var center := caster.global_position
	_active_zones_by_caster[caster_peer_id] = {
		"remaining": HEAL_DURATION_SEC,
		"tick_accumulator": 0.0,
		"lobby_id": lobby_id,
		"center": center,
	}
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, center)

func _execute_client_visual(caster_peer_id: int, center_world: Vector2) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster != null and caster.has_method("start_ulti_duration_bar"):
		caster.call("start_ulti_duration_bar", HEAL_DURATION_SEC, STATUS_TEXT)
	_spawn_or_refresh_client_vfx(caster_peer_id, center_world)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _active_zones_by_caster.is_empty():
		return

	var finished_casters: Array[int] = []
	for caster_value in _active_zones_by_caster.keys():
		var caster_peer_id := int(caster_value)
		var state := _active_zones_by_caster.get(caster_peer_id, {}) as Dictionary
		var remaining := maxf(0.0, float(state.get("remaining", 0.0)) - delta)
		if remaining <= 0.0:
			finished_casters.append(caster_peer_id)
			continue
		var tick_accumulator := float(state.get("tick_accumulator", 0.0)) + delta
		while tick_accumulator >= HEAL_TICK_SEC:
			tick_accumulator -= HEAL_TICK_SEC
			_apply_heal_tick(caster_peer_id, state, HEAL_TICK_SEC)
		state["remaining"] = remaining
		state["tick_accumulator"] = tick_accumulator
		_active_zones_by_caster[caster_peer_id] = state

	for caster_peer_id in finished_casters:
		_active_zones_by_caster.erase(caster_peer_id)

func _apply_heal_tick(caster_peer_id: int, state: Dictionary, tick_sec: float) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null or caster.get_health() <= 0:
		return
	var lobby_id := int(state.get("lobby_id", 0))
	if lobby_id <= 0:
		lobby_id = _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var center := state.get("center", caster.global_position) as Vector2
	var heal_amount := maxi(1, int(round(HEAL_PER_SECOND * tick_sec)))
	for target_value in players.keys():
		var target_peer_id := int(target_value)
		if _get_peer_lobby(target_peer_id) != lobby_id:
			continue
		var target := players.get(target_peer_id, null) as NetPlayer
		if target == null or target.get_health() <= 0:
			continue
		if not _can_heal_target(caster_peer_id, target_peer_id):
			continue
		if target.global_position.distance_to(center) > HEAL_RADIUS_PX + EPSILON:
			continue
		_apply_heal_to_target(target, heal_amount)

func _apply_heal_to_target(target: NetPlayer, heal_amount: int) -> void:
	if target == null or heal_amount <= 0:
		return
	var current_health := target.get_health()
	if current_health <= 0:
		return
	var max_health := target.get_max_health() if target.has_method("get_max_health") else 100
	if current_health >= max_health:
		return
	target.set_health(mini(max_health, current_health + heal_amount))

func _spawn_or_refresh_client_vfx(caster_peer_id: int, center_world: Vector2) -> void:
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
	var vfx := FRANKY_HEAL_CIRCLE_VFX.new()
	vfx.name = "FrankyHealCircle_%d" % caster_peer_id
	vfx.center_world = center_world
	vfx.duration_sec = HEAL_DURATION_SEC
	vfx.radius_px = HEAL_RADIUS_PX
	vfx.effect_color = _skill_color_for_peer(caster_peer_id)
	host.add_child(vfx)
	_client_vfx_by_caster[caster_peer_id] = vfx

func _can_heal_target(caster_peer_id: int, target_peer_id: int) -> bool:
	if target_peer_id == caster_peer_id:
		return true
	var tree := _scene_tree()
	var root := tree.current_scene if tree != null else null
	if root != null and root.has_method("_ctf_enabled") and bool(root.call("_ctf_enabled")):
		if root.has_method("_team_for_peer"):
			var caster_team := int(root.call("_team_for_peer", caster_peer_id))
			var target_team := int(root.call("_team_for_peer", target_peer_id))
			return caster_team >= 0 and caster_team == target_team
	return false

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
	return CHARACTER_ID_FRANKY

func _skill_color_for_peer(peer_id: int) -> Color:
	if skill_color_for_peer_cb.is_valid():
		var value: Variant = skill_color_for_peer_cb.call(peer_id)
		if value is Color:
			return value as Color
	return Color(0.32, 0.92, 0.55, 1.0)
