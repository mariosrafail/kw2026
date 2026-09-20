extends SceneTree
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	if not v:
		failures.append(label);push_error("VOXEL_DAMAGE_FAIL "+label)
func _initialize()->void:run.call_deferred()

func run()->void:
	ProjectSettings.set_setting("kw3d/offline_test_mode","sandbox")
	var stage=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(8):await physics_frame
	stage.combat.set_training_mode(true);stage.combat.set_roaming_enabled(false)

	var pd=stage.player_damage_visual
	check(pd!=null,"player_damage_visual_exists")
	check(pd.cell_count()>120 and pd.cell_count()<1600,"player_cell_count_bounded")
	check(pd.source_mesh_count()>8,"player_original_mesh_records")
	var mm_count: int=stage.head_style.find_children("DamageCells_*","MultiMeshInstance3D",true,false).size()
	check(mm_count==0,"player_has_no_visible_damage_grid")
	var visible_originals:=0
	for rig_name in ["HeadRig","TorsoRig","LeftLegRig","RightLegRig"]:
		var rig: Node3D=stage.head_style.get_node(rig_name)
		for child in rig.get_children():
			if child is MeshInstance3D and child.name!="ShaderInkOutline" and child.visible:visible_originals+=1
	check(visible_originals>8,"player_original_meshes_stay_visible")
	var first_mesh: MeshInstance3D=stage.head_style.get_node("TorsoRig").get_child(0)
	var before_material:=first_mesh.material_override
	var torso_point: Vector3=stage.torso_rig.global_position+Vector3(0,0.15,-0.25)
	var removed: int=pd.damage_at(torso_point,75.0,100.0,25.0,Vector3.FORWARD)
	check(removed>0 and removed<=10,"player_damage_removes_bounded_cells")
	check(pd.damaged_cell_count()>0,"player_hole_created")
	check(pd.debris.size()<=2,"player_debris_bounded")
	check(first_mesh.visible,"player_original_mesh_still_visible_after_hit")
	check(first_mesh.material_override is ShaderMaterial,"player_damage_uses_original_shader_path")
	var nearest:=INF
	for cell in pd.cells:
		if bool(cell.hidden):
			var mesh:=cell.mesh as MeshInstance3D
			var p: Vector3=mesh.global_transform*Vector3(cell.local)
			nearest=minf(nearest,p.distance_to(torso_point))
	check(nearest<0.55,"player_hole_local_to_hit")
	var affected_materials:=0
	for record in pd.records:
		if (record.hidden_indices as Array[int]).size()>0:
			affected_materials+=1
			check(int((record.toon as ShaderMaterial).get_shader_parameter("damage_cell_count"))>0,"toon_cutout_uniform_updates")
	check(affected_materials>0,"player_affected_original_materials")
	var masked_outline:=false
	for info in pd.rig_outlines.values():
		if int((info.material as ShaderMaterial).get_shader_parameter("damage_cell_count"))>0:masked_outline=true
	check(masked_outline,"player_outline_skips_damage_holes")
	pd.set_health(100.0,100.0)
	for i in range(40):await process_frame
	check(pd.damaged_cell_count()==0,"player_heal_restores_cells")
	for info in pd.rig_outlines.values():check(int((info.material as ShaderMaterial).get_shader_parameter("damage_cell_count"))==0,"outline_restored_after_heal")
	var target: Node3D=stage.combat.targets[0]
	target.set_physics_process(false)
	var td=target.damage_visual
	check(td!=null and td.cell_count()>60,"enemy_damage_visual_exists")
	var enemy_mm: int=target.visuals.find_children("DamageCells_*","MultiMeshInstance3D",true,false).size()
	check(enemy_mm==0,"enemy_has_no_visible_damage_grid")
	var enemy_visible:=0
	for rig_name in ["HeadRig","TorsoRig","LeftLegRig","RightLegRig"]:
		var rig: Node3D=target.visuals.get_node(rig_name)
		for child in rig.get_children():
			if child is MeshInstance3D and child.name!="ShaderInkOutline" and child.visible:enemy_visible+=1
	check(enemy_visible>4,"enemy_original_model_stays_visible")
	var enemy_color_before: Color=(target.visuals.get_node("TorsoRig").get_child(0).get_meta("plain_material") as StandardMaterial3D).albedo_color
	var head_point: Vector3=target.visuals.get_node("HeadRig").global_position
	var before: int=td.damaged_cell_count()
	check(target.receive_hit(5.0,Vector3.FORWARD,991,head_point),"enemy_hit_applied")
	check(td.damaged_cell_count()>before,"enemy_hit_cuts_blocks")
	var enemy_nearest:=INF
	for cell in td.cells:
		if bool(cell.hidden):
			var mesh:=cell.mesh as MeshInstance3D
			var p: Vector3=mesh.global_transform*Vector3(cell.local)
			enemy_nearest=minf(enemy_nearest,p.distance_to(head_point))
	check(enemy_nearest<0.55,"enemy_hole_local_to_hit")
	var enemy_color_after: Color=(target.visuals.get_node("TorsoRig").get_child(0).get_meta("plain_material") as StandardMaterial3D).albedo_color
	check(enemy_color_before.is_equal_approx(enemy_color_after),"enemy_palette_preserved")
	target.health=target.max_health;target._refresh_bar();td.set_health(target.max_health,target.max_health)
	for i in range(30):await process_frame
	check(td.damaged_cell_count()==0,"enemy_heal_restores_cells")

	print("VOXEL_DAMAGE_VISUAL_","PASS" if failures.is_empty() else "FAIL",failures,
		" player_cells=",pd.cell_count()," enemy_cells=",td.cell_count()," visible_meshes=",visible_originals)
	stage.queue_free();quit(0 if failures.is_empty() else 1)
