extends Node3D
## Authoritative 60 Hz co-op proof. This scene creates no camera, mesh, HUD or audio node.
signal event_created(data: Dictionary)
const LEVEL:=preload("res://scripts/kw3d/online_level.gd")
const AK_RECOIL:=preload("res://scripts/kw3d/ak_recoil.gd")
const WEAPON_RULES:=preload("res://scripts/kw3d/weapon_rules.gd")
const HIT_REGIONS:=preload("res://scripts/kw3d/hit_regions.gd")
const ACTOR:=preload("res://scripts/kw3d/authority_actor.gd")
const MOTOR:=preload("res://scripts/kw3d/actor_motor.gd")
const WARRIOR_SKILL_RULES:=preload("res://scripts/kw3d/warrior_skill_rules.gd")
const DT:=1.0/60.0
const SKINS: Array[String]=["tasko","gan","celler","nova","m4","crashout"]
const PADS: Array[Vector3]=[Vector3(-10,1.735,-10),Vector3(10,1.735,-10),Vector3(0,1.735,-17),Vector3(-18,1.735,5),Vector3(18,1.735,5),Vector3(-18,1.735,-22),Vector3(18,1.735,-24),Vector3(-9,1.735,-22),Vector3(9,1.735,-22)]
var data: Dictionary
var actors: Dictionary={}
var actor_ids_cache: Array[int]=[]
var actor_ids_dirty:=true
var hit_history: Dictionary={}
var qa_fixture=false
var grenade_bodies: Dictionary={}
var explosion_ids: Dictionary={}
var tick_id =0
var event_id =0
var match_id =""
var wave =0
var wave_budget =0
var wave_spawned =0
var rest_time =0.0
var phase ="WAITING"
var next_bot =1000
var next_grenade =0
var grenades: Dictionary={}
var bolts: Dictionary={}
var next_bolt =0
var attack_time =3.0
var warning: Dictionary={}
var spawn_time =0.0
var rng =RandomNumberGenerator.new()
var attacks_enabled =true
var round_live=false
var denied_actions =0
var grenade_count =0
var damage_count =0
var kill_count =0
var heal_count =0
var metrics = {"max_tick_usec":0,"ticks":0}
var shared_ray_query:=PhysicsRayQueryParameters3D.new()

func _ready() -> void:
	data=LEVEL.read();LEVEL.build_physics(self,data)
	shared_ray_query.hit_from_inside=true
	rng.seed=730137
	match_id=Crypto.new().generate_random_bytes(12).hex_encode()

func add_player(id: int) -> void:
	if actors.has(id): actors[id].connected=true;return
	var a =ACTOR.new();add_child(a)
	a.position=Vector3(-2 if id%2 else 2,2.2,8)
	a.configure(id,false,data.profiles.outrage,"outrage")
	actors[id]=a
	actor_ids_dirty=true
	if qa_fixture:a.health=60.0
	if wave==0: begin_wave(1)
	emit("join",{"actor":id})

func detach_player(id: int) -> void:
	if not actors.has(id):return
	var a: Node3D=actors[id]
	a.connected=false;a.input_queue.clear();a.command=MOTOR.empty(a.aim_yaw,a.aim_pitch)
	emit("disconnected",{"actor":id})

func remove_player(id: int) -> void:
	if not actors.has(id):return
	actors[id].queue_free();actors.erase(id);actor_ids_dirty=true;emit("leave",{"actor":id})

func respawn(id: int) -> bool:
	if not actors.has(id):return false
	var a: Node3D=actors[id]
	if a.health>0 or a.death_clock<3:return false
	a.health=100.0;a.death_clock=0;a.position=Vector3(-2 if id%2 else 2,2.2,8)
	a.reset_magazine()
	a.reset_warrior_skill()
	a.collision_layer=2;a.hit_body.collision_layer=16;a.velocity=Vector3.ZERO
	a.command=MOTOR.empty(a.aim_yaw,a.aim_pitch);a.input_queue.clear();a.locomotion.reset()
	emit("respawn",{"actor":id,"hp":100.0})
	return true

