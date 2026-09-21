extends SceneTree

const AK := preload("res://scripts/prototypes/ak47_voxel_builder.gd")
const SHOWROOM := preload("res://scripts/ui/main_menu/menu_weapon_showroom.gd")
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("AK_SKIN_FAIL " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	check(AK.skin_count() == 5, "skin_count")
	check(AK.skin_name(0) == "CLASSIC", "classic_name")
	check(AK.skin_name(4) == "INFERNO", "inferno_name")
	check(SHOWROOM.skin_count("ak47") == 5, "showroom_skin_count")

	var receiver_colors: Array[Color] = []
	for skin_id in range(AK.skin_count()):
		var model := Node3D.new()
		root.add_child(model)
		AK.build(model, skin_id)
		var receiver := model.get_node("Receiver") as MeshInstance3D
		var material := receiver.material_override as StandardMaterial3D
		receiver_colors.append(material.albedo_color)
		var flame_count := 0
		for child in model.get_children():
			if str(child.name).begins_with("InfernoFlame_"):
				flame_count += 1
		check(flame_count == (7 if skin_id == 4 else 0), "flame_geometry_%d" % skin_id)
		var flame_particles := model.get_node_or_null("InfernoWeaponParticles") as GPUParticles3D
		check((flame_particles != null) == (skin_id == 4), "flame_particles_%d" % skin_id)
		model.queue_free()

	check(receiver_colors[0] != receiver_colors[1], "crimson_recolor")
	check(receiver_colors[0] != receiver_colors[2], "arctic_recolor")
	check(receiver_colors[0] != receiver_colors[3], "neon_recolor")
	check(receiver_colors[4] != receiver_colors[0], "inferno_recolor")

	print("AK_SKIN_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
