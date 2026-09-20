extends CharacterBody3D
const LEVEL:=preload("res://scripts/kw3d/online_level.gd")
const MOTOR:=preload("res://scripts/kw3d/actor_motor.gd")
const WALK:=preload("res://scripts/kw3d/authority_locomotion.gd")
const BRAIN:=preload("res://scripts/prototypes/kw_roaming_brain.gd")
const WEAPON_RULES:=preload("res://scripts/kw3d/weapon_rules.gd")
const RIGS: Array[String]=["HeadRig","TorsoRig","LeftLegRig","RightLegRig"]
var actor_id =0
var is_bot =false
var skin ="outrage"
var health =100.0
var damage_grace=0.0
var kills =0
var connected =true
var ack =0
var last_input_tick =0
var fire_clock =0.0
var weapon_slot =0
var ammo_by_weapon: Array[int]=[25,2]
var reload_by_weapon: Array[float]=[0.0,0.0]
var ammo: int:
	get:return ammo_by_weapon[weapon_slot]
	set(value):ammo_by_weapon[weapon_slot]=value
var reload_clock: float:
	get:return reload_by_weapon[weapon_slot]
	set(value):reload_by_weapon[weapon_slot]=value
var grenade_clock =0.0
var death_clock =0.0
var body_yaw =0.0
var smoothed_weapon_side=1.0
var aim_yaw =0.0
var aim_pitch =-0.174533
var camera_boom =6.4
var camera_fraction =1.0
var phase =0.0
var command: Dictionary={}
var last_jump_serial =0
var last_grenade_serial =0
var visual: Node3D
var rigs: Dictionary={}
var hit_body: StaticBody3D
var hit_records: Array[Dictionary]=[]
var body_bridge: CollisionShape3D
const BODY_BRIDGE_RADIUS:=0.24
const BODY_BRIDGE_HEAD_CLEARANCE:=0.46
const BODY_BRIDGE_TORSO_DROP:=0.48
var locomotion: RefCounted
var brain: RefCounted
var input_queue: Dictionary={}
var input_started=false
var input_wait=0
var head_rotation =Vector3.ZERO
var head_velocity =Vector3.ZERO
var recoil =Vector3.ZERO
var recoil_velocity =Vector3.ZERO
var step_count =0
var muzzle =Vector3.ZERO
var aim_target =Vector3.ZERO
var camera_origin =Vector3.ZERO
var camera_direction =Vector3.FORWARD
var base_head =Vector3.ZERO
var base_torso =Vector3.ZERO
var probe =SphereShape3D.new()
var was_alive =true

func configure(id: int,bot: bool,profile: Dictionary,appearance: String) -> void:
	actor_id=id;is_bot=bot;skin=appearance
	name="Actor%d"%id
	collision_layer=8 if bot else 2
	collision_mask=11 if bot else 9
	floor_snap_length=0.30;safe_margin=0.004
	var shape =CapsuleShape3D.new();shape.height=3.43;shape.radius=0.44 if bot else 0.52
	var c =CollisionShape3D.new();c.shape=shape;add_child(c)
	visual=Node3D.new();visual.name="Pose";add_child(visual)
	hit_body=StaticBody3D.new();hit_body.collision_layer=4 if bot else 16;hit_body.collision_mask=0
	hit_body.set_meta("actor_id",actor_id);add_child(hit_body)
	for title in RIGS:
		var r: Dictionary=profile[title]
		var rig =Node3D.new();rig.name=title;visual.add_child(rig)
		rig.position=LEVEL.vec(r.p);rig.rotation=LEVEL.vec(r.r)
		rig.set_meta("sole_geometry",r.sole);rigs[title]=rig
		for part in r.parts:
			var hs =CollisionShape3D.new();var b =BoxShape3D.new();b.size=LEVEL.vec(part.s)
			hs.shape=b;hs.set_meta("hit_region","head" if title=="HeadRig" else "body");hit_body.add_child(hs)
			hit_records.append({"shape":hs,"rig":rig,"part":Transform3D(Basis.from_euler(LEVEL.vec(part.r)),LEVEL.vec(part.p)),"size":b.size,"region":"head" if title=="HeadRig" else "body"})
	body_bridge=CollisionShape3D.new();body_bridge.name="BodyBridgeHurtbox"
	var bridge_shape:=CylinderShape3D.new();bridge_shape.radius=BODY_BRIDGE_RADIUS;bridge_shape.height=1.0
	body_bridge.shape=bridge_shape;body_bridge.set_meta("hit_region","body");hit_body.add_child(body_bridge)
	base_head=rigs.HeadRig.position;base_torso=rigs.TorsoRig.position
	probe.radius=0.18
	command=MOTOR.empty()
	locomotion=WALK.new();locomotion.setup(self,visual,rigs.HeadRig,rigs.TorsoRig,rigs.LeftLegRig,rigs.RightLegRig,id*913+137)
	locomotion.playfulness=1.35 if bot else 1.2
	if bot:
		brain=BRAIN.new();brain.setup(self,visual,Rect2(-21,-27,42,42),id*1337)
	update_shapes()

