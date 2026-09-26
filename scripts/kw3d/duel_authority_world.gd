extends "res://scripts/kw3d/authority_world.gd"
## Server-authoritative Overdrive Duel: Outrage vs Erebus.
const BASE_LEVEL := preload("res://scripts/kw3d/online_level.gd")
const DUEL_ACTOR := preload("res://scripts/kw3d/duel_actor.gd")
const RULES := preload("res://scripts/kw3d/duel_rules.gd")
const ARENA := preload("res://scripts/kw3d/duel_arena.gd")
const DUEL_MOTOR := preload("res://scripts/kw3d/actor_motor.gd")

var ready_state: Dictionary = {}
var host_id := 0
var winner_id := 0
var round_phase := "LOBBY"
var round_number := 0
var round_scores: Dictionary = {}
var countdown_left := 0.0
var fight_time := 0.0
var core_delay := RULES.CORE_DELAY
var core_live_left := 0.0
var core_available := false
var overload := false
var overload_clock := 0.0
var reveal_clock := 0.0
var draft_pool: Array[String] = []
var draft_order: Array[int] = []
var draft_cursor := 0
var echoes: Array[Dictionary] = []
var grenade_context_owner := 0
var grenade_scale := 1.0

func max_players() -> int:
	return 2

func _ready() -> void:
	data = BASE_LEVEL.read()
	ARENA.build_physics(self)
	rng.seed = 991337
	match_id = Crypto.new().generate_random_bytes(12).hex_encode()
	wave = 0
	wave_budget = 0
	wave_spawned = 0
	phase = "LOBBY"
	round_phase = "LOBBY"
	attacks_enabled = false
	round_live = false

func _connected_human_ids() -> Array[int]:
	var ids: Array[int] = []
	for key in actors.keys():
		var a: Node3D = actors[key]
		if not a.is_bot and a.connected:
			ids.append(int(key))
	ids.sort()
	return ids

func _hero_for_new_player() -> String:
	return RULES.OUTRAGE if _connected_human_ids().is_empty() else RULES.EREBUS

func _spawn_for(id: int) -> Vector3:
	var ids := _connected_human_ids()
	var index := ids.find(id)
	if index < 0:index = 0 if id % 2 == 1 else 1
	return ARENA.spawn_for_index(clampi(index,0,1))

func _facing_for(id: int) -> float:
	# Godot forward is -Z. South spawn looks north; north spawn looks south.
	return 0.0 if _spawn_for(id).z > 0.0 else PI

func add_player(id: int) -> void:
	if actors.has(id):
		var existing: Node3D = actors[id]
		existing.connected = true
		ready_state[id] = false
		emit("room",{"room":room_packet()})
		return
	var hero := _hero_for_new_player()
	var a := DUEL_ACTOR.new()
	add_child(a)
	a.configure(id,false,data.profiles.outrage,hero)
	a.setup_duel(hero)
	a.global_position = ARENA.spawn_for_index(0 if hero == RULES.OUTRAGE else 1)
	a.hit_body.collision_layer = 4
	actors[id] = a
	ready_state[id] = false
	round_scores[id] = 0
	if host_id == 0:host_id = id
	emit("join",{"actor":id,"hero":hero})
	emit("room",{"room":room_packet()})

func detach_player(id: int) -> void:
	super.detach_player(id)
	ready_state[id] = false
	emit("room",{"room":room_packet()})

func remove_player(id: int) -> void:
	super.remove_player(id)
	ready_state.erase(id)
	round_scores.erase(id)
	if host_id == id:
		host_id = 0
		var ids := _connected_human_ids()
		if not ids.is_empty():host_id = ids[0]
	if phase != "MATCH":
		phase = "LOBBY"
		round_phase = "LOBBY"
		winner_id = 0
	emit("room",{"room":room_packet()})

func set_ready(id: int,value: bool) -> bool:
	if phase == "MATCH" or not actors.has(id) or actors[id].is_bot or not actors[id].connected:
		return false
	ready_state[id] = value
	emit("room",{"room":room_packet()})
	return true

func can_start() -> bool:
	var ids := _connected_human_ids()
	if ids.size() != 2:return false
	for id in ids:
		if not bool(ready_state.get(id,false)):return false
	return true

