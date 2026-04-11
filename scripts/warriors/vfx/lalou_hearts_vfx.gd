extends Node2D
class_name LalouHeartsVfx

const HEART_SIZE := Vector2(7.0, 6.0)
const HEART_SPAWN_INTERVAL_SEC := 0.09
const HEART_IMPACT_BURST_COUNT := 7
const HEART_HOMING_SPEED_PX_PER_SEC := 460.0
const HEART_HOMING_MIN_SCALE := 2.0
const HEART_HOMING_MAX_SCALE := 3.4
const HEART_IMPACT_RING_COLOR := Color(1.0, 0.92, 0.98, 1.0)

var source_player: Node2D
var duration_sec := 5.0
var radius_px := 176.0
var effect_color := Color(1.0, 0.41, 0.68, 1.0)

var _elapsed := 0.0
var _spawn_accumulator := 0.0
var _heart_texture: Texture2D
var _hearts: Array = []
var _impact_flashes: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 62
	_rng.seed = int(Time.get_ticks_usec()) ^ int(get_instance_id())
	_heart_texture = _build_heart_texture()
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	if is_instance_valid(source_player):
		global_position = source_player.global_position + Vector2(0.0, -16.0)
	_spawn_accumulator += maxf(0.0, delta)
	while _elapsed <= duration_sec and _spawn_accumulator >= HEART_SPAWN_INTERVAL_SEC:
		_spawn_accumulator -= HEART_SPAWN_INTERVAL_SEC
		_spawn_heart()
	var remaining: Array = []
	for heart_value in _hearts:
		var heart := heart_value as Dictionary
		var age := float(heart.get("age", 0.0)) + delta
		var life := float(heart.get("life", 0.5))
		var mode := str(heart.get("mode", "ambient"))
		if mode == "homing":
			if _process_homing_heart(heart, delta, age, life):
				remaining.append(heart)
			continue
		if age >= life:
			continue
		var position := heart.get("position", Vector2.ZERO) as Vector2
		var velocity := heart.get("velocity", Vector2.ZERO) as Vector2
		position += velocity * delta
		velocity += Vector2(0.0, -8.0) * delta
		heart["age"] = age
		heart["position"] = position
		heart["velocity"] = velocity
		remaining.append(heart)
	_hearts = remaining
	_tick_impact_flashes(delta)
	if _elapsed > duration_sec and _hearts.is_empty() and _impact_flashes.is_empty():
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	if _heart_texture == null:
		return
	for heart_value in _hearts:
		var heart := heart_value as Dictionary
		var position := heart.get("position", Vector2.ZERO) as Vector2
		var age := float(heart.get("age", 0.0))
		var life := maxf(0.05, float(heart.get("life", 0.5)))
		var scale_value := maxf(0.1, float(heart.get("scale", 1.0)))
		var alpha := clampf(1.0 - age / life, 0.0, 1.0)
		var draw_size := HEART_SIZE * scale_value
		var rect := Rect2(position - draw_size * 0.5, draw_size)
		draw_texture_rect(_heart_texture, rect, false, Color(1.0, 1.0, 1.0, alpha))
	for flash_value in _impact_flashes:
		var flash := flash_value as Dictionary
		var flash_position := flash.get("position", Vector2.ZERO) as Vector2
		var flash_age := float(flash.get("age", 0.0))
		var flash_life := maxf(0.05, float(flash.get("life", 0.16)))
		var ratio := clampf(flash_age / flash_life, 0.0, 1.0)
		var alpha := clampf(1.0 - ratio, 0.0, 1.0)
		var radius := lerpf(5.0, 18.0, ratio)
		draw_circle(flash_position, radius, Color(HEART_IMPACT_RING_COLOR.r, HEART_IMPACT_RING_COLOR.g, HEART_IMPACT_RING_COLOR.b, alpha * 0.32))
		draw_arc(flash_position, radius + 1.5, 0.0, TAU, 18, Color(effect_color.r, effect_color.g, effect_color.b, alpha * 0.95), 2.0, true)

func _spawn_heart() -> void:
	var angle := _rng.randf_range(-PI, PI)
	var dist := _rng.randf_range(10.0, maxf(24.0, radius_px * 0.45))
	var position := Vector2.RIGHT.rotated(angle) * dist
	position.y *= 0.48
	var velocity := Vector2.RIGHT.rotated(angle + _rng.randf_range(-0.45, 0.45)) * _rng.randf_range(18.0, 62.0)
	velocity.y -= _rng.randf_range(34.0, 78.0)
	_hearts.append({
		"position": position,
		"velocity": velocity,
		"age": 0.0,
		"life": _rng.randf_range(0.42, 0.78),
		"scale": _rng.randf_range(1.8, 3.6),
		"mode": "ambient",
	})

