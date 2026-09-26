extends "res://scripts/prototypes/kw_3d_prototype.gd"
## The old prototype supplies rendering only. No offline combat/wave/AI simulation is started.
const MOTOR:=preload("res://scripts/kw3d/actor_motor.gd")
const CONTROLS:=preload("res://scripts/kw3d/portable_input.gd")
const LEVEL:=preload("res://scripts/kw3d/online_level.gd")
const RIG_NAMES: Array[String]=["HeadRig","TorsoRig","LeftLegRig","RightLegRig"]
const REMOTE_FULL_ANIM_DISTANCE:=34.0
const REMOTE_REDUCED_ANIM_DISTANCE:=58.0
var session: Node
var input_adapter: Node
var menu: Control
var options: Dictionary={}
var player_count =0
var pending: Array[Dictionary]=[]
var pending_head:=0
var replay_command_scratch: Dictionary={}
var replica_removal_scratch: Array=[]
var flying_removal_scratch: Array=[]
var tracer_removal_scratch: Array=[]
var present_actor_scratch: Dictionary={}
var replicas: Dictionary={}
var flying: Dictionary={}
var projectile_visual_pool: Dictionary={"grenade":[],"launcher":[],"bolt":[]}
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
var current_input_sequence := 0
var local_tracer_predictions: Dictionary = {}
var menu_refresh_clock := 0.0
var network_status_clock := 0.0
var death_camera_active := false
var death_camera_target_id := 0
var death_camera_age := 0.0
var death_camera_anchor := Vector3.ZERO
var death_camera_position := Vector3.ZERO
var death_camera_side := 1.0

func _menu_script() -> Script:
	return load("res://scripts/kw3d/online_menu.gd")

func _combat_script() -> Script:
	return load("res://scripts/kw3d/combat_view.gd")

func _open_menu_on_death() -> bool:
	return true

func _ready() -> void:
	var requested_warrior := _initial_online_warrior_id()
	if requested_warrior in ["outrage","erebus","kosas","aevilok","loker"]:
		player_warrior_id = requested_warrior
	if player_warrior_id == "outrage":
		outrage_skin_id = clampi(int(ProjectSettings.get_setting("kw3d/selected_outrage_skin", outrage_skin_id)),0,OUTRAGE_SKINS.skin_count()-1)
	elif player_warrior_id == "erebus":
		erebus_skin_id = clampi(int(ProjectSettings.get_setting("kw3d/selected_erebus_skin", erebus_skin_id)),0,EREBUS_SKINS.skin_count()-1)
	_build_environment();_build_arena();_build_player()
	_set_player_virtual_name(str(options.get("name",VIRTUAL_PROFILE.local_username())))
	player.floor_snap_length=0.3;player.safe_margin=0.004
	locomotion=LOCOMOTION.new();locomotion.setup(player,player_visual,head_rig,torso_rig,left_leg_rig,right_leg_rig,137)
	_build_pixel_pass();_build_hud()
	input_adapter=CONTROLS.new()
	if options.has("profile"):input_adapter.config_path="user://kw3d_controls_"+str(options.profile).validate_filename()+".cfg"
	add_child(input_adapter)
	input_adapter.action_requested.connect(_control_action)
	input_adapter.device_lost.connect(func():set_menu(true))
	arena_audio=ARENA_AUDIO.new();add_child(arena_audio);arena_audio.setup(self)
	# Remote actors are driven by authoritative snapshots below, so their movement
	# sounds are emitted here from their replicated feet instead of the offline bot loop.
	arena_audio.track_combat_targets=false
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
		if c is Label and "WASD" in c.text:c.text="WASD / left stick move   MOUSE / right stick look\nLMB / RT fire   RMB / LT aim+magnet   R / X reload   WHEEL weapon   H inspect\nE / LB warrior skill   G / RB grenade   KAR: scope/no magnet   Y edges   Esc / Start menu"
	set_menu(true)
	if options.has("connect") or options.has("qa-client"):
		connect_server(str(options.get("host","127.0.0.1")),int(options.get("port","18886")))

func _initial_online_warrior_id() -> String:
	return str(ProjectSettings.get_setting("kw3d/selected_warrior_id",player_warrior_id)).strip_edges().to_lower()

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
		"inspect":_start_weapon_inspect()
		"skill":
			if session.connected:session.request_duel_skill()

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
	var error: Error=session.join(host,port,str(options.get("name","Outrage")),player_warrior_id)
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
	_pending_clear();correction=Vector3.ZERO;connected_age=0
	for state in payload.state.actors:
		if state.id==session.actor_id:
			_set_player_virtual_name(str(state.get("name",options.get("name","KW_ROOKIE"))))
			player.global_position=state.p;player.velocity=state.v
			player.set_meta("motor_grounded",bool(state.ground))
			input_adapter.yaw=state.ay;input_adapter.pitch=state.ap;input_adapter.weapon_slot=int(state.get("weapon",0))
			input_adapter.reset_weapon_recoil()
			_set_authoritative_weapon_state(state,true)
			_style_local_human(head_style,state)
			locomotion.reset();break
	set_menu(false)

func clear_session_view() -> void:
	for id in replicas:
		var r: Dictionary=replicas[id]
		if is_instance_valid(r.node):r.node.queue_free()
	replicas.clear();combat.targets.clear();state_records.clear();_pending_clear();local_tracer_predictions.clear();player_count=0

func _pending_count() -> int:
	return pending.size()-pending_head

func _pending_clear() -> void:
	pending.clear();pending_head=0

