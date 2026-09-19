extends "res://tools/kw3d/test_pixel_pass.gd"
func run() -> void:
	stage = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	stage.combat.set_training_mode(true)
	# Freeze target travel for deterministic aim/terrain fixtures; roaming has its own test.
	stage.combat.set_roaming_enabled(false)
	for i in range(5): await physics_frame
	stage.set_physics_process(false)
	stage.set_process_unhandled_input(false)
	var failure_count := 0
	for side in [-1.0,-0.5,0.0,0.5,1.0]:
		stage.weapon_side = side
		stage.smoothed_weapon_side = side
		for yaw in [0.0,1.4,-2.4]:
			stage.camera_yaw.rotation.y = yaw
			stage.torso_rig.rotation = Vector3(0.40,0.40,-0.40)
			stage.weapon_recoil = 1.0
			stage._update_weapon_pose(0.0)
			var desired: Vector3=(stage.aim_target-stage.weapon_muzzle.global_position).normalized()
			if desired.dot(stage.weapon_root.global_basis.x.normalized())<0.99998:
				failure_count+=1
				print("AIM_FAIL ",side," ",yaw)
			for gun in stage.weapon_root.get_children():
				if not gun is MeshInstance3D: continue
				for torso in stage.torso_rig.get_children():
					if not torso is MeshInstance3D or torso.name=="ShaderInkOutline": continue
					if overlaps(gun,torso):
						failure_count+=1
						if failure_count<6: print("CLIP ",side," ",yaw," ",gun.name," ",torso.name)
	# Crosshair must be centered in the actual HUD canvas, not at the top-left.
	await process_frame
	var crosshair: Control=stage.get_node("HUD/Crosshair")
	var line: ColorRect=crosshair.get_child(0)
	var center:=line.get_global_rect().get_center()
	if center.distance_to(crosshair.get_global_rect().get_center())>0.01:
		failure_count+=1
		print("RETICLE_FAIL ",center," ",crosshair.get_global_rect())
	stage.queue_free()
	for i in range(8): await process_frame
	print("SIDE_SWAP_CLEARANCE_RETICLE_", "PASS" if failure_count==0 else "FAIL", " failures=",failure_count)
	quit(0 if failure_count==0 else 1)