func begin_wave(n: int) -> void:
	wave=n;wave_budget=mini(19,3+(n-1)*2);wave_spawned=0;phase="WAVE";spawn_time=0;attack_time=3.0
	emit("wave",{"wave":wave,"budget":wave_budget})
	# Put the initial trio in the welcome snapshot: avoid first-play shader/object creation spikes while moving.
	for initial in range(mini(3,wave_budget)):_spawn_bot()
	spawn_time=0.65

func alive_bots() -> int:
	var count =0
	for a in actors.values():
		if a.is_bot and a.health>0:count+=1
	return count

func _spawn_bot() -> bool:
	var candidate =Vector3.ZERO
	var found =false
	for offset in range(PADS.size()):
		candidate=PADS[(wave_spawned+offset+(wave-1)*2)%PADS.size()]
		var occupied =false
		for a in actors.values():
			if a.health>0 and a.global_position.distance_to(candidate)<(2.5 if a.is_bot else 7.0):occupied=true;break
		if occupied:continue
		found=true;break
	if not found:return false
	var id =next_bot;next_bot+=1
	var skin: String=SKINS[(wave_spawned+wave-1)%SKINS.size()]
	var bot =ACTOR.new();add_child(bot);bot.position=candidate
	bot.configure(id,true,data.profiles[skin],skin);bot.visual.rotation.y=PI
	actors[id]=bot;actor_ids_dirty=true;wave_spawned+=1
	emit("spawn",{"actor":id,"p":candidate,"skin":skin})
	return true

func emit(kind: String,payload: Dictionary) -> void:
	event_id+=1
	var result =payload.duplicate();result.merge({"type":kind,"event":event_id,"tick":tick_id,"match":match_id})
	event_created.emit(result)

func _actor_ids_sorted() -> Array[int]:
	if actor_ids_dirty:
		actor_ids_cache.clear()
		for raw_id in actors.keys():actor_ids_cache.append(int(raw_id))
		actor_ids_cache.sort()
		actor_ids_dirty=false
	return actor_ids_cache

func step() -> void:
	var started =Time.get_ticks_usec()
	tick_id+=1
	var ids: Array[int]=_actor_ids_sorted()
	for id in ids:
		var a: Node3D=actors[id]
		if not a.is_bot:
			# A command sequence represents one simulation tick, including a lost packet.
			# Never replay late commands as extra time after extrapolating movement.
			if a.connected and not a.input_started and not a.input_queue.is_empty():
				var starts: Array=a.input_queue.keys();starts.sort()
				a.ack=int(starts[0])-1;a.input_started=true;a.input_wait=2
			if a.connected and a.input_started:
				if a.input_wait>0:
					a.input_wait-=1
				else:
					var next_seq: int=a.ack+1
					if a.input_queue.has(next_seq):
						var frame: Dictionary=a.input_queue[next_seq]
						a.input_queue.erase(next_seq)
						a.command=frame
						a.command.jump=int(frame.js)>a.last_jump_serial
						a.command.grenade=int(frame.gs)>a.last_grenade_serial
						a.last_jump_serial=maxi(a.last_jump_serial,int(frame.js))
						a.last_grenade_serial=maxi(a.last_grenade_serial,int(frame.gs))
					else:
						# Movement/look may be extrapolated across one lost input frame, but actions must not.
						# In particular, never fire another authoritative shot using stale yaw/pitch.
						a.command.jump=false
						a.command.grenade=false
						a.command.fire=false
						a.command.reload=false
					if tick_id-a.last_input_tick>12:
						a.command=MOTOR.empty(a.aim_yaw,a.aim_pitch)
					a.ack=next_seq
			a.tick(DT)
		else:
			a.tick(DT)
	_capture_hit_history()
	for id in ids:
		var a: Node3D=actors[id]
		if a.is_bot or a.health<=0:continue
		a.build_aim(get_world_3d().direct_space_state,DT)
		_tick_warrior_skill(a)
		if (a.command.get("move",Vector2.ZERO) as Vector2).length_squared()>0.001 or a.command.get("fire",false) or a.command.get("aim",false) or a.command.get("grenade",false) or a.command.get("reload",false):round_live=true
		if a.command.get("reload",false):_request_reload(a)
		if a.command.get("fire",false) and a.fire_clock<=0.00001:
			if a.reload_clock<=0.00001 and a.ammo>0:_shoot(a)
			elif a.reload_clock<=0.00001:_request_reload(a)
		if a.command.get("grenade",false):
			a.command.grenade=false
			if a.grenade_clock<=0.00001:_throw(a)
			else:denied_actions+=1
	_tick_grenades()
	_tick_bolts()
	if wave>0:
		if phase=="WAVE":
			spawn_time-=DT
			if wave_spawned<wave_budget and alive_bots()<8 and spawn_time<=0:
				_spawn_bot();spawn_time=0.65
			if wave_spawned>=wave_budget and alive_bots()==0:
				phase="REST";rest_time=4;warning.clear();emit("clear",{"wave":wave})
		else:
			rest_time-=DT
			if rest_time<=0:begin_wave(wave+1)
		if attacks_enabled and phase=="WAVE" and round_live:_tick_attacks()
	for id in ids:
		if not actors.has(id):continue
		var a: Node3D=actors[id]
		if a.is_bot and a.health<=0 and a.death_clock>1.6:
			a.queue_free();actors.erase(id);actor_ids_dirty=true
	metrics.max_tick_usec=maxi(metrics.max_tick_usec,Time.get_ticks_usec()-started);metrics.ticks=tick_id

