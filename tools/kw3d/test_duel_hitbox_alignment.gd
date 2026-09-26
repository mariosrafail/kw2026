extends SceneTree

const RIG_NAMES := ["HeadRig","TorsoRig","LeftLegRig","RightLegRig"]

var failures: Array[String] = []

func check(value: bool,label: String) -> void:
	if value:return
	failures.append(label)
	push_error("DUEL_HITBOX_ALIGNMENT_FAIL "+label)

func _initialize() -> void:
	run.call_deferred()

func _part_center(actor: Node3D,rig_name: String,part: Dictionary) -> Vector3:
	var rig:=actor.rigs[rig_name] as Node3D
	var local:=Transform3D(Basis.from_euler(load("res://scripts/kw3d/online_level.gd").vec(part.r)),load("res://scripts/kw3d/online_level.gd").vec(part.p))
	return (rig.global_transform*local).origin

func run() -> void:
	var level: Dictionary=load("res://scripts/kw3d/online_level.gd").read()
	check((level.profiles as Dictionary).has("erebus"),"erebus_profile_exists")
	var erebus_profile:=level.profiles.erebus as Dictionary
	check((erebus_profile.HeadRig.parts as Array).size()==7,"erebus_head_profile_is_authored_model")

	var world: Node=load("res://scripts/kw3d/duel_authority_world.gd").new()
	root.add_child(world)
	await process_frame
	world.add_player(11)
	world.set_bot_fallback(11,true)
	check(world.start_match(11),"bot_match_starts")
	var bot_id: int=world.duel_bot_id
	var bot: Node3D=world.actors[bot_id]
	check(str(bot.hero_id)=="erebus","bot_is_erebus")
	check(bot.hit_records.size()==15,"server_uses_erebus_part_count")
	for index in range(220):world.step()
	await physics_frame
	bot.update_shapes()
	await physics_frame

	for rig_name in RIG_NAMES:
		var parts:=((erebus_profile[rig_name] as Dictionary).parts as Array)
		if parts.is_empty():continue
		# Ray through the centre of a real visible mesh part, from front to back.
		var centre:=_part_center(bot,rig_name,parts[0] as Dictionary)
		var from:=centre+Vector3(0,0,-3.0)
		var to:=centre+Vector3(0,0,3.0)
		var exclusions: Array[RID]=[]
		var hit: Dictionary=world.ray(from,to,5,exclusions)
		check(not hit.is_empty(),rig_name+"_visible_part_has_hurtbox")
		if not hit.is_empty():
			check(int((hit.collider as Node).get_meta("actor_id",0))==bot_id,rig_name+"_hurtbox_is_bot")

	# Exercise the actual authoritative AK shot path through a visible Erebus
	# torso point. This catches the exact "I shoot the model but HP does not move"
	# regression, not merely the presence of a CollisionShape3D.
	var shooter: Node3D=world.actors[11]
	var torso_part:=((erebus_profile.TorsoRig as Dictionary).parts as Array)[0] as Dictionary
	var torso_centre:=_part_center(bot,"TorsoRig",torso_part)
	shooter.muzzle=shooter.weapon_anchor()
	shooter.aim_target=torso_centre
	bot.damage_grace=0.0
	var hp_before: float=bot.health
	world._shoot_single(shooter,load("res://scripts/kw3d/weapon_rules.gd").AK,0,"ak")
	check(bot.health<hp_before,"visible_torso_ak_shot_deals_damage")

	# The authority foot sole should be essentially on the floor when grounded.
	var nearest_sole:=INF
	for foot in bot.locomotion.feet:
		for corner in foot.corners:
			nearest_sole=minf(nearest_sole,(foot.node.global_transform*(corner as Vector3)).y)
	check(bot.is_on_floor(),"bot_body_grounded")
	check(absf(nearest_sole)<=0.10,"bot_authority_feet_on_floor")

	print("DUEL_HITBOX_ALIGNMENT_", "PASS" if failures.is_empty() else "FAIL", failures, " sole_y=", nearest_sole)
	quit(0 if failures.is_empty() else 1)
