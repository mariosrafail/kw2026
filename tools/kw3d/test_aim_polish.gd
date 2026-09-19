extends "res://tools/kw3d/test_combat_polish.gd"
func run() -> void:
	stage = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	stage.combat.set_training_mode(true)
	# Freeze target travel for deterministic aim/terrain fixtures; roaming has its own test.
	stage.combat.set_roaming_enabled(false)
	stage.ak_fire_audio.volume_db = -80.0
	for i in range(30): await physics_frame
	stage.set_physics_process(false)
	stage.set_process_unhandled_input(false)
	var reticle: Control = stage.get_node("HUD/Crosshair")
	var viewport_center := root.get_visible_rect().size * 0.5
	var hud_center: Vector2 = reticle.get_global_transform_with_canvas() * (reticle.size * 0.5)
	print("COORDINATES viewport=",root.get_visible_rect()," window=",root.size," hud=",reticle.size," hud_screen=",hud_center," final=",root.get_final_transform())
	check(hud_center.distance_to(viewport_center)<0.01,"hud_and_camera_same_centre")
	await capture("aim_gameplay")
	# No lateral/vertical reticle drift while entering/exiting ADS in open space.
	stage.player.global_position = Vector3(0,1.715,65)
	stage.camera_yaw.rotation = Vector3.ZERO
	stage.camera_pitch.rotation = Vector3(-0.10,0,0)
	stage.camera.rotation = Vector3.ZERO
	stage.camera.position = Vector3(stage.CAMERA_SHOULDER_X,1.35,6.4)
	stage.camera_boom_z = 6.4
	stage.camera_safe_fraction = 1.0
	var centre := root.get_visible_rect().size * 0.5
	var point: Vector3 = stage.camera.project_ray_origin(centre) + stage.camera.project_ray_normal(centre) * 18.0
	var max_drift := 0.0
	for ads in [true,false,true]:
		stage.aiming = ads
		for i in range(90):
			stage._update_third_person_camera(1.0/60.0)
			max_drift = maxf(max_drift,stage.camera.unproject_position(point).distance_to(centre))
	check(max_drift<0.02,"ads_optical_ray_stays_fixed")
	print("ADS_STABILITY_PASS drift_px=",max_drift)
	# Hit what the dot points at, with either weapon side, from near to far.
	for side in [-1.0,1.0]:
		for distance in [1.8,4.0,9.0,18.0]:
			stage.combat.reset_targets()
			for i in range(2): await physics_frame
			var bot: Node3D = stage.combat.targets[0]
			bot.set_physics_process(false)
			stage.player.global_position = bot.global_position+Vector3(0,0,distance)
			stage.player_visual.rotation = Vector3.ZERO
			stage.torso_rig.rotation = Vector3.ZERO
			stage.body_yaw = 0.0
			stage.weapon_side = side
			stage.smoothed_weapon_side = side
			stage.camera.global_position = stage.player.global_position + Vector3(stage.CAMERA_SHOULDER_X,1.35,3.8)
			stage.camera.look_at(bot.global_position+Vector3(0,0.30,0),Vector3.UP)
			stage.camera.fov = 58.0
			stage._update_weapon_pose(0.0)
			var before: Dictionary = stage.combat.aim_solution.duplicate()
			check(before.target_ready and not before.occluded,"valid_target_feedback_"+str([side,distance]))
			stage.shot_cooldown = 0.0
			stage._fire_physics_ball()
			if bot.health != 80.0: print("AIM_DIAGNOSTIC ",[side,distance]," health=",bot.health," before=",before," actual=",stage.combat.last_shot," wanted=",bot.name)
			check(bot.health == 80.0,"crosshair_hit_"+str([side,distance]))
			check(before.end.distance_to(stage.combat.last_shot.end)<0.001,"preview_shot_match")
			if side < 0.0 and distance == 9.0:
				await capture("aim_hit_confirmation")
				for i in range(12): await physics_frame
				await capture("aim_target_clear")
	print("NEAR_FAR_BOTH_SIDES_PASS")
	# Gun blocked at the holder while the camera can still see the victim.
	stage.combat.reset_targets()
	for i in range(3): await physics_frame
	var target: Node3D = stage.combat.targets[0]
	target.set_physics_process(false)
	place_for_target(target)
	stage.camera.global_position=stage.player.global_position+Vector3(stage.CAMERA_SHOULDER_X,1.35,3.8)
	stage.camera.look_at(target.global_position+Vector3(0,0.30,0),Vector3.UP)
	stage.weapon_side = -1.0
	stage.smoothed_weapon_side = -1.0
	stage._update_weapon_pose(0.0)
	var chest: Vector3 = stage._weapon_anchor()
	var muzzle: Vector3 = stage.weapon_muzzle.global_position
	var wall := StaticBody3D.new()
	wall.name = "AimQACover"
	stage.add_child(wall)
	wall.global_position = chest.lerp(muzzle,0.55)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.32,2.0,0.32)
	collision.shape = box
	wall.add_child(collision)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = box.size
	mesh.mesh = bm
	mesh.material_override = stage._material(Color(0.13,0.19,0.3),false,0)
	wall.add_child(mesh)
	for i in range(3): await physics_frame
	stage._update_weapon_pose(0.0)
	check(stage.combat.camera_hit.get("collider")==target,"camera_sees_target_behind_side_cover")
	var prediction: Dictionary = stage.combat.aim_solution.duplicate()
	check(prediction.occluded and not prediction.target_ready,"amber_when_muzzle_blocked")
	check(reticle.blocked and not reticle.obstruction_label.visible,"cover_respected_without_blocked_label")
	stage.shot_cooldown = 0.0
	stage._fire_physics_ball()
	check(target.health==100.0,"no_damage_through_side_cover")
	check(prediction.end.distance_to(stage.combat.last_shot.end)<0.001,"blocker_preview_matches_shot")
	var projected: Vector2 = stage.camera.unproject_position(prediction.end)
	print("BLOCKED_POINT viewport=",projected," hud_local=",reticle.get_global_transform_with_canvas().affine_inverse()*projected)
	var local_point: Vector2 = reticle.get_global_transform_with_canvas().affine_inverse() * projected
	check((reticle.get_global_transform_with_canvas() * local_point).distance_to(projected)<0.01,"obstruction_marker_uses_logical_viewport")
	await capture("aim_cover_warning")
	wall.queue_free()
	for i in range(3): await physics_frame
	# Actual playable ADS composition, not an independent inspection camera.
	stage.player.global_position = Vector3(0,1.715,6)
	stage.player_visual.rotation = Vector3.ZERO
	stage.body_yaw = 0.0
	stage.camera.rotation = Vector3.ZERO
	stage.camera_yaw.rotation = Vector3.ZERO
	stage.camera_pitch.rotation = Vector3(-0.1,0,0)
	stage.camera_boom_z = 6.4
	stage.camera_safe_fraction = 1.0
	stage.locomotion.reset()
	stage.aiming = true
	var point_to_aim: Vector3 = stage.combat.targets[0].global_position + Vector3(0,0.3,0)
	for i in range(90):
		var direction: Vector3 = (point_to_aim - stage.camera.global_position).normalized()
		stage.camera_yaw.rotation.y = atan2(-direction.x,-direction.z)
		stage.camera_pitch.rotation.x = atan2(direction.y,Vector2(direction.x,direction.z).length())
		stage.body_yaw = stage.camera_yaw.rotation.y
		stage.player_visual.rotation.y = stage.body_yaw
		stage._update_third_person_camera(1.0/60.0)
		stage._update_character_animation(1.0/60.0)
		stage._update_weapon_pose(1.0/60.0)
	var self_hits := 0
	for rig in stage.head_style.get_children():
		for part_mesh in rig.get_children():
			if not part_mesh is MeshInstance3D or part_mesh.name == "ShaderInkOutline": continue
			var inverse: Transform3D = part_mesh.global_transform.affine_inverse()
			var ro: Vector3 = inverse * stage.camera.project_ray_origin(centre)
			var rd: Vector3 = inverse.basis * stage.camera.project_ray_normal(centre)
			if part_mesh.mesh.get_aabb().intersects_ray(ro,rd) != null: self_hits += 1
	check(self_hits==0,"own_character_does_not_cover_ads_dot")
	print("ADS_SELF_OCCLUSION_PASS count=",self_hits)
	await capture("aim_live_ads")
	# Camera wall collision may not allow a view outside the arena.
	stage.player.global_position = Vector3(0,1.715,65)
	stage.camera_yaw.rotation = Vector3.ZERO
	stage.camera_pitch.rotation = Vector3(-0.1,0,0)
	stage.camera.rotation = Vector3.ZERO
	stage.aiming = false
	stage.camera_boom_z = 6.4
	stage.camera_safe_fraction = 1.0
	stage._update_third_person_camera(0.0)
	var anchor: Vector3 = stage.camera_yaw.global_position
	var wanted: Vector3 = stage.camera_pitch.to_global(Vector3(stage.CAMERA_SHOULDER_X,1.35,6.4))
	var backwall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var wallbox := BoxShape3D.new(); wallbox.size = Vector3(5,5,0.4)
	shape.shape = wallbox
	stage.add_child(backwall);backwall.add_child(shape)
	backwall.global_position = anchor.lerp(wanted,0.65)
	for i in range(3): await physics_frame
	stage._update_third_person_camera(1.0/60.0)
	check(stage.camera_safe_fraction < 0.70,"camera_retracts_before_wall")
	var ray := PhysicsRayQueryParameters3D.create(anchor,stage.camera.global_position,1,[stage.player.get_rid()])
	check(stage.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"camera_not_behind_wall")
	backwall.queue_free()
	print("COVER_AND_CAMERA_COLLISION_PASS")
	# Resize and pixel toggles cannot change the aim/reticle centre relationship.
	for resolution in [Vector2i(1024,768),Vector2i(1600,900),Vector2i(1280,720)]:
		root.size = resolution
		for i in range(4): await process_frame
		var vc := root.get_visible_rect().size * 0.5
		var hc := reticle.get_global_transform_with_canvas() * (reticle.size * 0.5)
		check(vc.distance_to(hc)<0.02,"resize_crosshair_"+str(resolution))
		for pixels in [true,false]:
			stage._set_pixel_enabled(pixels)
			var target_point: Vector3=stage.camera.project_ray_origin(vc)+stage.camera.project_ray_normal(vc)*10.0
			check(stage.camera.unproject_position(target_point).distance_to(vc)<0.01,"projection_roundtrip")
	print("RESIZE_AND_PIXEL_AIM_PASS")
	var result := FileAccess.open(output.path_join("aim_results.json"),FileAccess.WRITE)
	result.store_string(JSON.stringify({"failures":failures,"ads_drift_px":max_drift},"	")); result.close()
	stage.queue_free()
	for i in range(10): await process_frame
	print("AIM_POLISH_QA_", "PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
