extends RefCounted
## Collision-aware random roaming for visual target clones. Does not aim or shoot.
var body: CharacterBody3D
var visual: Node3D
var bounds := Rect2(-21, -27, 42, 42)
var goal := Vector3.ZERO
var spawn := Vector3.ZERO
var rng := RandomNumberGenerator.new()
var enabled := true
var pause := 0.0
var decision_time := 0.0
var stalled := 0.0
var stagger := 0.0
var knockback := Vector3.ZERO
var drive_velocity := Vector3.ZERO
var move_speed := 3.3
var impact_velocity := 0.0
var distance_travelled := 0.0
var direction_changes := 0
var last_direction := Vector3.FORWARD
var elapsed := 0.0

func setup(actor: CharacterBody3D, rig: Node3D, area: Rect2, seed_value: int) -> void:
	body = actor
	visual = rig
	bounds = area
	spawn = body.global_position
	rng.seed = seed_value
	_choose_goal()

func _choose_goal() -> void:
	for attempt in range(18):
		var angle := rng.randf_range(-PI, PI)
		var distance := rng.randf_range(3.5, 9.0)
		var candidate := body.global_position + Vector3(sin(angle), 0, cos(angle)) * distance
		candidate.x = clampf(candidate.x, bounds.position.x, bounds.end.x)
		candidate.z = clampf(candidate.z, bounds.position.y, bounds.end.y)
		var travel := candidate - body.global_position
		travel.y = 0.0
		if travel.length() > 2.0:
			goal = candidate
			break
	move_speed = rng.randf_range(2.6, 4.2)
	decision_time = rng.randf_range(2.0, 4.5)
	pause = rng.randf_range(0.12, 0.50) if rng.randf() < 0.30 else 0.0
	direction_changes += 1
	stalled = 0.0

func _safe_direction(direction: Vector3) -> bool:
	if direction.length_squared() < 0.001: return false
	var ahead := body.global_position + direction * 1.0
	if not bounds.grow(0.4).has_point(Vector2(ahead.x, ahead.z)): return false
	if body.test_move(body.global_transform, direction * 0.95): return false
	var foot := ahead + Vector3.DOWN * 1.715
	var query := PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 0.55, foot + Vector3.DOWN * 0.55, 1)
	query.exclude = [body.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit["normal"] as Vector3).y > 0.65

func impulse(direction: Vector3, strength: float) -> void:
	var horizontal := Vector3(direction.x, 0, direction.z)
	if horizontal.length_squared() > 0.001:
		knockback = (knockback + horizontal.normalized() * strength).limit_length(5.2)
	stagger = 0.14
	decision_time = minf(decision_time, 0.7)

func update(delta: float) -> void:
	var dt := clampf(delta, 0.0001, 0.1)
	elapsed += dt
	pause = maxf(0.0, pause - dt)
	stagger = maxf(0.0, stagger - dt)
	decision_time -= dt
	var difference := goal - body.global_position
	difference.y = 0.0
	if enabled and (decision_time <= 0.0 or difference.length() < 0.75 or stalled > 0.55):
		_choose_goal()
		difference = goal - body.global_position
		difference.y = 0.0
	var direction := Vector3.ZERO
	if enabled and pause <= 0.0 and stagger <= 0.0:
		direction = difference.normalized()
		if body.is_on_floor() and not _safe_direction(direction):
			var best := Vector3.ZERO
			var score := -INF
			for turn in [-0.60, 0.60, -1.2, 1.2, -1.9, 1.9, PI]:
				var test_direction := Basis(Vector3.UP, turn) * direction
				if _safe_direction(test_direction):
					var weight := test_direction.dot(direction) + test_direction.dot(last_direction) * 0.3
					if weight > score:
						score = weight
						best = test_direction
			direction = best
			if direction == Vector3.ZERO: stalled += dt
	var old_position := body.global_position
	var target := direction * move_speed
	drive_velocity = drive_velocity.move_toward(target, 18.0 * dt)
	body.velocity.x = drive_velocity.x + knockback.x
	body.velocity.z = drive_velocity.z + knockback.z
	body.velocity.y = -0.5 if body.is_on_floor() else body.velocity.y - 19.5 * dt
	impact_velocity = body.velocity.y
	body.move_and_slide()
	knockback = knockback.move_toward(Vector3.ZERO, 18.0 * dt)
	var travelled := body.global_position - old_position
	travelled.y = 0.0
	distance_travelled += travelled.length()
	if enabled and pause <= 0.0 and stagger <= 0.0:
		stalled = stalled + dt if travelled.length() < dt * 0.18 else 0.0
	if travelled.length() > dt * 0.2:
		last_direction = travelled.normalized()
		var heading := atan2(-last_direction.x, -last_direction.z)
		var rotation_value := visual.global_rotation
		rotation_value.y = lerp_angle(rotation_value.y, heading, 1.0 - exp(-9.0 * dt))
		visual.global_rotation = rotation_value
	if body.global_position.y < -10.0:
		body.global_position = spawn + Vector3.UP * 0.1
		body.velocity = Vector3.ZERO
		knockback = Vector3.ZERO
		_choose_goal()
