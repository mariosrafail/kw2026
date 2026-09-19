extends "res://scripts/prototypes/kw_3d_prototype.gd"
## The old prototype supplies rendering only. No offline combat/wave/AI simulation is started.
const MOTOR:=preload("res://scripts/kw3d/actor_motor.gd")
const CONTROLS:=preload("res://scripts/kw3d/portable_input.gd")
const LEVEL:=preload("res://scripts/kw3d/online_level.gd")
const RIG_NAMES: Array[String]=["HeadRig","TorsoRig","LeftLegRig","RightLegRig"]
var session: Node
var input_adapter: Node
var menu: Control
var options: Dictionary={}
var player_count =0
var pending: Array[Dictionary]=[]
var replicas: Dictionary={}
var flying: Dictionary={}
var state_records: Dictionary={}
var local_state: Dictionary={}
var latest_state: Dictionary={}
var inbound_state: Dictionary={}
var steady_max_correction=0.0
var corrections_over_half_meter=0
var local_jump =0
var local_grenade =0
var correction =Vector3.ZERO
var max_correction =0.0
var age =0.0
var connected_age =0.0
var last_prediction_at =-10.0
var owned_server_pid =-1
var network_status: Label
var qa_disconnected =false
var qa_rejoined =false
var qa_first_slot =0
var qa_events: Dictionary={}
var qa_did_throw =false
var pending_respawn =false
var last_health_tick =-1
var interpolation_seconds =0.05

func _menu_script() -> Script:
	return load("res://scripts/kw3d/online_menu.gd")

func _combat_script() -> Script:
	return load("res://scripts/kw3d/combat_view.gd")

func _open_menu_on_death() -> bool:
	return true

func _ready() -> void:
	_build_environment();_build_arena();_build_player()
	player.floor_snap_length=0.3;player.safe_margin=0.004
	locomotion=LOCOMOTION.new();locomotion.setup(player,player_visual,head_rig,torso_rig,left_leg_rig,right_leg_rig,137)
	_build_pixel_pass();_build_hud()
	input_adapter=CONTROLS.new()
	if options.has("profile"):input_adapter.config_path="user://kw3d_controls_"+str(options.profile).validate_filename()+".cfg"
	add_child(input_adapter)
	input_adapter.action_requested.connect(_control_action)
	input_adapter.device_lost.connect(func():set_menu(true))
	arena_audio=ARENA_AUDIO.new();add_child(arena_audio);arena_audio.setup(self)
	combat=_combat_script().new();add_child(combat);combat.setup(self)
	grenade_skill=load("res://scripts/kw3d/grenade_view.gd").new();add_child(grenade_skill);grenade_skill.setup(self)
	session.welcomed.connect(_welcome)
	session.state_received.connect(_snapshot)
	session.combat_event.connect(_event)
	session.connection_message.connect(_connection_message)
	var layer =CanvasLayer.new();layer.layer=30;add_child(layer)
	menu=_menu_script().new();layer.add_child(menu);menu.setup(self)
	network_status=Label.new();network_status.position=Vector2(12,108);network_status.add_theme_font_size_override("font_size",10)
	help_panel.add_child(network_status)
	for c in help_panel.get_children():
		if c is Label and "WASD" in c.text:c.text="WASD / left stick move   MOUSE / right stick look\nLMB / RT fire   RMB / LT aim   R / X reload   WHEEL weapon   G / RB grenade\nSpace / A jump   Q / R3 shoulder   Y Borderlands edges   Esc / Start menu"
	set_menu(true)
	if options.has("connect") or options.has("qa-client"):
		connect_server(str(options.get("host","127.0.0.1")),int(options.get("port","18886")))

func _unhandled_input(_event: InputEvent) -> void:pass
func _control_action(action: String) -> void:
	match action:
		"pause":set_menu(not menu.visible)
		"help":_toggle_instructions()
		"music":arena_audio.toggle_music()
		"comic":_set_comic_enabled(not comic_enabled)
		"pixels":_set_pixel_enabled(not pixel_enabled)
		"borderlands":_set_borderlands_enabled(not borderlands_enabled)
		"weapon":_set_weapon_slot(input_adapter.weapon_slot,true)

