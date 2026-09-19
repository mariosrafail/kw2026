extends "res://tools/kw3d/test_combat_polish.gd"
func run() -> void:
	stage = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	stage.combat.set_training_mode(true)
	stage.set_physics_process(false)
	stage.set_process_unhandled_input(false)
	stage.ak_fire_audio.volume_db = -80.0
	check(stage.shooting_volume_db == -7.5, "louder_rifle_gain")
	var floor_shape: CollisionShape3D
	for child in stage.get_node("Floor").get_children():
		if child is CollisionShape3D: floor_shape = child
	check((floor_shape.shape as BoxShape3D).size == Vector3(48, 1, 48), "quadruple_floor_area")
	check(stage.has_node("FrontWall") and stage.has_node("RearCoverLeft"), "expanded_arena_enclosed")
	var tab := InputEventKey.new()
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	stage._unhandled_input(tab)
	check(not stage.help_panel.visible, "tab_hides_all_instructions")
	check(stage.get_node("HUD/CombatScore").is_visible_in_tree(), "tab_keeps_kill_counter")
	check(stage.get_node("HUD/Crosshair").is_visible_in_tree(), "tab_keeps_crosshair")
	stage._unhandled_input(tab)
	check(stage.help_panel.visible, "tab_restores_instructions")
	print("MAP_TAB_AUDIO_PASS")
	var initial: Array[Vector3] = []
	var max_distances := [0.0, 0.0, 0.0]
	for bot in stage.combat.targets:
		initial.append(bot.global_position)
		check(bot.roaming_enabled and bot.movement_body.collision_layer == 8, "roaming_default_on")
		check(bot.collision_layer == 4, "precise_hit_layer_preserved")
	for tick in range(600):
		await physics_frame
		for index in range(stage.combat.targets.size()):
			var bot: Node3D = stage.combat.targets[index]
			max_distances[index] = maxf(max_distances[index], bot.global_position.distance_to(initial[index]))
			check(bot.global_transform.is_finite() and bot.global_position.y > 1.60, "clones_stay_above_floor")
			check(absf(bot.global_position.x) < 23.5 and bot.global_position.z > -29.5 and bot.global_position.z < 17.5, "clones_inside_map")
			for rig in bot.rigs: check((rig.node as Node3D).transform.is_finite(), "bot_animation_finite")
			for foot in bot.locomotion.feet:
				check(foot.node.global_position.distance_to(bot.global_position) < 3.1, "bot_foot_reach")
			for data in bot.hit_shapes:
				var expected: Transform3D = bot.global_transform.affine_inverse() * data.mesh.global_transform
				check(data.shape.position.distance_to(expected.origin) < 0.0001, "animated_hitbox_aligned")
		if tick == 200:
			stage._toggle_instructions()
			await capture("roaming_gameplay_clean")
	for index in range(3):
		var bot: Node3D = stage.combat.targets[index]
		check(max_distances[index] > 3.0, "bot_roams_" + str(index))
		check(bot.brain.direction_changes >= 3, "bot_changes_direction_" + str(index))
		check(bot.locomotion.step_count > 12, "bot_uses_walking_cycle_" + str(index))
		print("BOT_ROAM_PASS ",bot.warrior_id," distance=",bot.brain.distance_travelled," turns=",bot.brain.direction_changes," steps=",bot.locomotion.step_count)
	# Reuse actual shooting against a moving clone in an unobstructed fixture.
	stage._add_static_box("MovingCombatQAFloor", Vector3(0,-0.5,65), Vector3(50,1,50), Color(0.12,0.14,0.20))
	stage.combat.reset_targets()
	var target: Node3D = stage.combat.targets[0]
	target.global_position = Vector3(0,1.715,65)
	target.movement_body.global_position = target.global_position
	target.brain.spawn = target.global_position
	target.brain.bounds = Rect2(-12,53,24,24)
	target.brain._choose_goal()
	target.locomotion.reset()
	for tick in range(10): await physics_frame
	for shot in range(3):
		await physics_frame
		stage.player.global_position = target.global_position + Vector3(0,0,6)
		stage.player_visual.rotation = Vector3.ZERO
		stage.body_yaw = 0.0
		stage.camera.global_position = stage.player.global_position + Vector3(1.2,1.35,3.8)
		stage.camera.look_at(target.visuals.get_node("TorsoRig/Torso_Upper").global_position, Vector3.UP)
		stage._update_weapon_pose(0.0)
		check(stage.combat.aim_solution.target_ready, "moving_clone_target_ready_" + str(shot))
		stage.shot_cooldown = 0.0
		if shot==2:target.health=5.0;target._refresh_bar()
		stage._fire_physics_ball()
		check(target.health == (0.0 if shot==2 else 95.0-float(shot)*5.0), "moving_exact_damage_" + str(shot))
		check(target.flash_time > 0 and target.hit_squash > 0, "hit_flash_and_squash")
		if shot == 0:
			check(target.brain.knockback.length() > 2.0, "real_hit_knockback")
			for tick in range(3): await physics_frame
			check(target.recoil.length() > 0.04, "visible_directional_flinch")
			await capture("moving_target_hit_reaction")
		for tick in range(7): await physics_frame
	check(target.dead and target.health == 0, "moving_clone_dies")
	check(stage.combat.total_kills == 1 and stage.combat.kills == 1, "single_kill_credited")
	check(target.collision_layer == 0 and target.movement_body.collision_layer == 0, "death_disables_both_colliders")
	check(stage.combat.kill_label.text == "KILLS  1", "visible_kill_count")
	check(not target.receive_hit(5, Vector3.FORWARD, 99999), "dead_cannot_award_extra_kill")
	await capture("kill_counter_hidden_help")
	for tick in range(100): await physics_frame
	check(not is_instance_valid(target), "death_cleanup")
	stage.combat.reset_targets()
	for tick in range(4): await physics_frame
	check(stage.combat.total_kills == 1 and stage.combat.kills == 0, "respawn_preserves_session_kills")
	check(stage.combat.alive_label.text == "ENEMIES  3", "alive_count_reset")
	check(stage.combat.hit_effects.is_empty(), "hit_cosmetics_cleanup")
	print("MOVING_DAMAGE_KNOCKBACK_KILL_RESPAWN_PASS")
	var result := FileAccess.open(output.path_join("roaming_results.json"), FileAccess.WRITE)
	result.store_string(JSON.stringify({"failures":failures,"max_displacements":max_distances,"kills":stage.combat.total_kills}, "\t"))
	result.close()
	stage.queue_free()
	for tick in range(10): await process_frame
	print("ROAMING_RANGE_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
