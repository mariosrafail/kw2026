extends Node2D
class_name VarnCompanionVfx

var caster_peer_id := 0
var players: Dictionary = {}
var texture: Texture2D
var base_color := Color(0.66, 0.72, 0.08, 1.0)

var _follow_offset := Vector2(-18.0, -26.0)
var _follow_speed := 11.0
var _sprite: Sprite2D

func _ready() -> void:
	z_index = 47
	_sprite = Sprite2D.new()
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.texture = texture
	_sprite.modulate = base_color
	_sprite.scale = Vector2.ONE * 0.9
	add_child(_sprite)
	_update_follow_position(true)

func _process(_delta: float) -> void:
	_update_follow_position(false)
	_apply_idle_wobble()

func set_companion_color(color: Color) -> void:
	base_color = color
	if _sprite != null:
		_sprite.modulate = base_color

func _update_follow_position(snap: bool) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		queue_free()
		return
	var desired := caster.global_position + _follow_offset
	if snap:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, minf(1.0, _follow_speed * get_process_delta_time()))

func _apply_idle_wobble() -> void:
	if _sprite == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	_sprite.position = Vector2(0.0, sin(t * 5.4) * 1.7)
	_sprite.rotation = sin(t * 3.8) * 0.08
