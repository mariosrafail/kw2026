extends Camera2D
class_name MinimapCameraController

const DEFAULT_ZOOM := Vector2(0.16, 0.16)
const EDGE_INSET_WORLD := 8.0

var _focus_position_cb: Callable = Callable()
var _play_bounds_cb: Callable = Callable()
var _camera_limits_cb: Callable = Callable()
var _has_focus_target := false

func _ready() -> void:
	enabled = true
	zoom = DEFAULT_ZOOM
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	ignore_rotation = true

func configure(
	focus_position_cb: Callable,
	play_bounds_cb: Callable = Callable(),
	camera_limits_cb: Callable = Callable(),
	minimap_zoom: Vector2 = DEFAULT_ZOOM
) -> void:
	_focus_position_cb = focus_position_cb
	_play_bounds_cb = play_bounds_cb
	_camera_limits_cb = camera_limits_cb
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
	var bounds: Rect2i = _resolve_clamp_bounds_rect()
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return target_position
	var inset_x := minf(EDGE_INSET_WORLD, float(bounds.size.x) * 0.25)
	var inset_y := minf(EDGE_INSET_WORLD, float(bounds.size.y) * 0.25)
	var safe_left := float(bounds.position.x) + inset_x
	var safe_right := float(bounds.position.x + bounds.size.x) - inset_x
	var safe_top := float(bounds.position.y) + inset_y
	var safe_bottom := float(bounds.position.y + bounds.size.y) - inset_y
	if safe_right <= safe_left or safe_bottom <= safe_top:
		safe_left = float(bounds.position.x)
		safe_right = float(bounds.position.x + bounds.size.x)
		safe_top = float(bounds.position.y)
		safe_bottom = float(bounds.position.y + bounds.size.y)
	var viewport_size: Vector2 = get_viewport_rect().size
	var safe_zoom := Vector2(maxf(zoom.x, 0.0001), maxf(zoom.y, 0.0001))
	var half_extents := Vector2(
		viewport_size.x * 0.5 / safe_zoom.x,
		viewport_size.y * 0.5 / safe_zoom.y
	)
	var min_x := safe_left + half_extents.x
	var max_x := safe_right - half_extents.x
	var min_y := safe_top + half_extents.y
	var max_y := safe_bottom - half_extents.y
	if min_x > max_x:
		var center_x := float(bounds.position.x) + float(bounds.size.x) * 0.5
		min_x = center_x
		max_x = center_x
	if min_y > max_y:
		var center_y := float(bounds.position.y) + float(bounds.size.y) * 0.5
		min_y = center_y
		max_y = center_y
	return Vector2(
		clampf(target_position.x, min_x, max_x),
		clampf(target_position.y, min_y, max_y)
	)

func _resolve_clamp_bounds_rect() -> Rect2i:
	if _camera_limits_cb.is_valid():
		var camera_limits_value: Variant = _camera_limits_cb.call()
		if camera_limits_value is Rect2i:
			var camera_rect := camera_limits_value as Rect2i
			if camera_rect.size.x > 0 and camera_rect.size.y > 0:
				return camera_rect
	if _play_bounds_cb.is_valid():
		var bounds_value: Variant = _play_bounds_cb.call()
		if bounds_value is Rect2i:
			var bounds := bounds_value as Rect2i
			if bounds.size.x > 0 and bounds.size.y > 0:
				return bounds
	return Rect2i()