func _pending_compact() -> void:
	if pending_head<96 or pending_head*2<pending.size():return
	var compacted: Array[Dictionary]=[]
	for index in range(pending_head,pending.size()):compacted.append(pending[index])
	pending=compacted;pending_head=0

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
	current_input_sequence=int(command.get("seq",0))
	if options.has("qa-client"):_qa_command(command)
	_apply_online_aim_assist(command,dt)
	_apply_online_sniper_sway(command,dt)
	command.ct=maxi(0,session.last_snapshot_tick-3)
	_tick_reload(dt)
	if bool(command.get("reload",false)):_start_reload()
	if combat.is_game_over():command.move=Vector2.ZERO;command.fire=false
	if int(command.get("weapon",weapon_slot))!=weapon_slot:_set_weapon_slot(int(command.weapon),false)
	yaw=command.yaw;pitch=command.pitch;aiming=command.aim;fire_held=command.fire;weapon_side=1.0;command.side=1.0
	if aiming and weapon_slot==2:command.sprint=false
	visual_sprinting=bool(command.get("sprint",false))
	camera_yaw.rotation.y=yaw;camera_pitch.rotation.x=pitch
	command.jump=int(command.js)>local_jump;local_jump=command.js
	_decorate_prediction(command,dt)
	animation_impact_velocity=player.velocity.y
	MOTOR.step(player,command,dt)
	_after_prediction_step(dt)
	pending.append(command)
	if _pending_count()>180:pending_head+=_pending_count()-180
	_pending_compact()
	session.send_frames(pending)
	var desired: Vector3=Basis(Vector3.UP,yaw)*Vector3(command.move.x,0,-command.move.y)
	if aiming or fire_held:desired=-Basis(Vector3.UP,yaw).z
	if desired.length_squared()>0.001:body_yaw=lerp_angle(body_yaw,atan2(-desired.x,-desired.z),minf(1,10*dt))
	player_visual.rotation.y=body_yaw
	correction=correction.lerp(Vector3.ZERO,1-exp(-18*dt))
	player_visual.position=correction
	camera_yaw.position=Vector3(0,1.05,0)+correction
	_update_third_person_camera(dt);_update_character_animation(dt);_update_weapon_pose(dt)
	if death_camera_active:_update_death_camera(dt)
	shot_cooldown=maxf(-dt,shot_cooldown-dt)
	if fire_held:_fire_physics_ball()
	network_status_clock-=delta
	if network_status_clock<=0.0:
		network_status_clock=0.20
		network_status.text="PLAYER %d   |   RTT %.0f ms   |   %s%s"%[session.actor_id,session.rtt_ms,"PAD" if input_adapter.last_device=="pad" else "MOUSE","   |   MAGNET" if aim_assist_active else ""]

func _decorate_prediction(_simulation: Dictionary,_dt: float) -> void:pass
func _after_prediction_step(_dt: float) -> void:pass
func _style_local_human(_style: Node3D,_state: Dictionary) -> void:pass
func _style_remote_human(_style: Node3D,_state: Dictionary) -> void:pass

func _start_death_camera(killer_id: int,death_point: Vector3) -> void:
	death_camera_active=true
	death_camera_target_id=killer_id
	death_camera_age=0.0
	death_camera_anchor=death_point
	death_camera_position=camera.global_position if camera!=null else death_point+Vector3(0,2.2,4.5)
	death_camera_side=-1.0 if (killer_id+session.actor_id)%2==0 else 1.0
	aiming=false;fire_held=false
	if input_adapter!=null:input_adapter.suspend()
	var killer_name:=_actor_display_name(killer_id)
	if combat!=null and combat.director!=null and combat.director.hud!=null:
		combat.director.hud.announce("ELIMINATED BY  "+killer_name.to_upper(),"FOLLOWING THE ACTION",1.9)

func _stop_death_camera() -> void:
	death_camera_active=false
	death_camera_target_id=0
	death_camera_age=0.0
	if input_adapter!=null and session!=null and session.connected and (menu==null or not menu.visible):
		input_adapter.enabled=true

func _death_camera_target() -> Vector3:
	if death_camera_target_id==session.actor_id and head_rig!=null:
		return head_rig.global_position+Vector3.UP*0.18
	if death_camera_target_id>0 and replicas.has(death_camera_target_id):
		var r: Dictionary=replicas[death_camera_target_id]
		if is_instance_valid(r.node):
			var head:=r.rigs.get("HeadRig") as Node3D
			if head!=null:return head.global_position+Vector3.UP*0.18
			return r.node.global_position+Vector3.UP*1.25
	return death_camera_anchor+Vector3.UP*1.0

func _update_death_camera(dt: float) -> void:
	if camera==null:return
	death_camera_age+=dt
	var target:=_death_camera_target()
	var from_death:=death_camera_anchor-target
	from_death.y=0.0
	if from_death.length_squared()<0.25:
		from_death=Vector3(0,0,1)
	from_death=from_death.normalized()
	var tangent:=Vector3(-from_death.z,0,from_death.x)*death_camera_side
	var orbit:=sin(minf(death_camera_age,2.4)*0.72)*0.85
	var desired:=target+from_death*4.7+tangent*orbit+Vector3.UP*(2.15+0.18*sin(death_camera_age*0.8))
	var weight:=1.0-exp(-4.8*maxf(dt,0.0))
	death_camera_position=death_camera_position.lerp(desired,weight)
	camera.global_position=death_camera_position
	camera.look_at(target,Vector3.UP)
	camera.fov=lerpf(camera.fov,61.0,1.0-exp(-3.6*maxf(dt,0.0)))

func _aim_assist_is_hostile(state: Dictionary) -> bool:
	return bool(state.get("bot",false)) and float(state.get("hp",0.0))>0.0

func _best_online_aim_assist_target(command: Dictionary) -> Vector3:
	if camera==null:return Vector3(INF,INF,INF)
	var best_point:=Vector3(INF,INF,INF)
	var camera_position:=camera.global_position
	var cyaw:=float(command.get("yaw",input_adapter.yaw))
	var cpitch:=float(command.get("pitch",input_adapter.pitch))
	var forward:=AIM_ASSIST.forward(cyaw,cpitch)
	var best_alignment:=cos(deg_to_rad(AIM_ASSIST.CONE_DEG))
	var max_range_sq:=AIM_ASSIST.MAX_RANGE*AIM_ASSIST.MAX_RANGE
	for id in replicas:
		var record: Dictionary=replicas[id]
		if not is_instance_valid(record.node) or bool(record.get("dead",false)):continue
		var state: Dictionary=record.get("next",{})
		if not _aim_assist_is_hostile(state):continue
		var torso:=record.rigs.get("TorsoRig") as Node3D
		if torso==null:continue
		var point:=torso.global_position+Vector3.UP*0.34
		var offset:=point-camera_position
		var distance_sq:=offset.length_squared()
		if distance_sq<=0.0001 or distance_sq>max_range_sq:continue
		var alignment:=forward.dot(offset/sqrt(distance_sq))
		if alignment<best_alignment:continue
		if not _aim_assist_line_clear(point):continue
		best_alignment=alignment;best_point=point
	return best_point

