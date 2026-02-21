extends RefCounted

const CHARACTER_ID_OUTRAGE := "outrage"

const BOMB_TEXTURE := preload("res://assets/outrage_bomb.png")
const BOMB_SFX := preload("res://assets/sounds/sfx/skills/outrage_skill1.wav")

const FUSE_SEC := 0.9
const DAMAGE := 50
const RADIUS := 64.0

const BOMB_TINT := Color(1.0, 0.15, 0.15, 1.0)
const BOMB_SCALE := 1.25

# Timing (relative to explosion end).
const PRE_DAMAGE_SEC := 0.4
const END_PARTICLES_LEAD_SEC := 0.4
const SHAKE_LEAD_SEC := 0.4

# End particles tuning.
const END_PARTICLES_AMOUNT := 60
const END_PARTICLES_LIFETIME := 0.85
const END_PARTICLES_GRAVITY := Vector2(0.0, 1400.0)
const END_PARTICLES_SCALE_MIN := 6.0
const END_PARTICLES_SCALE_MAX := 12.0
const END_PARTICLES_COLOR := Color(0.02, 0.02, 0.02, 0.95)

# Screen shake tuning.
const SHAKE_INNER_RADIUS := 90.0
const SHAKE_OUTER_RADIUS := 360.0
const SHAKE_AMOUNT := 5.0
const SHAKE_MAX_TRAUMA := 0.95
const SHAKE_MAX_OFFSET := 22.0
const SHAKE_HOLD_SEC := 0.22

var players: Dictionary = {}
var multiplayer: MultiplayerAPI
var projectile_system: ProjectileSystem
var hit_damage_resolver: HitDamageResolver
var camera_shake: CameraShake

var _peer_lobby_cb: Callable = Callable()
var _lobby_members_cb: Callable = Callable()
var _character_id_for_peer_cb: Callable = Callable()
var _send_spawn_bomb_cb: Callable = Callable()

var _active_bombs: Array = []
var _bomb_frames_cache: Array[Texture2D] = []
var _particle_tex_cache: Texture2D

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	players = state_refs.get("players", {}) as Dictionary
	multiplayer = state_refs.get("multiplayer", null) as MultiplayerAPI
	projectile_system = state_refs.get("projectile_system", null) as ProjectileSystem
	hit_damage_resolver = state_refs.get("hit_damage_resolver", null) as HitDamageResolver
	camera_shake = state_refs.get("camera_shake", null) as CameraShake

	_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable()) as Callable
	_lobby_members_cb = callbacks.get("get_lobby_members", Callable()) as Callable
	_character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	_send_spawn_bomb_cb = callbacks.get("send_spawn_outrage_bomb", Callable()) as Callable