func set_menu(opened: bool) -> void:
	if input_adapter==null:return
	if opened:
		input_adapter.suspend();fire_held=false;aiming=false
		if menu!=null:menu.open()
		if combat!=null and combat.director!=null:combat.director.hud.game_over_panel.hide()
		if not options.has("qa-client"):Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	else:
		if not session.connected:return
		menu.hide();input_adapter.enabled=not combat.is_game_over()
		if not OS.get_cmdline_user_args().has("--kw-qa"):Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func connect_server(host: String,port: int) -> void:
	set_menu(true)
	var error: Error=session.join(host,port,str(options.get("name","Outrage")))
	if error!=OK:menu.message.text="Connection could not start: "+str(error)

func start_local_session() -> void:
	if options.has("qa-client"):return # Automated network fixtures never start a second authority.
	var port_value =int(menu.port.value)
	if owned_server_pid<0 or not OS.is_process_running(owned_server_pid):
		var args =PackedStringArray(["--headless","--path",ProjectSettings.globalize_path("res://"),"res://scenes/prototypes/kw_3d_multiplayer.tscn","--","--kw-server","--kw-port="+str(port_value),"--kw-bind=127.0.0.1","--kw-idle-exit=120"])
		owned_server_pid=OS.create_process(OS.get_executable_path(),args,false)
		if owned_server_pid<0:menu.message.text="Could not start local server.";return
	menu.message.text="Starting local authority..."
	await get_tree().create_timer(0.7).timeout
	if is_inside_tree():connect_server("127.0.0.1",port_value)

func _connection_message(text: String) -> void:
	if network_status!=null:network_status.text=text
	if not session.connected:
		input_adapter.suspend();fire_held=false
		set_menu(true)

func _welcome(payload: Dictionary) -> void:
	DisplayServer.window_set_title("KW 3D CO-OP | PLAYER %d"%payload.slot)
	if payload.match!=latest_state.get("match",""):clear_session_view()
	last_health_tick=-1
	if qa_first_slot==0:qa_first_slot=payload.slot
	elif payload.slot==qa_first_slot:qa_rejoined=true
	input_adapter.sequence=payload.ack
	input_adapter.jump_serial=payload.js;input_adapter.grenade_serial=payload.gs
	local_jump=payload.js;local_grenade=payload.gs
	pending.clear();correction=Vector3.ZERO;connected_age=0
	for state in payload.state.actors:
		if state.id==session.actor_id:
			player.global_position=state.p;player.velocity=state.v
			player.set_meta("motor_grounded",bool(state.ground))
			input_adapter.yaw=state.ay;input_adapter.pitch=state.ap;input_adapter.weapon_slot=int(state.get("weapon",0))
			input_adapter.reset_weapon_recoil()
			_set_authoritative_weapon_state(state,true)
			locomotion.reset();break
	set_menu(false)

func clear_session_view() -> void:
	for r in replicas.values():
		if is_instance_valid(r.node):r.node.queue_free()
	replicas.clear();combat.targets.clear();state_records.clear();pending.clear();player_count=0

func _physics_process(delta: float) -> void:
	age+=delta
	if not inbound_state.is_empty():
		var accepted: Dictionary=inbound_state;inbound_state={}
		_apply_snapshot(accepted)
	if options.has("qa-client"):_qa_tick(delta)
	if not session.connected:return
	connected_age+=delta
	var dt =1.0/60.0
	input_adapter.fov=camera.fov
	var command: Dictionary=input_adapter.sample(dt)
	command.ct=maxi(0,session.last_snapshot_tick-3)
	_tick_reload(dt)
	if bool(command.get("reload",false)):_start_reload()
	if options.has("qa-client"):_qa_command(command)
	if combat.is_game_over():command.move=Vector2.ZERO;command.fire=false
	if int(command.get("weapon",weapon_slot))!=weapon_slot:_set_weapon_slot(int(command.weapon),false)
	yaw=command.yaw;pitch=command.pitch;aiming=command.aim;fire_held=command.fire;weapon_side=command.side
	camera_yaw.rotation.y=yaw;camera_pitch.rotation.x=pitch
	var simulation =command.duplicate()
	simulation.jump=int(command.js)>local_jump;local_jump=command.js
	animation_impact_velocity=player.velocity.y
	MOTOR.step(player,simulation,dt)
	pending.append(command.duplicate())
	while pending.size()>180:pending.pop_front()
	var batch: Array=[]
	for i in range(maxi(0,pending.size()-4),pending.size()):batch.append(pending[i])
	session.send_frames(batch)
	var desired: Vector3=Basis(Vector3.UP,yaw)*Vector3(command.move.x,0,-command.move.y)
	if aiming or fire_held:desired=-Basis(Vector3.UP,yaw).z
	if desired.length_squared()>0.001:body_yaw=lerp_angle(body_yaw,atan2(-desired.x,-desired.z),minf(1,10*dt))
	player_visual.rotation.y=body_yaw
	correction=correction.lerp(Vector3.ZERO,1-exp(-18*dt))
	player_visual.position=correction
	camera_yaw.position=Vector3(0,1.05,0)+correction
	_update_third_person_camera(dt);_update_character_animation(dt);_update_weapon_pose(dt)
	shot_cooldown=maxf(-dt,shot_cooldown-dt)
	if fire_held:_fire_physics_ball()
	network_status.text="PLAYER %d   |   RTT %.0f ms   |   %s"%[session.actor_id,session.rtt_ms,"PAD" if input_adapter.last_device=="pad" else "MOUSE"]

