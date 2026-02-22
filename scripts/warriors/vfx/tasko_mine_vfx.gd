extends Node2D
class_name TaskoMineVfx

var color := Color(1.0, 0.35, 0.85, 0.95)

var _pulse_tween: Tween
var _particle_tex_cache: Texture2D

func _ready() -> void:
	_build_visual()

func explode() -> void:
	_spawn_explosion_particles()
	queue_free()

func _build_visual() -> void:
	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 41
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material = mat
	sprite.texture = _mine_tex()
	sprite.scale = Vector2.ONE * 1.35
	add_child(sprite)

	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(sprite, "scale", Vector2.ONE * 1.55, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pulse_tween.tween_property(sprite, "scale", Vector2.ONE * 1.35, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

func _mine_tex() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(16, 16)
	for y in range(32):
		for x in range(32):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) - c
			var r := p.length()
			if r > 14.5:
				continue
			var a := 1.0
			if r > 11.5:
				a = clampf((14.5 - r) / 3.0, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, a))
	return ImageTexture.create_from_image(img)

func _spawn_explosion_particles() -> void:
	var root := get_parent() as Node2D
	if root == null:
		return

	var particles := CPUParticles2D.new()
	particles.global_position = global_position
	particles.z_index = 42
	particles.amount = 42
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = 0.7
	particles.local_coords = false
	particles.gravity = Vector2(0.0, 1200.0)
	particles.initial_velocity_min = 180.0
	particles.initial_velocity_max = 520.0
	particles.angular_velocity_min = -1800.0
	particles.angular_velocity_max = 1800.0
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 11.0
	particles.color = Color(color.r, color.g, color.b, 0.95)
	particles.spread = 180.0
	particles.direction = Vector2.RIGHT.rotated(randf() * TAU)
	particles.texture = _particle_tex()
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = mat

	root.add_child(particles)
	particles.emitting = true

	var tree := get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(1.6)
	var particles_id := particles.get_instance_id()
	timer.timeout.connect(func() -> void:
		var obj := instance_from_id(particles_id)
		if obj != null and obj is Node:
			(obj as Node).queue_free()
	)

func _particle_tex() -> Texture2D:
	if _particle_tex_cache != null:
		return _particle_tex_cache
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1, 1, 1, 1))
	_particle_tex_cache = ImageTexture.create_from_image(img)
	return _particle_tex_cache