func _apply_online_aim_assist(command: Dictionary,dt: float) -> void:
	aim_assist_active=false
	if not bool(command.get("aim",false)):return
	var selected_weapon:=int(command.get("weapon",weapon_slot))
	if selected_weapon in [2,3]:
		if selected_weapon==2:command.sprint=false
		return
	var point:=_best_online_aim_assist_target(command)
	if not point.is_finite():return
	var cyaw:=float(command.get("yaw",input_adapter.yaw))
	var cpitch:=float(command.get("pitch",input_adapter.pitch))
	var assisted:=AIM_ASSIST.step(cyaw,cpitch,camera.global_position,point,dt)
	command.yaw=wrapf(assisted.x,-PI,PI)
	command.pitch=clampf(assisted.y,deg_to_rad(-48.0),deg_to_rad(30.0))
	input_adapter.yaw=command.yaw;input_adapter.pitch=command.pitch
	aim_assist_active=absf(angle_difference(cyaw,float(command.yaw)))>0.000001 or absf(cpitch-float(command.pitch))>0.000001

func _apply_online_sniper_sway(command: Dictionary,dt: float) -> void:
	var scoped:=bool(command.get("aim",false)) and int(command.get("weapon",weapon_slot))==2
	var movement:=minf(1.0,(command.get("move",Vector2.ZERO) as Vector2).length())
	var sway_delta:=_step_sniper_scope_sway(dt,movement,scoped)
	if sway_delta.length_squared()<=0.0000000001:return
	command.yaw=wrapf(float(command.get("yaw",input_adapter.yaw))+sway_delta.x,-PI,PI)
	command.pitch=clampf(float(command.get("pitch",input_adapter.pitch))+sway_delta.y,deg_to_rad(-48.0),deg_to_rad(30.0))
	input_adapter.yaw=float(command.yaw);input_adapter.pitch=float(command.pitch)

func _fire_physics_ball() -> void:
	if not session.connected or combat.is_game_over() or shot_cooldown>0.00001:return
	if inspect_time>0.0:return
	if reload_remaining>0.0:return
	if ammo_in_mag<=0:
		_start_reload();return
	var profile: Dictionary=WEAPON_RULES.by_slot(weapon_slot)
	# Remember the exact crosshair ray for this predicted local shot. When the server confirms
	# the shot later, the local tracer uses this visual path instead of the historical
	# lag-compensated hit endpoint.
	if weapon_slot not in [1,3] and current_input_sequence > 0:
		local_tracer_predictions[current_input_sequence]={
			"from":weapon_muzzle.global_position,
			"to":combat.camera_target(),
			"at":age
		}
		tracer_removal_scratch.clear()
		for sequence in local_tracer_predictions:
			if int(sequence)<current_input_sequence-30:tracer_removal_scratch.append(sequence)
		for sequence in tracer_removal_scratch:local_tracer_predictions.erase(sequence)
	ammo_in_mag-=1;_refresh_ammo_hud();shot_cooldown+=float(profile.fire_interval)
	_kick_weapon_visuals();_apply_body_fire_recoil(yaw);_play_weapon_fire_audio();_spawn_muzzle_flash();combat.reticle.notify_shot()
	var kick: Vector2=input_adapter.apply_weapon_recoil(aiming)
	if weapon_slot==1:
		kick+=input_adapter.apply_weapon_recoil(aiming)
	elif weapon_slot==2:
		kick+=input_adapter.apply_weapon_recoil(aiming)*1.55
	elif weapon_slot==3:
		kick+=input_adapter.apply_weapon_recoil(aiming)*1.25
	yaw=input_adapter.yaw;pitch=input_adapter.pitch
	camera_yaw.rotation.y=yaw;camera_pitch.rotation.x=pitch
	last_prediction_at=age
	input_adapter.rumble(0.68 if weapon_slot==3 else 0.65 if weapon_slot==2 else 0.42 if weapon_slot==1 else 0.24,0.15 if weapon_slot==3 else 0.14 if weapon_slot==2 else 0.11 if weapon_slot==1 else 0.08)
	if ammo_in_mag<=0:_start_reload()


func _local_skill_active_for(warrior_id: String) -> bool:
	return player_warrior_id==warrior_id and float(local_state.get("skill_active",0.0))>0.0001


func skill_fire_interval_multiplier() -> float:
	return 0.64 if _local_skill_active_for("loker") else 1.0


func skill_reload_duration_multiplier() -> float:
	return 0.58 if _local_skill_active_for("loker") else 1.0


func skill_damage_multiplier() -> float:
	return 2.0 if _local_skill_active_for("outrage") else 1.0


func skill_is_immune() -> bool:
	return _local_skill_active_for("erebus")

func _snapshot(snapshot: Dictionary) -> void:
	# Network polling may happen outside physics. Replay must only run in a fixed physics tick.
	inbound_state=snapshot

func _apply_snapshot(snapshot: Dictionary) -> void:
	latest_state=snapshot
	present_actor_scratch.clear()
	player_count=0
	for state in snapshot.actors:
		var id: int=state.id
		present_actor_scratch[id]=true;state_records[id]=state
		if not state.bot and state.connected:player_count+=1
		if id==session.actor_id:
			local_state=state
			if death_camera_active and float(state.get("hp",0.0))>0.0:
				_stop_death_camera()
			if int(state.ack)>input_adapter.sequence:input_adapter.sequence=int(state.ack)
			var old =player.global_position
			player.global_position=state.p;player.velocity=state.v
			player.set_meta("motor_grounded",bool(state.ground))
			while pending_head<pending.size() and int(pending[pending_head].seq)<=int(state.ack):pending_head+=1
			_pending_compact()
			var jump_seen =int(state.get("js",local_jump))
			for pending_index in range(pending_head,pending.size()):
				var command: Dictionary=pending[pending_index]
				var replay:=_prediction_replay(command,int(command.js)>jump_seen)
				jump_seen=maxi(jump_seen,command.js)
				MOTOR.step(player,replay,1.0/60.0)
			var difference =old-player.global_position
			var difference_length:=difference.length()
			max_correction=maxf(max_correction,difference_length)
			if connected_age>1.0:
				steady_max_correction=maxf(steady_max_correction,difference_length)
				if difference_length>0.5:
					corrections_over_half_meter+=1
					if options.has("qa-client"):print("CORRECTION_DEBUG ",age," ack=",state.ack," diff=",difference," server_p=",state.p," v=",state.v," js=",state.js," pending=",_pending_count()," floor=",state.ground)
			if difference_length<1.8:correction=(correction+difference).limit_length(0.45)
			else:correction=Vector3.ZERO;locomotion.reset()
			grenade_skill.set_cooldown(state.gcd)
			_update_warrior_skill_hud(float(state.get("skill_cd",0.0)),float(state.get("skill_active",0.0)))
			_set_authoritative_weapon_state(state,false)
			var predicted_slot:=int(state.get("weapon",weapon_slot))
			if _pending_count()>0:predicted_slot=int((pending.back() as Dictionary).get("weapon",predicted_slot))
			if predicted_slot!=weapon_slot:_set_weapon_slot(predicted_slot,false)
			input_adapter.weapon_slot=predicted_slot
			if snapshot.tick>=last_health_tick:combat.apply_status(snapshot,state)
			continue
		if not replicas.has(id):
			if state.hp<=0:continue
			_make_replica(state)
		var r: Dictionary=replicas[id]
		if not is_instance_valid(r.node):continue
		_capture_previous_pose(r)
		r.next=state;r.age=0.0
	replica_removal_scratch.clear()
	for id in replicas:
		if not present_actor_scratch.has(id):replica_removal_scratch.append(id)
	for id in replica_removal_scratch:
		var record: Dictionary=replicas[id]
		if is_instance_valid(record.node):record.node.queue_free()
		replicas.erase(id);state_records.erase(id)
		_sync_projectiles(snapshot)
		combat._update_counter()

