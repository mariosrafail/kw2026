extends SceneTree
const ASSIST:=preload("res://scripts/kw3d/aim_assist.gd")
const MOTOR:=preload("res://scripts/kw3d/actor_motor.gd")
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	if not v:
		failures.append(label);push_error("AIM_ASSIST_FAIL "+label)
func _initialize()->void:run.call_deferred()

func run()->void:
	var origin:=Vector3.ZERO
	var target:=Vector3(0.72,0.42,-12.0)
	var wanted:=ASSIST.target_angles(origin,target)
	var yaw:=wanted.x+deg_to_rad(4.0)
	var pitch:=wanted.y-deg_to_rad(1.5)
	var before:=ASSIST.angle_degrees(origin,yaw,pitch,target)
	check(before<ASSIST.CONE_DEG and before>2.0,"fixture_inside_cone")
	var assisted:=ASSIST.step(yaw,pitch,origin,target,1.0/60.0)
	var after:=ASSIST.angle_degrees(origin,assisted.x,assisted.y,target)
	check(after<before,"soft_magnet_reduces_angle")
	check(after>0.05,"soft_magnet_does_not_hard_snap")
	var outside_yaw:=wanted.x+deg_to_rad(7.0)
	var outside:=ASSIST.step(outside_yaw,wanted.y,origin,target,1.0/60.0)
	check(absf(wrapf(outside.x-outside_yaw,-PI,PI))<0.000001,"outside_cone_no_pull")
	check(not ASSIST.eligible(origin,wanted.x,wanted.y,Vector3(0,0,-60)),"range_cap")
	check(is_equal_approx(MOTOR.speed_for({"aim":false,"sprint":false}),7.5),"walk_speed")
	check(is_equal_approx(MOTOR.speed_for({"aim":false,"sprint":true}),11.0),"sprint_speed")
	check(is_equal_approx(MOTOR.speed_for({"aim":true,"sprint":false}),4.8),"ads_slow_speed")
	check(is_equal_approx(MOTOR.speed_for({"aim":true,"sprint":true}),4.8),"ads_blocks_sprint_speed")
	ProjectSettings.set_setting("kw3d/offline_test_mode","sandbox")
	var stage=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(8):await physics_frame
	stage.combat.set_training_mode(true);stage.combat.set_roaming_enabled(false)
	var enemy: Node3D=stage.combat.targets[0]
	enemy.set_physics_process(false)
	var point: Vector3=enemy.visuals.get_node("TorsoRig").global_position+Vector3.UP*0.34
	var desired:=ASSIST.target_angles(stage.camera.global_position,point)
	stage.yaw=desired.x+deg_to_rad(3.6);stage.pitch=desired.y;stage.aiming=true
	var chosen: Vector3=stage._best_offline_aim_assist_target()
	check(chosen.is_finite(),"offline_visible_target_acquired")
	if chosen.is_finite():
		var a0:=ASSIST.angle_degrees(stage.camera.global_position,stage.yaw,stage.pitch,chosen)
		stage._apply_offline_aim_assist(1.0/60.0)
		var a1:=ASSIST.angle_degrees(stage.camera.global_position,stage.yaw,stage.pitch,chosen)
		check(stage.aim_assist_active and a1<a0,"offline_runtime_magnet")
		var blocker:=StaticBody3D.new();blocker.collision_layer=1;blocker.collision_mask=0
		var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(3.0,3.0,3.0);shape.shape=box;blocker.add_child(shape)
		stage.add_child(blocker);blocker.global_position=stage.camera.global_position.lerp(chosen,0.45)
		for i in range(3):await physics_frame
		check(not stage._aim_assist_line_clear(chosen),"cover_blocks_magnet")
		blocker.queue_free()
	print("AIM_ASSIST_","PASS" if failures.is_empty() else "FAIL",failures,
		" before_deg=",before," after_deg=",after," ads_speed=",MOTOR.AIM_SPEED)
	stage.queue_free();quit(0 if failures.is_empty() else 1)
