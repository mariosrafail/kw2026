extends SceneTree
const RULES:=preload("res://scripts/kw3d/weapon_rules.gd")
const REGIONS:=preload("res://scripts/kw3d/hit_regions.gd")
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	if not v:
		failures.append(label);push_error("WEAPON_DAMAGE_FAIL "+label)
func _initialize()->void:run.call_deferred()
func run()->void:
	ProjectSettings.set_setting("kw3d/offline_test_mode","sandbox")
	var stage=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(6):await physics_frame
	stage.combat.set_training_mode(true);stage.combat.set_roaming_enabled(false)
	var target: Node3D=stage.combat.targets[0]
	target.global_position=Vector3(0,1.715,65)
	target.movement_body.global_position=target.global_position
	target.roaming_enabled=false;target._update_shapes()
	for i in range(3):await physics_frame
	var head: Node3D=target.visuals.get_node("HeadRig/Head")
	var torso: Node3D=target.visuals.get_node("TorsoRig/Torso_Upper")
	var head_from:=head.global_position+Vector3(0,0,5.0)
	var body_from:=torso.global_position+Vector3(0,0,5.0)
	var head_hit: Dictionary=stage.combat._ray(head_from,head.global_position+Vector3(0,0,-0.5))
	var body_hit: Dictionary=stage.combat._ray(body_from,torso.global_position+Vector3(0,0,-0.5))
	check(not head_hit.is_empty() and head_hit.collider==target,"real_head_ray_hits_target")
	check(REGIONS.is_headshot(head_hit),"head_shape_maps_head")
	check(not body_hit.is_empty() and body_hit.collider==target,"real_body_ray_hits_target")
	check(not REGIONS.is_headshot(body_hit),"torso_shape_maps_body")
	check(is_equal_approx(RULES.damage(RULES.AK,false),5.0),"ak_body_5")
	check(is_equal_approx(RULES.damage(RULES.AK,true),7.5),"headshot_multiplier_1_5")
	check(is_equal_approx(RULES.damage(RULES.SHOTGUN,true),7.5),"shotgun_pellet_headshot_multiplier_1_5")

	target.health=100.0;target.dead=false;target.collision_layer=4
	stage.combat.camera_hit=head_hit
	var head_result: Dictionary=stage.combat.fire(head_from,head.global_position,head_from+Vector3(0,0,0.05))
	check(head_result.damage_applied and head_result.headshot,"actual_ak_headshot_applied")
	check(is_equal_approx(float(head_result.damage),7.5) and is_equal_approx(target.health,92.5),"actual_ak_headshot_7_5")
	target.health=100.0;target.dead=false;target.collision_layer=4
	stage.combat.camera_hit=body_hit
	var body_result: Dictionary=stage.combat.fire(body_from,torso.global_position,body_from+Vector3(0,0,0.05))
	check(body_result.damage_applied and not body_result.headshot,"actual_ak_bodyshot_applied")
	check(is_equal_approx(float(body_result.damage),5.0) and is_equal_approx(target.health,95.0),"actual_ak_bodyshot_5")

	stage._set_weapon_slot(1,false)
	check(stage.weapon_slot==1 and stage.shotgun_visual_root.visible and not stage.ak_visual_root.visible,"shotgun_visual_switch")
	check(stage.ammo_in_mag==2 and int(RULES.SHOTGUN.pellets)==10,"shotgun_two_shell_ten_pellet")
	check(stage.player_ammo_label.position.y>stage.player_health_bar.position.y,"ammo_ui_above_healthbar")
	check("SHOTGUN" in stage.player_ammo_label.text,"ammo_ui_weapon_name")
	target.health=100.0;target.dead=false;target.collision_layer=4
	var sg: Dictionary=stage.combat.fire_shotgun(body_from,torso.global_position,body_from+Vector3(0,0,0.05))
	check(sg.weapon=="shotgun" and sg.pellets.size()==10,"shotgun_fires_ten_real_rays")
	check(float(sg.damage)>=0.0,"shotgun_damage_finite")
	stage.queue_free();for i in range(3):await process_frame

	var world=load("res://scripts/kw3d/authority_world.gd").new();root.add_child(world);world.attacks_enabled=false;world.add_player(1)
	for i in range(3):await physics_frame
	var bot: Node3D=null
	for actor in world.actors.values():
		if actor.is_bot:bot=actor;break
	check(bot!=null,"authority_bot_exists")
	if bot!=null:
		bot.update_shapes()
		var head_shape: CollisionShape3D=null
		for record in bot.hit_records:
			if str(record.get("region",""))=="head":head_shape=record.shape;break
		check(head_shape!=null,"authority_head_shape_exists")
		if head_shape!=null:
			var hfrom:=head_shape.global_position+Vector3(0,0,2.0)
			var hhit: Dictionary=world.ray(hfrom,head_shape.global_position-Vector3(0,0,0.2),4)
			check(not hhit.is_empty() and REGIONS.is_headshot(hhit),"authority_real_head_ray")
			var hp_before: float=bot.health
			world.damage(bot.actor_id,RULES.damage(RULES.AK,true),Vector3.FORWARD,1,head_shape.global_position,true,"ak")
			check(is_equal_approx(bot.health,hp_before-7.5),"authority_headshot_7_5")
	print("WEAPON_DAMAGE_HEADSHOT_","PASS" if failures.is_empty() else "FAIL",failures,
		" head_hp=",92.5," body_hp=",95.0," shotgun_damage=",sg.damage)
	world.free();quit(0 if failures.is_empty() else 1)