func _prediction_replay(source: Dictionary,jump: bool) -> Dictionary:
	replay_command_scratch.move=source.get("move",Vector2.ZERO)
	replay_command_scratch.yaw=float(source.get("yaw",0.0))
	replay_command_scratch.aim=bool(source.get("aim",false))
	replay_command_scratch.sprint=bool(source.get("sprint",false))
	replay_command_scratch.weapon=int(source.get("weapon",0))
	replay_command_scratch.speed_multiplier=float(source.get("speed_multiplier",1.0))
	replay_command_scratch.jump=jump
	return replay_command_scratch

func _capture_previous_pose(record: Dictionary) -> void:
	record.prev_p=(record.node as Node3D).global_position
	record.prev_yaw=(record.visual as Node3D).rotation.y
	var positions:=record.get("prev_rig_positions",[]) as Array
	var rotations:=record.get("prev_rig_rotations",[]) as Array
	var scales:=record.get("prev_rig_scales",[]) as Array
	if positions.size()!=4:
		positions.resize(4);rotations.resize(4);scales.resize(4)
	for index in range(4):
		var rig:=record.rigs[RIG_NAMES[index]] as Node3D
		positions[index]=rig.position
		rotations[index]=rig.quaternion
		scales[index]=rig.scale
	record.prev_rig_positions=positions
	record.prev_rig_rotations=rotations
	record.prev_rig_scales=scales

func _make_replica(state: Dictionary) -> void:
	var node: Node3D
	var visual: Node3D
	var style: Node3D
	var rig_nodes: Dictionary={}
	var gun: Node3D=null
	var ak_body: Node3D=null
	var shotgun_body: Node3D=null
	var kar_body: Node3D=null
	var launcher_body: Node3D=null
	var damage_visual: Node=null
	var tag: Label3D=null
	if state.bot:
		node=load("res://scripts/prototypes/kw_training_dummy.gd").new()
		node.warrior_id=state.skin;node.roaming_enabled=false;node.position=state.p
		add_child(node);node.set_physics_process(false)
		node.set_network_replica_mode(true)
		visual=node.visuals;style=node;damage_visual=null
		for title in RIG_NAMES:rig_nodes[title]=visual.get_node(title)
		combat.targets.append(node)
	else:
		node=Node3D.new();add_child(node);node.position=state.p
		visual=Node3D.new();node.add_child(visual)
		var remote_warrior := str(state.get("skin","outrage")).strip_edges().to_lower()
		if remote_warrior == "aevilok":
			style=AEVILOK_FULLBODY.instantiate()
			AEVILOK_STYLE.apply(style)
		elif remote_warrior == "loker":
			style=LOKER_FULLBODY.instantiate()
			LOKER_STYLE.apply(style)
		elif remote_warrior == "kosas":
			style=KOSAS_FULLBODY.instantiate()
			KOSAS_STYLE.apply(style)
		elif remote_warrior == "erebus":
			style=EREBUS_FULLBODY.instantiate()
		else:
			style=OUTRAGE_FULLBODY.instantiate()
		WARRIOR_HAND_STYLE.ensure_hands(style)
		WARRIOR_RENDER_LOD.apply(style)
		if remote_warrior=="aevilok":AEVILOK_STYLE.enable_wing_batch(style)
		visual.add_child(style)
		_style_remote_human(style,state)
		for title in RIG_NAMES:rig_nodes[title]=style.get_node(title)
		damage_visual=null
		tag = Label3D.new()
		tag.name = "VirtualUsername"
		tag.text = str(state.get("name","KW_%04d"%int(state.id)))
		tag.font_size = 36
		tag.outline_size = 6
		tag.modulate = Color("8ef1de")
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.position = Vector3(0,3.08,0)
		tag.render_priority = 126
		tag.visibility_range_end = 42.0
		tag.visibility_range_end_margin = 5.0
		node.add_child(tag)
		gun=Node3D.new();gun.name="RemoteWeapon";visual.add_child(gun);gun.position=Vector3(-1.10,torso_rest.y+0.88,-0.98)
	var record: Dictionary={"node":node,"visual":visual,"style":style,"rigs":rig_nodes,"next":state,"prev_p":state.p,"prev_yaw":float(state.get("yaw",0.0)),"prev_rig_positions":[],"prev_rig_rotations":[],"prev_rig_scales":[],"age":0.05,"bot":state.bot,"steps":state.steps,"grounded":bool(state.get("ground",true)),"dead":false,
			"gun":gun,"ak_body":ak_body,"shotgun_body":shotgun_body,"kar_body":kar_body,"launcher_body":launcher_body,"damage_visual":damage_visual,
			"weapon_bodies":[null,null,null,null],
			"health":float(state.get("hp",100.0)),"weapon":clampi(int(state.get("weapon",0)),0,3),"tag":tag,
			"lod_phase":int(node.get_instance_id()%12),"is_aevilok":str(state.get("skin","")).strip_edges().to_lower()=="aevilok",
		"left_hand":style.get_node_or_null("LeftHandRig") if style != null else null,
			"right_hand":style.get_node_or_null("RightHandRig") if style != null else null,
			"hit_punch":0.0,"hit_sign":1.0,"hit_seed":0.0}
	if not state.bot:_ensure_remote_weapon_body(record,int(record.weapon))
	_capture_previous_pose(record)
	replicas[state.id]=record
	_apply_replica(record,1.0)
	if state.bot:node.set_style(comic_enabled,pixel_enabled)
	else:
		style.set_enabled(comic_enabled);style.set_pixel_enabled(pixel_enabled);WARRIOR_RENDER_LOD.sync_batches(style)

