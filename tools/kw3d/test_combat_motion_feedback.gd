extends SceneTree
var failures: Array[String] = []
var stage: Node3D

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		push_error("COMBAT_MOTION_FAIL " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	ProjectSettings.set_setting("kw3d/offline_test_mode","sandbox")
	stage = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(8):
		await physics_frame
	stage.combat.set_training_mode(true)
	stage.combat.set_roaming_enabled(false)
	check(stage.player_health_bar != null and stage.player_health_bar.texture != null,"own_healthbar_exists")
	stage._set_player_healthbar(60.0,100.0)
	check(absf(stage.player_health_value-60.0)<0.001,"own_healthbar_tracks_value")
	var health_image: Image = stage.player_health_texture.get_image()
	check(health_image.get_pixel(8,9).r > health_image.get_pixel(100,9).r,"own_healthbar_fill_visible")

	stage.player.velocity = Vector3.ZERO
	stage.yaw = 0.0
	stage._apply_body_fire_recoil(stage.yaw)
	check(stage.player.velocity.z > 1.20,"shot_pushes_player_backward")
	check(absf(stage.player.velocity.x)<0.001,"body_recoil_direction_clean")

	stage.combat.hit_effects.clear()
	var tasko: Color = stage.combat.blood_color_for_skin("tasko")
	stage.combat._spawn_damage_feedback(stage.player.global_position+Vector3.UP,Vector3.FORWARD,20.0,false,tasko,false)
	check(stage.combat.hit_effects.size()>=8,"blood_particles_spawn")
	if not stage.combat.hit_effects.is_empty():
		var chip: MeshInstance3D = stage.combat.hit_effects[0].node
		var material := chip.material_override as StandardMaterial3D
		check(material != null,"blood_material_exists")
		if material != null:
			var actual: Color = material.albedo_color
			check(Vector3(actual.r,actual.g,actual.b).distance_to(Vector3(tasko.r,tasko.g,tasko.b))<0.45,"blood_uses_victim_palette")

	stage.player.global_position = Vector3(0,1.716,65)
	stage._add_static_box("CombatMotionFloor",Vector3(0,-0.5,65),Vector3(80,1,80),Color(0.1,0.1,0.1))
	stage.player.velocity=Vector3(0,-0.1,-7.5)
	stage.player.move_and_slide()
	stage.locomotion.reset()
	var max_lift := 0.0
	var max_duration := 0.0
	var max_swings := 0
	var double_air_frames := 0
	for frame in range(100):
		stage.player.velocity=Vector3(0,-0.1,-7.5)
		stage.player.move_and_slide()
		stage._update_character_animation(1.0/60.0)
		var swings := 0
		for foot in stage.locomotion.feet:
			if foot.swinging:
				swings += 1
				max_lift=maxf(max_lift,foot.lift)
				max_duration=maxf(max_duration,foot.duration)
		max_swings=maxi(max_swings,swings)
		if swings==2:double_air_frames+=1
	check(max_lift>0.65,"run_foot_lifts_high")
	check(max_duration>0.27,"run_foot_airtime_longer")
	check(max_swings==2 and double_air_frames>=4,"hop_step_has_double_air_overlap")
	print("COMBAT_MOTION_FEEDBACK_","PASS" if failures.is_empty() else "FAIL",failures,
		" max_lift=",max_lift," max_duration=",max_duration," double_air_frames=",double_air_frames)
	quit(0 if failures.is_empty() else 1)