func spawn_targeted_heart(target_player: Node2D, stun_duration_sec: float) -> void:
	if not is_instance_valid(source_player) or not is_instance_valid(target_player):
		if is_instance_valid(target_player) and target_player.has_method("set_petrified_visual"):
			target_player.call("set_petrified_visual", stun_duration_sec)
		return
	var local_target := to_local(target_player.global_position + Vector2(0.0, -16.0))
	var spawn_position := Vector2(_rng.randf_range(-10.0, 10.0), _rng.randf_range(-8.0, 8.0))
	var initial_direction := (local_target - spawn_position).normalized()
	if initial_direction == Vector2.ZERO:
		initial_direction = Vector2.RIGHT
	_hearts.append({
		"mode": "homing",
		"position": spawn_position,
		"velocity": initial_direction * HEART_HOMING_SPEED_PX_PER_SEC,
		"age": 0.0,
		"life": 1.2,
		"scale": _rng.randf_range(HEART_HOMING_MIN_SCALE, HEART_HOMING_MAX_SCALE),
		"target_player": target_player,
		"stun_duration_sec": stun_duration_sec,
		"impact_triggered": false,
	})

func _process_homing_heart(heart: Dictionary, delta: float, age: float, life: float) -> bool:
	if age >= life:
		return false
	var target_player := heart.get("target_player", null) as Node2D
	if target_player == null or not is_instance_valid(target_player):
		return false
	var position := heart.get("position", Vector2.ZERO) as Vector2
	var target_local := to_local(target_player.global_position + Vector2(0.0, -16.0))
	var to_target := target_local - position
	var distance := to_target.length()
	if distance <= 7.0:
		_trigger_homing_heart_impact(heart, target_local)
		return false
	var direction := to_target / maxf(0.001, distance)
	var velocity := direction * HEART_HOMING_SPEED_PX_PER_SEC
	position += velocity * delta
	heart["age"] = age
	heart["position"] = position
	heart["velocity"] = velocity
	if position.distance_to(target_local) <= 7.0:
		_trigger_homing_heart_impact(heart, target_local)
		return false
	return true

func _trigger_homing_heart_impact(heart: Dictionary, impact_position: Vector2) -> void:
	var target_player := heart.get("target_player", null) as Node2D
	var stun_duration_sec := maxf(0.0, float(heart.get("stun_duration_sec", 0.0)))
	_spawn_impact_flash(impact_position)
	_spawn_impact_burst(impact_position)
	if target_player != null and is_instance_valid(target_player) and target_player.has_method("set_petrified_visual"):
		target_player.call("set_petrified_visual", stun_duration_sec)

func _spawn_impact_flash(impact_position: Vector2) -> void:
	_impact_flashes.append({
		"position": impact_position,
		"age": 0.0,
		"life": 0.16,
	})

func _spawn_impact_burst(impact_position: Vector2) -> void:
	for _i in range(HEART_IMPACT_BURST_COUNT):
		var angle := _rng.randf_range(-PI, PI)
		var velocity := Vector2.RIGHT.rotated(angle) * _rng.randf_range(28.0, 76.0)
		velocity.y -= _rng.randf_range(8.0, 24.0)
		_hearts.append({
			"mode": "ambient",
			"position": impact_position + Vector2(_rng.randf_range(-3.0, 3.0), _rng.randf_range(-3.0, 3.0)),
			"velocity": velocity,
			"age": 0.0,
			"life": _rng.randf_range(0.18, 0.34),
			"scale": _rng.randf_range(1.3, 2.2),
		})

func _tick_impact_flashes(delta: float) -> void:
	var remaining: Array = []
	for flash_value in _impact_flashes:
		var flash := flash_value as Dictionary
		var age := float(flash.get("age", 0.0)) + delta
		var life := float(flash.get("life", 0.16))
		if age >= life:
			continue
		flash["age"] = age
		remaining.append(flash)
	_impact_flashes = remaining

func _build_heart_texture() -> Texture2D:
	var image := Image.create(7, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var core := effect_color
	var highlight := core.lightened(0.28)
	var pixels := {
		Vector2i(1, 0): highlight,
		Vector2i(2, 0): core,
		Vector2i(4, 0): highlight,
		Vector2i(5, 0): core,
		Vector2i(0, 1): highlight,
		Vector2i(1, 1): core,
		Vector2i(2, 1): core,
		Vector2i(3, 1): highlight,
		Vector2i(4, 1): core,
		Vector2i(5, 1): core,
		Vector2i(6, 1): highlight,
		Vector2i(0, 2): core,
		Vector2i(1, 2): core,
		Vector2i(2, 2): core,
		Vector2i(3, 2): core,
		Vector2i(4, 2): core,
		Vector2i(5, 2): core,
		Vector2i(6, 2): core,
		Vector2i(1, 3): core,
		Vector2i(2, 3): core,
		Vector2i(3, 3): core,
		Vector2i(4, 3): core,
		Vector2i(5, 3): core,
		Vector2i(2, 4): core,
		Vector2i(3, 4): core,
		Vector2i(4, 4): core,
		Vector2i(3, 5): core,
	}
	for point_value in pixels.keys():
		var point := point_value as Vector2i
		image.set_pixelv(point, pixels[point])
	return ImageTexture.create_from_image(image)