func _ensure_replica_damage_visual(r: Dictionary) -> Node:
	var existing:=r.get("damage_visual") as Node
	if existing!=null:return existing
	var created: Node=null
	if bool(r.get("bot",false)):
		var bot:=r.get("node") as Node
		if bot!=null and bot.has_method("_ensure_damage_visual"):created=bot._ensure_damage_visual()
	else:
		var visual:=r.get("visual") as Node3D
		var style:=r.get("style") as Node3D
		if visual!=null and style!=null:
			created=VOXEL_DAMAGE_VISUAL.new();visual.add_child(created)
			created.setup(style,RIG_NAMES,int((r.node as Node).get_instance_id()%2147483647))
			created.set_pixel_enabled(pixel_enabled);created.set_comic_enabled(comic_enabled)
	if created!=null:r.damage_visual=created
	return created

func _apply_replica(r: Dictionary,alpha: float) -> void:
	if not is_instance_valid(r.node) or r.dead:return
	var b: Dictionary=r.next
	if not r.bot:
		var name_label:=r.get("tag") as Label3D
		if name_label!=null:
			var desired_name:=str(b.get("name",name_label.text))
			if name_label.text!=desired_name:name_label.text=desired_name
	r.node.global_position=(r.prev_p as Vector3).lerp(b.p,alpha)
	r.visual.rotation.y=lerp_angle(float(r.prev_yaw),b.yaw,alpha)
	var remote_distance: float=r.node.global_position.distance_to(player.global_position) if player!=null else 0.0
	r.remote_distance=remote_distance
	var pose_stride:=1 if remote_distance<=REMOTE_FULL_ANIM_DISTANCE else (2 if remote_distance<=REMOTE_REDUCED_ANIM_DISTANCE else 3)
	var pose_phase:=int(r.get("lod_phase",0))%pose_stride if pose_stride>1 else 0
	var update_pose:=pose_stride==1 or int(Engine.get_process_frames()%pose_stride)==pose_phase
	if update_pose:
		var second: PackedFloat32Array=b.pose
		var prev_positions:=r.prev_rig_positions as Array
		var prev_rotations:=r.prev_rig_rotations as Array
		var prev_scales:=r.prev_rig_scales as Array
		for index in range(4):
			var rig: Node3D=r.rigs[RIG_NAMES[index]]
			var k =index*9
			rig.position=(prev_positions[index] as Vector3).lerp(Vector3(second[k],second[k+1],second[k+2]),alpha)
			rig.quaternion=(prev_rotations[index] as Quaternion).slerp(Quaternion.from_euler(Vector3(second[k+3],second[k+4],second[k+5])),alpha)
			rig.scale=(prev_scales[index] as Vector3).lerp(Vector3(second[k+6],second[k+7],second[k+8]),alpha)
	var replica_health:=float(b.get("hp",100.0))
	if r.damage_visual!=null and not is_equal_approx(replica_health,float(r.get("health",replica_health))):
		r.damage_visual.set_health(replica_health,100.0)
		r.health=replica_health
	if r.bot:
		if b.hp<r.node.health:r.node.health=b.hp;r.node._refresh_bar()
	else:
		var gun: Node3D=r.gun
		var selected_weapon:=clampi(int(b.get("weapon",0)),0,3)
		var weapon_changed:=selected_weapon!=int(r.get("weapon",-1))
		if weapon_changed:
			_ensure_remote_weapon_body(r,selected_weapon)
			r.weapon=selected_weapon
		var phase_value := float(b.get("phase",0.0))*TAU
		var remote_roll := sin(phase_value+1.2)*0.085
		var remote_pitch := sin(phase_value*1.7+0.4)*0.035
		gun.position=Vector3(-1.10,torso_rest.y+0.88+sin(phase_value)*0.035,-0.98)
		gun.global_rotation=Vector3(float(b.ap)+remote_pitch,float(b.ay),remote_roll)
		if weapon_changed or remote_distance<=REMOTE_FULL_ANIM_DISTANCE or Engine.get_process_frames()%2==0:
			_pose_remote_weapon_hands(r, selected_weapon)
	_update_replica_movement_audio(r,b)


func _build_remote_weapon_body(gun: Node3D,slot: int) -> Node3D:
	var body:=Node3D.new()
	body.name=["RemoteAKBody","RemoteShotgunBody","RemoteKARBody","RemoteGrenadeLauncherBody"][slot]
	body.rotation.y=PI*0.5
	body.position=Vector3(0.10,0,-0.30)
	gun.add_child(body)
	match slot:
		0:
			AK47_VOXEL_BUILDER.build(body)
			var materials: Dictionary={}
			for part in body.get_children():
				if not part is MeshInstance3D:continue
				var mesh:=part as MeshInstance3D
				var original:=mesh.material_override as StandardMaterial3D
				if original==null:continue
				var key:=original.get_instance_id()
				if not materials.has(key):
					var mat:=PIXEL_MATERIALS.from_standard(original,0.025)
					mat.set_shader_parameter("comic_enabled",comic_enabled);mat.set_shader_parameter("pixel_enabled",pixel_enabled)
					materials[key]=mat;pixel_materials.append(weakref(mat))
				mesh.material_override=materials[key];mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		1:
			_add_weapon_box(body,"SG_Stock",Vector3(-0.36,-0.02,0),Vector3(0.62,0.22,0.24),Color("6d4030"))
			_add_weapon_box(body,"SG_Receiver",Vector3(0.18,0.01,0),Vector3(0.62,0.25,0.22),Color("30343b"))
			_add_weapon_box(body,"SG_Barrel",Vector3(0.88,0.055,0),Vector3(0.92,0.12,0.14),Color("b7c0c8"))
			_add_weapon_box(body,"SG_Pump",Vector3(0.62,-0.09,0),Vector3(0.42,0.18,0.25),Color("8a5238"))
		2:
			KAR_VOXEL_BUILDER.build(body)
			var materials: Dictionary={}
			for part in body.get_children():
				if not part is MeshInstance3D:continue
				var mesh:=part as MeshInstance3D
				var original:=mesh.material_override as StandardMaterial3D
				if original==null:continue
				var key:=original.get_instance_id()
				if not materials.has(key):
					var mat:=PIXEL_MATERIALS.from_standard(original,0.018)
					mat.set_shader_parameter("comic_enabled",comic_enabled);mat.set_shader_parameter("pixel_enabled",pixel_enabled)
					materials[key]=mat;pixel_materials.append(weakref(mat))
				mesh.material_override=materials[key];mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		3:
			_build_grenade_launcher_visual(body)
	var outline_width:=1.15 if slot==0 else (1.10 if slot==2 else 1.25)
	_batch_weapon_visual(body,"REMOTE_%d"%slot,outline_width)
	for mesh in body.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return body


