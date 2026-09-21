extends SceneTree

const AK := preload("res://scripts/prototypes/ak47_voxel_builder.gd")
const KAR := preload("res://scripts/prototypes/kar_voxel_builder.gd")
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("PROJECTILE_SKIN_FX_FAIL " + label)

func color_matches(a: Color, b: Color) -> bool:
	return (
		absf(a.r - b.r) < 0.002
		and absf(a.g - b.g) < 0.002
		and absf(a.b - b.b) < 0.002
	)

func tracer_color(stage: Variant, weapon_id: String) -> Dictionary:
	var start := Vector3(0.0, 1.2, 2.0)
	var finish := Vector3(0.0, 1.2, -8.0)
	stage.combat._spawn_tracer(start, finish, weapon_id)
	var record: Dictionary = stage.combat.active_tracers[-1]
	var core := record["core"] as MeshInstance3D
	var material := core.material_override as StandardMaterial3D
	return {
		"color": material.albedo_color,
		"root": record["node"],
	}

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var old_ak := int(ProjectSettings.get_setting("kw3d/selected_ak_skin", 0))
	var old_kar := int(ProjectSettings.get_setting("kw3d/selected_kar_skin", 0))
	ProjectSettings.set_setting("kw3d/selected_ak_skin", 4)
	ProjectSettings.set_setting("kw3d/selected_kar_skin", 3)

	var stage: Variant = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	stage.use_menu_warrior_selection = false
	stage.player_warrior_id = "outrage"
	root.add_child(stage)
	for i in range(90):
		await physics_frame

	check(stage.ak_skin_id == 4, "ak_inferno_loaded")
	check(stage.kar_skin_id == 3, "kar_arctic_loaded")
	check(stage.ak_visual_root.find_child("InfernoWeaponParticles", true, false) is GPUParticles3D, "inferno_weapon_particles")

	var ak := tracer_color(stage, "ak")
	check(color_matches(ak["color"], AK.main_color(4)), "ak_bullet_main_color")
	check((ak["root"] as Node3D).find_child("InfernoBulletParticles", true, false) is GPUParticles3D, "inferno_bullet_particles")

	var shotgun := tracer_color(stage, "shotgun")
	check(color_matches(shotgun["color"], Color("6d4030")), "shotgun_bullet_main_color")
	check((shotgun["root"] as Node3D).find_child("InfernoBulletParticles", true, false) == null, "shotgun_no_inferno")

	var kar := tracer_color(stage, "kar")
	check(color_matches(kar["color"], KAR.main_color(3)), "kar_bullet_skin_main_color")
	check((kar["root"] as Node3D).find_child("InfernoBulletParticles", true, false) == null, "kar_no_inferno")

	stage._set_weapon_slot(1, false)
	check(not stage.ak_visual_root.visible, "inferno_particles_hide_with_ak")
	stage._set_weapon_slot(0, false)
	check(stage.ak_visual_root.visible, "inferno_particles_return_with_ak")

	ProjectSettings.set_setting("kw3d/selected_ak_skin", old_ak)
	ProjectSettings.set_setting("kw3d/selected_kar_skin", old_kar)
	print("PROJECTILE_SKIN_FX_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
