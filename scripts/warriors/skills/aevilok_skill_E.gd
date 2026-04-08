extends Skill

const AEVILOK_FLAMETHROWER_VFX := preload("res://scripts/warriors/vfx/aevilok_flamethrower_vfx.gd")

const CHARACTER_ID_AEVILOK := "aevilok"
const STATUS_TEXT := "Flamethrower"
const INTRO_ANIM_SEC := 0.52
const FLAME_DURATION_SEC := 3.0
const FLAME_RANGE_PX := 255.0
const FLAME_WIDTH_NEAR_PX := 24.0
const FLAME_WIDTH_FAR_PX := 56.0
const FLAME_DAMAGE_PER_SECOND := 46.0
const FLAME_DAMAGE_TICK_SEC := 0.1
const FLAME_IMPACT_VELOCITY := 190.0
const EPSILON := 0.0001

var character_id_for_peer_cb: Callable = Callable()
var skill_color_for_peer_cb: Callable = Callable()

var _active_by_caster: Dictionary = {}
var _client_vfx_by_caster: Dictionary = {}

func _init() -> void:
	super._init("aevilok_flamethrower", "Flamethrower", 0.0, "Warmup animation then channels fire in the head rotation direction")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	skill_color_for_peer_cb = callbacks.get("skill_color_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_AEVILOK:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	_active_by_caster[caster_peer_id] = {
		"intro_remaining": INTRO_ANIM_SEC,
		"fire_remaining": FLAME_DURATION_SEC,
		"tick_accumulator": 0.0,
		"lobby_id": lobby_id,
	}
	var payload := Vector2(INTRO_ANIM_SEC, FLAME_DURATION_SEC)
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, payload)

func _execute_client_visual(caster_peer_id: int, payload: Vector2) -> void:
	var intro_sec := maxf(0.1, payload.x if payload.x > 0.0 else INTRO_ANIM_SEC)
	var fire_sec := maxf(0.1, payload.y if payload.y > 0.0 else FLAME_DURATION_SEC)
	var total_sec := intro_sec + fire_sec
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster != null and caster.has_method("start_ulti_duration_bar"):
		caster.call("start_ulti_duration_bar", total_sec, STATUS_TEXT)
	_spawn_or_refresh_client_vfx(caster_peer_id, intro_sec, fire_sec)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _active_by_caster.is_empty():
		return

	var finished_casters: Array[int] = []
	for caster_value in _active_by_caster.keys():
		var caster_peer_id := int(caster_value)
		var state := _active_by_caster.get(caster_peer_id, {}) as Dictionary
		var intro_before := float(state.get("intro_remaining", 0.0))
		var intro_remaining := maxf(0.0, intro_before - delta)
		var fire_remaining := float(state.get("fire_remaining", 0.0))
		var tick_accumulator := float(state.get("tick_accumulator", 0.0))
		var spend_delta := delta
		var consumed_intro := minf(spend_delta, intro_before)
		spend_delta -= consumed_intro
		if intro_remaining > 0.0:
			tick_accumulator = 0.0
		if intro_remaining <= 0.0:
			fire_remaining = maxf(0.0, fire_remaining - spend_delta)
			tick_accumulator += spend_delta
			while tick_accumulator >= FLAME_DAMAGE_TICK_SEC and fire_remaining > 0.0:
				tick_accumulator -= FLAME_DAMAGE_TICK_SEC
				_apply_flamethrower_damage_tick(caster_peer_id, int(state.get("lobby_id", 0)), FLAME_DAMAGE_TICK_SEC)
		state["intro_remaining"] = intro_remaining
		state["fire_remaining"] = fire_remaining
		state["tick_accumulator"] = tick_accumulator
		if intro_remaining <= 0.0 and fire_remaining <= 0.0:
			finished_casters.append(caster_peer_id)
		else:
			_active_by_caster[caster_peer_id] = state

	for caster_peer_id in finished_casters:
		_active_by_caster.erase(caster_peer_id)

