extends RefCounted
## Authored-foot locomotion: world-space support, alternating swing, then bounded comedy.
## Never writes the CharacterBody/camera transform or changes gameplay velocity.
class FootState extends RefCounted:
	var node: Node3D
	var rest: Vector3
	var sole_center: Vector3
	var corners: Array[Vector3] = []
	var contact := Vector3.ZERO
	var normal := Vector3.UP
	var support: WeakRef
	var support_local := Vector3.ZERO
	var swinging := false
	var progress := 0.0
	var elapsed := 0.0
	var duration := 0.2
	var age := 0.0
	var heading := 0.0
	var from_heading := 0.0
	var start := Vector3.ZERO
	var goal := Vector3.ZERO
	var lift := 0.25
	var flourish := 0.0
	var toe_out := 0.0
	var settle := false
	var phase := "CONTACT"
	var step_id := 0

var actor: CharacterBody3D
var visual: Node3D
var torso: Node3D
var head: Node3D
var feet: Array[FootState] = []
var torso_rest := Vector3.ZERO
var head_rest := Vector3.ZERO
var playfulness := 1.2
var time := 0.0
var cycle := 0.0
var speed := 0.0
var move_blend := 0.0
var air_blend := 0.0
var landing_kick := 0.0
var secondary_head := Vector3.ZERO
var travel_yaw := 0.0
var velocity := Vector3.ZERO
var last_position := Vector3.ZERO
var last_velocity := Vector3.ZERO
var body_rotation := Vector3.ZERO
var body_angular_velocity := Vector3.ZERO
var body_offset := Vector3.ZERO
var body_offset_velocity := Vector3.ZERO
var head_offset := Vector3.ZERO
var head_offset_velocity := Vector3.ZERO
var step_interval := 0.23
var step_clock := 0.0
var next_foot := 0
var step_count := 0
var initialized := false
var was_grounded := false
var was_moving := false
var rng := RandomNumberGenerator.new()
var noise_phase := 0.0
var last_visual_yaw := 0.0
var turn_rate := 0.0

func setup(p: CharacterBody3D, v: Node3D, h: Node3D, t: Node3D, left: Node3D, right: Node3D, seed_value: int = 137) -> void:
	actor = p
	visual = v
	head = h
	torso = t
	torso_rest = t.position
	head_rest = h.position
	rng.seed = seed_value
	noise_phase = rng.randf_range(0.0, TAU)
	for n in [left, right]:
		var f := FootState.new()
		f.node = n
		f.rest = n.position
		# The sole, not the ankle/outline, defines heel and toe contact.
		for child in n.get_children():
			if child is MeshInstance3D and String(child.name).ends_with("_Sole"):
				var box: AABB = child.mesh.get_aabb()
				for i in range(8): f.corners.append(child.transform * box.get_endpoint(i))
				f.sole_center = child.transform * (box.position + Vector3(box.size.x * 0.5, 0, box.size.z * 0.5))
		assert(f.corners.size() == 8, "Foot model must expose its authored sole")
		feet.append(f)
	reset()

func reset() -> void:
	last_visual_yaw = visual.global_rotation.y
	turn_rate = 0.0
	last_position = actor.global_position
	last_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	travel_yaw = visual.global_rotation.y
	step_clock = 0.0
	cycle = 0.0
	move_blend = 0.0
	body_rotation = Vector3.ZERO
	body_angular_velocity = Vector3.ZERO
	body_offset = Vector3.ZERO
	body_offset_velocity = Vector3.ZERO
	head_offset = Vector3.ZERO
	head_offset_velocity = Vector3.ZERO
	for i in range(feet.size()):
		var f := feet[i]
		f.swinging = false
		f.heading = travel_yaw
		f.age = 0.0
		_set_contact(f, _ground(_neutral(i)))
	initialized = true
	was_grounded = actor.is_on_floor()
	was_moving = false