func ray(from: Vector3,to: Vector3,mask: int=5,exclude: Array[RID]=[]) -> Dictionary:
	if from.distance_squared_to(to)<0.000001:return {}
	shared_ray_query.from=from;shared_ray_query.to=to;shared_ray_query.collision_mask=mask;shared_ray_query.exclude=exclude
	return get_world_3d().direct_space_state.intersect_ray(shared_ray_query)

func _request_reload(a: Node3D) -> bool:
	if not a.start_reload():return false
	var profile: Dictionary=WEAPON_RULES.by_slot(a.weapon_slot)
	emit("reload",{"actor":a.actor_id,"weapon":a.weapon_slot,"duration":float(profile.reload),"ammo":a.ammo,"p":a.weapon_anchor()})
	return true

func _shoot(a: Node3D) -> void:
	var profile: Dictionary=WEAPON_RULES.by_slot(a.weapon_slot)
	a.fire_clock=float(profile.fire_interval)*float(a.skill_fire_interval_multiplier())
	a.ammo=maxi(0,a.ammo-1)
	var recoil_strength:=1.0 if a.weapon_slot==0 else 1.45 if a.weapon_slot==1 else 1.85 if a.weapon_slot==2 else 2.10
	a.recoil_velocity.x-=0.52*recoil_strength
	a.recoil_velocity.z+=0.20*recoil_strength
	var rewound: Array=_rewind_targets(int(a.command.get("ct",tick_id)))
	a.build_aim(get_world_3d().direct_space_state,0.0)
	if a.weapon_slot==0:_shoot_single(a,profile,0,"ak")
	elif a.weapon_slot==1:_shoot_shotgun(a,profile)
	elif a.weapon_slot==2:_shoot_single(a,profile,2,"kar")
	else:_shoot_launcher(a,profile)
	_restore_targets(rewound)
	if a.ammo<=0:_request_reload(a)

func _shoot_single(a: Node3D,profile: Dictionary,weapon_index: int,weapon_id: String) -> void:
	var exclusions: Array[RID]=[a.get_rid(),a.hit_body.get_rid()]
	var guard=ray(a.weapon_anchor(),a.muzzle,5,exclusions)
	var blocked: bool=not guard.is_empty()
	var base_direction: Vector3=(a.aim_target-a.muzzle).normalized()
	var seed:=int(tick_id*7919+a.actor_id*104729+a.ack*31+weapon_index*997)
	var direction:=WEAPON_RULES.spread_direction(base_direction,profile,bool(a.command.get("aim",false)),seed)
	var hit: Dictionary=guard if not guard.is_empty() else ray(a.muzzle,a.muzzle+direction*float(profile.range),5,exclusions)
	var endpoint: Vector3=hit.get("position",a.muzzle+direction*float(profile.range))
	var headshot:=HIT_REGIONS.is_headshot(hit) if not hit.is_empty() else false
	emit("shot",{"actor":a.actor_id,"input":a.ack,"weapon":weapon_index,"from":a.muzzle,"to":endpoint,"blocked":blocked,"ammo":a.ammo,
		"hit":not hit.is_empty(),"headshot":headshot,"normal":hit.get("normal",Vector3.UP),"spread":WEAPON_RULES.spread_for(profile,bool(a.command.get("aim",false)))})
	if not hit.is_empty() and (hit.collider as Node).has_meta("actor_id"):
		damage(int(hit.collider.get_meta("actor_id")),WEAPON_RULES.damage(profile,headshot),direction,a.actor_id,endpoint,headshot,weapon_id)

