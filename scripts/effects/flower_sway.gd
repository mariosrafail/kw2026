extends Node2D

@export_range(0.0, 30.0, 0.1) var idle_amplitude_deg: float = 10.0
@export_range(0.1, 12.0, 0.1) var idle_speed: float = 2.4
@export_range(0.0, 70.0, 0.1) var touch_kick_deg: float = 32.0
@export_range(0.0, 1.0, 0.01) var touch_cooldown_sec: float = 0.16

var _touch_offset_deg: float = 0.0
var _idle_time: float = 0.0
var _last_touch_time: float = -1000.0
var _touch_tween: Tween

@onready var _flower_sprite: Sprite2D = $FlowerSprite
@onready var _touch_area: Area2D = $TouchArea
@onready var _touch_shape: CollisionShape2D = $TouchArea/CollisionShape2D


func _ready() -> void:
	_setup_pivot_bottom_pixel()
	_setup_touch_shape()
	_touch_area.body_entered.connect(_on_touch_area_body_entered)


func _process(delta: float) -> void:
	_idle_time += delta
	var idle_deg := (
		sin(_idle_time * idle_speed) * idle_amplitude_deg
		+ sin(_idle_time * idle_speed * 2.1) * (idle_amplitude_deg * 0.22)
	)
	rotation = deg_to_rad(idle_deg + _touch_offset_deg)


func _setup_pivot_bottom_pixel() -> void:
	if _flower_sprite.texture == null:
		return

	var tex_size: Vector2 = _flower_sprite.texture.get_size()
	var pivot_x: float = floor((tex_size.x - 1.0) * 0.5)

	_flower_sprite.centered = false
	_flower_sprite.position = Vector2(-pivot_x, -(tex_size.y - 1.0))


func _setup_touch_shape() -> void:
	if _flower_sprite.texture == null:
		return

	var tex_size: Vector2 = _flower_sprite.texture.get_size()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(max(8.0, tex_size.x * 0.72), max(10.0, tex_size.y * 0.9))
	_touch_shape.shape = rect
	_touch_shape.position = Vector2(0.0, -tex_size.y * 0.5)


func _on_touch_area_body_entered(body: Node) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_touch_time < touch_cooldown_sec:
		return
	_last_touch_time = now

	var direction := 1.0
	if body is Node2D:
		direction = sign((body as Node2D).global_position.x - global_position.x)
		if direction == 0.0:
			direction = 1.0

	_play_touch_swing(-direction)


func _play_touch_swing(direction: float) -> void:
	if _touch_tween != null and _touch_tween.is_running():
		_touch_tween.kill()

	_touch_tween = create_tween()
	_touch_tween.set_trans(Tween.TRANS_CUBIC)
	_touch_tween.set_ease(Tween.EASE_OUT)
	_touch_tween.tween_property(self, "_touch_offset_deg", touch_kick_deg * direction, 0.045)
	_touch_tween.tween_property(self, "_touch_offset_deg", -touch_kick_deg * 0.62 * direction, 0.11)
	_touch_tween.tween_property(self, "_touch_offset_deg", touch_kick_deg * 0.28 * direction, 0.12)
	_touch_tween.tween_property(self, "_touch_offset_deg", 0.0, 0.2)
