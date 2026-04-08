extends Node2D
class_name AevilokFlamethrowerVfx

const AEVILOK_SKILL_TEXTURE := preload("res://assets/warriors/aevilok_skill.png")
const SKILL_FRAME_WIDTH := 64
const SKILL_FRAME_HEIGHT := 53
const SKILL_FRAME_COUNT := 10
const SKILL_ANIM_FPS := 18.0
const FLAME_OFFSET := Vector2(20.0, -2.0)
const HEAD_FRAME_SIZE := Vector2(64.0, 64.0)
const HEAD_ATTACH_OFFSET := Vector2(0.0, -9.0)

var players: Dictionary = {}
var caster_peer_id := 0
var intro_duration_sec := 0.52
var fire_duration_sec := 3.0
var flame_color := Color(1.0, 0.47, 0.16, 1.0)

var _elapsed := 0.0
var _stage := 0 # 0 intro, 1 fire, 2 outro
var _sprite: AnimatedSprite2D
var _flame_particles: CPUParticles2D
var _flame_core_particles: CPUParticles2D

func _ready() -> void:
	_build_visual()
	_start_intro()

func _process(delta: float) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null or caster.get_health() <= 0:
		queue_free()
		return
	_attach_to_head(caster)

	_elapsed += maxf(0.0, delta)
	if _stage == 0 and _elapsed >= intro_duration_sec:
		_enter_fire_stage()
	elif _stage == 1 and _elapsed >= intro_duration_sec + fire_duration_sec:
		_enter_outro_stage()

func _build_visual() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.z_index = 171
	_sprite.sprite_frames = _build_skill_frames()
	_sprite.animation = "cast"
	_sprite.frame = 0
	_sprite.animation_finished.connect(_on_sprite_animation_finished)
	add_child(_sprite)

	_flame_particles = CPUParticles2D.new()
	_flame_particles.z_index = 170
	_flame_particles.position = FLAME_OFFSET
	_flame_particles.amount = 72
	_flame_particles.lifetime = 0.28
	_flame_particles.one_shot = false
	_flame_particles.explosiveness = 0.12
	_flame_particles.local_coords = true
	_flame_particles.direction = Vector2.RIGHT
	_flame_particles.spread = 16.0
	_flame_particles.gravity = Vector2.ZERO
	_flame_particles.initial_velocity_min = 210.0
	_flame_particles.initial_velocity_max = 420.0
	_flame_particles.angular_velocity_min = -220.0
	_flame_particles.angular_velocity_max = 220.0
	_flame_particles.scale_amount_min = 1.0
	_flame_particles.scale_amount_max = 2.4
	_flame_particles.color = Color(flame_color.r, flame_color.g, flame_color.b, 0.74)
	_flame_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_flame_particles.emission_rect_extents = Vector2(8.0, 10.0)
	_flame_particles.emitting = false
	add_child(_flame_particles)

	_flame_core_particles = CPUParticles2D.new()
	_flame_core_particles.z_index = 172
	_flame_core_particles.position = FLAME_OFFSET + Vector2(1.0, 0.0)
	_flame_core_particles.amount = 30
	_flame_core_particles.lifetime = 0.2
	_flame_core_particles.one_shot = false
	_flame_core_particles.explosiveness = 0.18
	_flame_core_particles.local_coords = true
	_flame_core_particles.direction = Vector2.RIGHT
	_flame_core_particles.spread = 10.0
	_flame_core_particles.gravity = Vector2.ZERO
	_flame_core_particles.initial_velocity_min = 180.0
	_flame_core_particles.initial_velocity_max = 330.0
	_flame_core_particles.scale_amount_min = 0.45
	_flame_core_particles.scale_amount_max = 1.12
	_flame_core_particles.color = Color(1.0, 0.95, 0.82, 0.82)
	_flame_core_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_flame_core_particles.emission_rect_extents = Vector2(5.0, 6.0)
	_flame_core_particles.emitting = false
	add_child(_flame_core_particles)

func _build_skill_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.add_animation("cast")
	frames.set_animation_loop("cast", false)
	frames.set_animation_speed("cast", SKILL_ANIM_FPS)
	for frame_idx in range(SKILL_FRAME_COUNT):
		var atlas := AtlasTexture.new()
		atlas.atlas = AEVILOK_SKILL_TEXTURE
		atlas.region = Rect2(float(frame_idx * SKILL_FRAME_WIDTH), 0.0, float(SKILL_FRAME_WIDTH), float(SKILL_FRAME_HEIGHT))
		frames.add_frame("cast", atlas)
	return frames

func _start_intro() -> void:
	_stage = 0
	_sprite.speed_scale = _anim_speed_scale()
	_sprite.play("cast")
	_flame_particles.emitting = false
	_flame_core_particles.emitting = false

func _enter_fire_stage() -> void:
	if _stage != 0:
		return
	_stage = 1
	_sprite.stop()
	_sprite.frame = SKILL_FRAME_COUNT - 1
	_flame_particles.color = Color(flame_color.r, flame_color.g, flame_color.b, 0.74)
	_flame_core_particles.color = Color(
		clampf(flame_color.r + 0.25, 0.0, 1.0),
		clampf(flame_color.g + 0.25, 0.0, 1.0),
		clampf(flame_color.b + 0.25, 0.0, 1.0),
		0.86
	)
	_flame_particles.emitting = true
	_flame_core_particles.emitting = true

func _enter_outro_stage() -> void:
	if _stage != 1:
		return
	_stage = 2
	_flame_particles.emitting = false
	_flame_core_particles.emitting = false
	_sprite.frame = SKILL_FRAME_COUNT - 1
	_sprite.speed_scale = _anim_speed_scale()
	_sprite.play_backwards("cast")

func _attach_to_head(caster: NetPlayer) -> void:
	var head_node := caster.get_node_or_null("VisualRoot/head") as Node2D
	if head_node != null:
		global_position = head_node.global_position + HEAD_ATTACH_OFFSET.rotated(head_node.global_rotation)
		global_rotation = head_node.global_rotation
		_sync_skill_sprite_scale_from_head(head_node)
		return
	global_position = caster.global_position + Vector2(0.0, -14.0)
	if caster.has_method("get_aim_angle"):
		global_rotation = float(caster.call("get_aim_angle"))
	_sprite.scale = Vector2.ONE

func _sync_skill_sprite_scale_from_head(head_node: Node2D) -> void:
	if _sprite == null or head_node == null:
		return
	var head_scale := head_node.global_scale
	var fit_scale := Vector2(
		HEAD_FRAME_SIZE.x / float(SKILL_FRAME_WIDTH),
		HEAD_FRAME_SIZE.y / float(SKILL_FRAME_HEIGHT)
	)
	_sprite.scale = Vector2(absf(head_scale.x), absf(head_scale.y)) * fit_scale

func _anim_speed_scale() -> float:
	var native_duration := float(SKILL_FRAME_COUNT) / maxf(1.0, SKILL_ANIM_FPS)
	return native_duration / maxf(0.1, intro_duration_sec)

func _on_sprite_animation_finished() -> void:
	if _stage == 2:
		queue_free()
