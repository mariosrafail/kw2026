extends "res://tools/kw3d/test_combat_polish.gd"
func run() -> void:
	stage=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	stage.combat.set_training_mode(true)
	stage.combat.set_roaming_enabled(false)
	for i in range(40): await physics_frame
	stage.set_physics_process(false)
	stage.set_process_unhandled_input(false)
	stage.combat.set_physics_process(false)
	stage.grenade_skill.set_physics_process(false)
	var g: Node3D=stage.grenade_skill
	var director: RefCounted=stage.combat.director
	check(stage.arena_audio != null and stage.arena_audio.music.stream is AudioStreamWAV,"project_soundtrack_loaded")
	check(stage.arena_audio.music.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"soundtrack_loop")
	check(stage.arena_audio.qa_muted,"tests_are_quiet")
	check(stage.arena_audio.spatial_pool.size()==12,"bounded_sfx_pool")
	check(stage.WEAPON_HOLD_HEIGHT>=0.75,"shoulder_height_rifle")
	check(director.ATTACK_WARNING<0.45 and director.BULLET_SPEED>18,"faster_enemy_pressure")
	var reticle: Control=stage.get_node("HUD/Crosshair")
	reticle.set_feedback({"occluded":true,"end":Vector3.ZERO},stage.camera,false)
	check(not reticle.obstruction_label.visible and reticle.obstruction_label.text.is_empty(),"no_blocked_overlay")
	var floor_mesh: MeshInstance3D
	for child in stage.get_node("Floor").get_children():
		if child is MeshInstance3D: floor_mesh=child
	check(floor_mesh.has_node("WorldInkOutline"),"terrain_has_ink")
	check(stage.weapon_root.has_node("WorldInkOutline"),"single_union_ak_outline")
	check(floor_mesh.material_override.get_shader_parameter("comic_enabled"),"terrain_has_toon")
	stage._toggle_instructions()
	check(stage.get_node("HUD/GrenadeCooldown").is_visible_in_tree(),"tab_keeps_grenade_cooldown")
	await capture("global_comic_on")
	stage._set_comic_enabled(false)
	check(not floor_mesh.get_node("WorldInkOutline").visible,"terrain_outline_off")
	check(not floor_mesh.material_override.get_shader_parameter("comic_enabled"),"terrain_toon_off")
	check(not stage.head_style.enabled and not stage.combat.targets[0].comic_enabled,"characters_global_off")
	stage._spawn_chaos_drop()
	for node in stage.get_tree().get_nodes_in_group("kw_world_ink"):
		if stage.is_ancestor_of(node): check(not node.visible,"late_spawn_respects_comic_off")
	await capture("global_comic_off")
	stage._set_comic_enabled(true)
	stage._set_pixel_enabled(false)
	check(floor_mesh.get_node("WorldInkOutline").visible,"pixel_independent_from_ink")
	stage._set_pixel_enabled(true)
	stage.arena_audio.toggle_music()
	check(not stage.arena_audio.music_enabled,"music_toggle_off")
	stage.arena_audio.toggle_music()
	check(stage.arena_audio.music_enabled,"music_toggle_on")
	print("GLOBAL_STYLE_MUSIC_WEAPON_UI_PASS")
	# One radial event hits two enemies, not the third behind a solid wall.
	stage._add_static_box("BlastTestFloor",Vector3(0,-0.5,65),Vector3(40,1,40),Color(0.13,0.15,0.21))
	var placements := [Vector3(0,1.715,65),Vector3(3.2,1.715,65),Vector3(0,1.715,69)]
	for i in range(3):
		var bot: Node3D=stage.combat.targets[i]
		bot.set_physics_process(false)
		bot.global_position=placements[i]
		bot.movement_body.global_position=placements[i]
		bot.visuals.rotation=Vector3.ZERO
		bot._update_shapes()
	stage._add_static_box("BlastCover",Vector3(0,2.0,67),Vector3(3.0,4.0,0.4),Color(0.20,0.13,0.20))
	stage.player.global_position=Vector3(0,1.715,65)
	stage.camera.global_position=Vector3(8,7,75)
	stage.camera.look_at(Vector3(0,2,65),Vector3.UP)
	director.health=50
	director.hud.set_health(50,100,true)
	for i in range(4): await physics_frame
	var result: Dictionary=g.detonate(Vector3(0,1.7,65))
	check(result.targets.size()==2,"aoe_hits_nearby_targets_once")
	check(stage.combat.targets[0].dead,"blast_close_kill")
	check(stage.combat.targets[1].health<100 and stage.combat.targets[1].health>0,"blast_falloff")
	check(stage.combat.targets[2].health==100,"solid_cover_blocks_blast")
	check(stage.combat.total_kills==1 and director.health==58,"grenade_kill_heals_no_self_damage")
	check(not stage.combat.targets[1].receive_hit(10,Vector3.UP,result.id),"blast_idempotence")
	check(stage.arena_audio.event_counts.get("explosion",0)>0,"explosion_sound_triggered")
	g._tick_effects(0.06)
	await capture("grenade_explosion_radius")
	for i in range(100): g._tick_effects(1.0/60.0)
	check(g.effects.is_empty(),"explosion_fx_cleanup")
	stage.get_node("BlastCover").queue_free()
	for i in range(3): await physics_frame
	print("GRENADE_RADIUS_COVER_DAMAGE_KILL_HEAL_PASS")
	# Throw via the real aim path: fuse/collision and cooldown, not a teleport explosion.
	stage.player.global_position=Vector3(8,1.715,75)
	stage.player_visual.rotation=Vector3.ZERO
	stage.camera.global_position=Vector3(9.2,3.8,79)
	stage.camera.look_at(Vector3(8,0.1,61),Vector3.UP)
	check(g.throw_grenade(),"throw_ready")
	check(not g.throw_grenade(),"cannot_spam_cooldown")
	check(g.active.size()==1 and g.cooldown_left==6,"physical_grenade_and_cooldown")
	var origin: Vector3=g.active[0].body.global_position
	for i in range(10):
		await physics_frame
		g._physics_process(1.0/60.0)
	check(g.active.size()==1 and g.active[0].body.global_position.distance_to(origin)>0.8,"grenade_moves_in_arc")
	await capture("grenade_in_flight")
	var before: int=g.detonations
	for i in range(82):
		await physics_frame
		g._physics_process(1.0/60.0)
	check(g.active.is_empty() and g.detonations==before+1,"fuse_detonates_once")
	check(g.cooldown_left>4.0,"cooldown_not_reset_by_blast")
	for i in range(400): g._physics_process(1.0/60.0)
	check(g.cooldown_left==0 and g.skill_label.text.contains("READY"),"grenade_recharges")
	check(stage.arena_audio.event_counts.get("throw",0)==1,"throw_sound_once")
	check(g.throw_grenade(),"second_grenade_after_cooldown")
	director.damage_grace=0
	director.receive_player_damage(200,Vector3.ZERO)
	check(g.active.is_empty() and not g.throw_grenade(),"death_cancels_grenades")
	director.restart_run()
	check(g.cooldown_left==0 and not director.dead,"restart_resets_skill")
	print("GRENADE_THROW_FUSE_COOLDOWN_DEATH_PASS")
	# Footfall events are contact-driven. Idle must not keep making steps.
	stage.player.global_position=Vector3(5,1.715,65)
	stage.player.velocity=Vector3(0,-0.2,0)
	stage.player.move_and_slide()
	stage.locomotion.reset()
	stage.arena_audio.foot_states.clear()
	for bot in stage.combat.targets: bot.set_physics_process(false)
	var step_before: int=stage.arena_audio.event_counts.get("step",0)
	for i in range(110):
		await physics_frame
		stage.player.velocity=Vector3(0,-0.2,-4)
		stage.player.move_and_slide()
		stage._update_character_animation(1.0/60.0)
		stage.arena_audio._physics_process(1.0/60.0)
	check(stage.arena_audio.event_counts.get("step",0)>step_before+3,"walk_contacts_play_steps")
	print("FOOTSTEP_AUDIO_PASS")
	var file:=FileAccess.open(output.path_join("grenade_audio_ink_results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"blast":result,"audio_events":stage.arena_audio.event_counts},"\t"))
	file.close()
	stage.queue_free()
	for i in range(10): await process_frame
	print("GRENADE_AUDIO_INK_QA_","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
