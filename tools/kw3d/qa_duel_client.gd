extends "res://scripts/kw3d/overdrive_duel_client.gd"
var qa_index := 0
var qa_age := 0.0
var qa_ready_sent := false
var qa_start_requested := false
var qa_started := false
var qa_started_at := -1.0
var qa_player_peak := 0
var qa_rtt_min := 99999.0
var qa_rtt_max := 0.0
var qa_rtt_sum := 0.0
var qa_rtt_samples := 0
var qa_snapshot_start := 0
var qa_move_started := false
var qa_pending_peak := 0
var qa_bot_mode := false
var qa_bot_enabled_sent := false
var qa_hold_seconds := 9.0
var qa_static_visual := false
var qa_multiround := false
var qa_round_peak := 0
var qa_round2_seen := false
var qa_round2_seen_at := -1.0
var qa_round2_camera_bad := false
var qa_round2_self_aim := false
var qa_damage_taken := 0.0
var qa_bot_shots := 0
var qa_bot_hits := 0
var qa_bot_damage_by_weapon: Dictionary = {}
var qa_bot_visible_sole_max_y := 0.0
var qa_bot_visible_sole_samples := 0
var qa_attack_bot := false
var qa_damage_dealt_to_bot := 0.0

func _ready() -> void:
	qa_index = int(options.get("qa-duel","0"))
	qa_bot_mode = str(options.get("qa-bot","false")).to_lower() in ["1","true","yes"]
	qa_hold_seconds = maxf(9.0, float(options.get("qa-visual-hold","9")))
	qa_static_visual = str(options.get("qa-static","false")).to_lower() in ["1","true","yes"]
	qa_attack_bot = str(options.get("qa-attack-bot","false")).to_lower() in ["1","true","yes"]
	qa_multiround = str(options.get("qa-multiround","false")).to_lower() in ["1","true","yes"]
	if qa_multiround:qa_hold_seconds=maxf(qa_hold_seconds,28.0)
	super._ready()

func _welcome(payload: Dictionary) -> void:
	super._welcome(payload)
	if qa_bot_mode and not qa_bot_enabled_sent:
		qa_bot_enabled_sent = true
		session.set_duel_bot_fallback(true)
	elif not qa_ready_sent:
		qa_ready_sent = true
		session.set_ready(true)

func _apply_snapshot(snapshot: Dictionary) -> void:
	super._apply_snapshot(snapshot)
	var players: Array = room_state.get("players",[])
	qa_round_peak=maxi(qa_round_peak,int(room_state.get("round",0)))
	if qa_round_peak>=2 and not qa_round2_seen:
		qa_round2_seen=true;qa_round2_seen_at=qa_age
	qa_player_peak = maxi(qa_player_peak,players.size())
	var all_ready := players.size() == 2
	for p in players:
		all_ready = all_ready and (bool(p.get("ready",false)) or bool(p.get("bot",false)))
	var can_start := bool(room_state.get("can_start",false)) if qa_bot_mode else all_ready
	if str(room_state.get("phase","")) == "LOBBY" and can_start and int(room_state.get("host",0)) == session.actor_id and not qa_start_requested:
		qa_start_requested = true
		session.request_match_start()
	if str(room_state.get("phase","")) == "MATCH" and str(room_state.get("round_phase","")) in ["COUNTDOWN","FIGHT","OVERLOAD"]:
		if not qa_started:
			qa_started_at = qa_age
			qa_snapshot_start = session.snapshot_count
			qa_started = true
	if qa_bot_mode and str(room_state.get("phase",""))=="MATCH" and str(room_state.get("round_phase",""))=="DRAFT" and int(room_state.get("draft_chooser",0))==session.actor_id:
		var pool:=room_state.get("draft_pool",[]) as Array
		if not pool.is_empty():choose_augment(str(pool[0]))

func _event(e: Dictionary) -> void:
	super._event(e)
	if qa_bot_mode and str(e.get("type","")) in ["shot","shotgun"] and int(e.get("actor",0))!=session.actor_id:
		qa_bot_shots+=1
	if str(e.get("type",""))=="damage" and int(e.get("actor",0))==session.actor_id:
		qa_damage_taken+=float(e.get("amount",0.0))
		if qa_bot_mode and int(e.get("owner",0))!=session.actor_id:
			qa_bot_hits+=1
			var weapon_key:=str(e.get("weapon","unknown"))
			qa_bot_damage_by_weapon[weapon_key]=int(qa_bot_damage_by_weapon.get(weapon_key,0))+1
	if qa_attack_bot and str(e.get("type",""))=="damage" and int(e.get("owner",0))==session.actor_id:
		var bot_id:=0
		for p in room_state.get("players",[]):
			if bool(p.get("bot",false)):bot_id=int(p.get("id",0));break
		if bot_id>0 and int(e.get("actor",0))==bot_id:
			qa_damage_dealt_to_bot+=float(e.get("amount",0.0))