func _fire_physics_ball() -> void:
	if not session.connected or combat.is_game_over() or shot_cooldown>0.00001:return
	if reload_remaining>0.0:return
	if ammo_in_mag<=0:
		_start_reload();return
	var profile: Dictionary=WEAPON_RULES.by_slot(weapon_slot)
	ammo_in_mag-=1;_refresh_ammo_hud();shot_cooldown+=float(profile.fire_interval)
	_kick_weapon_visuals();_apply_body_fire_recoil(yaw);_play_weapon_fire_audio();_spawn_muzzle_flash();combat.reticle.notify_shot()
	var kick: Vector2=input_adapter.apply_weapon_recoil(aiming)
	if weapon_slot==1:
		kick+=input_adapter.apply_weapon_recoil(aiming)
	yaw=input_adapter.yaw;pitch=input_adapter.pitch
	camera_yaw.rotation.y=yaw;camera_pitch.rotation.x=pitch
	last_prediction_at=age;input_adapter.rumble(0.42 if weapon_slot==1 else 0.24,0.11 if weapon_slot==1 else 0.08)
	if ammo_in_mag<=0:_start_reload()

func _snapshot(snapshot: Dictionary) -> void:
	# Network polling may happen outside physics. Replay must only run in a fixed physics tick.
	inbound_state=snapshot

func _apply_snapshot(snapshot: Dictionary) -> void:
	latest_state=snapshot
	var present: Dictionary={}
	player_count=0
	for state in snapshot.actors:
		var id: int=state.id
		present[id]=true;state_records[id]=state
		if not state.bot and state.connected:player_count+=1
		if id==session.actor_id:
			local_state=state
			if int(state.ack)>input_adapter.sequence:input_adapter.sequence=int(state.ack)
			var old =player.global_position
			player.global_position=state.p;player.velocity=state.v
			player.set_meta("motor_grounded",bool(state.ground))
			while not pending.is_empty() and int(pending[0].seq)<=int(state.ack):pending.pop_front()
			var jump_seen =int(state.get("js",local_jump))
			for command in pending:
				var replay: Dictionary=command.duplicate()
				replay.jump=int(command.js)>jump_seen;jump_seen=maxi(jump_seen,command.js)
				MOTOR.step(player,replay,1.0/60.0)
			var difference =old-player.global_position
			max_correction=maxf(max_correction,difference.length())
			if connected_age>1.0:
				steady_max_correction=maxf(steady_max_correction,difference.length())
				if difference.length()>0.5:
					corrections_over_half_meter+=1
					if options.has("qa-client"):print("CORRECTION_DEBUG ",age," ack=",state.ack," diff=",difference," server_p=",state.p," v=",state.v," js=",state.js," pending=",pending.size()," floor=",state.ground)
			if difference.length()<1.8:correction=(correction+difference).limit_length(0.45)
			else:correction=Vector3.ZERO;locomotion.reset()
			grenade_skill.set_cooldown(state.gcd)
			_set_authoritative_weapon_state(state,false)
			var predicted_slot:=int(state.get("weapon",weapon_slot))
			if not pending.is_empty():predicted_slot=int((pending.back() as Dictionary).get("weapon",predicted_slot))
			if predicted_slot!=weapon_slot:_set_weapon_slot(predicted_slot,false)
			input_adapter.weapon_slot=predicted_slot
			if snapshot.tick>=last_health_tick:combat.apply_status(snapshot,state)
			continue
		if not replicas.has(id):
			if state.hp<=0:continue
			_make_replica(state)
		var r: Dictionary=replicas[id]
		if not is_instance_valid(r.node):continue
		r.prev=_current_pose(r,state)
		r.next=state;r.age=0.0
	for id in replicas.keys():
		if not present.has(id):
			var record: Dictionary=replicas[id]
			if is_instance_valid(record.node):record.node.queue_free()
			replicas.erase(id);state_records.erase(id)
	_sync_projectiles(snapshot)
	combat._update_counter()