func _ensure_remote_weapon_body(r: Dictionary,slot: int) -> Node3D:
	var bodies:=r.get("weapon_bodies",[]) as Array
	if bodies.size()<4:return null
	if bodies[slot]==null:
		bodies[slot]=_build_remote_weapon_body(r.gun as Node3D,slot)
		r.weapon_bodies=bodies
		match slot:
			0:r.ak_body=bodies[slot]
			1:r.shotgun_body=bodies[slot]
			2:r.kar_body=bodies[slot]
			3:r.launcher_body=bodies[slot]
	for index in range(4):
		var body:=bodies[index] as Node3D
		if body!=null:body.visible=index==slot
	return bodies[slot] as Node3D


func _replica_feet_midpoint(r: Dictionary) -> Vector3:
	var left:=r.rigs.get("LeftLegRig") as Node3D
	var right:=r.rigs.get("RightLegRig") as Node3D
	if left!=null and right!=null:return (left.global_position+right.global_position)*0.5
	if left!=null:return left.global_position
	if right!=null:return right.global_position
	return (r.node as Node3D).global_position


func _update_replica_movement_audio(r: Dictionary,state: Dictionary) -> void:
	if arena_audio==null or not is_instance_valid(r.node):return
	var next_steps:=int(state.get("steps",r.get("steps",0)))
	var previous_steps:=int(r.get("steps",next_steps))
	if next_steps<previous_steps:
		# Locomotion counters reset on respawn/reinitialization.
		r.steps=next_steps
	elif next_steps>previous_steps:
		r.steps=next_steps
		var foot_name:="LeftLegRig" if next_steps%2==0 else "RightLegRig"
		var foot:=r.rigs.get(foot_name) as Node3D
		var point:=foot.global_position if foot!=null else _replica_feet_midpoint(r)
		arena_audio._play_spatial(arena_audio.STEPS[next_steps%arena_audio.STEPS.size()],point,-18.0,randf_range(0.94,1.06))
	var grounded_now:=bool(state.get("ground",true))
	var grounded_before:=bool(r.get("grounded",grounded_now))
	if grounded_before!=grounded_now:
		var velocity:=state.get("v",Vector3.ZERO) as Vector3
		if grounded_before and not grounded_now and velocity.y>1.0:
			arena_audio.play_event("jump",_replica_feet_midpoint(r),-17.0)
		elif not grounded_before and grounded_now:
			arena_audio.play_event("land",_replica_feet_midpoint(r),-15.0)
	r.grounded=grounded_now


func _pose_remote_weapon_hands(r: Dictionary, selected_weapon: int) -> void:
	var left_hand := r.get("left_hand") as Node3D
	var right_hand := r.get("right_hand") as Node3D
	if left_hand == null or right_hand == null:
		return
	var pivot: Node3D = r.ak_body
	var right_grip := Vector3(-0.04, -0.12, -0.12)
	var left_grip := Vector3(0.50, -0.05, 0.09)
	var right_direction := Vector3(-0.10, 0.34, 0.94)
	var left_direction := Vector3(-0.20, 0.28, 0.94)
	match selected_weapon:
		1:
			pivot = r.shotgun_body
			right_grip = Vector3(0.02, -0.22, -0.12)
			left_grip = Vector3(0.62, -0.10, 0.09)
			right_direction = Vector3(-0.12, 0.32, 0.94)
			left_direction = Vector3(-0.22, 0.26, 0.94)
		2:
			pivot = r.kar_body
			right_grip = Vector3(-0.14, -0.27, -0.12)
			left_grip = Vector3(0.58, -0.07, 0.09)
			right_direction = Vector3(-0.10, 0.30, 0.95)
			left_direction = Vector3(-0.20, 0.24, 0.95)
		3:
			pivot = r.launcher_body
			right_grip = Vector3(0.00, -0.24, -0.12)
			left_grip = Vector3(0.66, -0.06, 0.09)
			right_direction = Vector3(-0.10, 0.32, 0.94)
			left_direction = Vector3(-0.18, 0.25, 0.95)
	_place_hand_on_grip(right_hand, pivot, right_grip, right_direction, 0.08)
	_place_hand_on_grip(left_hand, pivot, left_grip, left_direction, -0.10)

func _process(delta: float) -> void:
	var process_frame:=int(Engine.get_process_frames())
	for id in replicas:
		var r: Dictionary=replicas[id]
		if not is_instance_valid(r.node):continue
		r.age+=delta
		_apply_replica(r,clampf(r.age/interpolation_seconds,0,1))
		var remote_distance:=float(r.get("remote_distance",0.0))
		var frame_mod:=process_frame+int(r.get("lod_phase",0))%4
		if r.bot and not r.dead:
			if remote_distance<=REMOTE_FULL_ANIM_DISTANCE or frame_mod%3==0:r.node._update_readability(delta*3.0 if remote_distance>REMOTE_FULL_ANIM_DISTANCE else delta)
		elif not r.bot:
			var remote_style := r.get("style") as Node3D
			var animate_remote: bool=remote_distance<=REMOTE_REDUCED_ANIM_DISTANCE or frame_mod%4==0
			if animate_remote and remote_style != null and bool(r.get("is_aevilok",false)):
				var remote_state: Dictionary = r.get("next", {})
				var remote_velocity: Vector3 = remote_state.get("v", Vector3.ZERO) as Vector3
				var remote_phase := float(remote_state.get("phase", 0.0)) * TAU
				var remote_grounded := bool(remote_state.get("ground", absf(remote_velocity.y) < 0.12))
				var horizontal_speed:=sqrt(remote_velocity.x*remote_velocity.x+remote_velocity.z*remote_velocity.z)
				AEVILOK_STYLE.animate_wings(
					remote_style,
					delta,
					age,
					remote_phase,
					horizontal_speed,
					remote_velocity.y,
					remote_grounded
				)
			var punch := float(r.get("hit_punch",0.0))
			if punch > 0.0:
				if remote_distance>REMOTE_REDUCED_ANIM_DISTANCE and frame_mod%3!=0:
					r.hit_punch=maxf(0.0,punch-delta*7.6)
					continue
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
	if menu!=null and menu.visible:
		menu_refresh_clock-=delta
		if menu_refresh_clock<=0.0:
			menu_refresh_clock=0.10
			menu.refresh()
	for id in flying:
		var record: Dictionary=flying[id]
		if is_instance_valid(record.node):
			record.node.global_position=record.node.global_position.lerp(record.p,1-exp(-35*delta))
			record.node.rotation+=Vector3(3,2,4)*delta

