extends SceneTree

var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("SURFACE_IMPACT_PARTICLES_FAIL " + label)

func color_matches(a: Color, b: Color) -> bool:
	return (
		absf(a.r - b.r) < 0.025
		and absf(a.g - b.g) < 0.025
		and absf(a.b - b.b) < 0.025
	)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var stage: Variant = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	stage.use_menu_warrior_selection = false
	stage.use_menu_weapon_skin_selection = false
	root.add_child(stage)
	for i in range(90):
		await physics_frame

	var floor := stage.get_node("Floor") as StaticBody3D
	var floor_color := floor.get_meta("surface_color") as Color
	check(color_matches(floor_color, Color(0.075, 0.08, 0.11)), "floor_surface_metadata")
	check(color_matches(stage.combat._surface_color_from_collider(floor), floor_color), "floor_color_sampling")

	var before: int = stage.combat.hit_effects.size()
	stage.combat._spawn_impact(Vector3(0, 0.02, -6), Vector3.UP, floor_color, true)
	check(stage.combat.hit_effects.size() > before, "surface_particles_created")

	var debris: Array[MeshInstance3D] = []
	for index in range(before, stage.combat.hit_effects.size()):
		var created: Dictionary = stage.combat.hit_effects[index]
		if str(created.get("kind", "")) == "surface_debris":
			var created_node := created.get("node") as MeshInstance3D
			if created_node != null:
				debris.append(created_node)
	check(debris.size() >= 10, "surface_particle_count")
	if not debris.is_empty():
		var mat := debris[0].material_override as StandardMaterial3D
		check(mat != null, "surface_particle_material")
		if mat != null:
			var sampled := mat.albedo_color
			check(
				color_matches(sampled, floor_color)
				or color_matches(sampled, floor_color.lightened(0.16))
				or color_matches(sampled, floor_color.darkened(0.10)),
				"surface_particle_color"
			)
		var debris_box := debris[0].mesh as BoxMesh
		check(debris_box != null and debris_box.size.length() > 0.08, "surface_particles_larger")

	var effect: Dictionary = stage.combat.hit_effects[-1]
	var particle := effect["node"] as Node3D
	var duration := float(effect["duration"])
	stage.combat._update_feedback_effects(duration * 0.72)
	check(is_instance_valid(particle) and particle.scale.x < 0.70, "particle_shrinks_before_disappear")
	stage.combat._update_feedback_effects(duration * 0.35)
	await process_frame
	check(not is_instance_valid(particle) or not bool(particle.get_meta("kw_effect_active",false)), "particle_released")

	var wall := stage.get_node("BackWall") as StaticBody3D
	var wall_color := wall.get_meta("surface_color") as Color
	var holes_before: int = stage.combat.bullet_holes.size()
	stage.combat._spawn_impact(Vector3(0.0, 2.0, -29.58), Vector3.FORWARD, wall_color, true)
	check(stage.combat.bullet_holes.size() == holes_before + 1, "wall_bullet_hole_created")
	var hole := stage.combat.bullet_holes[-1] as MeshInstance3D
	check(hole != null and hole.name == "BulletHole", "bullet_hole_node")
	if hole != null:
		var hole_mat := hole.material_override as StandardMaterial3D
		check(hole_mat != null and hole_mat.albedo_color.get_luminance() < 0.02, "bullet_hole_black")
		check(hole.transparency < 0.10, "bullet_hole_initially_visible")
		await create_timer(1.20).timeout
		check(is_instance_valid(hole) and hole.transparency > 0.10, "bullet_hole_fades")
		await create_timer(0.70).timeout
		check(not is_instance_valid(hole) or not hole.visible, "bullet_hole_released")

	print("SURFACE_IMPACT_PARTICLES_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
