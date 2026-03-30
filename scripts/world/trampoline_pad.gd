extends Area2D
class_name TrampolinePad

@export var launch_velocity_idle_y := -1680.0
@export var launch_velocity_if_jumping_y := -1100.0
@export var jumping_upward_threshold_y := -220.0
@export var retrigger_cooldown_ms := 220

var _trigger_cooldowns: Dictionary = {}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	monitoring = true
	monitorable = true

func _physics_process(_delta: float) -> void:
	if not _can_apply_launch():
		return
	for body in get_overlapping_bodies():
		var player := body as NetPlayer
		if player == null:
			continue
		_try_launch_player(player)

func _on_body_entered(body: Node) -> void:
	var player := body as NetPlayer
	if player == null:
		return
	if not _can_apply_launch():
		return
	_try_launch_player(player)

func _try_launch_player(player: NetPlayer) -> void:
	var body_id := player.get_instance_id()
	var now_ms := Time.get_ticks_msec()
	var ready_at := int(_trigger_cooldowns.get(body_id, 0))
	if now_ms < ready_at:
		return
	_trigger_cooldowns[body_id] = now_ms + retrigger_cooldown_ms
	var launch_velocity := launch_velocity_idle_y
	if player.velocity.y <= jumping_upward_threshold_y:
		launch_velocity = launch_velocity_if_jumping_y
	player.velocity.y = minf(player.velocity.y, launch_velocity)
	player.target_velocity = player.velocity

func _can_apply_launch() -> bool:
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return true
	return multiplayer.is_server()
