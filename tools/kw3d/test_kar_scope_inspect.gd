extends SceneTree
const RULES:=preload("res://scripts/kw3d/weapon_rules.gd")
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	if not v:
		failures.append(label);push_error("KAR_SCOPE_FAIL "+label)
func _initialize()->void:run.call_deferred()

func _spread_angle(profile: Dictionary,aiming: bool,seed: int)->float:
	var base:=Vector3(0,0,-1)
	var d:=RULES.spread_direction(base,profile,aiming,seed)
	return rad_to_deg(acos(clampf(base.dot(d),-1.0,1.0)))

func run()->void:
	check(int(RULES.KAR.magazine)==1,"kar_one_round")
	check(is_equal_approx(float(RULES.KAR.reload),1.4),"kar_reload_1_4")
	check(is_equal_approx(RULES.damage(RULES.KAR,false),50.0),"kar_body_50")
	check(RULES.damage(RULES.KAR,true)>=100.0,"kar_head_instant_kill")
	var ak_hip:=_spread_angle(RULES.AK,false,12345)
	var ak_ads:=_spread_angle(RULES.AK,true,12345)
	var kar_hip:=_spread_angle(RULES.KAR,false,54321)
	var kar_ads:=_spread_angle(RULES.KAR,true,54321)
	check(ak_hip>ak_ads*5.0 and ak_hip>0.5,"ak_hip_spread_meaningful")
	check(kar_hip>kar_ads*10.0 and kar_hip>0.4,"kar_scope_accuracy_advantage")

	var holder:=Node3D.new();root.add_child(holder)
	load("res://scripts/prototypes/kar_voxel_builder.gd").build(holder)
	var parts:=holder.find_children("*","MeshInstance3D",true,false)
	check(parts.size()>=18,"kar_model_parts")
	var minp:=Vector3(INF,INF,INF);var maxp:=Vector3(-INF,-INF,-INF);var brown:=0
	for p in parts:
		var mi:=p as MeshInstance3D
		var a:=mi.mesh.get_aabb()
		for x in [a.position.x,a.end.x]:
			for y in [a.position.y,a.end.y]:
				for z in [a.position.z,a.end.z]:
					var q: Vector3=mi.transform*Vector3(x,y,z);minp=minp.min(q);maxp=maxp.max(q)
		var m:=mi.material_override as StandardMaterial3D
		if m!=null and m.albedo_color.r>m.albedo_color.b*1.25:brown+=1
	check((maxp-minp).x>2.6,"kar_long_profile")
	check(brown>=6,"kar_brown_identity")
	holder.free()

	ProjectSettings.set_setting("kw3d/offline_test_mode","sandbox")
	var stage=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate();root.add_child(stage)
	for i in range(8):await process_frame
	stage.combat.set_training_mode(true);stage.combat.set_roaming_enabled(false)
	stage._set_weapon_slot(2,false)
	check(stage.weapon_slot==2 and stage.kar_visual_root.visible and not stage.ak_visual_root.visible and not stage.shotgun_visual_root.visible,"kar_visual_slot")
	check(stage.ammo_in_mag==1,"kar_runtime_one_round")
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	stage.aiming=true
	for i in range(24):stage._update_third_person_camera(1.0/60.0)
	check(stage.camera.fov<31.0,"kar_scope_zoom")
	check(stage.sniper_scope_layer.visible,"kar_scope_overlay_visible")
	check(not stage.get_node("HUD/Crosshair").visible,"normal_crosshair_hidden")
	check(not stage.weapon_aim_pivot.visible,"weapon_hidden_in_scope")
	stage.aiming=false;stage._update_third_person_camera(0.25)
	check(not stage.sniper_scope_layer.visible and stage.weapon_aim_pivot.visible,"scope_restores_normal_view")

	var ammo_before: int=stage.ammo_in_mag
	stage._start_weapon_inspect()
	check(stage.inspect_time>1.5,"inspect_starts")
	var rot_before: Vector3=stage.weapon_visual_wobble.rotation
	stage._update_weapon_pose(0.32)
	check(stage.weapon_visual_wobble.rotation.distance_to(rot_before)>0.15,"inspect_rotates_3d_model")
	stage.shot_cooldown=0.0;stage._fire_physics_ball()
	check(stage.ammo_in_mag==ammo_before,"inspect_blocks_fire")
	for i in range(100):stage._update_weapon_pose(1.0/60.0)
	check(stage.inspect_time<=0.0001,"inspect_finishes")

	print("KAR_SCOPE_INSPECT_","PASS" if failures.is_empty() else "FAIL",failures,
		" ak_spread=",ak_hip,"/",ak_ads," kar_spread=",kar_hip,"/",kar_ads," kar_size=",maxp-minp)
	stage.queue_free();quit(0 if failures.is_empty() else 1)