func _current_pose(record: Dictionary,fallback: Dictionary) -> Dictionary:
	var s: Dictionary=fallback.duplicate()
	s.p=record.node.global_position;s.yaw=record.visual.rotation.y
	var values =PackedFloat32Array()
	for title in RIG_NAMES:
		var r: Node3D=record.rigs[title]
		for v in [r.position,r.rotation,r.scale]:values.append_array([v.x,v.y,v.z])
	s.pose=values
	return s

func _make_replica(state: Dictionary) -> void:
	var node: Node3D
	var visual: Node3D
	var style: Node3D
	var rig_nodes: Dictionary={}
	var gun: Node3D=null
	var ak_body: Node3D=null
	var shotgun_body: Node3D=null
	if state.bot:
		node=load("res://scripts/prototypes/kw_training_dummy.gd").new()
		node.warrior_id=state.skin;node.roaming_enabled=false;node.position=state.p
		add_child(node);node.set_physics_process(false)
		node.movement_body.collision_layer=8;node.movement_body.collision_mask=0
		visual=node.visuals;style=node
		for title in RIG_NAMES:rig_nodes[title]=visual.get_node(title)
		combat.targets.append(node)
	else:
		node=Node3D.new();add_child(node);node.position=state.p
		visual=Node3D.new();node.add_child(visual)
		style=OUTRAGE_FULLBODY.instantiate();visual.add_child(style)
		for title in RIG_NAMES:rig_nodes[title]=style.get_node(title)
		var tag =Label3D.new();tag.text="ALLY / OUTRAGE %d"%state.id;tag.font_size=36;tag.outline_size=6;tag.modulate=Color("8ef1de");tag.billboard=BaseMaterial3D.BILLBOARD_ENABLED;tag.position=Vector3(0,2.1,0);node.add_child(tag)
		gun=Node3D.new();gun.name="RemoteAK";visual.add_child(gun);gun.position=Vector3(-1.10,torso_rest.y+0.88,-0.98)
		ak_body=Node3D.new();ak_body.name="RemoteAKBody";ak_body.rotation.y=PI*0.5;ak_body.position=Vector3(0.10,0,-0.30);gun.add_child(ak_body)
		AK47_VOXEL_BUILDER.build(ak_body)
		var hand := MeshInstance3D.new()
		hand.name="RemoteRightHand"
		var hand_box := BoxMesh.new();hand_box.size=Vector3(0.22,0.22,0.28)
		hand.mesh=hand_box;hand.position=Vector3(0.31,-0.07,-0.50)
		hand.material_override=_material(Color(0.56,0.11,0.15),false,0.0)
		gun.add_child(hand);_add_scene_outline(hand,1.6)
		var gun_materials: Dictionary={}
		for part in ak_body.get_children():
			if not part is MeshInstance3D:continue
			var original: StandardMaterial3D=part.material_override
			var key: int=original.get_instance_id()
			if not gun_materials.has(key):
				var mat: ShaderMaterial=PIXEL_MATERIALS.from_standard(original,0.025)
				mat.set_shader_parameter("comic_enabled",comic_enabled);mat.set_shader_parameter("pixel_enabled",pixel_enabled)
				gun_materials[key]=mat;pixel_materials.append(weakref(mat))
			part.material_override=gun_materials[key]
		var outline =MeshInstance3D.new();outline.name="WorldInkOutline";outline.mesh=AK_INK_HULL
		var ink =ShaderMaterial.new();ink.shader=load("res://scripts/prototypes/kw_comic_ink.gdshader");ink.set_shader_parameter("width_pixels",1.6)
		outline.material_override=ink;outline.visible=comic_enabled;outline.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ak_body.add_child(outline);outline.add_to_group("kw_world_ink")
		shotgun_body=Node3D.new();shotgun_body.name="RemoteShotgunBody";shotgun_body.rotation.y=PI*0.5;shotgun_body.position=Vector3(0.10,0,-0.30);gun.add_child(shotgun_body)
		_add_weapon_box(shotgun_body,"SG_Stock",Vector3(-0.36,-0.02,0),Vector3(0.62,0.22,0.24),Color("6d4030"))
		_add_weapon_box(shotgun_body,"SG_Receiver",Vector3(0.18,0.01,0),Vector3(0.62,0.25,0.22),Color("30343b"))
		_add_weapon_box(shotgun_body,"SG_Barrel",Vector3(0.88,0.055,0),Vector3(0.92,0.12,0.14),Color("b7c0c8"))
		_add_weapon_box(shotgun_body,"SG_Pump",Vector3(0.62,-0.09,0),Vector3(0.42,0.18,0.25),Color("8a5238"))
		shotgun_body.visible=int(state.get("weapon",0))==1;ak_body.visible=not shotgun_body.visible
	var record: Dictionary={"node":node,"visual":visual,"style":style,"rigs":rig_nodes,"next":state,"prev":state,"age":0.05,"bot":state.bot,"steps":state.steps,"dead":false,
		"gun":gun,"ak_body":ak_body,"shotgun_body":shotgun_body,
		"hit_punch":0.0,"hit_sign":1.0,"hit_seed":0.0}
	replicas[state.id]=record
	_apply_replica(record,1.0)
	if state.bot:node.set_style(comic_enabled,pixel_enabled)
	else:style.set_enabled(comic_enabled);style.set_pixel_enabled(pixel_enabled)

