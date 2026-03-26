extends Camera2D
class_name MinimapCameraController

const DEFAULT_ZOOM := Vector2(0.16, 0.16)

var _focus_position_cb: Callable = Callable()
var _play_bounds_cb: Callable = Callable()
var _has_focus_target := false

func _ready() -> void:
	enabled = true
	zoom = DEFAULT_ZOOM
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	ignore_rotation = true

func configure(focus_position_cb: Callable, play_bounds_cb: Callable = Callable(), minimap_zoom: Vector2 = DEFAULT_ZOOM) -> void:
	_focus_position_cb = focus_position_cb
	_play_bounds_cb = play_bounds_cb
	zoom = minimap_zoom

func has_focus_target() -> bool:
	return _has_focus_target

func state_snapshot() -> Dictionary:
	return {
		"center": global_position,
		"zoom": zoom
	}

func _process(_delta: float) -> void:
	var target_position: Variant = _resolve_focus_position()
	if target_position == null:
		_has_focus_target = false
		return
	_has_focus_target = true
	global_position = _clamp_to_play_bounds(target_position as Vector2)

func _resolve_focus_position() -> Variant:
	if not _focus_position_cb.is_valid():
		return null
	var value: Variant = _focus_position_cb.call()
	if value is Vector2:
		return value as Vector2
	return null

func _clamp_to_play_bounds(target_position: Vector2) -> Vector2:
	if not _play_bounds_cb.is_valid():
		return target_position
	var bounds_value: Variant = _play_bounds_cb.call()
	if not (bounds_value is Rect2i):
		return target_position
	var bounds: Rect2i = bounds_value as Rect2i
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return target_position
	return Vector2(
		clampf(target_position.x, bounds.position.x, bounds.position.x + bounds.size.x),
		clampf(target_position.y, bounds.position.y, bounds.position.y + bounds.size.y)
	)