func start_match(requester: int) -> bool:
	if phase not in ["LOBBY","RESULT"]:return false
	if requester != host_id or not can_start():return false
	winner_id = 0
	phase = "MATCH"
	round_number = 1
	for id in _connected_human_ids():
		ready_state[id] = false
		round_scores[id] = 0
		var a: Node3D = actors[id]
		a.kills = 0
		a.augments.clear()
		a.refresh_build()
	_begin_round()
	emit("match_start",{"room":room_packet()})
	return true

func _begin_round() -> void:
	round_phase = "COUNTDOWN"
	countdown_left = RULES.COUNTDOWN_SECONDS
	fight_time = 0.0
	core_delay = RULES.CORE_DELAY
	core_live_left = 0.0
	core_available = false
	overload = false
	overload_clock = 0.0
	reveal_clock = 0.0
	echoes.clear()
	draft_pool.clear()
	draft_order.clear()
	draft_cursor = 0
	var ids := _connected_human_ids()
	for index in range(ids.size()):
		var a: Node3D = actors[ids[index]]
		a.reset_for_round(ARENA.spawn_for_index(index),_facing_for(ids[index]))
	emit("round_prepare",{"round":round_number,"room":room_packet()})

func _player_packet(id: int) -> Dictionary:
	var a: Node3D = actors[id]
	return {
		"id":id,
		"name":str(a.display_name),
		"hero":a.hero_id,
		"ready":bool(ready_state.get(id,false)),
		"rounds":int(round_scores.get(id,0)),
		"kills":a.kills,
		"hp":a.health,
		"max_hp":a.max_health,
		"augments":a.augments.duplicate(),
		"skill_charges":a.skill_charges,
		"skill_max":a.skill_max_charges,
		"skill_cd":a.skill_recharge
	}

func room_packet() -> Dictionary:
	var players: Array = []
	for id in _connected_human_ids():players.append(_player_packet(id))
	var chooser := draft_order[draft_cursor] if draft_cursor < draft_order.size() else 0
	return {
		"phase":phase,
		"round_phase":round_phase,
		"host":host_id,
		"players":players,
		"round":round_number,
		"round_target":RULES.ROUND_TARGET,
		"winner":winner_id,
		"countdown":maxf(0.0,countdown_left),
		"fight_time":fight_time,
		"overload":overload,
		"core_available":core_available,
		"core_delay":maxf(0.0,core_delay),
		"core_live":maxf(0.0,core_live_left),
		"draft_pool":draft_pool.duplicate(),
		"draft_order":draft_order.duplicate(),
		"draft_cursor":draft_cursor,
		"draft_chooser":chooser
	}

func begin_wave(_n: int) -> void:pass
func alive_bots() -> int:return 0
func respawn(_id: int) -> bool:return false

func _freeze_step() -> void:
	var started := Time.get_ticks_usec()
	tick_id += 1
	for id in actors.keys():
		var a: Node3D = actors[id]
		if a.is_bot:continue
		if not a.input_queue.is_empty():
			var sequences: Array = a.input_queue.keys()
			sequences.sort()
			var latest: Dictionary = a.input_queue[sequences[-1]]
			a.ack = int(sequences[-1])
			a.last_jump_serial = maxi(a.last_jump_serial,int(latest.get("js",a.last_jump_serial)))
			a.last_grenade_serial = maxi(a.last_grenade_serial,int(latest.get("gs",a.last_grenade_serial)))
			a.input_queue.clear()
		a.velocity = Vector3.ZERO
		a.command = DUEL_MOTOR.empty(a.aim_yaw,a.aim_pitch)
	metrics.max_tick_usec = maxi(metrics.max_tick_usec,Time.get_ticks_usec()-started)
	metrics.ticks = tick_id

func step() -> void:
	if phase != "MATCH":
		_freeze_step()
		return
	if round_phase == "COUNTDOWN":
		_freeze_step()
		countdown_left -= DT
		if countdown_left <= 0.0:
			round_phase = "FIGHT"
			round_live = true
			emit("round_start",{"round":round_number,"room":room_packet()})
		return
	if round_phase == "DRAFT":
		_freeze_step()
		return
	super.step()
	if round_phase in ["FIGHT","OVERLOAD"]:
		for id in _connected_human_ids():
			if actors[id].health <= 0.0:
				_finish_round(_other_player(id),id)
				return
		_tick_round_runtime()
		_tick_echoes()