func server_cast_skill1(caster_peer_id: int, world_position: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_OUTRAGE:
		return
	var lobby_id := _peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return

	_active_bombs.append({
		"caster_peer_id": caster_peer_id,
		"lobby_id": lobby_id,
		"world_position": world_position,
		"fuse_remaining": FUSE_SEC,
		"damage_applied": false
	})

	for member_value in _lobby_members(lobby_id):
		if _send_spawn_bomb_cb.is_valid():
			_send_spawn_bomb_cb.call(int(member_value), caster_peer_id, world_position, FUSE_SEC)

func server_tick(delta: float) -> void:
	if _active_bombs.is_empty():
		return
	for index in range(_active_bombs.size() - 1, -1, -1):
		var bomb := _active_bombs[index] as Dictionary
		var fuse_remaining := float(bomb.get("fuse_remaining", FUSE_SEC)) - delta

		var damage_applied := bool(bomb.get("damage_applied", false))
		if not damage_applied and fuse_remaining <= PRE_DAMAGE_SEC:
			_apply_bomb_damage(bomb)
			bomb["damage_applied"] = true
			damage_applied = true

		if fuse_remaining > 0.0:
			bomb["fuse_remaining"] = fuse_remaining
			_active_bombs[index] = bomb
			continue

		if not damage_applied:
			_apply_bomb_damage(bomb)
		_active_bombs.remove_at(index)

func client_spawn_bomb(world_position: Vector2, fuse_sec: float) -> void:
	if projectile_system == null or projectile_system.projectiles_root == null:
		return
	var visual_root: Node2D = projectile_system.projectiles_root

	var bomb_node := Node2D.new()
	bomb_node.z_index = 42
	bomb_node.global_position = world_position
	visual_root.add_child(bomb_node)

	var bomb_sprite := AnimatedSprite2D.new()
	bomb_sprite.centered = true
	bomb_sprite.z_as_relative = true
	bomb_sprite.texture_filter = CanvasItem.TextureFilter.TEXTURE_FILTER_NEAREST
	bomb_sprite.modulate = BOMB_TINT
	bomb_sprite.scale = Vector2.ONE * BOMB_SCALE
	var bomb_material := CanvasItemMaterial.new()
	bomb_material.light_mode = CanvasItemMaterial.LightMode.LIGHT_MODE_UNSHADED
	bomb_sprite.material = bomb_material
	bomb_sprite.sprite_frames = _build_sprite_frames(maxf(fuse_sec, 0.05))
	bomb_sprite.animation = "default"
	bomb_node.add_child(bomb_sprite)
	bomb_sprite.play()

	_schedule_end_particles(bomb_node, maxf(fuse_sec, 0.05))
	_schedule_screen_shake(world_position, maxf(fuse_sec, 0.05))

	var bomb_audio := AudioStreamPlayer2D.new()
	bomb_audio.stream = BOMB_SFX
	bomb_audio.max_polyphony = 2
	bomb_node.add_child(bomb_audio)
	bomb_audio.play()

	_queue_free_with_delay(bomb_node, maxf(fuse_sec, 0.05) + 0.2)

func _apply_bomb_damage(bomb: Dictionary) -> void:
	var caster_peer_id := int(bomb.get("caster_peer_id", 0))
	var lobby_id := int(bomb.get("lobby_id", 0))
	var world_position := bomb.get("world_position", Vector2.ZERO) as Vector2
	if lobby_id <= 0:
		return
	for member_value in _lobby_members(lobby_id):
		var target_peer_id := int(member_value)
		if target_peer_id <= 0 or target_peer_id == caster_peer_id:
			continue
		var target_player: NetPlayer = players.get(target_peer_id, null) as NetPlayer
		if target_player == null:
			continue
		if target_player.global_position.distance_to(world_position) > RADIUS:
			continue
		if hit_damage_resolver != null and hit_damage_resolver.has_method("server_apply_direct_damage"):
			hit_damage_resolver.server_apply_direct_damage(caster_peer_id, target_peer_id, target_player, DAMAGE)

func _schedule_end_particles(bomb_node: Node2D, fuse_sec: float) -> void:
	if bomb_node == null:
		return
	var tree: SceneTree = bomb_node.get_tree()
	if tree == null:
		return
	var bomb_id := bomb_node.get_instance_id()
	var lead := minf(END_PARTICLES_LEAD_SEC, fuse_sec)
	var delay := maxf(0.0, fuse_sec - lead)
	var timer: SceneTreeTimer = tree.create_timer(delay)
	timer.timeout.connect(func() -> void:
		var bomb_obj := instance_from_id(bomb_id)
		if bomb_obj == null or not (bomb_obj is Node2D):
			return
		var resolved_bomb := bomb_obj as Node2D
		_spawn_end_particles(resolved_bomb.global_position)
	)

func _spawn_end_particles(world_position: Vector2) -> void:
	if projectile_system == null or projectile_system.projectiles_root == null:
		return
	var visual_root: Node2D = projectile_system.projectiles_root

	var particles := CPUParticles2D.new()
	particles.z_index = 43
	particles.global_position = world_position
	particles.amount = END_PARTICLES_AMOUNT
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = END_PARTICLES_LIFETIME
	particles.local_coords = false
	particles.gravity = END_PARTICLES_GRAVITY
	particles.initial_velocity_min = 220.0
	particles.initial_velocity_max = 520.0
	particles.angular_velocity_min = -1400.0
	particles.angular_velocity_max = 1400.0
	particles.scale_amount_min = END_PARTICLES_SCALE_MIN
	particles.scale_amount_max = END_PARTICLES_SCALE_MAX
	particles.color = END_PARTICLES_COLOR
	particles.direction = Vector2.RIGHT.rotated(randf() * TAU)
	particles.spread = 180.0
	particles.texture = _particle_tex()
	particles.texture_filter = CanvasItem.TextureFilter.TEXTURE_FILTER_NEAREST
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LightMode.LIGHT_MODE_UNSHADED
	particles.material = unshaded

	visual_root.add_child(particles)
	particles.emitting = true
	_queue_free_with_delay(particles, END_PARTICLES_LIFETIME + 0.65)

func _particle_tex() -> Texture2D:
	if _particle_tex_cache != null:
		return _particle_tex_cache
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1, 1, 1, 1))
	_particle_tex_cache = ImageTexture.create_from_image(img)
	return _particle_tex_cache

