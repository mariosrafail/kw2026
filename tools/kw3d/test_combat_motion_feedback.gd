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
	var before_player_velocity: Vector3=stage.player.velocity
	var before_body_offset_velocity: Vector3=stage.locomotion.body_offset_velocity
	var before_body_angular_velocity: Vector3=stage.locomotion.body_angular_velocity
	var before_head_spring_velocity: Vector3=stage.head_spring_velocity
	stage._apply_body_fire_recoil(stage.yaw)
	check(stage.player.velocity.distance_to(before_player_velocity)<0.0001,"shot_recoil_does_not_move_characterbody")
	check(stage.locomotion.body_offset_velocity.z-before_body_offset_velocity.z>0.60 and stage.locomotion.body_angular_velocity.x-before_body_angular_velocity.x<-0.70,"shot_recoil_has_visual_body_kick")
	check(stage.head_spring_velocity.x-before_head_spring_velocity.x<-0.15,"shot_recoil_has_visual_head_kick")

	stage.combat.hit_effects.clear()
	var tasko: Color = stage.combat.blood_color_for_skin("tasko")
	stage.combat._spawn_damage_feedback(stage.player.global_position+Vector3.UP,Vector3.FORWARD,5.0,false,tasko,false)
	check(stage.combat.hit_effects.size()>=20,"blood_particles_are_dense")
	var largest_blood:=0.0
	for effect in stage.combat.hit_effects:
		if is_instance_valid(effect.node) and effect.node is MeshInstance3D and (effect.node as MeshInstance3D).mesh is BoxMesh:
			largest_blood=maxf(largest_blood,((effect.node as MeshInstance3D).mesh as BoxMesh).size.length())
	check(largest_blood>0.16,"blood_particles_are_visibly_large")
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
	var max_leg_split := -INF
	var min_leg_split := INF
	var min_body_y := INF
	var max_body_y := -INF
	for frame in range(120):
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
		var signed_split: float=(stage.left_leg_rig.global_position-stage.right_leg_rig.global_position).dot(Vector3.FORWARD)
		max_leg_split=maxf(max_leg_split,signed_split);min_leg_split=minf(min_leg_split,signed_split)
		var body_y: float=stage.torso_rig.position.y-stage.torso_rest.y
		min_body_y=minf(min_body_y,body_y);max_body_y=maxf(max_body_y,body_y)
	check(max_lift>0.48,"run_foot_lifts_high")
	check(max_duration>0.32,"run_air_pose_holds")
	check(max_swings==2 and double_air_frames>=18,"hop_step_has_long_double_air_overlap")
	check(max_leg_split>0.72 and min_leg_split<-0.72,"legs_alternate_front_and_back")
	check(max_body_y>0.12 and min_body_y<-0.025 and max_body_y-min_body_y>0.18,"body_head_high_low_cycle")
	print("COMBAT_MOTION_FEEDBACK_","PASS" if failures.is_empty() else "FAIL",failures,
		" max_lift=",max_lift," max_duration=",max_duration," double_air_frames=",double_air_frames,
		" split=[",min_leg_split,",",max_leg_split,"] body_y=[",min_body_y,",",max_body_y,"]")
	quit(0 if failures.is_empty() else 1)