func _tick_round_runtime() -> void:
	fight_time += DT
	if not overload and fight_time >= RULES.OVERLOAD_AT:
		overload = true
		round_phase = "OVERLOAD"
		overload_clock = 1.0
		reveal_clock = 0.2
		emit("overload",{"round":round_number})
	if core_available:
		core_live_left -= DT
		for id in _connected_human_ids():
			var a: Node3D = actors[id]
			if a.health > 0.0 and a.global_position.distance_to(ARENA.CORE_POSITION) <= RULES.CORE_RADIUS:
				a.refill_skill()
				core_available = false
				core_live_left = 0.0
				core_delay = RULES.CORE_DELAY
				emit("core_claim",{"actor":id,"hero":a.hero_id})
				break
		if core_available and core_live_left <= 0.0:
			core_available = false
			core_delay = RULES.CORE_DELAY
			emit("core_expired",{})
	else:
		core_delay -= DT
		if core_delay <= 0.0:
			core_available = true
			core_live_left = RULES.CORE_WINDOW
			emit("core_online",{"seconds":RULES.CORE_WINDOW})
	if overload:
		overload_clock -= DT
		reveal_clock -= DT
		if reveal_clock <= 0.0:
			reveal_clock = 5.0
			emit("reveal",{})
		if overload_clock <= 0.0:
			overload_clock = 1.0
			for id in _connected_human_ids():
				var a: Node3D = actors[id]
				if a.health > 0.0 and Vector2(a.global_position.x,a.global_position.z).length() > 11.5:
					_environment_damage(id,6.0)

func _environment_damage(victim: int,amount: float) -> void:
	if not actors.has(victim):return
	var target: Node3D = actors[victim]
	if target.health <= 0.0:return
	target.hurt(amount,Vector3.ZERO)
	damage_count += 1
	emit("damage",{"actor":victim,"owner":0,"amount":amount,"hp":target.health,"p":target.global_position+Vector3.UP,"dir":Vector3.ZERO,"headshot":false,"weapon":"overload","lethal":target.health<=0.0})
	if target.health <= 0.0:
		var other := _other_player(victim)
		_finish_round(other,victim)

func _other_player(id: int) -> int:
	for other in _connected_human_ids():
		if other != id:return other
	return 0

func _shoot(a: Node3D) -> void:
	super._shoot(a)
	if a.has_augment("heavy_rounds"):a.fire_clock *= 1.20
	if a.has_augment("feather_trigger"):a.fire_clock *= 0.72

func use_skill(id: int) -> bool:
	if phase != "MATCH" or round_phase not in ["FIGHT","OVERLOAD"] or not actors.has(id):return false
	var a: Node3D = actors[id]
	if not a.consume_skill():return false
	if a.hero_id == RULES.OUTRAGE:
		var move: Vector2 = a.command.get("move",Vector2.ZERO)
		var direction := Basis(Vector3.UP,a.aim_yaw)*Vector3(move.x,0,-move.y)
		if direction.length_squared() < 0.04:direction = -Basis(Vector3.UP,a.aim_yaw).z
		direction.y = 0.0
		direction = direction.normalized()
		var start := a.global_position
		var distance := 5.0 if a.has_augment("overclock") else 4.2
		a.move_and_collide(direction*distance)
		a.velocity.x = direction.x*10.0
		a.velocity.z = direction.z*10.0
		emit("skill",{"actor":id,"hero":a.hero_id,"skill":"blast_step","from":start,"to":a.global_position,"afterimage":a.has_augment("afterimage")})
		var other := _other_player(id)
		if a.has_augment("ram") and actors.has(other):
			var rival: Node3D = actors[other]
			if rival.health > 0.0 and rival.global_position.distance_to(a.global_position) < 2.35:
				rival.apply_duel_push(direction,2.8)
				emit("ram_hit",{"actor":id,"target":other,"p":rival.global_position})
	else:
		var guard_bonus := 0.25 if a.has_augment("phase_guard") else 0.0
		a.guard_time = (1.10 if a.has_augment("overclock") else 0.85)+guard_bonus
		a.damage_grace = maxf(a.damage_grace,a.guard_time)
		var other := _other_player(id)
		if actors.has(other):
			var rival: Node3D = actors[other]
			var offset := rival.global_position-a.global_position
			if offset.length() <= 4.5:
				rival.apply_duel_push(offset,3.8 if a.has_augment("void_anchor") else 2.1)
		emit("skill",{"actor":id,"hero":a.hero_id,"skill":"void_guard","duration":a.guard_time})
	return true