func tick(dt: float) -> void:
	damage_grace=maxf(0,damage_grace-dt)
	fire_clock=maxf(0,fire_clock-dt);grenade_clock=maxf(0,grenade_clock-dt)
	for slot in range(2):
		if reload_by_weapon[slot]<=0.0:continue
		var before_reload: float=reload_by_weapon[slot]
		reload_by_weapon[slot]=maxf(0.0,reload_by_weapon[slot]-dt)
		if before_reload>0.0 and reload_by_weapon[slot]<=0.0:
			ammo_by_weapon[slot]=int(WEAPON_RULES.by_slot(slot).magazine)
	if health<=0:
		death_clock+=dt;velocity=Vector3.ZERO;return
	var impact =velocity.y
	if is_bot:
		brain.update(dt);impact=brain.impact_velocity
		body_yaw=visual.rotation.y;aim_yaw=body_yaw
	else:
		weapon_slot=clampi(int(command.get("weapon",weapon_slot)),0,1)
		aim_yaw=command.get("yaw",aim_yaw);aim_pitch=command.get("pitch",aim_pitch)
		MOTOR.step(self,command,dt)
		var movement: Vector2=command.get("move",Vector2.ZERO)
		var front: Vector3=Basis(Vector3.UP,aim_yaw)*Vector3(movement.x,0,-movement.y)
		if command.get("aim",false) or command.get("fire",false): front=-Basis(Vector3.UP,aim_yaw).z
		if front.length_squared()>0.001: body_yaw=lerp_angle(body_yaw,atan2(-front.x,-front.z),minf(1,10*dt))
		visual.rotation.y=body_yaw
		command["jump"]=false
	if global_position.y < -12:
		global_position=Vector3(0,2.2,6);velocity=Vector3.ZERO;locomotion.reset()
	locomotion.update(dt,impact);phase=locomotion.cycle;step_count=locomotion.step_count
	var head: Node3D=rigs.HeadRig
	var target: Vector3=locomotion.secondary_head*0.8
	if not is_bot:
		target.y=clampf(wrapf(aim_yaw-body_yaw,-PI,PI),-1.22,1.22)
		target.x=aim_pitch
		var focus: bool=command.get("aim",false) or command.get("fire",false)
		for unused in range(2):
			head_velocity+=((target-head_rotation)*(170 if focus else 85)-head_velocity*(21 if focus else 11))*dt*0.5
			head_rotation+=head_velocity*dt*0.5
		head.rotation=head_rotation.clamp(Vector3(-0.85,-1.4,-0.6),Vector3(0.85,1.4,0.6))
	else: head.rotation=target
	for unused in range(2):
		recoil_velocity+=(-recoil*100-recoil_velocity*12)*dt*0.5;recoil+=recoil_velocity*dt*0.5
	recoil=recoil.limit_length(0.30)
	rigs.TorsoRig.rotation+=recoil*0.8;head.rotation+=recoil*1.2
	update_shapes()

func start_reload() -> bool:
	var profile: Dictionary=WEAPON_RULES.by_slot(weapon_slot)
	if is_bot or health<=0 or reload_clock>0.0 or ammo>=int(profile.magazine):return false
	reload_clock=float(profile.reload)
	return true

func reset_magazine() -> void:
	ammo_by_weapon=[int(WEAPON_RULES.AK.magazine),int(WEAPON_RULES.SHOTGUN.magazine)]
	reload_by_weapon=[0.0,0.0]
	weapon_slot=0

func update_shapes() -> void:
	for record in hit_records:
		var relative: Transform3D=global_transform.affine_inverse()*(record.rig as Node3D).global_transform*record.part
		(record.shape as CollisionShape3D).transform=relative
	_update_body_bridge()

func _update_body_bridge() -> void:
	if body_bridge==null or hit_body==null:return
	var torso: Node3D=rigs.TorsoRig
	var head: Node3D=rigs.HeadRig
	var top_y:=head.global_position.y-BODY_BRIDGE_HEAD_CLEARANCE
	var bottom_y:=torso.global_position.y-BODY_BRIDGE_TORSO_DROP
	var height:=maxf(0.58,top_y-bottom_y)
	var centre:=Vector3(lerpf(torso.global_position.x,head.global_position.x,0.30),(top_y+bottom_y)*0.5,lerpf(torso.global_position.z,head.global_position.z,0.30))
	var cylinder:=body_bridge.shape as CylinderShape3D
	cylinder.radius=BODY_BRIDGE_RADIUS;cylinder.height=height
	body_bridge.transform=hit_body.global_transform.affine_inverse()*Transform3D(Basis.IDENTITY,centre)

