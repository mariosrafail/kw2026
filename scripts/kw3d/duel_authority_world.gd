extends "res://scripts/kw3d/authority_world.gd"
## LAN duel authority. Keeps the co-op proof untouched and reuses its fixed-step combat.
const DUEL_ACTOR = preload("res://scripts/kw3d/authority_actor.gd")
const DUEL_MOTOR = preload("res://scripts/kw3d/actor_motor.gd")
const FRAG_LIMIT = 10
const RESPAWN_SECONDS = 2.0

var ready_state: Dictionary = {}
var host_id = 0
var winner_id = 0

func _ready() -> void:
	super._ready()
	wave = 0
	wave_budget = 0
	wave_spawned = 0
	phase = "LOBBY"
	attacks_enabled = false
	round_live = false

func _spawn_for_slot(id: int) -> Vector3:
	return Vector3(-6.0, 2.2, 8.0) if id % 2 == 1 else Vector3(6.0, 2.2, -18.0)

func _reset_actor_for_match(a: Node3D) -> void:
	a.health = 100.0
	a.damage_grace = 0.0
	a.kills = 0
	a.death_clock = 0.0
	a.global_position = _spawn_for_slot(a.actor_id)
	a.velocity = Vector3.ZERO
	a.collision_layer = 2
	a.hit_body.collision_layer = 4
	a.command = DUEL_MOTOR.empty(a.aim_yaw, a.aim_pitch)
	a.input_queue.clear()
	a.input_started = false
	a.input_wait = 0
	a.fire_clock = 0.0
	a.grenade_clock = 0.0
	a.locomotion.reset()
	a.update_shapes()

func add_player(id: int) -> void:
	if actors.has(id):
		var existing: Node3D = actors[id]
		existing.connected = true
		ready_state[id] = false
		emit("room", {"room": room_packet()})
		return
	var a = DUEL_ACTOR.new()
	add_child(a)
	a.position = _spawn_for_slot(id)
	a.configure(id, false, data.profiles.outrage, "outrage")
	a.hit_body.collision_layer = 4
	actors[id] = a
	ready_state[id] = false
	if host_id == 0:
		host_id = id
	emit("join", {"actor": id})
	emit("room", {"room": room_packet()})

func detach_player(id: int) -> void:
	super.detach_player(id)
	ready_state[id] = false
	emit("room", {"room": room_packet()})

func remove_player(id: int) -> void:
	super.remove_player(id)
	ready_state.erase(id)
	if host_id == id:
		host_id = 0
		var ids = _connected_human_ids()
		if not ids.is_empty():
			host_id = ids[0]
	if phase != "MATCH":
		phase = "LOBBY"
		winner_id = 0
	emit("room", {"room": room_packet()})

func _connected_human_ids() -> Array[int]:
	var ids: Array[int] = []
	for key in actors.keys():
		var a: Node3D = actors[key]
		if not a.is_bot and a.connected:
			ids.append(int(key))
	ids.sort()
	return ids

func set_ready(id: int, value: bool) -> bool:
	if phase == "MATCH" or not actors.has(id) or actors[id].is_bot or not actors[id].connected:
		return false
	ready_state[id] = value
	emit("room", {"room": room_packet()})
	return true

func can_start() -> bool:
	var ids = _connected_human_ids()
	if ids.size() != 2:
		return false
	for id in ids:
		if not bool(ready_state.get(id, false)):
			return false
	return true

func start_match(requester: int) -> bool:
	if requester != host_id or not can_start():
		return false
	winner_id = 0
	phase = "MATCH"
	round_live = true
	for id in _connected_human_ids():
		ready_state[id] = false
		_reset_actor_for_match(actors[id])
	emit("match_start", {"room": room_packet()})
	return true

func room_packet() -> Dictionary:
	var players: Array = []
	for id in _connected_human_ids():
		var a: Node3D = actors[id]
		players.append({
			"id": id,
			"name": "OUTRAGE %d" % id,
			"ready": bool(ready_state.get(id, false)),
			"kills": a.kills,
			"hp": a.health
		})
	return {
		"phase": phase,
		"host": host_id,
		"players": players,
		"frag_limit": FRAG_LIMIT,
		"winner": winner_id
	}

func begin_wave(_n: int) -> void:
	pass

func alive_bots() -> int:
	return 0

