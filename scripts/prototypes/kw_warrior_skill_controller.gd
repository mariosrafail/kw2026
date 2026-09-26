extends Node
## Offline implementation of the five current 3D warrior skills.

const RULES := preload("res://scripts/kw3d/warrior_skill_rules.gd")

var stage: Node3D
var cooldown_left := 0.0
var active_left := 0.0
var pulse_clock := 0.0
var cast_serial := 0
var pulse_serial := 0
var hud_refresh_clock := 0.0


func setup(owner_stage: Node3D) -> void:
	stage = owner_stage
	name = "WarriorSkill"
	set_physics_process(true)
	_update_hud()


func reset() -> void:
	cooldown_left = 0.0
	active_left = 0.0
	pulse_clock = 0.0
	_update_hud()


func cast() -> bool:
	if stage == null or stage.combat == null or stage.combat.is_game_over():
		return false
	if cooldown_left > 0.0001:
		return false
	var warrior_id := str(stage.player_warrior_id).strip_edges().to_lower()
	if not RULES.valid(warrior_id):
		return false
	var cfg := RULES.config_ref(warrior_id)
	cooldown_left = float(cfg.cooldown)
	active_left = float(cfg.duration)
	pulse_clock = 0.0
	cast_serial += 1
	if warrior_id == "kosas":
		_nose_rush()
	if stage.has_method("_spawn_warrior_skill_vfx"):
		stage.call("_spawn_warrior_skill_vfx", stage.player_visual, warrior_id, maxf(0.35, active_left))
	_update_hud()
	return true


func damage_multiplier() -> float:
	return 2.0 if _active_for("outrage") else 1.0


func fire_interval_multiplier() -> float:
	return 0.64 if _active_for("loker") else 1.0


func reload_duration_multiplier() -> float:
	return 0.58 if _active_for("loker") else 1.0


func is_immune() -> bool:
	return _active_for("erebus")


func _active_for(warrior_id: String) -> bool:
	return active_left > 0.0001 and stage != null and str(stage.player_warrior_id) == warrior_id


func _physics_process(delta: float) -> void:
	if stage == null:
		return
	var dt := clampf(delta, 0.0, 0.10)
	cooldown_left = maxf(0.0, cooldown_left - dt)
	active_left = maxf(0.0, active_left - dt)
	pulse_clock = maxf(0.0, pulse_clock - dt)
	if _active_for("aevilok") and pulse_clock <= 0.0001:
		pulse_clock = 0.18
		_flamethrower_pulse()
	hud_refresh_clock-=dt
	if hud_refresh_clock<=0.0:
		hud_refresh_clock=0.10
		_update_hud()


func _nose_rush() -> void:
	if stage.player == null:
		return
	var start: Vector3 = stage.player.global_position
	var direction: Vector3 = -stage.camera_yaw.global_basis.z
	direction.y = 0.0
	if direction.length_squared() < 0.001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	stage.player.move_and_collide(direction * 4.8)
	var finish: Vector3 = stage.player.global_position
	stage.player.velocity.x = direction.x * 11.0
	stage.player.velocity.z = direction.z * 11.0
	if stage.has_method("_spawn_kosas_dash_vfx"):
		stage.call("_spawn_kosas_dash_vfx", start, finish)
	for target in stage.combat.targets.duplicate():
		if not is_instance_valid(target) or bool(target.dead):
			continue
		var offset: Vector3 = target.global_position - stage.player.global_position
		if offset.length() > 2.45:
			continue
		var hit_direction: Vector3 = offset.normalized() if offset.length_squared() > 0.001 else direction
		var point: Vector3 = target.global_position + Vector3.UP * 0.9
		var shot_id: int = -(cast_serial * 1000 + int(target.get_instance_id() % 997))
		if target.receive_hit(35.0, hit_direction, shot_id, point):
			stage.combat._spawn_damage_feedback(point, hit_direction, 35.0, bool(target.dead), stage.combat.blood_color_for_skin(str(target.warrior_id)), true)
			if target.brain != null:
				target.brain.impulse(hit_direction, 5.0)


func _flamethrower_pulse() -> void:
	if stage.player == null or stage.camera_yaw == null:
		return
	pulse_serial += 1
	var origin: Vector3 = stage.player.global_position + Vector3.UP * 1.10
	var direction: Vector3 = -stage.camera.global_basis.z if stage.camera != null else -stage.camera_yaw.global_basis.z
	direction = direction.normalized()
	if stage.has_method("_spawn_aevilok_flame_burst"):
		stage.call("_spawn_aevilok_flame_burst", origin, direction)
	var cone_cos: float = cos(deg_to_rad(31.0))
	for target in stage.combat.targets.duplicate():
		if not is_instance_valid(target) or bool(target.dead):
			continue
		var point: Vector3 = target.global_position + Vector3.UP * 0.85
		var offset: Vector3 = point - origin
		var distance: float = offset.length()
		if distance <= 0.05 or distance > 7.2:
			continue
		var hit_direction: Vector3 = offset / distance
		if direction.dot(hit_direction) < cone_cos:
			continue
		var shot_id: int = -(cast_serial * 100000 + pulse_serial * 100 + int(target.get_instance_id() % 97))
		if target.receive_hit(7.0, hit_direction, shot_id, point):
			stage.combat._spawn_damage_feedback(point, hit_direction, 7.0, bool(target.dead), stage.combat.blood_color_for_skin(str(target.warrior_id)), true)
			if target.brain != null:
				target.brain.impulse(hit_direction, 0.55)


func _update_hud() -> void:
	if stage != null and stage.has_method("_update_warrior_skill_hud"):
		stage.call("_update_warrior_skill_hud", cooldown_left, active_left)