func update(delta: float, impact_velocity: float = 0.0) -> void:
	var dt := clampf(delta, 0.0001, 0.1)
	if not initialized or actor.global_position.distance_to(last_position) > 3.0:
		reset()
	time += dt
	# Displacement after collisions, not input: no running against a wall / skating.
	velocity = (actor.global_position - last_position) / dt
	last_position = actor.global_position
	var horizontal := Vector3(velocity.x, 0, velocity.z)
	speed = horizontal.length()
	var grounded := actor.is_on_floor()
	var moving := grounded and speed > 0.12
	var ratio := clampf(speed / 11.0, 0.0, 1.0)
	if speed > 0.12:
		var desired := atan2(-horizontal.x, -horizontal.z)
		travel_yaw = rotate_toward(travel_yaw, desired, dt * 11.0)
	elif grounded:
		travel_yaw = rotate_toward(travel_yaw, visual.global_rotation.y, dt * 5.0)
	move_blend = move_toward(move_blend, 1.0 if moving else 0.0, dt * 7.0)
	air_blend = move_toward(air_blend, 0.0 if grounded else 1.0, dt * 8.0)
	landing_kick = move_toward(landing_kick, 0.0, dt * 0.9)
	var acceleration := ((velocity - last_velocity) / dt).limit_length(60.0)
	var local_accel := visual.global_basis.inverse() * acceleration
	var local_velocity := visual.global_basis.inverse() * horizontal
	if grounded and not was_grounded:
		landing_kick = clampf(maxf(-impact_velocity, -last_velocity.y) * 0.023, 0.06, 0.28)
		body_offset_velocity.y -= landing_kick * 5.0
		head_offset_velocity.y -= landing_kick * 6.5
		body_angular_velocity.x += landing_kick * 3.0
		for i in range(feet.size()):
			feet[i].swinging = false
			feet[i].heading = travel_yaw
			feet[i].age = 0.0
			_set_contact(feet[i], _ground(_neutral(i)))
	if not grounded and was_grounded:
		body_offset_velocity.y -= 0.36
		head_offset_velocity.y -= 0.65
		for f in feet: f.swinging = false
	if grounded:
		var stride_distance := lerpf(0.8, 3.2, sqrt(ratio))
		step_interval = clampf(stride_distance / maxf(0.25, speed) * 0.5, 0.14, 0.40)
		if moving:
			cycle = fposmod(cycle + dt / (step_interval * 2.0), 1.0)
			step_clock += dt
			if not was_moving: step_clock = step_interval
		else:
			step_clock = 0.0
		if moving: _guard_reach(horizontal)
		for i in range(feet.size()): _tick_foot(i, dt, moving, horizontal)
		if moving and step_clock >= step_interval and not _any_swing():
			_begin_swing(next_foot, horizontal, false)
			next_foot = 1 - next_foot
			step_clock = 0.0
		elif not moving and not _any_swing():
			# Finish a final small step rather than sliding both feet back to idle.
			for i in [next_foot, 1 - next_foot]:
				var f := feet[i]
				var difference := _neutral(i) - f.contact
				difference.y = 0.0
				if difference.length() > 0.13 or absf(wrapf(f.heading - travel_yaw, -PI, PI)) > 0.3:
					_begin_swing(i, Vector3.ZERO, true)
					next_foot = 1 - i
					break
	else:
		for i in range(feet.size()): _air_foot(i, dt)
	_update_body(dt, local_velocity, local_accel, grounded)
	was_grounded = grounded
	was_moving = moving
	last_velocity = velocity

func _neutral(index: int) -> Vector3:
	var f := feet[index]
	var rest_center := f.rest + f.sole_center
	return actor.global_position + Basis(Vector3.UP, travel_yaw) * rest_center

func _ground(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.65, point + Vector3.DOWN * 1.15)
	query.exclude = [actor.get_rid()]
	query.collision_mask = 1 # ground only; target hitboxes must not become foot supports
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit["normal"] as Vector3).y > 0.45:
		return hit
	# Unsupported edge: keep the foot near the body, never snap into a pit.
	return {"position": point, "normal": Vector3.UP}

func _set_contact(f: FootState, hit: Dictionary) -> void:
	f.contact = hit["position"]
	f.normal = hit["normal"]
	f.support = null
	var surface := hit.get("collider") as Node3D
	if surface != null:
		f.support = weakref(surface)
		f.support_local = surface.to_local(f.contact)

func _any_swing() -> bool:
	return feet[0].swinging or feet[1].swinging

func _guard_reach(horizontal: Vector3) -> void:
	# A sharp reversal can outpace the previously planned contact. Take a quick
	# recovery step instead of stretching a planted shoe far behind the character.
	for i in range(feet.size()):
		var foot := feet[i]
		if foot.swinging: continue
		var error := foot.contact - _neutral(i)
		error.y = 0.0
		if error.length() <= 1.10: continue
		var other := feet[1 - i]
		if other.swinging:
			other.duration = minf(other.duration, other.elapsed + 0.045)
		else:
			_begin_swing(i, horizontal, false)
			next_foot = 1 - i
			step_clock = 0.0
		return

