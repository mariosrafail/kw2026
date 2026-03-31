extends Area2D
class_name TrampolinePad

@export var launch_velocity_idle_y := -1680.0
@export var launch_velocity_if_jumping_y := -1100.0
@export var jumping_upward_threshold_y := -220.0
@export var retrigger_cooldown_ms := 220
@export var force_jump_hold_duration_sec := 0.17
@export var force_jump_hold_bonus_if_input_held_sec := 0.04
@export var visual_path := NodePath("../PadVisual")
@export var impact_widen_scale_x := 1.25
@export var impact_compress_scale_y := 0.45
@export var impact_press_duration := 0.055
@export var impact_rebound_duration := 0.16
@export var impact_wobble_degrees := 5.0
@export var impact_glow_strength := 0.65

var _trigger_cooldowns: Dictionary = {}
var _pad_visual: Node2D
var _visual_base_scale := Vector2.ONE
var _visual_base_rotation := 0.0
var _visual_base_modulate := Color.WHITE
var _impact_tween: Tween

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = true
	_resolve_pad_visual()

func _physics_process(_delta: float) -> void:
	if not _can_apply_launch():
		return
	for body in get_overlapping_bodies():
		var player := body as NetPlayer
		if player == null:
			continue
		if _try_launch_player(player):
			_broadcast_impact_animation(player)

func _on_body_entered(body: Node) -> void:
	var player := body as NetPlayer
	if player == null:
		return
	if not _can_apply_launch():
		return
	if _try_launch_player(player):
		_broadcast_impact_animation(player)

func _try_launch_player(player: NetPlayer) -> bool:
	var body_id := player.get_instance_id()
	var now_ms := Time.get_ticks_msec()
	var ready_at := int(_trigger_cooldowns.get(body_id, 0))
	if now_ms < ready_at:
		return false
	_trigger_cooldowns[body_id] = now_ms + retrigger_cooldown_ms
	# Always apply the strongest trampoline boost, regardless of current upward movement.
	var launch_velocity := minf(launch_velocity_idle_y, launch_velocity_if_jumping_y)
	player.velocity.y = minf(player.velocity.y, launch_velocity)
	player.target_velocity = player.velocity
	var hold_duration := force_jump_hold_duration_sec
	if player.is_jump_input_held():
		hold_duration += force_jump_hold_bonus_if_input_held_sec
	player.apply_external_jump_hold(hold_duration)
	return true

func _can_apply_launch() -> bool:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return true
	return multiplayer.is_server()

func _impact_direction_for_player(player: NetPlayer) -> float:
	if player == null:
		return 1.0
	var player_offset_x := player.global_position.x - global_position.x
	if absf(player_offset_x) <= 0.01:
		return 1.0
	return signf(player_offset_x)

func _broadcast_impact_animation(player: NetPlayer) -> void:
	var direction := _impact_direction_for_player(player)
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		_rpc_play_impact_animation(direction)
		return
	if multiplayer.is_server():
		_rpc_play_impact_animation.rpc(direction)

@rpc("authority", "call_local", "reliable")
func _rpc_play_impact_animation(impact_direction: float) -> void:
	_play_impact_animation(impact_direction)

func _resolve_pad_visual() -> void:
	var visual_node := get_node_or_null(visual_path)
	_pad_visual = visual_node as Node2D
	if _pad_visual == null:
		return
	_visual_base_scale = _pad_visual.scale
	_visual_base_rotation = _pad_visual.rotation
	_visual_base_modulate = _pad_visual.modulate

func _play_impact_animation(impact_direction: float = 1.0) -> void:
	if _pad_visual == null:
		return
	if is_instance_valid(_impact_tween):
		_impact_tween.kill()
	_pad_visual.scale = _visual_base_scale
	_pad_visual.rotation = _visual_base_rotation
	_pad_visual.modulate = _visual_base_modulate
	_impact_tween = create_tween()
	_impact_tween.set_trans(Tween.TRANS_QUAD)
	_impact_tween.set_ease(Tween.EASE_OUT)
	var impact_scale := Vector2(_visual_base_scale.x * impact_widen_scale_x, _visual_base_scale.y * impact_compress_scale_y)
	var wobble_radians := deg_to_rad(impact_wobble_degrees * impact_direction)
	var glow_color := _visual_base_modulate.lerp(Color.WHITE, clampf(impact_glow_strength, 0.0, 1.0))
	_impact_tween.tween_property(_pad_visual, "scale", impact_scale, impact_press_duration)
	_impact_tween.parallel().tween_property(_pad_visual, "rotation", _visual_base_rotation + wobble_radians, impact_press_duration)
	_impact_tween.parallel().tween_property(_pad_visual, "modulate", glow_color, impact_press_duration)
	_impact_tween.set_trans(Tween.TRANS_BACK)
	_impact_tween.set_ease(Tween.EASE_OUT)
	_impact_tween.tween_property(_pad_visual, "scale", _visual_base_scale, impact_rebound_duration)
	_impact_tween.parallel().tween_property(_pad_visual, "rotation", _visual_base_rotation, impact_rebound_duration)
	_impact_tween.parallel().tween_property(_pad_visual, "modulate", _visual_base_modulate, impact_rebound_duration)