func step() -> void:
	if phase != "MATCH":
		var started = Time.get_ticks_usec()
		tick_id += 1
		for id in actors.keys():
			var a: Node3D = actors[id]
			if a.is_bot:
				continue
			if not a.input_queue.is_empty():
				var sequences: Array = a.input_queue.keys()
				sequences.sort()
				var latest: Dictionary = a.input_queue[sequences[-1]]
				a.ack = int(sequences[-1])
				a.last_jump_serial = maxi(a.last_jump_serial,int(latest.get("js",a.last_jump_serial)))
				a.last_grenade_serial = maxi(a.last_grenade_serial,int(latest.get("gs",a.last_grenade_serial)))
				a.input_queue.clear()
			a.velocity = Vector3.ZERO
			a.command = DUEL_MOTOR.empty(a.aim_yaw, a.aim_pitch)
			a.tick(DT)
		metrics.max_tick_usec = maxi(metrics.max_tick_usec, Time.get_ticks_usec() - started)
		metrics.ticks = tick_id
		return
	super.step()
	for id in _connected_human_ids():
		var a: Node3D = actors[id]
		if a.health <= 0.0 and a.death_clock >= RESPAWN_SECONDS:
			respawn(id)

func respawn(id: int) -> bool:
	if phase != "MATCH" or not actors.has(id):
		return false
	var a: Node3D = actors[id]
	if a.health > 0.0 or a.death_clock < RESPAWN_SECONDS:
		return false
	a.health = 100.0
	a.death_clock = 0.0
	a.global_position = _spawn_for_slot(id)
	a.collision_layer = 2
	a.hit_body.collision_layer = 4
	a.velocity = Vector3.ZERO
	a.command = DUEL_MOTOR.empty(a.aim_yaw, a.aim_pitch)
	a.input_queue.clear()
	a.input_started = false
	a.locomotion.reset()
	a.update_shapes()
	emit("respawn", {"actor": id, "hp": 100.0})
	return true

func damage(victim: int, amount: float, direction: Vector3, owner: int, point: Vector3) -> bool:
	if phase != "MATCH" or not actors.has(victim) or amount <= 0.0:
		return false
	if owner <= 0 or owner == victim or not actors.has(owner):
		return false
	var target: Node3D = actors[victim]
	if target.is_bot or target.health <= 0.0 or target.damage_grace > 0.0:
		return false
	target.hurt(amount, direction)
	target.damage_grace = 0.06
	damage_count += 1
	emit("damage", {
		"actor": victim,
		"owner": owner,
		"amount": amount,
		"hp": target.health,
		"p": point,
		"dir": direction,
		"lethal": target.health <= 0.0
	})
	if target.health <= 0.0:
		kill_count += 1
		var killer: Node3D = actors[owner]
		killer.kills += 1
		emit("kill", {
			"actor": victim,
			"owner": owner,
			"kills": killer.kills,
			"hp": killer.health,
			"heal": 0.0
		})
		if killer.kills >= FRAG_LIMIT:
			winner_id = owner
			phase = "RESULT"
			round_live = false
			for id in _connected_human_ids():
				actors[id].command = DUEL_MOTOR.empty(actors[id].aim_yaw, actors[id].aim_pitch)
				actors[id].velocity = Vector3.ZERO
			emit("match_over", {"winner": winner_id, "room": room_packet()})
	return true

func explode(point: Vector3, owner: int, gid: int) -> void:
	if phase != "MATCH" or explosion_ids.has(gid):
		return
	explosion_ids[gid] = true
	if explosion_ids.size() > 256:
		explosion_ids.erase(explosion_ids.keys()[0])
	var origin = point + Vector3.UP * 0.12
	emit("explosion", {"p": origin, "id": gid, "owner": owner})
	for id in _connected_human_ids():
		if id == owner:
			continue
		var target: Node3D = actors[id]
		if target.health <= 0.0:
			continue
		var center: Vector3 = target.rigs.TorsoRig.global_position + target.rigs.TorsoRig.global_basis * Vector3(0, 0.35, 0)
		var head: Vector3 = target.rigs.HeadRig.global_position
		var distance = center.distance_to(origin)
		if distance > 5.5:
			continue
		if not ray(origin, center, 1).is_empty() and not ray(origin, head, 1).is_empty():
			continue
		var amount = roundf(lerpf(110.0, 35.0, clampf((distance - 1.4) / 4.1, 0.0, 1.0)))
		damage(id, amount, (center - origin).normalized(), owner, center)

func snapshot() -> Dictionary:
	var result: Dictionary = super.snapshot()
	result["wave"] = 0
	result["remaining"] = 0
	result["room"] = room_packet()
	return result