func _shoot_shotgun(a: Node3D,profile: Dictionary) -> void:
	var exclusions: Array[RID]=[a.get_rid(),a.hit_body.get_rid()]
	var guard:=ray(a.weapon_anchor(),a.muzzle,5,exclusions)
	var centre: Vector3=(a.aim_target-a.muzzle).normalized()
	var pellets: Array=[]
	for pellet in range(int(profile.pellets)):
		var direction: Vector3=WEAPON_RULES.spread_direction(centre,profile,bool(a.command.get("aim",false)),int(tick_id*7919+a.actor_id*104729+a.ack*31+pellet*131))
		var hit: Dictionary=guard if not guard.is_empty() else ray(a.muzzle,a.muzzle+direction*float(profile.range),5,exclusions)
		var endpoint: Vector3=hit.get("position",a.muzzle+direction*float(profile.range))
		var headshot:=HIT_REGIONS.is_headshot(hit) if not hit.is_empty() else false
		pellets.append({"to":endpoint,"normal":hit.get("normal",Vector3.UP),"hit":not hit.is_empty(),"headshot":headshot})
		if not hit.is_empty() and (hit.collider as Node).has_meta("actor_id"):
			damage(int(hit.collider.get_meta("actor_id")),WEAPON_RULES.damage(profile,headshot),direction,a.actor_id,endpoint,headshot,"shotgun")
	emit("shotgun",{"actor":a.actor_id,"input":a.ack,"weapon":1,"from":a.muzzle,"pellets":pellets,"blocked":not guard.is_empty(),"ammo":a.ammo})


func _shoot_launcher(a: Node3D,profile: Dictionary) -> void:
	next_grenade+=1;grenade_count+=1
	var direction: Vector3=(a.aim_target-a.muzzle).normalized()
	if direction.length_squared()<0.001:direction=-a.visual.global_basis.z
	var origin: Vector3=a.muzzle+direction*0.30
	var guard: Dictionary=ray(a.weapon_anchor(),origin,1,[a.get_rid(),a.hit_body.get_rid()])
	if not guard.is_empty():origin=guard.position-direction*0.12
	var speed:=float(profile.get("projectile_speed",22.0))
	var velocity:=direction*speed
	var body=CharacterBody3D.new();body.name="LauncherGrenade%d"%next_grenade
	body.collision_layer=0;body.collision_mask=5;body.safe_margin=0.004
	add_child(body);body.global_position=origin
	var c=CollisionShape3D.new();var sphere=SphereShape3D.new();sphere.radius=0.14;c.shape=sphere;body.add_child(c)
	grenade_bodies[next_grenade]=body
	grenades[next_grenade]={
		"id":next_grenade,"owner":a.actor_id,"p":origin,"v":velocity,
		"fuse":float(profile.get("fuse",2.4)),"bounce_gate":0.0,"kind":"launcher",
		"gravity":float(profile.get("gravity",16.0)),"radius":float(profile.get("blast_radius",4.8)),
		"max_damage":float(profile.get("max_damage",72.0)),"min_damage":float(profile.get("min_damage",22.0))
	}
	emit("launcher_shot",{"actor":a.actor_id,"input":a.ack,"weapon":3,"from":origin,"v":velocity,"ammo":a.ammo,"id":next_grenade})

