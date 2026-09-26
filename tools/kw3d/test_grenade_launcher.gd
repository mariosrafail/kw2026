extends SceneTree

const RULES := preload("res://scripts/kw3d/weapon_rules.gd")
const MOTOR := preload("res://scripts/kw3d/actor_motor.gd")
const SHOWROOM := preload("res://scripts/ui/main_menu/menu_weapon_showroom.gd")

var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("GRENADE_LAUNCHER_FAIL " + label)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var profile: Dictionary = RULES.by_slot(3)
	check(str(profile.get("id", "")) == "grenade_launcher", "slot_three_launcher_profile")
	check(int(profile.get("magazine", 0)) == 1, "single_shot_magazine")
	check(absf(float(profile.get("projectile_speed", 0.0)) - 22.0) < 0.001, "fixed_launch_speed")
	check(absf(float(profile.get("gravity", 0.0)) - 16.0) < 0.001, "launcher_gravity_profile")
	var showroom := Node3D.new()
	root.add_child(showroom)
	SHOWROOM.build_weapon(showroom, "grenade_launcher", 0)
	check(showroom.get_node_or_null("GL_Muzzle") is MeshInstance3D, "launcher_armory_preview")
	check(SHOWROOM.display_name("grenade_launcher") == "GRENADE LAUNCHER", "launcher_armory_name")
	showroom.free()

	var stage: Variant = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(12):
		await physics_frame
	stage.combat.set_training_mode(true)
	stage.combat.set_roaming_enabled(false)
	stage.grenade_skill.set_physics_process(false)
	stage._set_weapon_slot(3, false)
	check(stage.weapon_slot == 3, "offline_slot_three_selected")
	check(stage.grenade_launcher_visual_root != null and stage.grenade_launcher_visual_root.visible, "launcher_visual_visible")
	check(not stage.ak_visual_root.visible and not stage.shotgun_visual_root.visible and not stage.kar_visual_root.visible, "other_weapon_visuals_hidden")
	check(stage.grenade_launcher_fire_audio != null and stage.grenade_launcher_fire_audio.stream != null, "launcher_fire_audio_loaded")
	check(stage.grenade_launcher_reload_audio != null and stage.grenade_launcher_reload_audio.stream != null, "launcher_reload_audio_loaded")

	var horizontal_origin := Vector3(0.0, 8.0, 7.0)
	check(stage.grenade_skill.fire_launcher(horizontal_origin, Vector3(0.0, 0.0, -1.0), profile), "offline_horizontal_launch")
	check(stage.grenade_skill.active.size() == 1, "offline_projectile_created")
	if stage.grenade_skill.active.size() == 1:
		var projectile: Dictionary = stage.grenade_skill.active[0]
		var initial_velocity: Vector3 = projectile.velocity
		check(absf(initial_velocity.y) < 0.0001, "horizontal_launch_has_no_auto_lift")
		check(absf(initial_velocity.length() - 22.0) < 0.001, "offline_launch_speed_exact")
		var body := projectile.body as CharacterBody3D
		var before_y := body.global_position.y
		stage.grenade_skill._physics_process(0.10)
		if not stage.grenade_skill.active.is_empty():
			var after: Dictionary = stage.grenade_skill.active[0]
			check((after.velocity as Vector3).y < -1.0, "gravity_pulls_projectile_down")
			check((after.body as CharacterBody3D).global_position.y < before_y, "projectile_arc_descends")
	stage.grenade_skill.clear_active(false)

	var upward_direction := Vector3(0.0, 0.38, -1.0).normalized()
	check(stage.grenade_skill.fire_launcher(horizontal_origin, upward_direction, profile), "offline_upward_launch")
	if not stage.grenade_skill.active.is_empty():
		var upward: Dictionary = stage.grenade_skill.active[0]
		check((upward.velocity as Vector3).y > 6.0, "aiming_up_creates_positive_vertical_velocity")
	stage.grenade_skill.clear_active(false)

	stage.ammo_by_weapon[3] = 1
	stage.reload_by_weapon[3] = 0.0
	stage.shot_cooldown = 0.0
	stage._update_weapon_pose(0.0)
	stage._fire_physics_ball()
	check(stage.ammo_by_weapon[3] == 0, "launcher_shot_consumes_round")
	check(stage.grenade_skill.active.size() == 1, "weapon_fire_spawns_ballistic_projectile")
	check(stage.reload_by_weapon[3] > 0.0, "empty_launcher_starts_reload")
	stage.grenade_skill.clear_active(false)

	stage.aiming = true
	var yaw_before: float = stage.yaw
	var pitch_before: float = stage.pitch
	stage._apply_offline_aim_assist(1.0 / 60.0)
	check(not stage.aim_assist_active, "launcher_has_no_aim_magnet")
	check(absf(stage.yaw - yaw_before) < 0.000001 and absf(stage.pitch - pitch_before) < 0.000001, "launcher_aim_angle_preserved")
	stage.queue_free()
	for i in range(6):
		await process_frame

	var world: Node3D = load("res://scripts/kw3d/authority_world.gd").new()
	root.add_child(world)
	world.attacks_enabled = false
	world.add_player(1)
	var actor: Node3D = world.actors[1]
	actor.weapon_slot = 3
	actor.ammo_by_weapon[3] = 1
	actor.command = MOTOR.empty(0.0, 0.0)
	actor.command.weapon = 3
	actor.command.aim = false
	actor.command.fire = true
	world._shoot(actor)
	check(world.grenades.size() == 1, "authority_launcher_projectile_created")
	if world.grenades.size() == 1:
		var key: Variant = world.grenades.keys()[0]
		var grenade: Dictionary = world.grenades[key]
		check(str(grenade.get("kind", "")) == "launcher", "authority_projectile_kind")
		var velocity: Vector3 = grenade.v
		check(absf(velocity.length() - 22.0) < 0.01, "authority_fixed_launch_speed")
		var expected_direction: Vector3 = (actor.aim_target - actor.muzzle).normalized()
		check(velocity.normalized().dot(expected_direction) > 0.9999, "authority_uses_raw_aim_direction")
		var before_vy := velocity.y
		world._tick_grenades()
		if world.grenades.has(key):
			check(float((world.grenades[key] as Dictionary).v.y) < before_vy, "authority_gravity_reduces_vertical_velocity")
	world.queue_free()
	for i in range(5):
		await process_frame

	print("GRENADE_LAUNCHER_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
