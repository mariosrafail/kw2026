extends Skill

const CHARACTER_ID_VEILA := "veila"
const DARKNESS_DURATION_SEC := 5.0
const STATUS_TEXT := "Darkness"
const SELF_MOVE_MULTIPLIER := 1.18
const SELF_JUMP_MULTIPLIER := 1.14
const OVERLAY_LAYER := 235
const OVERLAY_ALPHA := 0.82

var character_id_for_peer_cb: Callable = Callable()
var _darkness_remaining_by_caster: Dictionary = {}
var _active_darkness_for_peer: Dictionary = {}

static var _darkness_layer: CanvasLayer
static var _darkness_rect: ColorRect
static var _darkness_count := 0

func _init() -> void:
	super._init("veila_darkness", "Darkness", 0.0, "Darken enemy screens for 5 seconds and gain bonus mobility")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_VEILA:
		print("[veila_darkness] reject_cast caster=%d reason=character_mismatch resolved=%s" % [caster_peer_id, _character_id_for_peer(caster_peer_id)])
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		print("[veila_darkness] reject_cast caster=%d reason=no_lobby" % caster_peer_id)
		return
	print("[veila_darkness] cast caster=%d lobby=%d members=%s" % [caster_peer_id, lobby_id, str(_get_lobby_members(lobby_id))])
	_darkness_remaining_by_caster[caster_peer_id] = DARKNESS_DURATION_SEC
	_active_darkness_for_peer[caster_peer_id] = true
	_apply_server_mobility_for_caster(caster_peer_id, true)
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, target_world)

func _execute_client_visual(caster_peer_id: int, _target_world: Vector2) -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster != null and caster.has_method("start_ulti_duration_bar"):
		caster.call("start_ulti_duration_bar", DARKNESS_DURATION_SEC, STATUS_TEXT)
	var should_darken := _should_darken_for_local_viewer(caster_peer_id)
	var local_peer_id := 0
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		local_peer_id = multiplayer.get_unique_id()
	print("[veila_darkness] client_visual local=%d caster=%d should_darken=%s" % [local_peer_id, caster_peer_id, str(should_darken)])
	if should_darken:
		_enable_darkness_overlay(DARKNESS_DURATION_SEC)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _darkness_remaining_by_caster.is_empty():
		return
	var ended: Array[int] = []
	for caster_value in _darkness_remaining_by_caster.keys():
		var caster_peer_id := int(caster_value)
		var remaining := maxf(0.0, float(_darkness_remaining_by_caster.get(caster_peer_id, 0.0)) - delta)
		if remaining <= 0.0:
			ended.append(caster_peer_id)
			continue
		_darkness_remaining_by_caster[caster_peer_id] = remaining
		_apply_server_mobility_for_caster(caster_peer_id, true)
	for caster_peer_id in ended:
		_darkness_remaining_by_caster.erase(caster_peer_id)
		_active_darkness_for_peer.erase(caster_peer_id)
		_apply_server_mobility_for_caster(caster_peer_id, false)

func _apply_server_mobility_for_caster(caster_peer_id: int, enabled: bool) -> void:
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player == null:
		return
	if player.has_method("set_external_status_movement_speed_multiplier"):
		player.call("set_external_status_movement_speed_multiplier", SELF_MOVE_MULTIPLIER if enabled else 1.0)
	if player.has_method("set_external_status_jump_velocity_multiplier"):
		player.call("set_external_status_jump_velocity_multiplier", SELF_JUMP_MULTIPLIER if enabled else 1.0)

func _should_darken_for_local_viewer(caster_peer_id: int) -> bool:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		print("[veila_darkness] skip_darkness reason=no_multiplayer_peer caster=%d" % caster_peer_id)
		return false
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		print("[veila_darkness] skip_darkness reason=invalid_local_peer caster=%d local=%d" % [caster_peer_id, local_peer_id])
		return false
	if local_peer_id == caster_peer_id:
		print("[veila_darkness] skip_darkness reason=self_cast caster=%d" % caster_peer_id)
		return false
	var tree := _scene_tree()
	var root := tree.current_scene if tree != null else null
	var team_mode := false
	if root != null and root.has_method("_ctf_enabled"):
		team_mode = bool(root.call("_ctf_enabled"))
	if team_mode and root != null and root.has_method("_team_for_peer"):
		var local_team := int(root.call("_team_for_peer", local_peer_id))
		var caster_team := int(root.call("_team_for_peer", caster_peer_id))
		if local_team >= 0 and caster_team >= 0 and local_team == caster_team:
			print("[veila_darkness] skip_darkness reason=same_team local=%d caster=%d team=%d" % [local_peer_id, caster_peer_id, local_team])
			return false
		print("[veila_darkness] team_mode local=%d caster=%d local_team=%d caster_team=%d" % [local_peer_id, caster_peer_id, local_team, caster_team])
	else:
		print("[veila_darkness] non_team_mode local=%d caster=%d apply=true" % [local_peer_id, caster_peer_id])
	return true

func _enable_darkness_overlay(duration_sec: float) -> void:
	_ensure_darkness_overlay()
	if _darkness_rect == null:
		return
	_darkness_count += 1
	_darkness_rect.visible = true
	_darkness_rect.color = Color(0.0, 0.0, 0.0, OVERLAY_ALPHA)
	var tree := _scene_tree()
	if tree == null:
		return
	var timer := tree.create_timer(maxf(0.05, duration_sec))
	timer.timeout.connect(Callable(self, "_on_darkness_timeout"), CONNECT_ONE_SHOT)

func _on_darkness_timeout() -> void:
	_darkness_count = maxi(0, _darkness_count - 1)
	if _darkness_count <= 0 and _darkness_rect != null and is_instance_valid(_darkness_rect):
		_darkness_rect.visible = false

func _ensure_darkness_overlay() -> void:
	if _darkness_rect != null and is_instance_valid(_darkness_rect):
		return
	var tree := _scene_tree()
	if tree == null:
		return
	var host: Node = tree.current_scene
	if host == null:
		host = tree.root
	if _darkness_layer == null or not is_instance_valid(_darkness_layer):
		_darkness_layer = CanvasLayer.new()
		_darkness_layer.name = "VeilaDarknessLayer"
		_darkness_layer.layer = OVERLAY_LAYER
		host.add_child(_darkness_layer)
	_darkness_layer.layer = OVERLAY_LAYER
	_darkness_layer.follow_viewport_enabled = false
	_darkness_rect = ColorRect.new()
	_darkness_rect.name = "VeilaDarknessRect"
	_darkness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_darkness_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_darkness_rect.offset_left = 0.0
	_darkness_rect.offset_top = 0.0
	_darkness_rect.offset_right = 0.0
	_darkness_rect.offset_bottom = 0.0
	_darkness_rect.color = Color(0.0, 0.0, 0.0, OVERLAY_ALPHA)
	_darkness_rect.visible = false
	_darkness_layer.add_child(_darkness_rect)

func _scene_tree() -> SceneTree:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return loop as SceneTree
	return null

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_VEILA
