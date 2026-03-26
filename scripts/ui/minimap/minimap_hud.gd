extends Control
class_name MinimapHud

const MINIMAP_CAMERA_CONTROLLER_SCRIPT := preload("res://scripts/ui/minimap/minimap_camera_controller.gd")
const MINIMAP_MARKER_OVERLAY_SCRIPT := preload("res://scripts/ui/minimap/minimap_marker_overlay.gd")
const MINIMAP_VISIBLE_CANVAS_CULL_MASK := 1
const PANEL_SIZE := Vector2(228.0, 132.0)
const PANEL_BOTTOM_MARGIN := 16.0
const PANEL_BORDER := 3
const PANEL_BG := Color(0.02, 0.04, 0.08, 1.0)
const PANEL_BORDER_COLOR := Color(0.92, 0.97, 1.0, 0.9)
var _panel: PanelContainer
var _viewport_container: SubViewportContainer
var _viewport: SubViewport
var _camera: Node
var _marker_overlay: Node

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	_build_ui()
	_layout_panel()

func configure(world_2d: World2D, focus_position_cb: Callable, play_bounds_cb: Callable = Callable(), marker_data_cb: Callable = Callable()) -> void:
	if _viewport == null or _camera == null:
		return
	_viewport.world_2d = world_2d
	if _camera.has_method("configure"):
		_camera.call("configure", focus_position_cb, play_bounds_cb)
	if _marker_overlay != null and _marker_overlay.has_method("configure"):
		_marker_overlay.call("configure", marker_data_cb, Callable(_camera, "state_snapshot"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_panel()

func _process(_delta: float) -> void:
	if _panel == null or _camera == null:
		return
	_panel.visible = bool(_camera.call("has_focus_target")) if _camera.has_method("has_focus_target") else false

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "MiniMapPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = PANEL_BG
	panel_style.border_width_left = PANEL_BORDER
	panel_style.border_width_top = PANEL_BORDER
	panel_style.border_width_right = PANEL_BORDER
	panel_style.border_width_bottom = PANEL_BORDER
	panel_style.border_color = PANEL_BORDER_COLOR
	_panel.add_theme_stylebox_override("panel", panel_style)

	var root: Control = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(root)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.stretch = true
	_viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.handle_input_locally = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_2d = Viewport.MSAA_2X
	_viewport.canvas_cull_mask = MINIMAP_VISIBLE_CANVAS_CULL_MASK
	_viewport_container.add_child(_viewport)

	_camera = MINIMAP_CAMERA_CONTROLLER_SCRIPT.new()
	_camera.name = "MinimapCamera"
	_viewport.add_child(_camera)

	_marker_overlay = MINIMAP_MARKER_OVERLAY_SCRIPT.new()
	_marker_overlay.name = "MarkerOverlay"
	root.add_child(_marker_overlay)

func _layout_panel() -> void:
	if _panel == null:
		return
	var size_scale: float = clampf(size.x / 1280.0, 0.84, 1.0)
	var resolved_size: Vector2 = PANEL_SIZE * size_scale
	_panel.size = resolved_size
	_panel.position = Vector2(
		(size.x - resolved_size.x) * 0.5,
		size.y - resolved_size.y - PANEL_BOTTOM_MARGIN
	)
	if _viewport != null:
		_viewport.size = Vector2i(maxi(1, int(round(resolved_size.x))), maxi(1, int(round(resolved_size.y))))
