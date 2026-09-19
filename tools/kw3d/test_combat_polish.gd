extends SceneTree
var stage: Node3D
var output := ""
var failures: Array[String] = []
var observer: Camera3D
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output = arg.trim_prefix("--qa-output=")
	assert(not output.is_empty())
	run.call_deferred()
func check(value: bool, label: String) -> void:
	if not value and not failures.has(label):
		failures.append(label)
		push_error("COMBAT_QA_FAIL "+label)
func run() -> void:
	stage = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	stage.combat.set_training_mode(true)
	# Freeze target travel for deterministic aim/terrain fixtures; roaming has its own test.
	stage.combat.set_roaming_enabled(false)
	stage.ak_fire_audio.volume_db = -80
	for i in range(90): await physics_frame
	stage.set_physics_process(false)
	stage.set_process_unhandled_input(false)
	check(stage.combat.targets.size()==3,"three_targets")
	check(stage.player.is_on_floor(),"player_grounded")
	check(stage.head_rest.z < stage.torso_rest.z-0.25,"head_forward")
	check(stage.head_rest.y-stage.torso_rest.y>1.40,"readable_neck_gap")
	check(stage.weapon_side<0,"left_side_default")
	await capture("combat_gameplay")
	var spawn_points: Array[Vector3] = []
	for bot in stage.combat.targets: spawn_points.append(bot.global_position)
	for i in range(20): await physics_frame
	for i in range(3):
		var bot: Node3D = stage.combat.targets[i]
		check(bot.global_position.is_equal_approx(spawn_points[i]),"stationary_"+str(i))
		check(bot.health==100.0 and bot.health_bar.visible,"full_health_"+str(i))
	# Inspect the player without redirecting his gameplay camera.
	stage.get_node("HUD").visible=false
	for tag in stage.player_visual.get_children():
		if tag is Label3D: tag.visible=false
	observer=Camera3D.new()
	stage.add_child(observer)
	observer.current=true
	observer.global_position=stage.player.global_position+Vector3(4.5,1.3,-6.2)
	observer.look_at(stage.player.global_position+Vector3(0,0.05,0),Vector3.UP)
	observer.fov=40.0
	await capture("player_separation_side_hold")
	observer.global_position=Vector3(14,10,9)
	observer.look_at(Vector3(0,2.8,-5),Vector3.UP)
	observer.fov=56
	await capture("three_warrior_targets")
	# Damage through the same camera/muzzle path used by the playable rifle.
	var target: Node3D = stage.combat.targets[0]
	place_for_target(target)
	for i in range(3): await physics_frame
	stage._update_weapon_pose(0.0)
	var before: float = target.health
	stage.shot_cooldown=0
	stage._fire_physics_ball()
	check(stage.combat.last_shot.damage_applied,"camera_to_muzzle_hits_target")
	check(is_equal_approx(target.health,before-5.0),"exact_ak_body_damage_5")
	check(target.hit_count==1,"one_hit_per_shot")
	check(target.flash_time>0,"flash_started")
	for record in target.records: check(record.mesh.material_overlay!=null,"all_parts_white")
	for record in stage.combat.targets[1].records: check(record.mesh.material_overlay==null,"other_target_not_flashing")
	check(not target.receive_hit(5,Vector3.FORWARD,stage.combat.shots_fired),"duplicate_shot_ignored")
	observer.global_position=target.global_position+Vector3(3.2,1.2,4.2)
	observer.look_at(target.global_position+Vector3(0,0.3,0),Vector3.UP)
	observer.fov=42
	await capture("target_hit_white")
	for i in range(10): await physics_frame
	for record in target.records: check(record.mesh.material_overlay==null,"flash_recovers")
	check(target.health==95,"health_persists")
	await capture("target_health_95")
	# Occlusion: insert cover between the muzzle and the victim.
	var shield:=StaticBody3D.new()
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new(); box.size=Vector3(6,5,0.2); shape.shape=box
	stage.add_child(shield); shield.add_child(shape)
	shield.global_position=target.global_position+Vector3(0,0,2)
	for i in range(2): await physics_frame
	stage.shot_cooldown=0; stage._fire_physics_ball()
	check(target.health==95,"cover_blocks_damage")
	shield.queue_free()
	for i in range(2): await physics_frame
	target.health=5.0;target._refresh_bar()
	place_for_target(target);stage.shot_cooldown=0;stage._fire_physics_ball();await physics_frame
	check(target.dead and target.health==0,"five_damage_finisher_death")
	check(stage.combat.kills==1,"one_kill")
	check(target.collision_layer==0 and not target.health_bar.visible,"dead_no_collider_or_healthbar")
	check(not target.receive_hit(5,Vector3.FORWARD,99999),"dead_ignores_more_damage")
	await capture("target_death")
	for i in range(100): await physics_frame
	check(not is_instance_valid(target),"death_cleanup")
	stage.combat.reset_targets()
	for i in range(3): await physics_frame
	check(stage.combat.kills==0 and stage.combat.targets.size()==3,"reset_targets")
	for bot in stage.combat.targets: check(bot.health==100,"reset_health")
	# All variants can be hit; off/on style changes cannot tint the player or others.
	for i in [1,2]:
		var bot: Node3D=stage.combat.targets[i]
		place_for_target(bot)
		await physics_frame
		stage.shot_cooldown=0; stage._fire_physics_ball()
		check(bot.health==95,"variant_hit_"+str(i))
	stage._set_pixel_enabled(false); stage.head_style.set_enabled(false); stage.combat.sync_style()
	for bot in stage.combat.targets: check(not bot.pixel_enabled and not bot.comic_enabled,"style_sync")
	stage._set_pixel_enabled(true); stage.head_style.set_enabled(true); stage.combat.sync_style()
	# Repeatable fire interval; cosmetic traces never block subsequent shots.
	var count: int=stage.combat.shots_fired
	stage.ammo_by_weapon[0]=25;stage.reload_by_weapon[0]=0.0;stage._set_weapon_slot(0,false)
	stage.shot_cooldown=0.0
	for i in range(120):
		stage.shot_cooldown=maxf(-1.0/60.0,stage.shot_cooldown-1.0/60.0)
		stage._fire_physics_ball()
	check(stage.combat.shots_fired-count>=19 and stage.combat.shots_fired-count<=21,"automatic_fire_rate")
	print("COMBAT_DAMAGE_FLASH_DEATH_COVER_PASS")
	# Animated torso turns independently, with the head still target-directed.
	stage.player.global_position=Vector3(0,1.715,6)
	stage.player_visual.rotation=Vector3.ZERO; stage.body_yaw=0.0
	stage.locomotion.reset()
	stage.camera.position=Vector3(0.65,1.35,6.4); stage.camera.rotation=Vector3.ZERO
	stage.camera_yaw.rotation=Vector3.ZERO; stage.camera_pitch.rotation.x=-0.10
	var max_twist:=0.0
	for i in range(120):
		stage.player_visual.rotation.y=sin(float(i)*0.07)*0.9
		stage.body_yaw=stage.player_visual.rotation.y
		stage._update_character_animation(1.0/60.0)
		stage._update_weapon_pose(1.0/60.0)
		max_twist=maxf(max_twist,absf(stage.torso_rig.rotation.y))
		check(stage.head_rig.transform.is_finite() and stage.torso_rig.transform.is_finite(),"stable_secondary_motion")
	check(max_twist>0.15,"visible_torso_turn_lag")
	stage.aiming=true
	for i in range(100): stage._update_character_animation(1.0/60.0)
	var desired: Vector3=(stage._get_aim_target()-stage.head_rig.global_position).normalized()
	check(desired.dot(-stage.head_rig.global_basis.z)>0.96,"head_keeps_aim")
	print("TORSO_GAP_LAG_GAZE_PASS twist=",max_twist)
	var result=FileAccess.open(output.path_join("combat_results.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify({"failures":failures,"max_torso_twist":max_twist},"\t")); result.close()
	stage.queue_free()
	for i in range(10): await process_frame
	print("COMBAT_POLISH_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
func place_for_target(bot: Node3D) -> void:
	stage.player.global_position=bot.global_position+Vector3(0,0,5.5)
	stage.player_visual.rotation=Vector3.ZERO; stage.body_yaw=0.0
	stage.camera.global_position=stage.player.global_position+Vector3(0.65,1.35,2.8)
	stage.camera.look_at(bot.visuals.get_node("TorsoRig/Torso_Upper").global_position,Vector3.UP)
	stage._update_weapon_pose(0.0)
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"screenshot_saved")
