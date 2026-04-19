extends Node2D
class_name AgelikoulaBlocksVfx

const BLOCK_SPAWN_INTERVAL_SEC := 0.032
const BLOCK_BASE_SIZE := 8.0
const BLOCK_LIFE_MIN_SEC := 0.24
const BLOCK_LIFE_MAX_SEC := 0.58
const BLOCK_MIN_SPEED := 70.0
const BLOCK_MAX_SPEED := 225.0
const BLOCK_GRAVITY := 980.0
const BLOCK_AIR_DRAG := 0.992
const TARGET_BLOCK_GRAVITY := 900.0
const TARGET_STEER_STRENGTH := 3.0
const BLOCK_TEXTURE_SIZE := 8
const BLOCK_TEXTURE_VARIANTS := 12

var source_player: Node2D
var duration_sec := 5.0
var effect_color := Color(0.95, 0.74, 0.33, 1.0)

var _elapsed := 0.0
var _spawn_accumulator := 0.0
var _blocks: Array = []
var _hit_bursts: Array = []
var _block_textures: Array[Texture2D] = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 62
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id())
	_build_block_texture_variants()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	if is_instance_valid(source_player):
		global_position = source_player.global_position + Vector2(0.0, -16.0)
	_spawn_accumulator += maxf(0.0, delta)
	while _elapsed <= duration_sec and _spawn_accumulator >= BLOCK_SPAWN_INTERVAL_SEC:
		_spawn_accumulator -= BLOCK_SPAWN_INTERVAL_SEC
		_spawn_ambient_block()

	_tick_blocks(delta)
	_tick_hit_bursts(delta)
	if _elapsed > duration_sec and _blocks.is_empty() and _hit_bursts.is_empty():
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for block_value in _blocks:
		var block := block_value as Dictionary
		var pos := block.get("position", Vector2.ZERO) as Vector2
		var size := maxf(2.0, float(block.get("size", BLOCK_BASE_SIZE)))
		var age := float(block.get("age", 0.0))
		var life := maxf(0.05, float(block.get("life", 0.4)))
		var alpha := clampf(1.0 - age / life, 0.0, 1.0)
		var tint := block.get("color", effect_color) as Color
		var tex := _texture_for_block(block)
		var rect := Rect2(pos - Vector2.ONE * (size * 0.5), Vector2.ONE * size)
		if tex != null:
			draw_texture_rect(tex, rect, false, Color(tint.r, tint.g, tint.b, alpha))
		else:
			draw_rect(rect, Color(tint.r, tint.g, tint.b, alpha), true)
	for burst_value in _hit_bursts:
		var burst := burst_value as Dictionary
		var pos := burst.get("position", Vector2.ZERO) as Vector2
		var age := float(burst.get("age", 0.0))
		var life := maxf(0.05, float(burst.get("life", 0.14)))
		var ratio := clampf(age / life, 0.0, 1.0)
		var alpha := clampf(1.0 - ratio, 0.0, 1.0)
		var radius := lerpf(4.0, 17.0, ratio)
		draw_circle(pos, radius, Color(effect_color.r, effect_color.g, effect_color.b, alpha * 0.3))
		draw_arc(pos, radius + 1.2, 0.0, TAU, 16, Color(1.0, 1.0, 1.0, alpha), 1.6, true)

func spawn_targeted_block(target_player: Node2D) -> void:
	if not is_instance_valid(target_player):
		return
	var target_local := to_local(target_player.global_position + Vector2(0.0, -14.0))
	var from := Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-6.0, 6.0))
	var to_target := target_local - from
	var dist := maxf(1.0, to_target.length())
	var dir := to_target / dist
	var speed := clampf(dist / 0.26, 210.0, 720.0)
	var arc_lift := _rng.randf_range(80.0, 180.0)
	_blocks.append({
		"position": from,
		"velocity": dir * speed + Vector2(0.0, -arc_lift),
		"age": 0.0,
		"life": 0.5,
		"size": _rng.randf_range(8.0, 13.5),
		"color": effect_color.lightened(0.14),
		"tex_idx": _random_texture_index(),
		"mode": "homing",
		"target": target_player,
	})

func _spawn_ambient_block() -> void:
	var dir := Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
	_blocks.append({
		"position": Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-8.0, 8.0)),
		"velocity": dir * _rng.randf_range(BLOCK_MIN_SPEED, BLOCK_MAX_SPEED),
		"age": 0.0,
		"life": _rng.randf_range(BLOCK_LIFE_MIN_SEC, BLOCK_LIFE_MAX_SEC),
		"size": _rng.randf_range(BLOCK_BASE_SIZE, BLOCK_BASE_SIZE * 1.7),
		"color": effect_color.lerp(Color.WHITE, _rng.randf_range(0.08, 0.24)),
		"tex_idx": _random_texture_index(),
		"mode": "ambient",
	})

