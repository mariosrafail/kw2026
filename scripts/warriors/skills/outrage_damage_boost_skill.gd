## Outrage Skill 2: Damage Boost (E key)
##
## Temporary damage multiplier ability
## Increases weapon damage while active, and shows flame VFX.

extends Skill

const BOOST_DURATION_SEC := 4.0
const VFX_NAME := "OutrageBoostVfx"
const VFX_COLOR := Color(1.0, 0.55, 0.15, 0.95)

func _init() -> void:
	super._init("outrage_boost", "Damage Boost", 8.0, "Temporarily increases damage by 50%")

var boost_remaining_by_peer: Dictionary = {}
var _particle_tex_cache: Texture2D

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
		var peer_id: int = int(peer_value)
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

	var vfx := Node2D.new()
	vfx.name = VFX_NAME
	vfx.position = Vector2(0.0, -10.0)
	visual_root.add_child(vfx)

	var particles := CPUParticles2D.new()
	particles.amount = 32
	particles.lifetime = 0.55
	particles.one_shot = false
	particles.emitting = true
	particles.local_coords = true
	particles.spread = 28.0
	particles.direction = Vector2.UP
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 95.0
	particles.angular_velocity_min = -90.0
	particles.angular_velocity_max = 90.0
	particles.gravity = Vector2(0.0, -80.0)
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 9.0
	particles.color = VFX_COLOR
	particles.texture = _particle_tex()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = mat
	vfx.add_child(particles)

	var glow := Sprite2D.new()
	glow.centered = true
	glow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	glow.modulate = Color(1.0, 0.35, 0.05, 0.65)
	glow.z_index = 14
	glow.material = mat
	glow.texture = _glow_tex()
	glow.scale = Vector2.ONE * 1.6
	vfx.add_child(glow)

	var tween := vfx.create_tween()
	tween.set_loops()
	tween.tween_property(glow, "scale", Vector2.ONE * 1.85, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "scale", Vector2.ONE * 1.6, 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	var tree := vfx.get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(maxf(0.05, duration_sec))
	timer.timeout.connect(func() -> void:
		if vfx != null and is_instance_valid(vfx):
			vfx.queue_free()
	)

func _set_boost_damage(peer_id: int, enabled: bool) -> void:
	if not input_states.has(peer_id):
		return
	var state := input_states.get(peer_id, {}) as Dictionary
	state["boost_damage"] = enabled
	input_states[peer_id] = state

func _set_boost_server_until_msec(peer_id: int, until_msec: int) -> void:
	if not input_states.has(peer_id):
		return
	var state := input_states.get(peer_id, {}) as Dictionary
	if until_msec > 0:
		state["boost_server_until_msec"] = until_msec
	else:
		if state.has("boost_server_until_msec"):
			state.erase("boost_server_until_msec")
	input_states[peer_id] = state

func _particle_tex() -> Texture2D:
	if _particle_tex_cache != null:
		return _particle_tex_cache
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1, 1, 1, 1))
	_particle_tex_cache = ImageTexture.create_from_image(img)
	return _particle_tex_cache

func _glow_tex() -> Texture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 0.35, 0.05, 0.0),
		Color(1, 0.55, 0.15, 1.0),
		Color(1, 0.35, 0.05, 0.0)
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex
