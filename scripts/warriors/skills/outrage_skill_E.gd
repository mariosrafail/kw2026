## Outrage Skill E: Damage Boost
##
## Temporary damage multiplier ability
## Increases weapon damage while active, and shows flame VFX.

extends Skill

const BOOST_DURATION_SEC := 4.0
const BOOST_DAMAGE_MULTIPLIER := 1.5
const VFX_NAME := "OutrageBoostVfx"
const BOOST_SFX := preload("res://assets/sounds/sfx/skills/outrage_skill2.wav")
const BOOST_VFX_FADE_IN_SEC := 0.12
const BOOST_VFX_FADE_OUT_SEC := 0.22
const BOOST_VFX_FOLLOW_LAG := 0.12
const BOOST_VFX_TRAIL_OFFSET := Vector2(-3.0, -4.0)

var boost_remaining_by_peer: Dictionary = {}
var _particle_tex_cache: Texture2D
var _ember_tex_cache: Texture2D
var _smoke_tex_cache: Texture2D

func _init() -> void:
	super._init("outrage_boost", "Damage Boost", 8.0, "Temporarily increases damage by 50%")

func _execute_cast(caster_peer_id: int, target_world: Vector2) -> void:
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	boost_remaining_by_peer[caster_peer_id] = BOOST_DURATION_SEC
	_set_boost_server_until_msec(caster_peer_id, Time.get_ticks_msec() + int(BOOST_DURATION_SEC * 1000.0))
	_set_boost_damage(caster_peer_id, true)

	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, target_world)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	var duration := BOOST_DURATION_SEC
	if target_world.x > 0.05:
		duration = maxf(0.05, float(target_world.x))
	client_spawn_boost(caster_peer_id, duration)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if boost_remaining_by_peer.is_empty():
		return
	for peer_value in boost_remaining_by_peer.keys():
		var peer_id := int(peer_value)
		var remaining := float(boost_remaining_by_peer.get(peer_id, 0.0)) - delta
		if remaining > 0.0:
			boost_remaining_by_peer[peer_id] = remaining
			_set_boost_damage(peer_id, true)
		else:
			boost_remaining_by_peer.erase(peer_id)
			_set_boost_damage(peer_id, false)
			_set_boost_server_until_msec(peer_id, 0)