func _apply_flamethrower_damage_tick(caster_peer_id: int, lobby_id: int, tick_sec: float) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null or caster.get_health() <= 0:
		return
	if lobby_id <= 0:
		lobby_id = _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return

	var origin := _flame_origin_for_player(caster)
	var flame_dir := _flame_direction_for_caster(caster_peer_id, caster)
	if flame_dir.length_squared() <= EPSILON:
		return

	var base_damage := maxi(1, int(round(FLAME_DAMAGE_PER_SECOND * tick_sec)))
	for target_value in players.keys():
		var target_peer_id := int(target_value)
		if target_peer_id == caster_peer_id:
			continue
		if _get_peer_lobby(target_peer_id) != lobby_id:
			continue
		if not _can_damage_target(caster_peer_id, target_peer_id):
			continue
		var target := players.get(target_peer_id, null) as NetPlayer
		if target == null or target.get_health() <= 0:
			continue
		if _wall_blocks_target(caster, target, origin):
			continue
		var to_target := target.global_position - origin
		var along := to_target.dot(flame_dir)
		if along < 0.0 or along > FLAME_RANGE_PX:
			continue
		var lateral := absf(to_target.cross(flame_dir))
		var t := clampf(along / FLAME_RANGE_PX, 0.0, 1.0)
		var target_radius := target.get_hit_radius() if target.has_method("get_hit_radius") else 12.0
		var allowed_radius := lerpf(FLAME_WIDTH_NEAR_PX, FLAME_WIDTH_FAR_PX, t) + target_radius
		if lateral > allowed_radius:
			continue
		if hit_damage_resolver != null:
			hit_damage_resolver.server_apply_direct_damage(
				caster_peer_id,
				target_peer_id,
				target,
				base_damage,
				flame_dir * FLAME_IMPACT_VELOCITY
			)

func _spawn_or_refresh_client_vfx(caster_peer_id: int, intro_sec: float, fire_sec: float) -> void:
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
	var vfx := AEVILOK_FLAMETHROWER_VFX.new()
	vfx.name = "AevilokFlame_%d" % caster_peer_id
	vfx.players = players
	vfx.caster_peer_id = caster_peer_id
	vfx.intro_duration_sec = intro_sec
	vfx.fire_duration_sec = fire_sec
	vfx.flame_color = _skill_color_for_peer(caster_peer_id)
	host.add_child(vfx)
	_client_vfx_by_caster[caster_peer_id] = vfx

func _flame_origin_for_player(player: NetPlayer) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var head_node := player.get_node_or_null("VisualRoot/head") as Node2D
	if head_node != null:
		return head_node.global_position
	return player.global_position + Vector2(0.0, -14.0)

func _flame_direction_for_caster(caster_peer_id: int, caster: NetPlayer) -> Vector2:
	if caster != null:
		var head_node := caster.get_node_or_null("VisualRoot/head") as Node2D
		if head_node != null:
			var head_dir := Vector2.RIGHT.rotated(head_node.global_rotation)
			if head_dir.length_squared() > EPSILON:
				return head_dir.normalized()
	var origin := _flame_origin_for_player(caster)
	var state := input_states.get(caster_peer_id, {}) as Dictionary
	if state.has("aim_world"):
		var aim_world := state.get("aim_world", origin) as Vector2
		var dir := aim_world - origin
		if dir.length_squared() > EPSILON:
			return dir.normalized()
	if caster != null and caster.has_method("get_aim_angle"):
		var angle := float(caster.call("get_aim_angle"))
		return Vector2.RIGHT.rotated(angle).normalized()
	return Vector2.RIGHT

func _wall_blocks_target(caster: NetPlayer, target: NetPlayer, origin: Vector2) -> bool:
	if caster == null or target == null:
		return true
	var world := caster.get_world_2d()
	if world == null:
		return false
	var query := PhysicsRayQueryParameters2D.create(origin, target.global_position, 1)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = [caster, target]
	var hit := world.direct_space_state.intersect_ray(query)
	return not hit.is_empty()

func _vfx_host_node() -> Node:
	if projectile_system != null and projectile_system.projectiles_root != null:
		return projectile_system.projectiles_root
	var tree := _scene_tree()
	if tree == null:
		return null
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root

func _can_damage_target(caster_peer_id: int, target_peer_id: int) -> bool:
	var tree := _scene_tree()
	var root := tree.current_scene if tree != null else null
	if root != null and root.has_method("_ctf_enabled") and bool(root.call("_ctf_enabled")):
		if root.has_method("_team_for_peer"):
			var caster_team := int(root.call("_team_for_peer", caster_peer_id))
			var target_team := int(root.call("_team_for_peer", target_peer_id))
			if caster_team >= 0 and target_team >= 0 and caster_team == target_team:
				return false
	return true

func _scene_tree() -> SceneTree:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return loop as SceneTree
	return null

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_AEVILOK

func _skill_color_for_peer(peer_id: int) -> Color:
	if skill_color_for_peer_cb.is_valid():
		var value: Variant = skill_color_for_peer_cb.call(peer_id)
		if value is Color:
			return value as Color
	return Color(1.0, 0.47, 0.16, 1.0)
