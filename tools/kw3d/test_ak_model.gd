extends SceneTree
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	if not v:
		failures.append(label);push_error("AK_MODEL_FAIL "+label)
func _initialize()->void:run.call_deferred()

func run()->void:
	var root3:=Node3D.new();root.add_child(root3)
	load("res://scripts/prototypes/ak47_voxel_builder.gd").build(root3)
	var parts: Array[MeshInstance3D]=[]
	for child in root3.get_children():
		if child is MeshInstance3D:parts.append(child)
	check(parts.size()>=20 and parts.size()<=28,"ak_part_count")
	var names:=PackedStringArray()
	var minp:=Vector3(INF,INF,INF);var maxp:=Vector3(-INF,-INF,-INF)
	var black_parts:=0
	for part in parts:
		names.append(part.name)
		var mat:=part.material_override as StandardMaterial3D
		check(mat!=null,"part_material_"+part.name)
		if mat!=null:
			var c:=mat.albedo_color
			if maxf(c.r,maxf(c.g,c.b))<0.12:black_parts+=1
		var aabb:=part.mesh.get_aabb()
		var local:=part.transform
		for x in [aabb.position.x,aabb.end.x]:
			for y in [aabb.position.y,aabb.end.y]:
				for z in [aabb.position.z,aabb.end.z]:
					var p: Vector3=local*Vector3(x,y,z)
					minp=minp.min(p);maxp=maxp.max(p)
	for required in ["StockBody","Receiver","TopCover","Handguard","Barrel","MuzzleBrake","PistolGrip","MagazineTop","MagazineMid","MagazineBottom","FrontSightPost"]:
		check(names.has(required),"missing_"+required)
	check(black_parts==0,"no_black_surfaces_materials")
	var size:=maxp-minp
	check(size.x>1.9 and size.x<2.4,"ak_length_preserved")
	check(size.y>0.9 and size.y<1.4,"ak_vertical_profile")
	check(size.z>0.28 and size.z<0.5,"ak_real_3d_depth")
	print("AK_MODEL_","PASS" if failures.is_empty() else "FAIL",failures," parts=",parts.size()," size=",size)
	root3.free();quit(0 if failures.is_empty() else 1)
