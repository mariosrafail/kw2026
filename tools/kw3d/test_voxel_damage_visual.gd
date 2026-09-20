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
	var mm_count: int=stage.head_style.find_children("DamageCells_*","MultiMeshInstance3D",true,false).size()
	check(mm_count==4,"player_uses_four_multimeshes")
	check(pd.damaged_cell_count()==0,"player_starts_pristine")

	var torso_point: Vector3=stage.torso_rig.global_position+Vector3(0,0.15,-0.25)
	var removed: int=pd.damage_at(torso_point,75.0,100.0,25.0,Vector3.FORWARD)
	check(removed>0 and removed<=10,"player_damage_removes_bounded_cells")
	check(pd.damaged_cell_count()>0,"player_hole_created")
	check(pd.debris.size()<=2,"player_debris_bounded")
	var nearest:=INF
	for cell in pd.cells:
		if bool(cell.hidden):
			var p: Vector3=(cell.rig as Node3D).global_transform*(cell.transform as Transform3D).origin
			nearest=minf(nearest,p.distance_to(torso_point))
	check(nearest<0.55,"player_hole_local_to_hit")
	pd.set_health(100.0,100.0)
	for i in range(40):await process_frame
	check(pd.damaged_cell_count()==0,"player_heal_restores_cells")

	var target: Node3D=stage.combat.targets[0]
	target.set_physics_process(false)
	var td=target.damage_visual
	check(td!=null and td.cell_count()>60,"enemy_damage_visual_exists")
	var enemy_mm: int=target.visuals.find_children("DamageCells_*","MultiMeshInstance3D",true,false).size()
	check(enemy_mm==4,"enemy_uses_four_multimeshes")
	var head_point: Vector3=target.visuals.get_node("HeadRig").global_position
	var before: int=td.damaged_cell_count()
	check(target.receive_hit(5.0,Vector3.FORWARD,991,head_point),"enemy_hit_applied")
	check(td.damaged_cell_count()>before,"enemy_hit_cuts_blocks")
	var enemy_nearest:=INF
	for cell in td.cells:
		if bool(cell.hidden):
			var p: Vector3=(cell.rig as Node3D).global_transform*(cell.transform as Transform3D).origin
			enemy_nearest=minf(enemy_nearest,p.distance_to(head_point))
	check(enemy_nearest<0.55,"enemy_hole_local_to_hit")
	target.health=target.max_health;target._refresh_bar();td.set_health(target.max_health,target.max_health)
	for i in range(30):await process_frame
	check(td.damaged_cell_count()==0,"enemy_heal_restores_cells")

	print("VOXEL_DAMAGE_VISUAL_","PASS" if failures.is_empty() else "FAIL",failures,
		" player_cells=",pd.cell_count()," enemy_cells=",td.cell_count()," multimeshes=",mm_count)
	stage.queue_free();quit(0 if failures.is_empty() else 1)