func client_spawn_boost(peer_id: int, duration_sec: float) -> void:
	var player: NetPlayer = players.get(peer_id, null) as NetPlayer
	if player == null:
		return
	var visual_root := player.get_node_or_null("VisualRoot") as Node2D
	if visual_root == null:
		return

	var existing := visual_root.get_node_or_null(VFX_NAME) as Node
	if existing != null:
		existing.queue_free()
	if player.has_method("set_outrage_boost_visual"):
		player.call("set_outrage_boost_visual", duration_sec)

	var vfx := Node2D.new()
	vfx.name = VFX_NAME
	vfx.position = Vector2(0.0, -6.0)
	vfx.modulate = Color(1.0, 1.0, 1.0, 0.0)
	vfx.z_index = -5
	visual_root.add_child(vfx)

	var trail_anchor := Node2D.new()
	trail_anchor.name = "TrailAnchor"
	trail_anchor.position = BOOST_VFX_TRAIL_OFFSET
	trail_anchor.set_meta("last_root_global_position", vfx.global_position)
	vfx.add_child(trail_anchor)
	_begin_vfx_follow_lag(trail_anchor, vfx)

	var boost_audio := AudioStreamPlayer2D.new()
	boost_audio.stream = BOOST_SFX
	boost_audio.bus = "SFX"
	boost_audio.max_polyphony = 1
	boost_audio.volume_db = -1.0
	vfx.add_child(boost_audio)
	boost_audio.play()

	var flame_particles := CPUParticles2D.new()
	flame_particles.amount = 34
	flame_particles.lifetime = 0.34
	flame_particles.one_shot = false
	flame_particles.emitting = true
	flame_particles.local_coords = true
	flame_particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flame_particles.spread = 14.0
	flame_particles.direction = Vector2.UP
	flame_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flame_particles.emission_rect_extents = Vector2(8.0, 9.0)
	flame_particles.initial_velocity_min = 28.0
	flame_particles.initial_velocity_max = 56.0
	flame_particles.angular_velocity_min = -18.0
	flame_particles.angular_velocity_max = 18.0
	flame_particles.gravity = Vector2(0.0, -52.0)
	flame_particles.scale_amount_min = 1.0
	flame_particles.scale_amount_max = 1.9
	flame_particles.color = Color(1.0, 0.56, 0.14, 0.88)
	flame_particles.texture = _particle_tex()
	var flame_mat := CanvasItemMaterial.new()
	flame_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	flame_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	flame_particles.material = flame_mat
	trail_anchor.add_child(flame_particles)

	var flame_core_particles := CPUParticles2D.new()
	flame_core_particles.amount = 18
	flame_core_particles.lifetime = 0.28
	flame_core_particles.one_shot = false
	flame_core_particles.emitting = true
	flame_core_particles.local_coords = true
	flame_core_particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flame_core_particles.spread = 9.0
	flame_core_particles.direction = Vector2.UP
	flame_core_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flame_core_particles.emission_rect_extents = Vector2(5.0, 7.0)
	flame_core_particles.initial_velocity_min = 16.0
	flame_core_particles.initial_velocity_max = 30.0
	flame_core_particles.angular_velocity_min = -10.0
	flame_core_particles.angular_velocity_max = 10.0
	flame_core_particles.gravity = Vector2(0.0, -40.0)
	flame_core_particles.scale_amount_min = 0.8
	flame_core_particles.scale_amount_max = 1.35
	flame_core_particles.color = Color(1.0, 0.9, 0.32, 0.82)
	flame_core_particles.texture = _ember_tex()
	flame_core_particles.material = flame_mat
	trail_anchor.add_child(flame_core_particles)

	var ember_particles := CPUParticles2D.new()
	ember_particles.amount = 10
	ember_particles.lifetime = 0.42
	ember_particles.one_shot = false
	ember_particles.emitting = true
	ember_particles.local_coords = true
	ember_particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ember_particles.spread = 16.0
	ember_particles.direction = Vector2.UP
	ember_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ember_particles.emission_rect_extents = Vector2(7.0, 7.0)
	ember_particles.initial_velocity_min = 50.0
	ember_particles.initial_velocity_max = 86.0
	ember_particles.angular_velocity_min = -85.0
	ember_particles.angular_velocity_max = 85.0
	ember_particles.gravity = Vector2(0.0, -12.0)
	ember_particles.scale_amount_min = 0.45
	ember_particles.scale_amount_max = 0.9
	ember_particles.color = Color(1.0, 0.8, 0.26, 0.82)
	ember_particles.texture = _ember_tex()
	ember_particles.material = flame_mat
	trail_anchor.add_child(ember_particles)

	var smoke_particles := CPUParticles2D.new()
	smoke_particles.amount = 5
	smoke_particles.lifetime = 0.55
	smoke_particles.one_shot = false
	smoke_particles.emitting = true
	smoke_particles.local_coords = true
	smoke_particles.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	smoke_particles.spread = 9.0
	smoke_particles.direction = Vector2.UP
	smoke_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	smoke_particles.emission_rect_extents = Vector2(4.0, 5.0)
	smoke_particles.initial_velocity_min = 8.0
	smoke_particles.initial_velocity_max = 14.0
	smoke_particles.gravity = Vector2(0.0, -6.0)
	smoke_particles.scale_amount_min = 0.8
	smoke_particles.scale_amount_max = 1.4
	smoke_particles.color = Color(0.22, 0.12, 0.08, 0.18)
	smoke_particles.texture = _smoke_tex()
	var smoke_mat := CanvasItemMaterial.new()
	smoke_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	smoke_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	smoke_particles.material = smoke_mat
	trail_anchor.add_child(smoke_particles)

	var fade_in := vfx.create_tween()
	fade_in.tween_property(vfx, "modulate:a", 1.0, BOOST_VFX_FADE_IN_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var tree := vfx.get_tree()
	if tree == null:
		return
	var visible_duration := maxf(0.05, duration_sec)
	var fade_out_delay := maxf(0.0, visible_duration - BOOST_VFX_FADE_OUT_SEC)
	var player_id := player.get_instance_id()
	var vfx_id := vfx.get_instance_id()
	var flame_particles_id := flame_particles.get_instance_id()
	var flame_core_particles_id := flame_core_particles.get_instance_id()
	var ember_particles_id := ember_particles.get_instance_id()
	var smoke_particles_id := smoke_particles.get_instance_id()
	if fade_out_delay <= 0.001:
		_begin_boost_vfx_fade_out(player_id, vfx_id, flame_particles_id, flame_core_particles_id, ember_particles_id, smoke_particles_id)
		return
	var timer := tree.create_timer(fade_out_delay)
	timer.timeout.connect(
		Callable(self, "_begin_boost_vfx_fade_out").bind(
			player_id,
			vfx_id,
			flame_particles_id,
			flame_core_particles_id,
			ember_particles_id,
			smoke_particles_id
		),
		CONNECT_ONE_SHOT
	)

func _begin_vfx_follow_lag(trail_anchor: Node2D, vfx_root: Node2D) -> void:
	if trail_anchor == null or vfx_root == null:
		return
	var tree := vfx_root.get_tree()
	if tree == null:
		return
	_schedule_vfx_follow_frame(tree, trail_anchor.get_instance_id(), vfx_root.get_instance_id())

func _follow_boost_vfx_frame(trail_anchor_instance_id: int, vfx_root_instance_id: int) -> void:
	var trail_anchor_obj := instance_from_id(trail_anchor_instance_id)
	var vfx_root_obj := instance_from_id(vfx_root_instance_id)
	if trail_anchor_obj == null or not (trail_anchor_obj is Node2D):
		return
	if vfx_root_obj == null or not (vfx_root_obj is Node2D):
		return
	var trail_anchor := trail_anchor_obj as Node2D
	var vfx_root := vfx_root_obj as Node2D
	var last_root_global_value: Variant = trail_anchor.get_meta("last_root_global_position", vfx_root.global_position)
	var last_root_global := last_root_global_value as Vector2 if last_root_global_value is Vector2 else vfx_root.global_position
	var root_delta := vfx_root.global_position - last_root_global
	trail_anchor.position -= root_delta * 0.42
	var desired_position := BOOST_VFX_TRAIL_OFFSET
	trail_anchor.position = trail_anchor.position.lerp(desired_position, BOOST_VFX_FOLLOW_LAG)
	trail_anchor.set_meta("last_root_global_position", vfx_root.global_position)
	var next_tree := vfx_root.get_tree()
	if next_tree != null:
		_schedule_vfx_follow_frame(next_tree, trail_anchor_instance_id, vfx_root_instance_id)

func _schedule_vfx_follow_frame(tree: SceneTree, trail_anchor_instance_id: int, vfx_root_instance_id: int) -> void:
	var follow_callable := Callable(self, "_follow_boost_vfx_frame").bind(trail_anchor_instance_id, vfx_root_instance_id)
	if tree.process_frame.is_connected(follow_callable):
		return
	tree.process_frame.connect(follow_callable, CONNECT_ONE_SHOT)

func _begin_boost_vfx_fade_out(
	player_id: int,
	vfx_id: int,
	flame_particles_id: int,
	flame_core_particles_id: int,
	ember_particles_id: int,
	smoke_particles_id: int
) -> void:
	for particle_id in [flame_particles_id, flame_core_particles_id, ember_particles_id, smoke_particles_id]:
		var particle_obj := instance_from_id(particle_id)
		if particle_obj != null and particle_obj is CPUParticles2D:
			(particle_obj as CPUParticles2D).emitting = false
	var vfx_obj := instance_from_id(vfx_id)
	if vfx_obj == null or not (vfx_obj is Node2D):
		_clear_boost_visual_for_player(player_id)
		return
	var vfx := vfx_obj as Node2D
	var fade_out := vfx.create_tween()
	fade_out.tween_property(vfx, "modulate:a", 0.0, BOOST_VFX_FADE_OUT_SEC).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	fade_out.finished.connect(Callable(self, "_finish_boost_vfx_fade_out").bind(player_id, vfx_id), CONNECT_ONE_SHOT)

func _finish_boost_vfx_fade_out(player_id: int, vfx_id: int) -> void:
	_clear_boost_visual_for_player(player_id)
	var vfx_obj := instance_from_id(vfx_id)
	if vfx_obj != null and vfx_obj is Node:
		(vfx_obj as Node).queue_free()

func _clear_boost_visual_for_player(player_id: int) -> void:
	var player_obj := instance_from_id(player_id)
	if player_obj != null and player_obj is NetPlayer and (player_obj as NetPlayer).has_method("clear_outrage_boost_visual"):
		(player_obj as NetPlayer).call("clear_outrage_boost_visual")

func _set_boost_damage(peer_id: int, enabled: bool) -> void:
	if not input_states.has(peer_id):
		return
	var state = input_states.get(peer_id, {}) as Dictionary
	state["boost_damage"] = enabled
	if enabled:
		state["boost_damage_multiplier"] = BOOST_DAMAGE_MULTIPLIER
	elif state.has("boost_damage_multiplier"):
		state.erase("boost_damage_multiplier")
	input_states[peer_id] = state

func _set_boost_server_until_msec(peer_id: int, until_msec: int) -> void:
	if not input_states.has(peer_id):
		return
	var state = input_states.get(peer_id, {}) as Dictionary
	if until_msec > 0:
		state["boost_server_until_msec"] = until_msec
	elif state.has("boost_server_until_msec"):
		state.erase("boost_server_until_msec")
	input_states[peer_id] = state

func _particle_tex() -> Texture2D:
	if _particle_tex_cache != null:
		return _particle_tex_cache
	var img := Image.create(5, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(7):
		for x in range(5):
			var dx := absf(float(x) - 2.0)
			var top_cut := 1 if y <= 1 else 0
			if dx <= 2.0 - float(top_cut) and (y >= 1 or dx <= 1.0):
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	_particle_tex_cache = ImageTexture.create_from_image(img)
	return _particle_tex_cache

func _ember_tex() -> Texture2D:
	if _ember_tex_cache != null:
		return _ember_tex_cache
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_ember_tex_cache = ImageTexture.create_from_image(img)
	return _ember_tex_cache

func _smoke_tex() -> Texture2D:
	if _smoke_tex_cache != null:
		return _smoke_tex_cache
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(4):
		for x in range(4):
			var dx := absf(float(x) - 1.5)
			var dy := absf(float(y) - 1.5)
			if dx + dy <= 2.5:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	_smoke_tex_cache = ImageTexture.create_from_image(img)
	return _smoke_tex_cache
