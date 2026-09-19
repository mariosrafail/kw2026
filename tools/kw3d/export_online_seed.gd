extends SceneTree
func _initialize() -> void:
	export_seed.call_deferred()
func v3(v: Vector3) -> Array:
	return [v.x,v.y,v.z]
func describe(root: Node3D) -> Dictionary:
	var rigs: Dictionary = {}
	for rig in root.get_children():
		if not rig is Node3D or not str(rig.name).ends_with("Rig"): continue
		var parts: Array = []
		var sole: Dictionary = {}
		for part in rig.get_children():
			if not part is MeshInstance3D or "Outline" in str(part.name): continue
			var box: AABB = part.mesh.get_aabb()
			parts.append({"name":str(part.name),"p":v3(part.transform * box.get_center()),"r":v3(part.rotation),"s":v3(box.size * part.scale)})
			if str(part.name).ends_with("_Sole"):
				var corners: Array = []
				for i in range(8): corners.append(v3(part.transform * box.get_endpoint(i)))
				sole={"corners":corners,"center":v3(part.transform*(box.position+Vector3(box.size.x*0.5,0,box.size.z*0.5)))}
		rigs[str(rig.name)]={"p":v3(rig.position),"r":v3(rig.rotation),"parts":parts,"sole":sole}
	return rigs
func export_seed() -> void:
	var stage: Node3D = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	stage.set_physics_process(false)
	stage.set_process_unhandled_input(false)
	stage.combat.set_training_mode(true)
	stage.combat.set_roaming_enabled(false)
	var world: Array = []
	for body in stage.get_children():
		if not body is StaticBody3D: continue
		for c in body.get_children():
			if not c is CollisionShape3D: continue
			var row: Dictionary={"id":"solid_%02d"%world.size(),"p":v3(body.position),"r":v3(body.rotation),"local_p":v3(c.position)}
			if c.shape is BoxShape3D: row.merge({"kind":"box","s":v3(c.shape.size)})
			elif c.shape is CylinderShape3D: row.merge({"kind":"cylinder","radius":c.shape.radius,"height":c.shape.height})
			else: assert(false,"unsupported collision shape")
			world.append(row)
	var profiles: Dictionary={"outrage":describe(stage.head_style)}
	for skin in ["tasko","gan","celler","nova","m4","crashout"]:
		var bot: Node3D=load("res://scripts/prototypes/kw_training_dummy.gd").new()
		bot.warrior_id=skin;bot.roaming_enabled=false
		stage.add_child(bot)
		bot.set_physics_process(false)
		profiles[skin]=describe(bot.visuals)
		bot.free()
	var file=FileAccess.open("res://assets/kw3d/arena_seed.json",FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify({"schema":1,"revision":"kw-arena-01","world":world,"profiles":profiles},"\t"))
	file.close()
	print("ONLINE_SEED_EXPORTED colliders=",world.size()," profiles=",profiles.size()," joypads=",Input.get_connected_joypads())
	stage.free()
	quit()
