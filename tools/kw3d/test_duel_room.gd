extends SceneTree
var failures: Array[String] = []
func check(value: bool,label: String) -> void:
	if not value:
		failures.append(label)
		push_error("DUEL_QA_FAIL "+label)
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var world = load("res://scripts/kw3d/duel_authority_world.gd").new()
	root.add_child(world)
	await process_frame
	world.add_player(1)
	world.add_player(2)
	check(world.room_packet().players.size()==2,"two_players")
	check(not world.can_start(),"not_ready")
	world.set_ready(1,true)
	world.set_ready(2,true)
	check(world.can_start(),"both_ready")
	check(world.start_match(1),"host_starts")
	check(world.phase=="MATCH","match_phase")
	var p1: Node3D=world.actors[1]
	var p2: Node3D=world.actors[2]
	p1.global_position=Vector3(-18,1.735,12)
	p2.global_position=Vector3(-16.8,1.735,4)
	p1.velocity=Vector3.ZERO;p2.velocity=Vector3.ZERO
	p1.update_shapes();p2.update_shapes()
	for i in range(2): await physics_frame
	p1.aim_yaw=0.0
	p1.aim_pitch=-0.38
	p1.command=load("res://scripts/kw3d/actor_motor.gd").empty(0.0,-0.38)
	p1.command["aim"]=true
	p1.build_aim(world.get_world_3d().direct_space_state,0.0)
	print("DUEL_AIM muzzle=",p1.muzzle," target=",p1.aim_target," cam=",p1.camera_origin," dir=",p1.camera_direction," p2_torso=",p2.rigs.TorsoRig.global_position," layer=",p2.hit_body.collision_layer)
	var exclusions: Array[RID]=[p1.get_rid(),p1.hit_body.get_rid()]
	var probe_hit=world.ray(p1.muzzle,p1.aim_target,5,exclusions)
	print("DUEL_RAY ",probe_hit)
	world._shoot(p1)
	check(p2.health==95.0,"real_hitscan_player_damage_5")
	p2.health=5.0;p2.damage_grace=0.0
	for tick in range(7):world.step()
	p1.fire_clock=0;p1.build_aim(world.get_world_3d().direct_space_state,0.0);world._shoot(p1)
	check(p2.health==0.0 and p1.kills==1,"player_kill_counts")
	for i in range(125):
		world.step()
	check(p2.health==100.0,"auto_respawn")
	p1.kills=9
	p2.health=5.0
	p2.damage_grace=0
	check(world.damage(2,5,Vector3.FORWARD,1,p2.global_position,false,"ak"),"final_damage")
	check(world.phase=="RESULT" and world.winner_id==1 and p1.kills==10,"first_to_ten_result")
	world.set_ready(1,true);world.set_ready(2,true)
	check(world.start_match(1),"rematch_start")
	check(p1.kills==0 and p2.kills==0 and p1.health==100 and p2.health==100,"rematch_resets")
	print("DUEL_ROOM_QA_","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