func damage(victim: int,amount: float,direction: Vector3,owner: int,point: Vector3,headshot: bool=false,weapon: String="") -> bool:
	if not actors.has(victim) or amount<=0:return false
	var target: Node3D=actors[victim]
	if target.health<=0:return false
	if not target.is_bot and (owner>0 or target.damage_grace>0):return false # friendly fire is disabled in this proof
	if target.has_method("skill_is_immune") and bool(target.skill_is_immune()):return false
	if owner>0 and actors.has(owner) and actors[owner].has_method("skill_damage_multiplier"):
		amount*=float(actors[owner].skill_damage_multiplier())
	target.hurt(amount,direction);damage_count+=1
	if not target.is_bot:target.damage_grace=0.38
	emit("damage",{"actor":victim,"owner":owner,"amount":amount,"hp":target.health,"p":point,"dir":direction,"headshot":headshot,"weapon":weapon,"lethal":target.health<=0})
	if target.health<=0:
		kill_count+=1
		if owner>0 and actors.has(owner) and actors[owner].health>0:
			var killer: Node3D=actors[owner]
			killer.kills+=1
			var healed: float=minf(8,100-killer.health);killer.health+=healed;heal_count+=1
			emit("kill",{
				"actor":victim,"owner":owner,"kills":killer.kills,"hp":killer.health,"heal":healed,
				"weapon":weapon,"headshot":headshot,
				"killer_name":str(killer.display_name),"victim_name":str(target.display_name)
			})
	return true


func use_skill(id: int) -> bool:
	if not actors.has(id):return false
	var a: Node3D=actors[id]
	if a.is_bot or a.health<=0.0:return false
	if not a.start_warrior_skill():return false
	var cfg:=WARRIOR_SKILL_RULES.config_ref(a.skin)
	round_live=true
	var skill_from: Vector3=a.global_position
	var skill_to: Vector3=a.global_position
	match a.skin:
		"kosas":
			_nose_rush(a)
			skill_to=a.global_position
	emit("skill",{
		"actor":id,"hero":a.skin,"skill":str(cfg.get("id","skill")),
		"duration":float(cfg.get("duration",0.0)),"cooldown":float(cfg.get("cooldown",0.0)),"p":a.global_position,
		"from":skill_from,"to":skill_to
	})
	return true


func _tick_warrior_skill(a: Node3D) -> void:
	if a.skin!="aevilok" or a.warrior_skill_active<=0.0001 or a.warrior_skill_pulse>0.0001:return
	a.warrior_skill_pulse=0.18
	_flamethrower_pulse(a)


func _nose_rush(a: Node3D) -> void:
	var direction: Vector3=-Basis(Vector3.UP,a.aim_yaw).z
	direction.y=0.0
	if direction.length_squared()<0.001:direction=Vector3.FORWARD
	direction=direction.normalized()
	a.move_and_collide(direction*4.8)
	a.velocity.x=direction.x*11.0;a.velocity.z=direction.z*11.0
	for target_id in actors.keys():
		if int(target_id)==int(a.actor_id):continue
		var target: Node3D=actors[target_id]
		if not target.is_bot or target.health<=0.0:continue
		var offset: Vector3=target.global_position-a.global_position
		if offset.length()>2.45:continue
		var hit_direction:=offset.normalized() if offset.length_squared()>0.001 else direction
		damage(int(target_id),35.0,hit_direction,a.actor_id,target.global_position+Vector3.UP*0.9,false,"nose_rush")
		if target.brain!=null:target.brain.impulse(hit_direction,5.0)


func _flamethrower_pulse(a: Node3D) -> void:
	var origin: Vector3=a.global_position+Vector3.UP*1.10
	var direction: Vector3=a.camera_direction.normalized()
	if direction.length_squared()<0.001:direction=-Basis(Vector3.UP,a.aim_yaw).z
	var cone_cos: float=cos(deg_to_rad(31.0))
	for target_id in actors.keys():
		var target: Node3D=actors[target_id]
		if not target.is_bot or target.health<=0.0:continue
		var point: Vector3=target.rigs.TorsoRig.global_position+Vector3.UP*0.30
		var offset: Vector3=point-origin
		var distance: float=offset.length()
		if distance<=0.05 or distance>7.2:continue
		var hit_direction: Vector3=offset/distance
		if direction.dot(hit_direction)<cone_cos:continue
		if not ray(origin,point,1,[a.get_rid(),a.hit_body.get_rid()]).is_empty():continue
		damage(int(target_id),7.0,hit_direction,a.actor_id,point,false,"flamethrower")