func _apply_replica(r: Dictionary,alpha: float) -> void:
	if not is_instance_valid(r.node) or r.dead:return
	var a: Dictionary=r.prev
	var b: Dictionary=r.next
	r.node.global_position=(a.p as Vector3).lerp(b.p,alpha)
	r.visual.rotation.y=lerp_angle(a.yaw,b.yaw,alpha)
	var first: PackedFloat32Array=a.pose
	var second: PackedFloat32Array=b.pose
	for index in range(4):
		var rig: Node3D=r.rigs[RIG_NAMES[index]]
		var k =index*9
		rig.position=Vector3(first[k],first[k+1],first[k+2]).lerp(Vector3(second[k],second[k+1],second[k+2]),alpha)
		rig.quaternion=Quaternion.from_euler(Vector3(first[k+3],first[k+4],first[k+5])).slerp(Quaternion.from_euler(Vector3(second[k+3],second[k+4],second[k+5])),alpha)
		rig.scale=Vector3(second[k+6],second[k+7],second[k+8])
	if r.bot:
		r.node.movement_body.global_position=r.node.global_position
		if b.hp<r.node.health:r.node.health=b.hp;r.node._refresh_bar()
		r.node._update_shapes()
	else:
		var gun: Node3D=r.gun
		var selected_weapon:=clampi(int(b.get("weapon",0)),0,1)
		r.ak_body.visible=selected_weapon==0;r.shotgun_body.visible=selected_weapon==1
		var phase_value := float(b.get("phase",0.0))*TAU
		var remote_roll := sin(phase_value+1.2)*0.085
		var remote_pitch := sin(phase_value*1.7+0.4)*0.035
		gun.position=Vector3(-1.10,torso_rest.y+0.88+sin(phase_value)*0.035,-0.98)
		gun.global_rotation=Vector3(float(b.ap)+remote_pitch,float(b.ay),remote_roll)
	if int(b.steps)>int(r.steps) and r.node.global_position.distance_to(player.global_position)<16:
		r.steps=b.steps
		arena_audio._play_spatial(arena_audio.STEPS[int(b.steps)%4],r.rigs.LeftLegRig.global_position,-26.0,1.0)