func _tick_blocks(delta: float) -> void:
	var keep: Array = []
	for block_value in _blocks:
		var block := block_value as Dictionary
		var age := float(block.get("age", 0.0)) + delta
		var life := float(block.get("life", 0.4))
		if age >= life:
			continue
		var mode := str(block.get("mode", "ambient"))
		var pos := block.get("position", Vector2.ZERO) as Vector2
		var vel := block.get("velocity", Vector2.ZERO) as Vector2
		if mode == "homing":
			var target := block.get("target", null) as Node2D
			if target == null or not is_instance_valid(target):
				continue
			var target_local := to_local(target.global_position + Vector2(0.0, -14.0))
			var to_target := target_local - pos
			if to_target.length() <= 8.0:
				_spawn_hit_burst(target_local)
				continue
			var steer_dir := to_target.normalized()
			var steer := steer_dir * TARGET_STEER_STRENGTH * delta * maxf(140.0, vel.length())
			vel += steer
			vel.y += TARGET_BLOCK_GRAVITY * delta
			vel *= BLOCK_AIR_DRAG
		else:
			vel.y += BLOCK_GRAVITY * delta
			vel *= BLOCK_AIR_DRAG
		pos += vel * delta
		block["age"] = age
		block["position"] = pos
		block["velocity"] = vel
		keep.append(block)
	_blocks = keep

func _spawn_hit_burst(pos: Vector2) -> void:
	_hit_bursts.append({
		"position": pos,
		"age": 0.0,
		"life": 0.14,
	})
	for _i in range(7):
		var dir := Vector2.RIGHT.rotated(_rng.randf_range(-PI, PI))
		_blocks.append({
			"position": pos + Vector2(_rng.randf_range(-2.0, 2.0), _rng.randf_range(-2.0, 2.0)),
			"velocity": dir * _rng.randf_range(80.0, 210.0),
			"age": 0.0,
			"life": _rng.randf_range(0.12, 0.24),
			"size": _rng.randf_range(4.0, 7.8),
			"color": effect_color.lightened(0.2),
			"tex_idx": _random_texture_index(),
			"mode": "ambient",
		})

func _tick_hit_bursts(delta: float) -> void:
	var keep: Array = []
	for burst_value in _hit_bursts:
		var burst := burst_value as Dictionary
		var age := float(burst.get("age", 0.0)) + delta
		var life := float(burst.get("life", 0.14))
		if age >= life:
			continue
		burst["age"] = age
		keep.append(burst)
	_hit_bursts = keep

func _random_texture_index() -> int:
	if _block_textures.is_empty():
		return 0
	return _rng.randi_range(0, _block_textures.size() - 1)

func _texture_for_block(block: Dictionary) -> Texture2D:
	if _block_textures.is_empty():
		return null
	var idx := int(block.get("tex_idx", 0))
	if idx < 0 or idx >= _block_textures.size():
		idx = posmod(idx, _block_textures.size())
	return _block_textures[idx]

func _build_block_texture_variants() -> void:
	_block_textures.clear()
	for _i in range(BLOCK_TEXTURE_VARIANTS):
		_block_textures.append(_build_single_block_texture())

func _build_single_block_texture() -> Texture2D:
	var image := Image.create(BLOCK_TEXTURE_SIZE, BLOCK_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var c_dark := effect_color.darkened(_rng.randf_range(0.28, 0.44))
	var c_mid := effect_color.darkened(_rng.randf_range(0.10, 0.22))
	var c_light := effect_color.lightened(_rng.randf_range(0.08, 0.24))
	var c_moss := effect_color.lerp(Color(0.24, 0.35, 0.13, 1.0), _rng.randf_range(0.18, 0.36))

	for y in range(BLOCK_TEXTURE_SIZE):
		for x in range(BLOCK_TEXTURE_SIZE):
			var pixel := c_mid
			var edge := x == 0 or y == 0 or x == BLOCK_TEXTURE_SIZE - 1 or y == BLOCK_TEXTURE_SIZE - 1
			var top_lit := y <= 1 and _rng.randf() < 0.75
			var rnd := _rng.randf()
			if edge and _rng.randf() < 0.70:
				pixel = c_dark
			elif top_lit:
				pixel = c_light
			elif rnd < 0.20:
				pixel = c_dark
			elif rnd < 0.36:
				pixel = c_light
			if _rng.randf() < 0.10:
				pixel = c_moss
			image.set_pixel(x, y, pixel)

	# Random tiny "ore" clusters for extra Minecraft-like variation.
	var ore_count := _rng.randi_range(1, 3)
	for _j in range(ore_count):
		var ox := _rng.randi_range(1, BLOCK_TEXTURE_SIZE - 2)
		var oy := _rng.randi_range(1, BLOCK_TEXTURE_SIZE - 2)
		var ore := c_light.lightened(_rng.randf_range(0.05, 0.20))
		image.set_pixel(ox, oy, ore)
		if _rng.randf() < 0.45:
			image.set_pixel(clampi(ox + _rng.randi_range(-1, 1), 1, BLOCK_TEXTURE_SIZE - 2), clampi(oy + _rng.randi_range(-1, 1), 1, BLOCK_TEXTURE_SIZE - 2), ore.darkened(0.08))

	return ImageTexture.create_from_image(image)
