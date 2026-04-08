extends Skill

const GAN_BARRIER_VFX := preload("res://scripts/warriors/vfx/gan_barrier_vfx.gd")

const CHARACTER_ID_GAN := "gan"
const BARRIER_DURATION_SEC := 5.0
const BARRIER_RADIUS_PX := 208.0
const PUSH_SPEED_PX_PER_SEC := 820.0
const PUSH_BORDER_PADDING_PX := 4.0
const CENTER_EPSILON := 0.0001
const STATUS_TEXT := "No Entry"
const BARRIER_COLOR := Color(0.38, 0.86, 1.0, 0.9)

var character_id_for_peer_cb: Callable = Callable()
var _barriers_by_caster: Dictionary = {}

func _init() -> void:
	super._init("gan_no_entry", "No Entry", 0.0, "Deploy a stationary barrier that pushes enemies out")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, _target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_GAN:
		return
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var center := caster.global_position
	_barriers_by_caster[caster_peer_id] = {
		"remaining": BARRIER_DURATION_SEC,
		"lobby_id": lobby_id,
		"radius": BARRIER_RADIUS_PX,
		"center": center
	}
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, center)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	_spawn_barrier_vfx(caster_peer_id, target_world, BARRIER_DURATION_SEC, BARRIER_RADIUS_PX)
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player != null and player.has_method("start_ulti_duration_bar"):
		player.call("start_ulti_duration_bar", BARRIER_DURATION_SEC, STATUS_TEXT)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _barriers_by_caster.is_empty():
		return

	var expired_casters: Array[int] = []
	for peer_value in _barriers_by_caster.keys():
		var caster_peer_id := int(peer_value)
		var barrier_data := _barriers_by_caster.get(caster_peer_id, {}) as Dictionary
		var remaining := maxf(0.0, float(barrier_data.get("remaining", 0.0)) - delta)
		if remaining <= 0.0:
			expired_casters.append(caster_peer_id)
			continue
		barrier_data["remaining"] = remaining
		_barriers_by_caster[caster_peer_id] = barrier_data

		var lobby_id := int(barrier_data.get("lobby_id", _get_peer_lobby(caster_peer_id)))
		if lobby_id <= 0:
			continue
		var center := barrier_data.get("center", Vector2.ZERO) as Vector2
		var radius := maxf(24.0, float(barrier_data.get("radius", BARRIER_RADIUS_PX)))
		var push_target_radius := radius + PUSH_BORDER_PADDING_PX

		for target_peer_value in players.keys():
			var target_peer_id := int(target_peer_value)
			if target_peer_id == caster_peer_id:
				continue
			if _get_peer_lobby(target_peer_id) != lobby_id:
				continue
			var target := players.get(target_peer_id, null) as NetPlayer
			if target == null or target.get_health() <= 0:
				continue

			var offset := target.global_position - center
			var distance := offset.length()
			if distance >= radius:
				continue

			var push_dir := Vector2.ZERO
			if distance <= CENTER_EPSILON:
				push_dir = Vector2.RIGHT.rotated(float(target_peer_id) * 0.31)
			else:
				push_dir = offset / distance

			var desired_position := center + push_dir * push_target_radius
			var correction := desired_position - target.global_position
			if correction.length_squared() <= CENTER_EPSILON:
				continue
			var max_step := PUSH_SPEED_PX_PER_SEC * delta
			var step := correction.normalized() * minf(max_step, correction.length())
			target.global_position += step
			target.target_position = target.global_position
			target.velocity.x = maxf(target.velocity.x, push_dir.x * 120.0) if push_dir.x >= 0.0 else minf(target.velocity.x, push_dir.x * 120.0)
			target.target_velocity = target.velocity

	for caster_peer_id in expired_casters:
		_barriers_by_caster.erase(caster_peer_id)

func _spawn_barrier_vfx(caster_peer_id: int, center: Vector2, duration_sec: float, radius_px: float) -> void:
	if projectile_system == null or projectile_system.projectiles_root == null:
		return
	var existing := projectile_system.projectiles_root.get_node_or_null("GanBarrier_%d" % caster_peer_id) as Node
	if existing != null:
		existing.queue_free()
	var vfx := GAN_BARRIER_VFX.new()
	vfx.name = "GanBarrier_%d" % caster_peer_id
	vfx.global_position = center
	vfx.duration_sec = maxf(0.05, duration_sec)
	vfx.radius = maxf(24.0, radius_px)
	vfx.color = BARRIER_COLOR
	projectile_system.projectiles_root.add_child(vfx)

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_GAN
