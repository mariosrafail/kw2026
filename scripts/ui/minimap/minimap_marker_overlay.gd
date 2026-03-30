extends Control
class_name MinimapMarkerOverlay

const SELF_COLOR := Color(0.18, 1.0, 0.34, 0.98)
const ALLY_COLOR := Color(0.22, 0.62, 1.0, 0.95)
const ENEMY_COLOR := Color(1.0, 0.22, 0.22, 0.95)
const SELF_SIZE := 4.0
const OTHER_RADIUS := 4.0
const ENEMY_SIZE := 3.0

var _marker_data_cb: Callable = Callable()
var _camera_state_cb: Callable = Callable()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

func configure(marker_data_cb: Callable, camera_state_cb: Callable) -> void:
	_marker_data_cb = marker_data_cb
	_camera_state_cb = camera_state_cb
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not _marker_data_cb.is_valid() or not _camera_state_cb.is_valid():
		return
	var state_value: Variant = _camera_state_cb.call()
	if not (state_value is Dictionary):
		return
	var state: Dictionary = state_value as Dictionary
	var center_value: Variant = state.get("center", Vector2.ZERO)
	var zoom_value: Variant = state.get("zoom", Vector2.ONE)
	if not (center_value is Vector2) or not (zoom_value is Vector2):
		return
	var camera_center: Vector2 = center_value as Vector2
	var camera_zoom: Vector2 = zoom_value as Vector2
	var payload_value: Variant = _marker_data_cb.call()
	if not (payload_value is Array):
		return
	var payload: Array = payload_value as Array
	var viewport_center: Vector2 = size * 0.5
	for marker_value in payload:
		if not (marker_value is Dictionary):
			continue
		var marker: Dictionary = marker_value as Dictionary
		var world_value: Variant = marker.get("world_position", Vector2.ZERO)
		if not (world_value is Vector2):
			continue
		var world_position: Vector2 = world_value as Vector2
		var offset: Vector2 = Vector2(
			(world_position.x - camera_center.x) * camera_zoom.x,
			(world_position.y - camera_center.y) * camera_zoom.y
		)
		var screen_position: Vector2 = viewport_center + offset
		if screen_position.x < 0.0 or screen_position.y < 0.0 or screen_position.x > size.x or screen_position.y > size.y:
			continue
		var relation: String = str(marker.get("relation", "enemy")).strip_edges().to_lower()
		var color: Color = ENEMY_COLOR
		var draw_self_square := false
		var draw_enemy_square := false
		if relation == "self":
			color = SELF_COLOR
			draw_self_square = true
		elif relation == "ally":
			color = ALLY_COLOR
		elif relation == "enemy":
			draw_enemy_square = true
		if draw_self_square:
			var side := SELF_SIZE
			var top_left := screen_position - Vector2(side * 0.5, side * 0.5)
			draw_rect(Rect2(top_left, Vector2(side, side)), color, true)
		elif draw_enemy_square:
			var enemy_side := ENEMY_SIZE
			var enemy_top_left := screen_position - Vector2(enemy_side * 0.5, enemy_side * 0.5)
			draw_rect(Rect2(enemy_top_left, Vector2(enemy_side, enemy_side)), ENEMY_COLOR, true)
		else:
			draw_circle(screen_position, OTHER_RADIUS, color)