func _process(delta: float) -> void:
	for r in replicas.values():
		if not is_instance_valid(r.node):continue
		r.age+=delta
		_apply_replica(r,clampf(r.age/interpolation_seconds,0,1))
		if r.bot and not r.dead:
			r.node._update_readability(delta)
		elif not r.bot:
			var punch := float(r.get("hit_punch",0.0))
			if punch > 0.0:
				var sign := float(r.get("hit_sign",1.0))
				var seed := float(r.get("hit_seed",0.0))
				var torso: Node3D = r.rigs.TorsoRig
				var head: Node3D = r.rigs.HeadRig
				var kick := punch * punch
				torso.rotation.z += sign * kick * 0.24
				torso.rotation.x += sin(seed + punch * 5.0) * kick * 0.12
				head.rotation.z -= sign * kick * 0.38
				head.rotation.x += kick * 0.18
				r.visual.position += Vector3(sign * 0.025 * kick,0.018 * sin(punch*PI),-0.045 * kick)
				r.hit_punch = maxf(0.0,punch-delta*7.6)
	if menu!=null and menu.visible:menu.refresh()
	for record in flying.values():
		if is_instance_valid(record.node):
			record.node.global_position=record.node.global_position.lerp(record.p,1-exp(-35*delta))
			record.node.rotation+=Vector3(3,2,4)*delta

func _sync_projectiles(snapshot: Dictionary) -> void:
	var seen: Dictionary={}
	for group in [snapshot.grenades,snapshot.bolts]:
		for p in group:
			var grenade: bool=p.has("fuse")
			var id: String=("g" if grenade else "b")+str(p.id);seen[id]=true
			if not flying.has(id):
				var mesh =MeshInstance3D.new();var box =BoxMesh.new();box.size=Vector3(0.28,0.32,0.28) if grenade else Vector3(0.12,0.12,0.4)
				mesh.mesh=box;mesh.material_override=_material(Color("537668") if grenade else Color("ff6949"),not grenade,0.6);add_child(mesh)
				mesh.global_position=p.p;_add_scene_outline(mesh,1.4)
				flying[id]={"node":mesh,"p":p.p}
			flying[id].p=p.p
	for id in flying.keys():
		if not seen.has(id):flying[id].node.queue_free();flying.erase(id)