func _throw(a: Node3D) -> void:
	a.grenade_clock=6.0;next_grenade+=1;grenade_count+=1
	var anchor: Vector3=a.weapon_anchor()+Vector3.UP*0.15
	var direction: Vector3=(a.aim_target-anchor).normalized()
	var origin: Vector3=anchor+direction*0.65
	var guard: Dictionary=ray(anchor,origin,1)
	if not guard.is_empty():origin=guard.position-direction*0.22
	var delta_goal: Vector3=(a.aim_target-origin).limit_length(22.0)
	var flight: float=clampf(delta_goal.length()/17.0,0.4,1.05)
	var velocity: Vector3=(delta_goal/flight+Vector3.UP*(8.0*flight)).limit_length(29.0)
	var body =CharacterBody3D.new();body.name="Grenade%d"%next_grenade
	body.collision_layer=0;body.collision_mask=5;body.safe_margin=0.004
	add_child(body);body.global_position=origin
	var c =CollisionShape3D.new();var sphere =SphereShape3D.new();sphere.radius=0.16;c.shape=sphere;body.add_child(c)
	grenade_bodies[next_grenade]=body
	grenades[next_grenade]={"id":next_grenade,"owner":a.actor_id,"p":origin,"v":velocity,"fuse":1.25,"bounce_gate":0.0,"kind":"skill","gravity":16.0,"radius":5.5,"max_damage":110.0,"min_damage":35.0}
	emit("throw",grenades[next_grenade])

func _tick_grenades() -> void:
	for id in grenades.keys():
		var g: Dictionary=grenades[id]
		var body: CharacterBody3D=grenade_bodies.get(id)
		if not is_instance_valid(body):grenades.erase(id);grenade_bodies.erase(id);continue
		g.fuse-=DT;g.bounce_gate=maxf(0,g.bounce_gate-DT)
		for substep in range(2):
			g.v.y-=float(g.get("gravity",16.0))*DT*0.5
			var collision: KinematicCollision3D=body.move_and_collide(g.v*DT*0.5)
			if collision!=null:
				var object: Object=collision.get_collider()
				if object is Node and object.has_meta("actor_id"):g.fuse=0;break
				var normal =collision.get_normal()
				g.v=(g.v as Vector3).bounce(normal)*0.46
				if normal.y>0.7:g.v*=Vector3(0.78,1,0.78)
				if g.bounce_gate<=0 and (g.v as Vector3).length()>0.6:
					g.bounce_gate=0.14;emit("bounce",{"p":body.global_position})
		g.p=body.global_position
		if g.fuse<=0 or body.global_position.y < -5:
			explode(
				g.p,g.owner,id,
				float(g.get("radius",5.5)),float(g.get("max_damage",110.0)),float(g.get("min_damage",35.0)),str(g.get("kind","skill"))
			)
			body.queue_free();grenades.erase(id);grenade_bodies.erase(id)

func explode(point: Vector3,owner: int,gid: int,radius: float=5.5,max_damage: float=110.0,min_damage: float=35.0,kind: String="skill") -> void:
	if explosion_ids.has(gid):return
	explosion_ids[gid]=true
	if explosion_ids.size()>256:explosion_ids.erase(explosion_ids.keys()[0])
	var origin =point+Vector3.UP*0.12
	emit("explosion",{"p":origin,"id":gid,"owner":owner,"kind":kind})
	for id in actors.keys():
		var bot: Node3D=actors[id]
		if not bot.is_bot or bot.health<=0:continue
		var center: Vector3=bot.rigs.TorsoRig.global_position+bot.rigs.TorsoRig.global_basis*Vector3(0,0.35,0)
		var head: Vector3=bot.rigs.HeadRig.global_position
		var distance =center.distance_to(origin)
		if distance>radius:continue
		if not ray(origin,center,1).is_empty() and not ray(origin,head,1).is_empty():continue
		var amount =roundf(lerpf(max_damage,min_damage,clampf((distance-1.2)/maxf(0.1,radius-1.2),0,1)))
		damage(id,amount,(center-origin).normalized(),owner,center,false,"grenade_launcher" if kind=="launcher" else "grenade")