func _draft_cards() -> Array[String]:
	var pool: Array[String] = []
	for card_id in RULES.CARD_ORDER:pool.append(str(card_id))
	for i in range(pool.size()-1,0,-1):
		var j := rng.randi_range(0,i)
		var tmp: String = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var result: Array[String] = []
	for index in range(mini(4,pool.size())):result.append(pool[index])
	return result

func _finish_round(winner: int,loser: int) -> void:
	if phase != "MATCH" or round_phase not in ["FIGHT","OVERLOAD"]:return
	round_live = false
	if winner > 0 and round_scores.has(winner):round_scores[winner] = int(round_scores[winner])+1
	emit("round_over",{"winner":winner,"loser":loser,"round":round_number,"room":room_packet()})
	if winner > 0 and int(round_scores.get(winner,0)) >= RULES.ROUND_TARGET:
		winner_id = winner
		phase = "RESULT"
		round_phase = "RESULT"
		for id in _connected_human_ids():
			actors[id].command = DUEL_MOTOR.empty(actors[id].aim_yaw,actors[id].aim_pitch)
			actors[id].velocity = Vector3.ZERO
		emit("match_over",{"winner":winner_id,"room":room_packet()})
		return
	round_phase = "DRAFT"
	draft_pool = _draft_cards()
	draft_order = [loser,winner]
	draft_cursor = 0
	emit("draft_start",{"pool":draft_pool.duplicate(),"order":draft_order.duplicate(),"room":room_packet()})

func choose_augment(id: int,card_id: String) -> bool:
	if phase != "MATCH" or round_phase != "DRAFT" or draft_cursor >= draft_order.size():return false
	if draft_order[draft_cursor] != id or card_id not in draft_pool or not actors.has(id):return false
	var a: Node3D = actors[id]
	var mapped := RULES.mapped_augment(card_id,a.hero_id)
	a.add_augment(mapped)
	draft_pool.erase(card_id)
	draft_cursor += 1
	emit("augment_pick",{"actor":id,"hero":a.hero_id,"card":card_id,"augment":mapped,"room":room_packet()})
	if draft_cursor >= draft_order.size():
		round_number += 1
		_begin_round()
	return true
func damage(victim: int,amount: float,direction: Vector3,owner: int,point: Vector3,headshot: bool=false,weapon: String="") -> bool:
	if phase != "MATCH" or round_phase not in ["FIGHT","OVERLOAD"] or not actors.has(victim) or amount <= 0.0:return false
	if owner <= 0 or owner == victim or not actors.has(owner):return false
	var target: Node3D = actors[victim]
	if target.is_bot or target.health <= 0.0 or target.damage_grace > 0.0:return false
	target.hurt(amount,direction)
	target.damage_grace = 0.06
	damage_count += 1
	emit("damage",{"actor":victim,"owner":owner,"amount":amount,"hp":target.health,"p":point,"dir":direction,"headshot":headshot,"weapon":weapon,"lethal":target.health<=0.0})
	if target.health <= 0.0:
		kill_count += 1
		var killer: Node3D = actors[owner]
		killer.kills += 1
		emit("kill",{
			"actor":victim,"owner":owner,"kills":killer.kills,"hp":killer.health,"heal":0.0,
			"weapon":weapon,"headshot":headshot,
			"killer_name":str(killer.display_name),"victim_name":str(target.display_name)
		})
	return true