func _create_projectile_visual(kind: String) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new()
	mesh.name="PooledOnlineProjectile_"+kind
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match kind:
		"launcher":
			var sphere:=SphereMesh.new();sphere.radius=0.14;sphere.height=0.28;mesh.mesh=sphere
			mesh.material_override=_material(Color("d7b04c"),false,0.0)
		"grenade":
			var box:=BoxMesh.new();box.size=Vector3(0.28,0.32,0.28);mesh.mesh=box
			mesh.material_override=_material(Color("537668"),false,0.0)
		_:
			var box:=BoxMesh.new();box.size=Vector3(0.12,0.12,0.4);mesh.mesh=box
			mesh.material_override=_material(Color("ff6949"),true,0.6)
	add_child(mesh)
	_add_scene_outline(mesh,1.4)
	mesh.visible=false
	(projectile_visual_pool[kind] as Array).append(mesh)
	return mesh

func _acquire_projectile_visual(kind: String) -> MeshInstance3D:
	if not projectile_visual_pool.has(kind):projectile_visual_pool[kind]=[]
	for visual in projectile_visual_pool[kind]:
		if is_instance_valid(visual) and not visual.visible:
			visual.visible=true
			visual.rotation=Vector3.ZERO
			visual.scale=Vector3.ONE
			return visual
	var created:=_create_projectile_visual(kind)
	created.visible=true
	return created

func _release_projectile_visual(record: Dictionary) -> void:
	var visual:=record.get("node") as MeshInstance3D
	if visual==null:return
	visual.visible=false
	visual.rotation=Vector3.ZERO
	visual.scale=Vector3.ONE

func _sync_projectiles(snapshot: Dictionary) -> void:
	var seen: Dictionary={}
	for group in [snapshot.grenades,snapshot.bolts]:
		for p in group:
			var grenade: bool=p.has("fuse")
			var launcher: bool=grenade and str(p.get("kind","skill"))=="launcher"
			var id: String=("g" if grenade else "b")+str(p.id);seen[id]=true
			if not flying.has(id):
				var pool_kind:="launcher" if launcher else ("grenade" if grenade else "bolt")
				var mesh:=_acquire_projectile_visual(pool_kind)
				mesh.global_position=p.p
				flying[id]={"node":mesh,"p":p.p,"kind":pool_kind}
			flying[id].p=p.p
	flying_removal_scratch.clear()
	for id in flying:
		if not seen.has(id):flying_removal_scratch.append(id)
	for id in flying_removal_scratch:
		_release_projectile_visual(flying[id] as Dictionary)
		flying.erase(id)

func _consume_local_tracer_prediction(input_seq: int) -> Dictionary:
	var chosen := -1
	var best_delta := 999
	for key in local_tracer_predictions:
		var sequence := int(key)
		var delta := absi(sequence-input_seq)
		if delta <= 4 and delta < best_delta:
			chosen = sequence
			best_delta = delta
	if chosen < 0:return {}
	var result: Dictionary=local_tracer_predictions[chosen]
	local_tracer_predictions.erase(chosen)
	return result

