extends SceneTree

var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("WARRIOR_SKILL_FEEDBACK_FAIL " + label)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var stage: Variant = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	stage.use_menu_warrior_selection = false
	stage.player_warrior_id = "outrage"
	root.add_child(stage)
	for i in range(16):
		await physics_frame
	stage.combat.set_training_mode(true)
	stage.combat.set_roaming_enabled(false)
	check(stage.warrior_skill_label != null, "skill_label_exists")
	check(stage.warrior_skill_bar != null, "skill_bar_exists")

	stage.player_warrior_id = "outrage"
	stage.warrior_skill.reset()
	check(stage.warrior_skill.cast(), "outrage_cast")
	check(absf(stage.skill_damage_multiplier() - 2.0) < 0.001, "outrage_x2_damage")
	check(stage.player_visual.find_child("WarriorFireAuraParticles", true, false) is GPUParticles3D, "outrage_fire_aura")
	check("ACTIVE" in stage.warrior_skill_label.text, "active_text_visible")

	stage.warrior_skill.active_left = 0.0
	stage.warrior_skill.cooldown_left = 6.0
	stage._update_warrior_skill_hud(6.0, 0.0)
	check("6.0s" in stage.warrior_skill_label.text, "cooldown_seconds_visible")
	check(stage.warrior_skill_bar.value > 0.0 and stage.warrior_skill_bar.value < 1.0, "cooldown_bar_partial")

	stage.player_warrior_id = "erebus"
	stage.warrior_skill.reset()
	check(stage.warrior_skill.cast(), "erebus_cast")
	check(stage.skill_is_immune(), "erebus_immunity_active")
	var immunity_bubble := stage.player_visual.find_child("ImmunityBubble", true, false) as Node3D
	check(immunity_bubble != null, "erebus_bubble")
	if immunity_bubble != null:
		check(immunity_bubble.get_node_or_null("ShieldRing00") is MeshInstance3D, "erebus_bubble_ring")

	stage.player_warrior_id = "loker"
	stage.warrior_skill.reset()
	check(stage.warrior_skill.cast(), "loker_cast")
	check(absf(stage.skill_fire_interval_multiplier() - 0.64) < 0.001, "loker_fire_rate_boost")
	check(absf(stage.skill_reload_duration_multiplier() - 0.58) < 0.001, "loker_reload_boost")
	check(stage.player_visual.find_child("WarriorFireAuraParticles", true, false) is GPUParticles3D, "loker_green_aura")

	stage.player_warrior_id = "aevilok"
	stage.warrior_skill.reset()
	check(stage.warrior_skill.cast(), "aevilok_cast")
	check(stage.player_visual.find_child("AevilokFlamethrowerParticles", true, false) is GPUParticles3D, "aevilok_fire_particles")
	stage.warrior_skill._flamethrower_pulse()
	var world_burst := stage.get_node_or_null("AevilokWorldFlameBurst") as Node3D
	check(world_burst != null, "aevilok_world_flame_burst")
	if world_burst != null:
		var first_flame := world_burst.get_node_or_null("WorldFlame00") as MeshInstance3D
		var last_flame := world_burst.get_node_or_null("WorldFlame08") as MeshInstance3D
		check(first_flame != null and last_flame != null, "aevilok_world_flame_meshes")
		if first_flame != null and last_flame != null:
			check(first_flame.global_position.distance_to(stage.player.global_position) > 0.3, "aevilok_flame_starts_forward")
			check(last_flame.global_position.distance_to(stage.player.global_position) > 4.0, "aevilok_flame_extends_forward")
			check(not stage.camera.is_position_behind(first_flame.global_position), "aevilok_first_flame_in_front_of_camera")
			check(not stage.camera.is_position_behind(last_flame.global_position), "aevilok_last_flame_in_front_of_camera")

	stage.player_warrior_id = "kosas"
	stage.warrior_skill.reset()
	check(stage.warrior_skill.cast(), "kosas_cast")
	check(stage.get_node_or_null("KosasNoseRushTrail") is Node3D, "kosas_dash_trail")

	stage.warrior_skill.active_left = 0.0
	stage.warrior_skill.cooldown_left = 0.0
	stage._update_warrior_skill_hud(0.0, 0.0)
	check("READY" in stage.warrior_skill_label.text, "ready_text_visible")
	check(absf(stage.warrior_skill_bar.value - 1.0) < 0.001, "ready_bar_full")

	stage.queue_free()
	for i in range(5):
		await process_frame
	print("WARRIOR_SKILL_FEEDBACK_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