func _tick_attacks() -> void:
	attack_time-=DT
	if not warning.is_empty():
		var id: int=warning.actor
		if not actors.has(id) or actors[id].health<=0 or actors[id].brain.stagger>0:
			emit("warning_end",{"actor":id});warning.clear();attack_time=0.3;return
		warning.time-=DT
		if warning.time<=0:
			var bot: Node3D=actors[id]
			var origin: Vector3=bot.rigs.TorsoRig.global_position+Vector3(0,0.50,0)
			if ray(origin,warning.target,1).is_empty():
				next_bolt+=1
				bolts[next_bolt]={"id":next_bolt,"p":origin,"v":(warning.target-origin).normalized()*21,"life":3.2,"owner":id}
				emit("hostile_shot",bolts[next_bolt])
			emit("warning_end",{"actor":id})
			bot.fire_clock=rng.randf_range(1.8,3.0)
			warning.clear();attack_time=rng.randf_range(0.3,0.58)
		return
	if attack_time>0 or bolts.size()>=6:return
	var humans: Array=[];var bots: Array=[]
	for a in actors.values():
		if a.health<=0:continue
		if a.is_bot and a.fire_clock<=0:bots.append(a)
		else:humans.append(a)
	if humans.is_empty() or bots.is_empty():return
	bots.shuffle()
	for bot in bots:
		var human: Node3D=humans[rng.randi_range(0,humans.size()-1)]
		var target: Vector3=human.rigs.TorsoRig.global_position+Vector3(0,0.4,0)
		if bot.position.distance_to(human.position)>34 or not ray(bot.global_position+Vector3(0,0.4,0),target,1).is_empty():continue
		warning={"actor":bot.actor_id,"target":target,"time":0.38}
		emit("warning",warning);return
	attack_time=0.3

func _tick_bolts() -> void:
	for id in bolts.keys():
		var b: Dictionary=bolts[id]
		b.life-=DT
		var to: Vector3=b.p+b.v*DT
		var hit =ray(b.p,to,17)
		if not hit.is_empty():
			if (hit.collider as Node).has_meta("actor_id"):
				damage(int(hit.collider.get_meta("actor_id")),8,(b.v as Vector3).normalized(),0,hit.position)
			bolts.erase(id)
		elif b.life<=0:bolts.erase(id)
		else:b.p=to

func snapshot() -> Dictionary:
	var records: Array=[]
	for a in actors.values():records.append(a.packet())
	return {"tick":tick_id,"match":match_id,"round_live":round_live,"wave":wave,"phase":phase,"remaining":alive_bots()+maxi(0,wave_budget-wave_spawned),
		"actors":records,"grenades":grenades.values(),"bolts":bolts.values(),"event":event_id}

func network_snapshot(viewer_id: int) -> Array:
	var records: Array=[]
	for actor in actors.values():records.append(actor.network_record(int(actor.actor_id)==viewer_id))
	return [2,tick_id,match_id,round_live,wave,phase,alive_bots()+maxi(0,wave_budget-wave_spawned),records,grenades.values(),bolts.values(),event_id,{}]

func _capture_hit_history() -> void:
	var frame: Dictionary={}
	for a in actors.values():
		if a.health<=0 or not a.connected or a.hit_body==null:continue
		# Store the authoritative hurtbox body's world transform. Moving the PhysicsServer RID
		# directly during rewind is immediately visible to intersect_ray in the same tick.
		frame[a.actor_id]=a.hit_body.global_transform
	hit_history[tick_id]=frame
	# Fixed-size rewind window: one exact expiry per tick avoids allocating/scanning
	# the history key list 60 times per second.
	hit_history.erase(tick_id-13)

func _rewind_targets(requested: int) -> Array:
	var selected =clampi(requested,tick_id-9,tick_id)
	if not hit_history.has(selected):return []
	var history: Dictionary=hit_history[selected]
	var saved: Array=[]
	for id in history:
		if not actors.has(id) or actors[id].health<=0:continue
		var a: Node3D=actors[id]
		if a.hit_body==null:continue
		var body_rid: RID=a.hit_body.get_rid()
		var current: Transform3D=PhysicsServer3D.body_get_state(body_rid,PhysicsServer3D.BODY_STATE_TRANSFORM)
		saved.append([body_rid,current])
		PhysicsServer3D.body_set_state(body_rid,PhysicsServer3D.BODY_STATE_TRANSFORM,history[id])
	return saved

func _restore_targets(saved: Array) -> void:
	for entry in saved:
		var body_rid: RID=entry[0]
		if body_rid.is_valid():
			PhysicsServer3D.body_set_state(body_rid,PhysicsServer3D.BODY_STATE_TRANSFORM,entry[1])