func _event(e: Dictionary) -> void:
	qa_events[e.type]=int(qa_events.get(e.type,0))+1
	match str(e.type):
		"shot":
			if not e.blocked:combat._spawn_tracer(e.from,e.to)
			if bool(e.get("hit",false)):combat._spawn_impact(e.to,e.get("normal",Vector3.UP))
			if e.actor!=session.actor_id:
				combat._spawn_world_muzzle_flash(e.from,(e.to-e.from).normalized())
				arena_audio._play_spatial(AK47_SHOT_SFX,e.from,-14.0,randf_range(0.96,1.04))
		"shotgun":
			for pellet in e.pellets:
				combat._spawn_tracer(e.from,pellet.to)
				if bool(pellet.get("hit",false)):combat._spawn_impact(pellet.to,pellet.get("normal",Vector3.UP))
			if e.actor!=session.actor_id:
				var first_to: Vector3=e.pellets[0].to if not e.pellets.is_empty() else e.from-Vector3.FORWARD
				combat._spawn_world_muzzle_flash(e.from,(first_to-e.from).normalized())
				arena_audio._play_spatial(SHOTGUN_FIRE_SFX,e.from,-11.0,randf_range(0.78,0.86))
		"damage":
			var victim_skin := "outrage"
			if int(e.actor)==session.actor_id:
				victim_skin=str(local_state.get("skin","outrage"))
			elif state_records.has(e.actor):
				victim_skin=str((state_records[e.actor] as Dictionary).get("skin","outrage"))
			combat._spawn_damage_feedback(e.p,e.dir,e.amount,e.lethal,combat.blood_color_for_skin(victim_skin),e.owner==session.actor_id)
			if e.owner==session.actor_id:
				combat.notify_hit(e.p,e.dir,e.amount,e.lethal)
			if e.actor==session.actor_id:
				last_health_tick=e.tick;combat.director.health=e.hp;combat.director.dead=e.lethal
				_set_player_healthbar(e.hp,100.0)
				combat.director.hud.set_health(e.hp,100);combat.director.hud.notify_hurt(e.amount);input_adapter.rumble(0.65,0.15)
				var local_dir: Vector3 = player_visual.global_basis.inverse() * (e.dir as Vector3)
				if locomotion != null:
					locomotion.body_angular_velocity += Vector3(local_dir.z,0,-local_dir.x) * 1.15
				head_spring_velocity += Vector3(local_dir.z*0.18,0,-local_dir.x*0.25)
				if e.lethal and _open_menu_on_death():input_adapter.suspend();set_menu(true)
			elif replicas.has(e.actor):
				var r: Dictionary=replicas[e.actor]
				if is_instance_valid(r.node):
					if r.bot:
						r.node.set_attack_warning(false)
						r.node.health=e.hp
						r.node._refresh_bar()
						r.node.show_network_hit(e.dir,e.lethal)
						if e.lethal:
							r.dead=true
							r.node.set_physics_process(true)
					else:
						r.hit_punch = 1.0
						r.hit_sign = -1.0 if (int(e.actor)+int(qa_events.get("damage",0))) % 2 == 0 else 1.0
						r.hit_seed = randf_range(0.0,TAU)
		"kill":
			if e.owner==session.actor_id:
				last_health_tick=e.tick;combat.total_kills=e.kills;combat.score_pulse=0.65
				combat.director.health=e.hp;combat.director.hud.set_health(e.hp,100);combat.director.hud.notify_heal(e.heal)
				if float(e.get("heal",0.0))>0.0:arena_audio.play_event("heal")
				combat._update_counter()
		"explosion":grenade_skill.show_blast(e.p)
		"reload":
			var reload_slot:=clampi(int(e.get("weapon",0)),0,1)
			if int(e.actor)!=session.actor_id:
				arena_audio._play_spatial(AK47_RELOAD_SFX if reload_slot==0 else SHOTGUN_RELOAD_SFX,e.p,-17.0,1.0)
			elif reload_by_weapon[reload_slot]<=0.0:
				ammo_by_weapon[reload_slot]=int(e.get("ammo",ammo_by_weapon[reload_slot]))
				reload_by_weapon[reload_slot]=float(e.get("duration",WEAPON_RULES.by_slot(reload_slot).reload))
				if reload_slot==weapon_slot:
					var reload_audio:=ak_reload_audio if reload_slot==0 else shotgun_reload_audio
					if reload_audio!=null:reload_audio.play()
					_spawn_reload_magazine();_refresh_ammo_hud()
		"throw":arena_audio.play_event("throw",e.p,-14)
		"bounce":arena_audio.play_event("bounce",e.p,-19)
		"wave":combat.director.hud.announce("WAVE %02d"%e.wave,"ONLINE CO-OP  /  %d ENEMIES"%e.budget);arena_audio.play_event("wave")
		"clear":combat.director.hud.announce("WAVE CLEAR","NEXT WAVE IN 4 SECONDS");arena_audio.play_event("wave")
		"warning":
			if replicas.has(e.actor):replicas[e.actor].node.set_attack_warning(true);replicas[e.actor].node.aim_weapon(e.target)
		"warning_end":
			if replicas.has(e.actor) and is_instance_valid(replicas[e.actor].node):replicas[e.actor].node.set_attack_warning(false)
		"hostile_shot":
			if replicas.has(e.owner):replicas[e.owner].node.set_attack_warning(false);replicas[e.owner].node.notify_enemy_fire()
		"respawn":
			if e.actor==session.actor_id:combat.director.dead=false;last_health_tick=e.tick;combat.director.hud.reset_run();set_menu(false)

func _flash_end(bot: Node3D) -> void:
	await get_tree().create_timer(0.075).timeout
	if is_instance_valid(bot):
		bot.flash_time=0
		for material in bot.records:material.mesh.material_overlay=null

func _set_comic_enabled(value: bool) -> void:
	super._set_comic_enabled(value)
	for r in replicas.values():
		if is_instance_valid(r.node) and not r.bot:r.style.set_enabled(value)
func _set_pixel_enabled(value: bool) -> void:
	super._set_pixel_enabled(value)
	for r in replicas.values():
		if is_instance_valid(r.node) and not r.bot:r.style.set_pixel_enabled(value)

func _notification(what: int) -> void:
	if input_adapter==null:return
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and not options.has("qa-client"):
		input_adapter.focused=false;set_menu(true)
	elif what==NOTIFICATION_WM_WINDOW_FOCUS_IN:input_adapter.focused=true

func _qa_tick(_delta: float) -> void:pass
func _qa_command(_command: Dictionary) -> void:pass