func _schedule_screen_shake(world_position: Vector2, fuse_sec: float) -> void:
	if camera_shake == null:
		return
	if projectile_system == null or projectile_system.projectiles_root == null:
		return
	var tree: SceneTree = projectile_system.projectiles_root.get_tree()
	if tree == null:
		return
	var lead := minf(SHAKE_LEAD_SEC, fuse_sec)
	var timer: SceneTreeTimer = tree.create_timer(maxf(0.0, fuse_sec - lead))
	timer.timeout.connect(func() -> void:
		_apply_screen_shake(world_position)
	)

func _apply_screen_shake(world_position: Vector2) -> void:
	if camera_shake == null or multiplayer == null:
		return
	var local_peer_id: int = multiplayer.get_unique_id()
	var local_player: Node2D = players.get(local_peer_id, null) as Node2D
	if local_player == null:
		return
	var dist: float = local_player.global_position.distance_to(world_position)
	if dist >= SHAKE_OUTER_RADIUS:
		return

	var t := 1.0
	if dist > SHAKE_INNER_RADIUS:
		t = 1.0 - (dist - SHAKE_INNER_RADIUS) / maxf(1.0, SHAKE_OUTER_RADIUS - SHAKE_INNER_RADIUS)
	t = clampf(t, 0.0, 1.0)
	camera_shake.add_explosion_shake(SHAKE_AMOUNT * t, SHAKE_MAX_TRAUMA, SHAKE_MAX_OFFSET, SHAKE_HOLD_SEC)

func _build_sprite_frames(fuse_sec: float) -> SpriteFrames:
	var frames := SpriteFrames.new()
	if not frames.has_animation("default"):
		frames.add_animation("default")
	var textures := _frame_textures()
	if textures.is_empty():
		frames.add_frame("default", BOMB_TEXTURE)
		frames.set_animation_speed("default", 1.0)
		return frames
	for texture in textures:
		frames.add_frame("default", texture)
	frames.set_animation_loop("default", false)
	frames.set_animation_speed("default", maxf(1.0, float(textures.size()) / fuse_sec))
	return frames

func _frame_textures() -> Array[Texture2D]:
	if not _bomb_frames_cache.is_empty():
		return _bomb_frames_cache
	if BOMB_TEXTURE == null:
		return []
	var texture_size := BOMB_TEXTURE.get_size()
	var width := int(texture_size.x)
	var height := int(texture_size.y)
	if width <= 0 or height <= 0:
		return []

	if width == height:
		_bomb_frames_cache.append(BOMB_TEXTURE)
		return _bomb_frames_cache

	var horizontal_strip := width > height
	var frame_size := height if horizontal_strip else width
	if frame_size <= 0:
		_bomb_frames_cache.append(BOMB_TEXTURE)
		return _bomb_frames_cache
	var frame_count := int(width / frame_size) if horizontal_strip else int(height / frame_size)
	if frame_count <= 1:
		_bomb_frames_cache.append(BOMB_TEXTURE)
		return _bomb_frames_cache

	for frame_index in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = BOMB_TEXTURE
		if horizontal_strip:
			atlas.region = Rect2(float(frame_index * frame_size), 0.0, float(frame_size), float(frame_size))
		else:
			atlas.region = Rect2(0.0, float(frame_index * frame_size), float(frame_size), float(frame_size))
		_bomb_frames_cache.append(atlas)
	return _bomb_frames_cache

func _peer_lobby(peer_id: int) -> int:
	if _peer_lobby_cb.is_valid():
		return int(_peer_lobby_cb.call(peer_id))
	return 0

func _lobby_members(lobby_id: int) -> Array:
	if _lobby_members_cb.is_valid():
		return _lobby_members_cb.call(lobby_id) as Array
	return []

func _character_id_for_peer(peer_id: int) -> String:
	if _character_id_for_peer_cb.is_valid():
		return str(_character_id_for_peer_cb.call(peer_id))
	return CHARACTER_ID_OUTRAGE

func _queue_free_with_delay(node: Node, delay_sec: float) -> void:
	if node == null:
		return
	var tree := node.get_tree()
	if tree == null:
		return
	var instance_id := node.get_instance_id()
	var timer := tree.create_timer(delay_sec)
	timer.timeout.connect(func() -> void:
		var obj := instance_from_id(instance_id)
		if obj != null and obj is Node:
			(obj as Node).queue_free()
	)
