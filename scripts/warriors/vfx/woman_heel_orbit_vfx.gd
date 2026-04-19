extends Node2D
class_name WomanHeelOrbitVfx

const HEEL_TEXTURE := preload("res://assets/warriors/woman/legs.png")
const START_ANGLE := -PI * 0.5
const ORBIT_BOOT_COUNT := 3
const HEEL_BASE_SCALE := 1.04
const HEEL_GLOW_BASE_SCALE := 1.22

var source_player: Node2D
var duration_sec := 5.0
var orbit_radius_px := 54.0
var angular_speed := TAU * 1.18
var effect_color := Color(1.0, 0.31, 0.73, 1.0)

var _elapsed_sec := 0.0
var _heel_sprites: Array[Sprite2D] = []
var _glow_sprites: Array[Sprite2D] = []

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 64
	for i in range(ORBIT_BOOT_COUNT):
		var glow_sprite := Sprite2D.new()
		glow_sprite.texture = HEEL_TEXTURE
		glow_sprite.centered = true
		glow_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		glow_sprite.scale = Vector2.ONE * HEEL_GLOW_BASE_SCALE
		glow_sprite.modulate = Color(effect_color.r, effect_color.g, effect_color.b, 0.24)
		add_child(glow_sprite)
		_glow_sprites.append(glow_sprite)

		var heel_sprite := Sprite2D.new()
		heel_sprite.texture = HEEL_TEXTURE
		heel_sprite.centered = true
		heel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heel_sprite.scale = Vector2.ONE * HEEL_BASE_SCALE
		heel_sprite.modulate = effect_color.lerp(Color.WHITE, 0.12)
		add_child(heel_sprite)
		_heel_sprites.append(heel_sprite)

func _process(delta: float) -> void:
	_elapsed_sec += maxf(0.0, delta)
	if _elapsed_sec >= maxf(0.05, duration_sec):
		queue_free()
		return
	if source_player == null or not is_instance_valid(source_player):
		queue_free()
		return
	var orbit_center := source_player.global_position + Vector2(0.0, -20.0)
	global_position = orbit_center
	var life_ratio := clampf(1.0 - (_elapsed_sec / maxf(0.05, duration_sec)), 0.0, 1.0)
	var base_orbit_angle := START_ANGLE + _elapsed_sec * angular_speed
	for i in range(ORBIT_BOOT_COUNT):
		var phase := float(i) * TAU / float(ORBIT_BOOT_COUNT)
		var orbit_angle := base_orbit_angle + phase
		var orbit_offset := Vector2.RIGHT.rotated(orbit_angle) * orbit_radius_px
		var pulse := 1.0 + sin(_elapsed_sec * 8.5 + phase) * 0.08
		if i < _heel_sprites.size():
			var heel_sprite := _heel_sprites[i]
			heel_sprite.position = orbit_offset
			heel_sprite.rotation = orbit_angle + PI * 0.5
			heel_sprite.scale = Vector2.ONE * (HEEL_BASE_SCALE * pulse)
		if i < _glow_sprites.size():
			var glow_sprite := _glow_sprites[i]
			glow_sprite.position = orbit_offset
			glow_sprite.rotation = orbit_angle + PI * 0.5
			glow_sprite.scale = Vector2.ONE * (HEEL_GLOW_BASE_SCALE + (1.0 - life_ratio) * 0.2)
			glow_sprite.modulate = Color(effect_color.r, effect_color.g, effect_color.b, 0.18 + life_ratio * 0.12)