func emit(kind: String,payload: Dictionary) -> void:
	if kind == "damage":
		var owner := int(payload.get("owner",0))
		var victim := int(payload.get("actor",0))
		if owner > 0 and owner != victim and actors.has(owner) and actors.has(victim):
			var attacker: Node3D = actors[owner]
			var target: Node3D = actors[victim]
			var original := float(payload.get("amount",0.0))
			var mult := 1.0
			if attacker.has_augment("heavy_rounds"):mult *= 1.25
			if attacker.has_augment("feather_trigger"):mult *= 0.85
			if attacker.has_augment("glass_cannon"):mult *= 1.20
			if grenade_context_owner == owner:
				mult *= grenade_scale
				if attacker.has_augment("rubber_grenade"):mult *= 0.55
			var adjusted := original*mult
			var delta := adjusted-original
			var direction: Vector3 = payload.get("dir",Vector3.ZERO)
			if delta > 0.001:
				target.hurt(delta,direction)
			elif delta < -0.001:
				target.health = minf(target.max_health,target.health-delta)
			payload["amount"] = adjusted
			payload["hp"] = target.health
			payload["lethal"] = target.health <= 0.0
			if attacker.hero_id == RULES.OUTRAGE:
				attacker.reduce_skill_recharge(0.45 if attacker.has_augment("afterimage") else 0.25)
			if attacker.has_augment("quick_feet"):attacker.haste_time = 1.25
			if attacker.has_augment("vamp_shot") and attacker.vamp_lock <= 0.0:
				attacker.health = minf(attacker.max_health,attacker.health+10.0)
				attacker.vamp_lock = 8.0
	super.emit(kind,payload)

func explode(point: Vector3,owner: int,gid: int,_radius: float=5.5,_max_damage: float=110.0,_min_damage: float=35.0,_kind: String="skill") -> void:
	_explode_duel(point,owner,gid,true,1.0)

func _explode_duel(point: Vector3,owner: int,gid: int,allow_echo: bool,power: float) -> void:
	if phase != "MATCH" or round_phase not in ["FIGHT","OVERLOAD"] or explosion_ids.has(gid):return
	explosion_ids[gid] = true
	if explosion_ids.size() > 256:explosion_ids.erase(explosion_ids.keys()[0])
	grenade_context_owner = owner
	grenade_scale = power
	var origin := point+Vector3.UP*0.12
	emit("explosion",{"p":origin,"id":gid,"owner":owner,"echo":not allow_echo})
	for id in _connected_human_ids():
		if id == owner:continue
		var target: Node3D = actors[id]
		if target.health <= 0.0:continue
		var center: Vector3 = target.rigs.TorsoRig.global_position+target.rigs.TorsoRig.global_basis*Vector3(0,0.35,0)
		var head: Vector3 = target.rigs.HeadRig.global_position
		var distance := center.distance_to(origin)
		if distance > 5.5:continue
		if not ray(origin,center,1).is_empty() and not ray(origin,head,1).is_empty():continue
		var amount := roundf(lerpf(110.0,35.0,clampf((distance-1.4)/4.1,0.0,1.0)))
		damage(id,amount,(center-origin).normalized(),owner,center,false,"grenade")
	_apply_grenade_push(point,owner,power)
	grenade_context_owner = 0
	grenade_scale = 1.0
	if allow_echo and actors.has(owner) and actors[owner].has_augment("double_trouble"):
		echoes.append({"time":0.32,"p":point,"owner":owner,"id":gid+1000000})

func _apply_grenade_push(point: Vector3,owner: int,power: float) -> void:
	var attacker: Node3D = actors.get(owner)
	var boost := 2.6 if attacker != null and attacker.has_augment("rubber_grenade") else 1.0
	for id in _connected_human_ids():
		if id == owner:continue
		var target: Node3D = actors[id]
		if target.health <= 0.0:continue
		var centre := target.global_position+Vector3.UP*0.9
		var delta := centre-(point+Vector3.UP*0.12)
		if delta.length() > 5.5:continue
		if not ray(point+Vector3.UP*0.12,centre,1).is_empty():continue
		target.apply_duel_push(delta.normalized(),1.3*boost*power)

func _tick_echoes() -> void:
	for index in range(echoes.size()-1,-1,-1):
		echoes[index]["time"] = float(echoes[index].time)-DT
		if float(echoes[index].time) > 0.0:continue
		var e: Dictionary = echoes[index]
		echoes.remove_at(index)
		_explode_duel(e.p,int(e.owner),int(e.id),false,0.48)

func snapshot() -> Dictionary:
	var result: Dictionary = super.snapshot()
	result["wave"] = 0
	result["remaining"] = 0
	result["room"] = room_packet()
	return result

func network_snapshot(viewer_id: int) -> Array:
	var result: Array=super.network_snapshot(viewer_id)
	result[4]=0
	result[6]=0
	result[11]=room_packet()
	return result