func _begin_swing(index: int, horizontal: Vector3, settle: bool) -> void:
	var f := feet[index]
	f.swinging = true
	f.settle = settle
	f.elapsed = 0.0
	f.progress = 0.0
	f.duration = 0.19 if settle else step_interval * 0.86
	f.start = f.contact
	f.from_heading = f.heading
	f.lift = (0.11 if settle else lerpf(0.20, 0.38, clampf(speed / 11.0, 0, 1))) * rng.randf_range(0.92, 1.14)
	f.flourish = rng.randf_range(-0.22, 0.22) * playfulness
	f.toe_out = (1.0 if index == 0 else -1.0) * 0.055 + rng.randf_range(-0.04, 0.04) * playfulness
	f.goal = _ground(_neutral(index) + horizontal * (f.duration + step_interval * 0.54))["position"]
	f.phase = "TOE_OFF"
	f.step_id += 1
	step_count += 1

func _tick_foot(index: int, dt: float, moving: bool, horizontal: Vector3) -> void:
	var f := feet[index]
	var pitch_angle := 0.0
	var roll := 0.0
	var lift := 0.0
	if f.swinging:
		f.elapsed += dt
		f.progress = clampf(f.elapsed / f.duration, 0.0, 1.0)
		var p := f.progress
		if p < 0.87:
			var remaining := maxf(0, f.duration - f.elapsed)
			var lead := horizontal * (remaining + step_interval * 0.54) if moving and not f.settle else Vector3.ZERO
			var target := _ground(_neutral(index) + lead)
			f.goal = f.goal.lerp(target["position"], 1.0 - exp(-24.0 * dt))
			f.normal = target["normal"]
		# Clamp stale predictions on sudden turns/stops, including the final approach.
		var neutral := _neutral(index)
		var delta_goal := f.goal - neutral
		delta_goal.y = 0.0
		var reach := 1.05 + speed * maxf(0.0, f.duration - f.elapsed)
		if delta_goal.length() > reach:
			f.goal = _ground(neutral + delta_goal.normalized() * reach)["position"]
		var eased := p * p * (3.0 - 2.0 * p)
		f.contact = f.start.lerp(f.goal, eased)
		lift = sin(PI * p) * f.lift
		var outward := Basis(Vector3.UP, travel_yaw).x * (-1.0 if index == 0 else 1.0)
		f.contact += outward * sin(PI * p) * 0.055 * playfulness
		f.heading = lerp_angle(f.from_heading, travel_yaw + f.toe_out, eased)
		pitch_angle = _swing_pitch(p) + sin(time * 14.0 + index * 2.0) * 0.075 * sin(PI * p) * playfulness
		roll = f.flourish * sin(PI * p)
		f.phase = "PASSING" if p < 0.65 else "UP"
		if p >= 1.0:
			f.swinging = false
			f.age = 0.0
			_set_contact(f, _ground(f.goal))
			pitch_angle = 0.25
			lift = 0.0
			f.phase = "CONTACT"
			body_offset_velocity.y -= 0.14 * playfulness
			body_angular_velocity.z += (1.0 if index == 0 else -1.0) * 0.33 * playfulness
	else:
		f.age += dt
		if f.support != null:
			var platform := f.support.get_ref() as Node3D
			if is_instance_valid(platform): f.contact = platform.to_global(f.support_local)
		var stance := clampf(f.age / (step_interval * 1.14), 0, 1)
		pitch_angle = 0.25 * (1.0 - smoothstep(0.0, 0.32, stance))
		if moving: pitch_angle -= 0.32 * smoothstep(0.75, 1.0, stance)
		f.phase = "CONTACT" if stance < 0.17 else "DOWN" if stance < 0.55 else "SUPPORT"
	_apply_foot(f, pitch_angle, roll, lift)

func _swing_pitch(p: float) -> float:
	if p < 0.25: return lerpf(-0.32, -0.55, smoothstep(0, 0.25, p))
	if p < 0.68: return lerpf(-0.55, 0.32, smoothstep(0.25, 0.68, p))
	return lerpf(0.32, 0.25, smoothstep(0.68, 1, p))

func _apply_foot(f: FootState, pitch_angle: float, roll: float, lift: float) -> void:
	var front := Vector3(-sin(f.heading), 0, -cos(f.heading))
	front = (front - f.normal * front.dot(f.normal)).normalized()
	var right := front.cross(f.normal).normalized()
	var basis := Basis(right, f.normal, -front) * Basis.from_euler(Vector3(pitch_angle, 0, roll))
	var bottom := INF
	for point in f.corners: bottom = minf(bottom, f.normal.dot(basis * point))
	var center := basis * f.sole_center
	# A heel/toe roll may rotate the mesh, but cannot push the sole through its floor.
	var origin := f.contact - center + f.normal * (center.dot(f.normal) - bottom + lift + 0.012)
	f.node.global_transform = Transform3D(basis, origin)