func build_aim(space: PhysicsDirectSpaceState3D,dt: float) -> void:
	var aim: bool=command.get("aim",false)
	camera_boom=lerpf(camera_boom,3.8 if aim else 6.4,1-exp(-12*dt))
	var view =Basis(Vector3.UP,aim_yaw)*Basis(Vector3.RIGHT,aim_pitch)
	camera_direction=-view.z
	var anchor =global_position+Vector3(0,1.05,0)
	var desired =anchor+view*Vector3(1.2,1.35,camera_boom)
	var query =PhysicsShapeQueryParameters3D.new();query.shape=probe;query.transform=Transform3D(Basis.IDENTITY,anchor)
	query.motion=desired-anchor;query.collision_mask=1;query.exclude=[get_rid()];query.margin=0.025
	var safe =space.cast_motion(query)
	var fraction: float=safe[0] if safe.size()>0 else 1.0
	if fraction<0.999: fraction=maxf(0,fraction-0.035/maxf(0.1,query.motion.length()))
	camera_fraction=fraction if fraction<camera_fraction else lerpf(camera_fraction,fraction,1-exp(-16*dt))
	camera_origin=anchor.lerp(desired,camera_fraction)
	var end =camera_origin+camera_direction*120
	var ray =PhysicsRayQueryParameters3D.create(camera_origin,end,5,[get_rid(),hit_body.get_rid()])
	ray.hit_from_inside=true
	var hit =space.intersect_ray(ray);aim_target=hit.get("position",end)
	var chest =weapon_anchor()
	var front: Vector3=(aim_target-chest).normalized()
	var right =front.cross(Vector3.UP).normalized()
	var side: float=1.0
	smoothed_weapon_side=move_toward(smoothed_weapon_side,side,maxf(0,dt)*10.0)
	var clearance: float=0.0
	var pivot =chest+front*(0.64+clearance)+right*smoothed_weapon_side
	var distance =pivot.distance_to(aim_target)
	var muzzle_length:=1.58 if weapon_slot==0 else 1.78
	var m =Vector3(0.10,0.02,-muzzle_length+maxf(0,1.92-distance))
	var local_target =Vector3(m.x,m.y,-sqrt(maxf(0.00001,distance*distance-m.x*m.x-m.y*m.y))).normalized()
	var gun_basis =Basis.looking_at(aim_target-pivot,Vector3.UP)*Basis(Quaternion(local_target,Vector3.FORWARD))
	muzzle=pivot+gun_basis*m

func weapon_anchor() -> Vector3:
	var bob: float=clampf(rigs.TorsoRig.position.y-base_torso.y,-0.1,0.1)
	return visual.to_global(Vector3(0,base_torso.y+0.8+bob*0.35,base_torso.z))

func hurt(amount: float,direction: Vector3) -> void:
	health=maxf(0,health-amount)
	var local =visual.global_basis.inverse()*direction
	recoil_velocity=(recoil_velocity+Vector3(local.z,0,-local.x)*2.8).limit_length(6.5)
	if brain!=null: brain.impulse(direction,3.2)
	if health<=0:
		collision_layer=0;hit_body.collision_layer=0;death_clock=0

func packet() -> Dictionary:
	var pose =PackedFloat32Array()
	for title in RIGS:
		var rig: Node3D=rigs[title]
		for v in [rig.position,rig.rotation,rig.scale]: pose.append_array([v.x,v.y,v.z])
	return {"id":actor_id,"bot":is_bot,"skin":skin,"p":global_position,"v":velocity,"yaw":body_yaw,
		"ay":aim_yaw,"ap":aim_pitch,"hp":health,"kills":kills,"gcd":grenade_clock,"fcd":fire_clock,"weapon":weapon_slot,
		"ammo":ammo,"reload":reload_clock,"ak_ammo":ammo_by_weapon[0],"sg_ammo":ammo_by_weapon[1],"ak_reload":reload_by_weapon[0],"sg_reload":reload_by_weapon[1],
		"ack":ack,"js":last_jump_serial,"gs":last_grenade_serial,"connected":connected,"respawn_left":maxf(0,3.0-death_clock) if health<=0 else 0.0,"pose":pose,"steps":step_count,"ground":is_on_floor(),"phase":phase}