func _qa_angles_to(point: Vector3) -> Vector2:
	var anchor:=player.global_position+Vector3(0,1.05,0)
	var angles:=AIM_ASSIST.target_angles(anchor,point)
	for unused in range(5):
		var view:=Basis(Vector3.UP,angles.x)*Basis(Vector3.RIGHT,angles.y)
		var origin:=anchor+view*Vector3(1.2,1.35,3.8)
		angles=AIM_ASSIST.target_angles(origin,point)
	return angles

func _physics_process(delta: float) -> void:
	# Same deterministic strafe on both A/B tests so prediction/correction numbers are comparable.
	var fighting := str(room_state.get("phase","")) == "MATCH" and str(room_state.get("round_phase","")) in ["FIGHT","OVERLOAD"]
	if qa_attack_bot and fighting:
		var attack_bot_id:=0
		for p in room_state.get("players",[]):
			if bool(p.get("bot",false)):attack_bot_id=int(p.get("id",0));break
		if attack_bot_id>0 and replicas.has(attack_bot_id):
			var attack_record:=replicas[attack_bot_id] as Dictionary
			var torso:=attack_record.rigs.get("TorsoRig") as Node3D
			if torso!=null:
				var attack_angles:=_qa_angles_to(torso.global_position+Vector3.UP*0.10)
				input_adapter.yaw=attack_angles.x
				input_adapter.pitch=attack_angles.y
				Input.action_press("kw3d_aim",1.0)
				Input.action_press("kw3d_fire",1.0)
	else:
		Input.action_release("kw3d_aim")
		Input.action_release("kw3d_fire")
	if fighting and not qa_static_visual and qa_started_at >= 0.0 and qa_age-qa_started_at < 7.0:
		qa_move_started = true
		if qa_index == 1:
			Input.action_press("kw3d_right",0.72)
			Input.action_release("kw3d_left")
		else:
			Input.action_press("kw3d_left",0.72)
			Input.action_release("kw3d_right")
	else:
		Input.action_release("kw3d_left")
		Input.action_release("kw3d_right")
	super._physics_process(delta)
	qa_age += delta
	if qa_bot_mode:
		var bot_actor_id:=0
		for p in room_state.get("players",[]):
			if bool(p.get("bot",false)):bot_actor_id=int(p.get("id",0));break
		if bot_actor_id>0 and replicas.has(bot_actor_id):
			var record:=replicas[bot_actor_id] as Dictionary
			var remote_state:=record.get("next",{}) as Dictionary
			if bool(remote_state.get("ground",false)):
				var nearest_sole:=INF
				for rig_name in ["LeftLegRig","RightLegRig"]:
					var rig:=record.rigs.get(rig_name) as Node3D
					if rig==null:continue
					for node in rig.get_children():
						if node is MeshInstance3D and str(node.name).ends_with("_Sole") and node.mesh!=null:
							var box: AABB=node.mesh.get_aabb()
							for corner_index in range(8):nearest_sole=minf(nearest_sole,(node.global_transform*box.get_endpoint(corner_index)).y)
				if nearest_sole<INF:
					qa_bot_visible_sole_samples+=1
					qa_bot_visible_sole_max_y=maxf(qa_bot_visible_sole_max_y,nearest_sole)
	if qa_round2_seen and not death_camera_active and str(room_state.get("round_phase","")) in ["COUNTDOWN","FIGHT","OVERLOAD"]:
		if camera!=null and camera.rotation.length()>0.01:qa_round2_camera_bad=true
		if weapon_muzzle!=null and player!=null:
			var shot_direction: Vector3=(aim_target-weapon_muzzle.global_position).normalized()
			var self_direction: Vector3=(player.global_position+Vector3.UP*0.9-weapon_muzzle.global_position).normalized()
			if shot_direction.length_squared()>0.01 and self_direction.length_squared()>0.01 and shot_direction.dot(self_direction)>0.80:
				qa_round2_self_aim=true
	qa_pending_peak = maxi(qa_pending_peak,pending.size())
	if session.connected and session.rtt_ms > 0.0:
		qa_rtt_min = minf(qa_rtt_min,session.rtt_ms)
		qa_rtt_max = maxf(qa_rtt_max,session.rtt_ms)
		qa_rtt_sum += session.rtt_ms
		qa_rtt_samples += 1
	if qa_multiround and qa_round2_seen and qa_round2_seen_at>=0.0 and qa_age-qa_round2_seen_at>3.0:
		_finish_qa()
	elif qa_started and qa_started_at >= 0.0 and qa_age-qa_started_at > qa_hold_seconds:
		_finish_qa()
	elif qa_age > 40.0:
		_finish_qa()

