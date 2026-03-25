extends RefCounted
class_name SkullFfaMatchIntroController

const TOUR_SLOT_COUNT := 5
const PLAYER_FOCUS_OFFSET := Vector2(0.0, -28.0)

var _host: Node
var _main_camera: Camera2D
var _players: Dictionary = {}
var _countdown_label: Label
var _active := false
var _elapsed_sec := 0.0
var _duration_sec := 13.0
var _local_peer_id := 0
var _tour_peer_ids: Array[int] = []

func configure(host: Node, main_camera: Camera2D, players: Dictionary) -> void:
	_host = host
	_main_camera = main_camera
	_players = players
	_ensure_countdown_label()

func is_active() -> bool:
	return _active

func start(participant_peer_ids: Array, local_peer_id: int, duration_sec: float = 13.0) -> void:
	_ensure_countdown_label()
	_local_peer_id = local_peer_id
	_duration_sec = maxf(1.0, duration_sec)
	_elapsed_sec = 0.0
	_active = true
	_tour_peer_ids.clear()

	var filtered_ids: Array[int] = []
	for peer_value in participant_peer_ids:
		var peer_id := int(peer_value)
		if peer_id == 0 or filtered_ids.has(peer_id):
			continue
		filtered_ids.append(peer_id)
	if filtered_ids.is_empty() and _local_peer_id != 0:
		filtered_ids.append(_local_peer_id)
	if filtered_ids.is_empty():
		_active = false
		_hide_countdown()
		return

	var fallback_peer_id := filtered_ids[filtered_ids.size() - 1]
	for index in range(TOUR_SLOT_COUNT):
		var slot_peer_id := fallback_peer_id
		if index < filtered_ids.size():
			slot_peer_id = filtered_ids[index]
		_tour_peer_ids.append(slot_peer_id)

	_hide_countdown()

func stop() -> void:
	_active = false
	_hide_countdown()

func visual_tick(_delta: float) -> void:
	if not _active or _main_camera == null:
		return
	_elapsed_sec += _delta
	if _elapsed_sec >= _duration_sec:
		_active = false
		_hide_countdown()
		return

	_main_camera.global_position = _camera_position_for_elapsed(_elapsed_sec)
	_update_countdown(_elapsed_sec)

func _camera_position_for_elapsed(elapsed_sec: float) -> Vector2:
	var slot_positions: Array[Vector2] = []
	var fallback := _main_camera.global_position if _main_camera != null else Vector2.ZERO
	for peer_id in _tour_peer_ids:
		var focus := _focus_position_for_peer(peer_id, fallback)
		slot_positions.append(focus)
		fallback = focus
	var local_focus := _focus_position_for_peer(_local_peer_id, fallback)

	if slot_positions.is_empty():
		return local_focus
	if elapsed_sec < 1.0:
		return slot_positions[0]
	if elapsed_sec < 2.0:
		return slot_positions[0].lerp(slot_positions[1], elapsed_sec - 1.0)
	if elapsed_sec < 3.0:
		return slot_positions[1]
	if elapsed_sec < 4.0:
		return slot_positions[1].lerp(slot_positions[2], elapsed_sec - 3.0)
	if elapsed_sec < 5.0:
		return slot_positions[2]
	if elapsed_sec < 6.0:
		return slot_positions[2].lerp(slot_positions[3], elapsed_sec - 5.0)
	if elapsed_sec < 7.0:
		return slot_positions[3]
	if elapsed_sec < 8.0:
		return slot_positions[3].lerp(slot_positions[4], elapsed_sec - 7.0)
	if elapsed_sec < 9.0:
		return slot_positions[4]
	if elapsed_sec < 10.0:
		return slot_positions[4].lerp(local_focus, elapsed_sec - 9.0)
	return local_focus

func _focus_position_for_peer(peer_id: int, fallback: Vector2) -> Vector2:
	var player := _players.get(peer_id, null) as NetPlayer
	if player == null:
		return fallback
	return player.global_position + PLAYER_FOCUS_OFFSET

func _update_countdown(elapsed_sec: float) -> void:
	if _countdown_label == null:
		return
	if elapsed_sec < 10.0 or elapsed_sec >= 13.0:
		_hide_countdown()
		return
	_countdown_label.visible = true
	if elapsed_sec < 11.0:
		_countdown_label.text = "3"
	elif elapsed_sec < 12.0:
		_countdown_label.text = "2"
	else:
		_countdown_label.text = "1"

func _hide_countdown() -> void:
	if _countdown_label == null:
		return
	_countdown_label.visible = false
	_countdown_label.text = ""

func _ensure_countdown_label() -> void:
	if _host == null:
		return
	if _countdown_label != null and is_instance_valid(_countdown_label):
		return
	var hud_layer := _host.get_node_or_null("ClientHud") as CanvasLayer
	if hud_layer == null:
		return
	var existing := hud_layer.get_node_or_null("SkullMatchIntroCountdown") as Label
	if existing != null:
		_countdown_label = existing
		return
	var label := Label.new()
	label.name = "SkullMatchIntroCountdown"
	label.visible = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.anchor_left = 0.5
	label.anchor_top = 0.5
	label.anchor_right = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -160.0
	label.offset_top = -80.0
	label.offset_right = 160.0
	label.offset_bottom = 80.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_as_relative = false
	label.z_index = 3000
	label.add_theme_font_size_override("font_size", 88)
	label.add_theme_color_override("font_color", Color(0.98, 0.97, 0.95, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08, 1.0))
	label.add_theme_constant_override("outline_size", 10)
	hud_layer.add_child(label)
	_countdown_label = label
