extends SceneTree
var failures: Array[String] = []
var events: Array[Dictionary] = []

func check(value: bool,label: String) -> void:
	if not value:
		failures.append(label)
		push_error("OVERDRIVE_QA_FAIL "+label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var world = load("res://scripts/kw3d/duel_authority_world.gd").new()
	root.add_child(world)
	world.event_created.connect(func(data: Dictionary):events.append(data.duplicate(true)))
	await process_frame
	world.add_player(1)
	world.add_player(2)
	var p1: Node3D = world.actors[1]
	var p2: Node3D = world.actors[2]
	check(p1.hero_id=="outrage","p1_is_outrage")
	check(p2.hero_id=="erebus","p2_is_erebus")
	check(world.room_packet().players.size()==2,"two_players")
	check(not world.can_start(),"not_ready")
	world.set_ready(1,true)
	world.set_ready(2,true)
	check(world.can_start(),"both_ready")
	check(world.start_match(1),"host_starts")
	check(world.phase=="MATCH" and world.round_phase=="COUNTDOWN","match_countdown")
	check(absf(p1.global_position.x)<0.01 and p1.global_position.z>9.0,"flat_spawn_p1")
	check(absf(p2.global_position.x)<0.01 and p2.global_position.z<-9.0,"flat_spawn_p2")
	check(absf(p1.aim_yaw)<0.01 and absf(absf(p2.aim_yaw)-PI)<0.01,"players_face_each_other")
	for i in range(190):world.step()
	check(world.round_phase=="FIGHT","fight_after_countdown")

	# Human-vs-human lag compensation must exist in Duel. The old co-op history stored bots only,
	# and node CollisionShape transforms did not reach PhysicsServer until the following frame.
	await physics_frame
	world._capture_hit_history()
	var history_tick: int=world.tick_id
	check(world.hit_history.has(history_tick) and (world.hit_history[history_tick] as Dictionary).has(2),"human_hit_history_recorded")
	var tracked_shape: CollisionShape3D=p2.hit_records[0].shape
	var past_target: Vector3=tracked_shape.global_transform.origin
	p2.global_position.x+=4.0
	await physics_frame
	var exclusions: Array[RID]=[p1.get_rid(),p1.hit_body.get_rid()]
	var test_origin: Vector3=p1.weapon_anchor()
	var test_direction: Vector3=(past_target-test_origin).normalized()
	var test_end: Vector3=past_target+test_direction*3.0
	var ray_without_rewind: Dictionary=world.ray(test_origin,test_end,5,exclusions)
	check(ray_without_rewind.is_empty() or int((ray_without_rewind.get("collider") as Node).get_meta("actor_id",0))!=2,"current_position_misses_old_target_line")
	var rewound: Array=world._rewind_targets(history_tick)
	var ray_with_rewind: Dictionary=world.ray(test_origin,test_end,5,exclusions)
	check(not ray_with_rewind.is_empty() and int((ray_with_rewind.get("collider") as Node).get_meta("actor_id",0))==2,"physics_rid_rewind_hits_historical_human")
	world._restore_targets(rewound)
	var ray_after_restore: Dictionary=world.ray(test_origin,test_end,5,exclusions)
	check(ray_after_restore.is_empty() or int((ray_after_restore.get("collider") as Node).get_meta("actor_id",0))!=2,"physics_rid_restore_returns_current_target")
	p2.global_position.x-=4.0
	await physics_frame

	# A lost input frame must never repeat FIRE with stale yaw/pitch.
	p1.input_started=true
	p1.input_wait=0
	p1.input_queue.clear()
	p1.command=load("res://scripts/kw3d/actor_motor.gd").empty(p1.aim_yaw,p1.aim_pitch)
	p1.command.fire=true
	p1.fire_clock=0.0
	p1.last_input_tick=world.tick_id
	var stale_ammo: int=p1.ammo
	world.step()
	check(p1.ammo==stale_ammo and not bool(p1.command.get("fire",true)),"lost_frame_does_not_fire_stale_shot")

	p2.damage_grace=0.0
	var hp_before: float=p2.health
	check(world.damage(2,5.0,Vector3.FORWARD,1,p2.global_position,false,"ak"),"pvp_damage_allowed")
	check(is_equal_approx(p2.health,hp_before-5.0),"base_damage_applied")
	p1.add_augment("heavy_rounds")
	p2.health=100.0
	p2.damage_grace=0.0
	world.damage(2,5.0,Vector3.FORWARD,1,p2.global_position,false,"ak")
	check(is_equal_approx(p2.health,93.75),"heavy_rounds_25_percent")
	p1.augments.clear()
	p1.refresh_build()

	p2.damage_grace=0.0
	p2.refill_skill()
	var guard_hp: float=p2.health
	check(world.use_skill(2),"erebus_guard_cast")
	check(p2.damage_grace>=0.84,"erebus_guard_window")
	check(not world.damage(2,20.0,Vector3.FORWARD,1,p2.global_position,false,"ak"),"guard_blocks_hit")
	check(is_equal_approx(p2.health,guard_hp),"guard_preserves_hp")

	p1.refill_skill()
	var dash_from: Vector3=p1.global_position
	check(world.use_skill(1),"outrage_dash_cast")
	check(p1.global_position.distance_to(dash_from)>2.0,"outrage_dash_moves_authority")

	p1.skill_charges=0
	p1.skill_recharge=5.0
	p1.velocity=Vector3.ZERO
	p1.command=load("res://scripts/kw3d/actor_motor.gd").empty()
	p1.global_position=Vector3(0,1.25,0)
	world.core_delay=0.0
	world.core_available=false
	world.step()
	world.step()
	check(p1.skill_charges==p1.skill_max_charges,"core_refills_skill")

	world.round_phase="FIGHT"
	events.clear()
	world._finish_round(1,2)
	check(world.round_phase=="DRAFT","round_enters_draft")
	var round_over_event: Dictionary={}
	for event in events:
		if str(event.get("type",""))=="round_over":round_over_event=event;break
	check(not round_over_event.is_empty(),"round_over_event_emitted")
	check(round_over_event.has("room"),"round_over_carries_fresh_room")
	if round_over_event.has("room"):
		var packet:=round_over_event.room as Dictionary
		var fresh_score:=0
		for player in packet.get("players",[]):
			if int(player.get("id",0))==1:fresh_score=int(player.get("rounds",0))
		check(fresh_score==1,"round_over_room_has_incremented_score")
	check(world.draft_order.size()==2 and world.draft_order[0]==2 and world.draft_order[1]==1,"loser_picks_first")
	check(world.draft_pool.size()==4,"four_draft_cards")
	var first_card: String=world.draft_pool[0]
	check(not world.choose_augment(1,first_card),"winner_cannot_pick_first")
	check(world.choose_augment(2,first_card),"loser_picks")
	var second_card: String=world.draft_pool[0]
	check(world.choose_augment(1,second_card),"winner_picks_second")
	check(world.round_number==2 and world.round_phase=="COUNTDOWN","next_round_starts")
	check(not p1.augments.is_empty() and not p2.augments.is_empty(),"augments_persist")

	world.round_scores[1]=4
	world.round_phase="FIGHT"
	world._finish_round(1,2)
	check(world.phase=="RESULT" and world.winner_id==1,"first_to_five_result")

	world.set_ready(1,true)
	world.set_ready(2,true)
	check(world.start_match(1),"rematch_start")
	check(world.phase=="MATCH" and world.round_number==1,"rematch_round_reset")
	check(int(world.round_scores[1])==0 and int(world.round_scores[2])==0,"rematch_score_reset")
	check(p1.augments.is_empty() and p2.augments.is_empty(),"rematch_augments_reset")
	print("OVERDRIVE_DUEL_QA_","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