func _finish_qa() -> void:
	var out := {
		"index": qa_index,
		"connected": session.connected,
		"actor": session.actor_id,
		"phase": room_state.get("phase",""),
		"round_phase": room_state.get("round_phase",""),
		"heroes": room_state.get("players",[]).map(func(p):return p.get("hero","")),
		"players": qa_player_peak,
		"started": qa_started,
		"host": room_state.get("host",0),
		"rtt": session.rtt_ms,
		"rtt_min": 0.0 if qa_rtt_samples==0 else qa_rtt_min,
		"rtt_max": qa_rtt_max,
		"rtt_avg": 0.0 if qa_rtt_samples==0 else qa_rtt_sum/float(qa_rtt_samples),
		"snapshots_during_match": session.snapshot_count-qa_snapshot_start,
		"snapshot_rate_hz": 0.0 if qa_started_at<0.0 else float(session.snapshot_count-qa_snapshot_start)/maxf(0.001,qa_age-qa_started_at),
		"pending_peak": qa_pending_peak,
		"max_correction": max_correction,
		"steady_max_correction": steady_max_correction,
		"large_corrections": corrections_over_half_meter,
		"move_injected": qa_move_started
	}
	var bot_seen := false
	var own_hero := ""
	for p in room_state.get("players",[]):
		bot_seen = bot_seen or bool(p.get("bot",false))
		if int(p.get("id",0)) == int(session.actor_id):
			own_hero = str(p.get("hero",p.get("skin",""))).strip_edges().to_lower()
	out["bot_mode"] = qa_bot_mode
	out["bot_seen"] = bot_seen
	out["own_hero"] = own_hero
	out["local_warrior"] = str(player_warrior_id)
	out["local_body_matches_role"] = own_hero.is_empty() or own_hero == str(player_warrior_id)
	out["round_peak"] = qa_round_peak
	out["round2_seen"] = qa_round2_seen
	out["round2_camera_bad"] = qa_round2_camera_bad
	out["round2_self_aim"] = qa_round2_self_aim
	out["damage_taken"] = qa_damage_taken
	out["bot_shots"] = qa_bot_shots
	out["bot_hits"] = qa_bot_hits
	out["bot_damage_by_weapon"] = qa_bot_damage_by_weapon.duplicate()
	out["bot_visible_sole_max_y"] = qa_bot_visible_sole_max_y
	out["bot_visible_sole_samples"] = qa_bot_visible_sole_samples
	out["damage_dealt_to_bot"] = qa_damage_dealt_to_bot
	if qa_bot_mode:
		var debug_bot_id:=0
		for p in room_state.get("players",[]):
			if bool(p.get("bot",false)):debug_bot_id=int(p.get("id",0));break
		if debug_bot_id>0 and replicas.has(debug_bot_id):
			var debug_record:=replicas[debug_bot_id] as Dictionary
			var debug_state:=debug_record.get("next",{}) as Dictionary
			var debug_pose:=debug_state.get("pose",PackedFloat32Array()) as PackedFloat32Array
			out["bot_root_y"]=(debug_record.node as Node3D).global_position.y
			out["bot_render_left_leg_y"]=(debug_record.rigs.LeftLegRig as Node3D).position.y
			if debug_pose.size()>=27:out["bot_server_left_leg_y"]=debug_pose[19]
			var sources:=debug_record.get("source_rig_positions",[]) as Array
			var targets:=debug_record.get("target_rig_positions",[]) as Array
			if sources.size()>=3:out["bot_source_left_leg_y"]=(sources[2] as Vector3).y
			if targets.size()>=3:out["bot_target_left_leg_y"]=(targets[2] as Vector3).y
	var folder := str(options.get("output",""))
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		var f := FileAccess.open(folder.path_join("duel_client_%d.json"%qa_index),FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(out,"\t"))
			f.close()
	print("DUEL_QA_",qa_index," ",JSON.stringify(out))
	var passed: bool = session.connected and qa_started and qa_player_peak==2
	passed = passed and bool(out.local_body_matches_role)
	if qa_bot_mode:
		passed = passed and bot_seen and qa_damage_taken>0.0 and qa_bot_visible_sole_samples>0 and qa_bot_visible_sole_max_y<=0.14
	if qa_attack_bot:
		passed = passed and qa_damage_dealt_to_bot>0.0
	if qa_multiround:
		passed = passed and qa_round2_seen and not qa_round2_camera_bad and not qa_round2_self_aim
	get_tree().quit(0 if passed else 1)
	set_physics_process(false)