func _air_foot(index: int, dt: float) -> void:
	var f := feet[index]
	f.phase = "AIR"
	var side := -1.0 if index == 0 else 1.0
	var flight := Basis(Vector3.UP, travel_yaw)
	var target := _neutral(index) + flight * Vector3(side * 0.09, 0.20 + (0.12 if index == 0 else 0.0), side * 0.24)
	f.contact = target
	f.heading = lerp_angle(f.heading, travel_yaw, 1.0 - exp(-10.0 * dt))
	f.normal = Vector3.UP
	var flutter := sin(time * 10.0 + index * 2.6) * 0.13 * playfulness
	var old := f.node.global_transform
	_apply_foot(f, side * 0.48 + flutter, side * 0.16 + flutter * 0.65, 0.0)
	var goal := f.node.global_transform
	f.node.global_transform = old.interpolate_with(goal, 1.0 - exp(-16.0 * dt))

func _noise(offset: float) -> float:
	return sin(time * 2.7 + noise_phase + offset) * 0.65 + sin(time * 4.13 + noise_phase * 1.7 + offset * 2.0) * 0.35

func _update_body(dt: float, local_velocity: Vector3, accel: Vector3, grounded: bool) -> void:
	var phase := cycle * TAU
	var amount := playfulness
	var facing := visual.global_rotation.y
	var raw_turn := clampf(wrapf(facing-last_visual_yaw,-PI,PI)/dt,-10.0,10.0)
	last_visual_yaw = facing
	turn_rate = lerpf(turn_rate,raw_turn,1.0-exp(-9.0*dt))
	# The upper mass follows the feet with weight, then lags behind body turns.
	# Translation and rotation have different springs; the torso is not welded to the head.
	var bob := -cos(phase*2.0-0.45)*0.105*move_blend
	var weight_shift := sin(phase)*0.105*move_blend
	var idle := sin(time*2.15)*0.034*(1.0-move_blend)
	var target_pos := Vector3(weight_shift,bob+idle-landing_kick,0)
	target_pos += Vector3(-accel.x,0,-accel.z)*0.0018
	target_pos += Vector3(_noise(0)*0.031,_noise(2)*0.023,_noise(4)*0.026)*amount
	var target_rot := Vector3(
		clampf(local_velocity.z*0.022-accel.z*0.005,-0.28,0.28),
		sin(phase+0.55)*0.20*move_blend-turn_rate*0.060,
		clampf(-local_velocity.x*0.026+accel.x*0.004,-0.27,0.27))
	target_rot.z += sin(phase)*0.16*move_blend*amount
	target_rot += Vector3(_noise(1)*0.046,_noise(3)*0.058,_noise(5)*0.075)*amount
	if not grounded:
		target_rot.x += clampf(-velocity.y*0.032,-0.25,0.25)
		target_rot.y += sin(time*4.5)*0.10*amount
	var head_target := Vector3(-accel.x*0.002,bob*1.15+idle*1.6-landing_kick*0.90,-accel.z*0.002)
	head_target += Vector3(_noise(8)*0.04,_noise(9)*0.03,_noise(10)*0.03)*amount
	head_target = head_target.clamp(Vector3(-0.14,-0.20,-0.14),Vector3(0.14,0.23,0.14))
	var steps := maxi(1,int(ceil(dt*120.0)))
	var h := dt/float(steps)
	for unused in range(steps):
		body_angular_velocity += ((target_rot-body_rotation)*Vector3(72,58,68)-body_angular_velocity*Vector3(7.8,6.8,7.2))*h
		body_rotation += body_angular_velocity*h
		body_offset_velocity += ((target_pos-body_offset)*140.0-body_offset_velocity*13.0)*h
		body_offset += body_offset_velocity*h
		head_offset_velocity += ((head_target-head_offset)*105.0-head_offset_velocity*10.0)*h
		head_offset += head_offset_velocity*h
	body_rotation = body_rotation.clamp(Vector3(-0.42,-0.42,-0.42),Vector3(0.42,0.42,0.42))
	body_offset = body_offset.clamp(Vector3(-0.18,-0.26,-0.16),Vector3(0.18,0.20,0.16))
	head_offset = head_offset.clamp(Vector3(-0.15,-0.22,-0.15),Vector3(0.15,0.25,0.15))
	torso.position = torso_rest+body_offset
	torso.rotation = body_rotation
	head.position = head_rest+head_offset
	# Preserve a readable floating neck gap even when the two springs move oppositely.
	head.position.y = maxf(head.position.y,torso.position.y+1.38)
	secondary_head = Vector3(-body_rotation.x*0.38+_noise(11)*0.04,_noise(13)*0.03,-body_rotation.z*0.64+_noise(12)*0.14)
	secondary_head.z += sin(phase+1.0)*0.12*move_blend
	secondary_head *= amount