func _event(e: Dictionary) -> void:
	qa_events[e.type]=int(qa_events.get(e.type,0))+1
	match str(e.type):
		"shot":
			if int(e.get("weapon",0))==2:qa_events["kar_shot"]=int(qa_events.get("kar_shot",0))+1
			var tracer_from: Vector3=e.from
			var tracer_to: Vector3=e.to
			if int(e.actor)==int(session.actor_id):
				var prediction:=_consume_local_tracer_prediction(int(e.get("input",-1000)))
				if not prediction.is_empty():
					tracer_from=prediction.from
					tracer_to=prediction.to
			if not e.blocked:combat._spawn_tracer(tracer_from,tracer_to)
			if bool(e.get("hit",false)):combat._spawn_impact(e.to,e.get("normal",Vector3.UP))
			if e.actor!=session.actor_id:
				combat._spawn_world_muzzle_flash(e.from,(e.to-e.from).normalized())
				var shot_weapon:=int(e.get("weapon",0))
				var stream: AudioStream=KAR_FIRE_SFX if shot_weapon==2 else AK47_SHOT_SFX
				arena_audio._play_spatial(stream,e.from,-10.0 if shot_weapon==2 else -14.0,randf_range(0.96,1.04))
		"shotgun":
			var pellets: Array=e.get("pellets",[]) as Array
			var pellet_count: int=pellets.size()
			var tracer_stride: int=maxi(1,int(ceil(float(pellet_count)/5.0)))
			for pellet_index in range(pellet_count):
				var pellet: Dictionary=pellets[pellet_index] as Dictionary
				if pellet_index%tracer_stride==0:combat._spawn_tracer(e.from,pellet.to,"shotgun")
				if bool(pellet.get("hit",false)):combat._spawn_impact(pellet.to,pellet.get("normal",Vector3.UP))
			if e.actor!=session.actor_id:
				var first_to: Vector3=pellets[0].to if not pellets.is_empty() else e.from-Vector3.FORWARD
				combat._spawn_world_muzzle_flash(e.from,(first_to-e.from).normalized())
				arena_audio._play_spatial(SHOTGUN_FIRE_SFX,e.from,-11.0,randf_range(0.78,0.86))
		"launcher_shot":
			if int(e.actor)!=session.actor_id:
				combat._spawn_world_muzzle_flash(e.from,(e.v as Vector3).normalized())
				arena_audio._play_spatial(GRENADE_LAUNCHER_FIRE_SFX,e.from,-10.0,randf_range(0.96,1.02))
		"skill":
			var skill_actor:=int(e.get("actor",0))
			var skill_hero:=str(e.get("hero","outrage"))
			var skill_duration:=float(e.get("duration",0.35))
			var fx_root: Node3D=player_visual if skill_actor==session.actor_id else null
			if fx_root==null and replicas.has(skill_actor):fx_root=(replicas[skill_actor] as Dictionary).get("visual") as Node3D
			if skill_hero=="kosas":
				_spawn_kosas_dash_vfx(e.get("from",e.get("p",Vector3.ZERO)),e.get("to",e.get("p",Vector3.ZERO)))
			if fx_root!=null:_spawn_warrior_skill_vfx(fx_root,skill_hero,maxf(0.35,skill_duration))
			if skill_actor==session.actor_id:
				_update_warrior_skill_hud(float(e.get("cooldown",0.0)),skill_duration)
				input_adapter.rumble(0.48,0.10)
		"damage":
			var victim_skin := "outrage"
			if int(e.actor)==session.actor_id:
				victim_skin=str(local_state.get("skin","outrage"))
			elif state_records.has(e.actor):
				victim_skin=str((state_records[e.actor] as Dictionary).get("skin","outrage"))
			combat._spawn_damage_feedback(e.p,e.dir,e.amount,e.lethal,combat.blood_color_for_skin(victim_skin),e.owner==session.actor_id)
			if e.owner==session.actor_id:
				combat.notify_hit(e.p,e.dir,e.amount,e.lethal,bool(e.get("headshot",false)))
			if e.actor==session.actor_id:
				last_health_tick=e.tick
				combat.director.health=e.hp
				combat.director.dead=e.lethal
				if player_damage_visual!=null:
					player_damage_visual.damage_at(e.p,float(e.hp),100.0,float(e.amount),e.dir)
				_set_player_healthbar(e.hp,100.0)
				combat.director.hud.set_health(e.hp,100)
				combat.director.hud.notify_hurt(e.amount)
				input_adapter.rumble(0.65,0.15)
				var local_dir: Vector3=player_visual.global_basis.inverse()*(e.dir as Vector3)
				if int(e.get("owner",0))>0:
					combat.director.hud.notify_directional_damage(local_dir,float(e.get("amount",0.0)),bool(e.get("headshot",false)))
					if locomotion!=null:
						locomotion.body_angular_velocity+=Vector3(local_dir.z,0,-local_dir.x)*1.15
					head_spring_velocity+=Vector3(local_dir.z*0.18,0,-local_dir.x*0.25)
					if e.lethal:
						_start_death_camera(int(e.get("owner",0)),e.p as Vector3)
					if e.lethal and _open_menu_on_death():
						input_adapter.suspend()
						set_menu(true)
			elif replicas.has(e.actor):
				var r: Dictionary=replicas[e.actor]
				var remote_damage:=_ensure_replica_damage_visual(r)
				if remote_damage!=null:
					remote_damage.damage_at(e.p,float(e.hp),100.0,float(e.amount),e.dir)
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
						r.hit_punch=1.0
						r.hit_sign=-1.0 if (int(e.actor)+int(qa_events.get("damage",0)))%2==0 else 1.0
						r.hit_seed=randf_range(0.0,TAU)
		"kill":
			var killer_name:=str(e.get("killer_name",_actor_display_name(int(e.get("owner",0)))))
			var victim_name:=str(e.get("victim_name",_actor_display_name(int(e.get("actor",0)))))
			combat.director.hud.add_kill_feed(
				killer_name,victim_name,str(e.get("weapon","")),bool(e.get("headshot",false)),
				int(e.get("owner",0))==session.actor_id,int(e.get("actor",0))==session.actor_id
			)
			if e.owner==session.actor_id:
				last_health_tick=e.tick
				combat.total_kills=e.kills
				combat.score_pulse=0.65
				combat.director.health=e.hp
				combat.director.hud.set_health(e.hp,100)
				combat.director.hud.notify_heal(e.heal)
				_set_player_healthbar(float(e.hp),100.0)
				if float(e.get("heal",0.0))>0.0:
					arena_audio.play_event("heal")
				combat._update_counter()
		"explosion":grenade_skill.show_blast(e.p)
		"reload":
			var reload_slot:=clampi(int(e.get("weapon",0)),0,3)
			if int(e.actor)!=session.actor_id:
				var reload_stream: AudioStream=AK47_RELOAD_SFX if reload_slot==0 else SHOTGUN_RELOAD_SFX if reload_slot==1 else KAR_RELOAD_SFX if reload_slot==2 else GRENADE_LAUNCHER_RELOAD_SFX
				arena_audio._play_spatial(reload_stream,e.p,-14.0,1.0)
			elif reload_by_weapon[reload_slot]<=0.0:
				ammo_by_weapon[reload_slot]=int(e.get("ammo",ammo_by_weapon[reload_slot]))
				reload_by_weapon[reload_slot]=float(e.get("duration",WEAPON_RULES.by_slot(reload_slot).reload))
				if reload_slot==weapon_slot:
					var reload_audio:=ak_reload_audio if reload_slot==0 else shotgun_reload_audio if reload_slot==1 else kar_reload_audio if reload_slot==2 else grenade_launcher_reload_audio
					if reload_audio!=null:reload_audio.play()
					if reload_slot in [0,1]:_spawn_reload_magazine()
					_refresh_ammo_hud()
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
			if e.actor==session.actor_id:
				_stop_death_camera()
				combat.director.dead=false;last_health_tick=e.tick;combat.director.hud.reset_run();set_menu(false)

func _actor_display_name(id: int) -> String:
	if id<=0:return "ENVIRONMENT"
	if id==session.actor_id:
		return str(local_state.get("name",options.get("name","PLAYER %d"%id)))
	if state_records.has(id):
		var state:=state_records[id] as Dictionary
		return str(state.get("name","PLAYER %d"%id))
	if replicas.has(id):
		var record:=replicas[id] as Dictionary
		var state:=record.get("next",{}) as Dictionary
		return str(state.get("name","PLAYER %d"%id))
	return "PLAYER %d"%id

func _flash_end(bot: Node3D) -> void:
	await get_tree().create_timer(0.075).timeout
	if is_instance_valid(bot):
		bot.flash_time=0
		for material in bot.records:material.mesh.material_overlay=null

func _set_comic_enabled(value: bool) -> void:
	super._set_comic_enabled(value)
	for id in replicas:
		var r: Dictionary=replicas[id]
		if is_instance_valid(r.node) and not r.bot:
			r.style.set_enabled(value);WARRIOR_RENDER_LOD.sync_batches(r.style)
func _set_pixel_enabled(value: bool) -> void:
	super._set_pixel_enabled(value)
	for id in replicas:
		var r: Dictionary=replicas[id]
		if is_instance_valid(r.node) and not r.bot:
			r.style.set_pixel_enabled(value);WARRIOR_RENDER_LOD.sync_batches(r.style)

func _notification(what: int) -> void:
	if input_adapter==null:return
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and not options.has("qa-client"):
		input_adapter.focused=false;set_menu(true)
	elif what==NOTIFICATION_WM_WINDOW_FOCUS_IN:input_adapter.focused=true

func _qa_tick(_delta: float) -> void:pass
func _qa_command(_command: Dictionary) -> void:pass
