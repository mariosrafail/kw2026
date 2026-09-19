extends "res://scripts/kw3d/online_client.gd"
## Automated client, used only by the explicit --kw-qa-client flag. Real ENet transport.
var finished =false
var screenshot_done =false
var resume_time =-1.0
var injected: Dictionary={}
var gamepad_move_seen =false
var gamepad_fire_seen =false
var rejection_probe_sent =false
var probe_round=0
var joined_slots: Array[int]=[]
var initial_position =Vector3.ZERO
var maximum_travel =0.0
var first_health =100.0
func _welcome(payload: Dictionary) -> void:
	super._welcome(payload)
	joined_slots.append(payload.slot)
	if initial_position==Vector3.ZERO:initial_position=player.global_position
	first_health=float(local_state.get("hp",60))

func axis(id: int,value: float) -> void:
	var event =InputEventJoypadMotion.new();event.device=0;event.axis=id;event.axis_value=value
	Input.parse_input_event(event)
func button(id: int,down: bool) -> void:
	var event =InputEventJoypadButton.new();event.device=0;event.button_index=id;event.pressed=down
	Input.parse_input_event(event)

func _qa_tick(_delta: float) -> void:
	if finished:return
	var role =int(options.get("qa-client","1"))
	if session.connected:
		maximum_travel=maxf(maximum_travel,player.global_position.distance_to(initial_position))
		if role==2:
			axis(JOY_AXIS_LEFT_X,0.55 if age<1.8 else 0.0)
			axis(JOY_AXIS_TRIGGER_RIGHT,1.0 if age>2.1 and age<7.2 else 0.0)
			axis(JOY_AXIS_TRIGGER_LEFT,1.0)
			if age>1.0 and not injected.has("jump"):
				injected.jump=true;button(JOY_BUTTON_A,true)
			elif injected.has("jump"):button(JOY_BUTTON_A,false)
			if age>4.5 and not injected.has("grenade"):
				injected.grenade=true;button(JOY_BUTTON_RIGHT_SHOULDER,true)
			elif injected.has("grenade"):button(JOY_BUTTON_RIGHT_SHOULDER,false)
		if age>7.5 and probe_round<6 and age>=7.5+float(probe_round)*0.12:
			probe_round+=1
			var source: Dictionary={"seq":input_adapter.sequence+1,"ct":0,"js":0,"gs":0,"move":Vector2.ZERO,"yaw":0.0,"pitch":0.0,"side":-1.0,"fire":false,"aim":false,"sprint":false,"reload":false}
			var bad_move: Dictionary=source.duplicate();bad_move.move=Vector2(NAN,0)
			var bad_sequence: Dictionary=source.duplicate();bad_sequence.seq=2000000000
			var bad_pitch: Dictionary=source.duplicate();bad_pitch.pitch=20.0
			session._inputs.rpc_id(1,session.CODEC.encode([bad_move,bad_sequence,bad_pitch]))
		if age>9 and role==2 and not qa_disconnected:
			qa_disconnected=true;session.close_connection(false);resume_time=age+1.0
	if resume_time>0 and age>=resume_time:
		resume_time=-1.0;session.reconnect()
	if age>13 and not screenshot_done and session.connected:
		screenshot_done=true;capture_online()
	if age>float(options.get("test-seconds","18")):
		finished=true
		var failures: Array[String]=[]
		if not session.connected:failures.append("not_connected")
		if session.snapshot_count<70:failures.append("insufficient_snapshots")
		if player_count!=2:failures.append("two_real_players_missing")
		if maximum_travel<0.4:failures.append("no_movement")
		if steady_max_correction>0.55:failures.append("prediction_correction_over_budget")
		if int(qa_events.get("damage",0))<1:failures.append("no_authority_damage")
		if int(qa_events.get("explosion",0))<1:failures.append("no_shared_explosion")
		if int(qa_events.get("reload",0))<1:failures.append("no_authority_reload")
		if role==2:
			if not qa_rejoined or joined_slots.size()!=2 or joined_slots[0]!=joined_slots[1]:failures.append("rejoin_identity")
			if not gamepad_move_seen or not gamepad_fire_seen:failures.append("synthetic_gamepad_path")
		var actors: Dictionary={}
		for id in state_records:
			var s: Dictionary=state_records[id]
			actors[str(id)]={"hp":s.hp,"kills":s.kills,"bot":s.bot,"gcd":s.gcd,"ammo":s.get("ammo",-1),"reload":s.get("reload",-1.0),"p":s.p}
		var result: Dictionary={"failures":failures,"slot":session.actor_id,"joined_slots":joined_slots,"snapshots":session.snapshot_count,"rtt_ms":session.rtt_ms,"max_correction":max_correction,"steady_max_correction":steady_max_correction,"large_corrections":corrections_over_half_meter,"maximum_travel":maximum_travel,"events":qa_events,"actors":actors,"synthetic_pad_move":gamepad_move_seen,"synthetic_pad_fire":gamepad_fire_seen,"physical_controllers":Input.get_connected_joypads()}
		var file =FileAccess.open(str(options.output).path_join("client_%d.json"%role),FileAccess.WRITE)
		file.store_string(JSON.stringify(result,"\t"));file.close()
		print("ONLINE_CLIENT_",role,"_", "PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(result))
		get_tree().quit(0 if failures.is_empty() else 1)

func _qa_command(command: Dictionary) -> void:
	var role =int(options.get("qa-client","1"))
	if role==2:
		if command.move.x>0.2:gamepad_move_seen=true
		if command.fire:gamepad_fire_seen=true
	else:
		command.move=Vector2(-0.5,0) if age<1.8 else Vector2.ZERO
		command.fire=age>1.7 and age<7.2
		if age>3.0 and not qa_did_throw:
			qa_did_throw=true;input_adapter.grenade_serial+=1;command.gs=input_adapter.grenade_serial
	var target: Dictionary={}
	for s in state_records.values():
		if s.bot and s.hp>0:target=s;break
	if not target.is_empty():
		var pose: PackedFloat32Array=target.pose
		var point: Vector3=target.p+Basis(Vector3.UP,target.yaw)*Vector3(pose[9],pose[10]+0.35,pose[11])
		var direction: Vector3=(point-camera.global_position).normalized()
		command.yaw=atan2(-direction.x,-direction.z)
		command.pitch=clampf(atan2(direction.y,Vector2(direction.x,direction.z).length()),-0.83,0.52)
		input_adapter.yaw=command.yaw;input_adapter.pitch=command.pitch
	command.aim=true

func capture_online() -> void:
	if instructions_visible:_toggle_instructions()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(str(options.output).path_join("online_client_%s.png"%str(options.get("qa-client","1"))))
