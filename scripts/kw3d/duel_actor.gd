extends "res://scripts/kw3d/authority_actor.gd"
const RULES := preload("res://scripts/kw3d/duel_rules.gd")
const ARENA := preload("res://scripts/kw3d/duel_arena.gd")

var hero_id := RULES.OUTRAGE
var max_health := 100.0
var augments: Dictionary = {}
var skill_charges := 1
var skill_max_charges := 1
var skill_recharge := 0.0
var guard_time := 0.0
var haste_time := 0.0
var vamp_lock := 0.0
var duel_ai := false
var duel_has_aim_point := false
var duel_aim_point := Vector3.ZERO
const ROUND_AIM_PITCH := -0.174533

func setup_duel(hero: String) -> void:
	hero_id = hero
	skin = hero
	refresh_build()
	skill_charges = skill_max_charges

func add_augment(id: String) -> void:
	augments[id] = int(augments.get(id,0)) + 1
	refresh_build()

func has_augment(id: String) -> bool:
	return RULES.has(augments,id)

func augment_count(id: String) -> int:
	return RULES.count(augments,id)

func refresh_build() -> void:
	max_health = 80.0 if has_augment("glass_cannon") else 100.0
	skill_max_charges = 2 if has_augment("second_charge") else 1
	skill_charges = mini(skill_charges,skill_max_charges)
	health = minf(health,max_health)

func reset_for_round(spawn: Vector3, facing: float) -> void:
	refresh_build()
	health = max_health
	damage_grace = 0.0
	death_clock = 0.0
	global_position = spawn
	velocity = Vector3.ZERO
	aim_yaw = facing
	aim_pitch = ROUND_AIM_PITCH
	body_yaw = facing
	command = MOTOR.empty(aim_yaw,aim_pitch)
	input_queue.clear()
	input_started = false
	input_wait = 0
	fire_clock = 0.0
	reset_magazine()
	grenade_clock = 0.0
	guard_time = 0.0
	haste_time = 0.0
	vamp_lock = 0.0
	skill_charges = skill_max_charges
	skill_recharge = 0.0
	duel_has_aim_point = false
	head_rotation = Vector3.ZERO
	head_velocity = Vector3.ZERO
	recoil = Vector3.ZERO
	recoil_velocity = Vector3.ZERO
	camera_fraction = 1.0
	smoothed_weapon_side = 1.0
	locomotion.reset()
	collision_layer = 2
	collision_mask = 9
	if hit_body != null:
		hit_body.collision_layer = 4
		hit_body.collision_mask = 0
	update_shapes()

func set_duel_aim_point(point: Vector3) -> void:
	duel_aim_point = point
	duel_has_aim_point = true

func clear_duel_aim_point() -> void:
	duel_has_aim_point = false

func build_aim(space: PhysicsDirectSpaceState3D,dt: float) -> void:
	if not duel_ai or not duel_has_aim_point:
		super.build_aim(space,dt)
		return
	# Duel AI already has an authoritative world-space target. Do not route its
	# shot through the human right-shoulder camera, otherwise the 1.2 m camera
	# offset makes an apparently correct bot fire a parallel line beside the rival.
	aim_target = duel_aim_point
	var anchor: Vector3 = global_position+Vector3(0,1.05,0)
	camera_direction = (aim_target-anchor).normalized()
	camera_origin = anchor
	var chest: Vector3 = weapon_anchor()
	var front: Vector3 = (aim_target-chest).normalized()
	if front.length_squared()<0.0001:
		front = -visual.global_basis.z
	var right: Vector3 = front.cross(Vector3.UP).normalized()
	if right.length_squared()<0.01:
		right = visual.global_basis.x.normalized()
	smoothed_weapon_side = move_toward(smoothed_weapon_side,1.0,maxf(0.0,dt)*10.0)
	var pivot: Vector3 = chest+front*0.64+right*smoothed_weapon_side
	var distance: float = pivot.distance_to(aim_target)
	var muzzle_length: float=1.58 if weapon_slot==0 else 1.78 if weapon_slot==1 else 2.08 if weapon_slot==2 else 1.88
	var m: Vector3 = Vector3(0.10,0.02,-muzzle_length+maxf(0.0,1.92-distance))
	var local_target: Vector3 = Vector3(m.x,m.y,-sqrt(maxf(0.00001,distance*distance-m.x*m.x-m.y*m.y))).normalized()
	var gun_basis: Basis = Basis.looking_at(aim_target-pivot,Vector3.UP)*Basis(Quaternion(local_target,Vector3.FORWARD))
	muzzle = pivot+gun_basis*m

func skill_cooldown() -> float:
	var value := RULES.skill_base_cooldown(hero_id)
	if has_augment("overclock"):
		value *= 1.25
	return value

func consume_skill() -> bool:
	if health <= 0.0 or skill_charges <= 0:
		return false
	skill_charges -= 1
	if skill_charges < skill_max_charges and skill_recharge <= 0.0:
		skill_recharge = skill_cooldown()
	return true

func refill_skill() -> void:
	skill_charges = skill_max_charges
	skill_recharge = 0.0

func reduce_skill_recharge(seconds: float) -> void:
	if skill_charges < skill_max_charges:
		skill_recharge = maxf(0.0,skill_recharge-seconds)

func apply_duel_push(direction: Vector3, distance: float) -> void:
	var scale := 0.68 if hero_id == RULES.EREBUS else 1.0
	if has_augment("grounded"):
		scale *= 0.55
	var flat := Vector3(direction.x,0.0,direction.z)
	if flat.length_squared() > 0.001:
		move_and_collide(flat.normalized()*distance*scale)

func tick(dt: float) -> void:
	guard_time = maxf(0.0,guard_time-dt)
	haste_time = maxf(0.0,haste_time-dt)
	vamp_lock = maxf(0.0,vamp_lock-dt)
	if skill_charges < skill_max_charges:
		var recharge_rate := 1.0
		if has_augment("last_stand") and health <= max_health*0.30:
			recharge_rate = 1.30
		skill_recharge = maxf(0.0,skill_recharge-dt*recharge_rate)
		if skill_recharge <= 0.0:
			skill_charges += 1
			if skill_charges < skill_max_charges:
				skill_recharge = skill_cooldown()
	var speed := 1.0
	if haste_time > 0.0:
		speed *= 1.20
	if has_augment("grounded"):
		speed *= 0.93
	if has_augment("air_control") and not is_on_floor():
		speed *= 1.18
	if has_augment("last_stand") and health <= max_health*0.30:
		speed *= 1.15
	command["speed_multiplier"] = speed
	super.tick(dt)
	command.erase("speed_multiplier")
	if health > 0.0:
		ARENA.apply_jump_pad(self)

func packet() -> Dictionary:
	var result: Dictionary = super.packet()
	result["hero"] = hero_id
	result["skin"] = hero_id
	result["max_hp"] = max_health
	result["skill_charges"] = skill_charges
	result["skill_max"] = skill_max_charges
	result["skill_cd"] = skill_recharge
	result["guard"] = guard_time
	result["haste"] = haste_time
	result["augments"] = augments.duplicate()
	return result

func network_record(owner: bool) -> Array:
	var result: Array=super.network_record(owner)
	result[2]=hero_id
	result[22]=[hero_id,max_health,skill_charges,skill_max_charges,guard_time,haste_time,augments.duplicate()]
	if owner and (result[21] as Array).size()>=5:(result[21] as Array)[4]=skill_recharge
	return result
