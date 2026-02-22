extends Node2D
class_name TaskoInvisibilityFieldVfx

const STATUS_TEXT := "Invisible"

var caster_peer_id := 0
var center := Vector2.ZERO
var radius := 140.0
var duration_sec := 6.0
var color := Color(1.0, 0.35, 0.85, 0.9)

var players: Dictionary = {}
var local_peer_id := 0

var _remaining := 0.0
var _applied_hidden := false
var _applied_status := false

func _ready() -> void:
	global_position = center
	_remaining = maxf(0.05, duration_sec)
	_build_visual()

func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	_apply_effect()
	if _remaining <= 0.0:
		queue_free()

func _exit_tree() -> void:
	_clear_effect()

func _build_visual() -> void:
	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = Color(1, 1, 1, 1)
	sprite.z_index = 40
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material = mat
	sprite.texture = _ring_tex()
	sprite.scale = Vector2.ONE * (radius / 32.0)
	add_child(sprite)

func _ring_tex() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.72, 0.82, 0.9, 1.0])
	g.colors = PackedColorArray([
		Color(color.r, color.g, color.b, 0.0),
		Color(color.r, color.g, color.b, 0.0),
		Color(color.r, color.g, color.b, color.a),
		Color(color.r, color.g, color.b, 0.0),
		Color(color.r, color.g, color.b, 0.0)
	])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	return tex

func _apply_effect() -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		_clear_effect()
		return

	var inside := caster.global_position.distance_to(center) <= radius

	if local_peer_id == caster_peer_id:
		# Never hide self. Only show a UI hint while inside.
		_set_status(inside)
		return

	_set_hidden(inside, caster)

func _set_hidden(hidden: bool, caster: NetPlayer) -> void:
	if caster == null or caster.visual_root == null:
		return
	if hidden:
		if not _applied_hidden:
			caster.visual_root.visible = false
			if caster.has_method("set_sfx_suppressed"):
				caster.call("set_sfx_suppressed", true)
			_applied_hidden = true
	else:
		if _applied_hidden:
			caster.visual_root.visible = true
			if caster.has_method("set_sfx_suppressed"):
				caster.call("set_sfx_suppressed", false)
			_applied_hidden = false

func _set_status(enabled: bool) -> void:
	var root := get_tree().current_scene
	if root == null:
		return
	if enabled:
		if not _applied_status and root.has_method("client_set_status_text"):
			root.call("client_set_status_text", STATUS_TEXT)
			_applied_status = true
	else:
		if _applied_status and root.has_method("client_set_status_text"):
			root.call("client_set_status_text", "")
			_applied_status = false

func _clear_effect() -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster != null:
		_set_hidden(false, caster)
	_set_status(false)

