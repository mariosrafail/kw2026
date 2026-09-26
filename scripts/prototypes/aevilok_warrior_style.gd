extends RefCounted
## Visual-only Aevilok treatment layered over the stable authored fullbody rig.
## Wings deliberately stay cosmetic: gameplay collision/hurtboxes keep the standard profile.

const HAND_STYLE := preload("res://scripts/prototypes/warrior_hand_style.gd")

const HEAD_BLACK := Color("09090d")
const HEAD_HIGHLIGHT := Color("1a1a22")
const BODY_BLACK := Color("0d0d13")
const BODY_RIB := Color("24232d")
const BODY_EDGE := Color("34313d")
const WING_FRAME := Color("0a090d")
const WING_FRAME_HIGHLIGHT := Color("29252e")
const WING_CRIMSON := Color("63172a")
const WING_CRIMSON_DARK := Color("35101c")
const WING_CRIMSON_BRIGHT := Color("9a2038")
const EYE_WHITE := Color("fff9ef")
const FOOT_DARK := Color("111118")


static func apply(model: Node3D) -> void:
	if model == null:
		return
	if bool(model.get_meta("aevilok_style_applied", false)):
		return
	model.set_meta("aevilok_style_applied", true)
	model.set_meta("warrior_id", "aevilok")
	model.set_meta("warrior_display_name", "Aevilok")
	model.set_meta("capsule_height", 3.43)
	model.set_meta("hitbox_profile", "standard")
	model.set_meta("wings_visual_only", true)
	HAND_STYLE.ensure_hands(model)

	var head := model.get_node_or_null("HeadRig") as Node3D
	var torso := model.get_node_or_null("TorsoRig") as Node3D
	var left_leg := model.get_node_or_null("LeftLegRig") as Node3D
	var right_leg := model.get_node_or_null("RightLegRig") as Node3D
	if head != null:
		head.position += Vector3(0.0, 0.20, -0.02)
		head.scale = Vector3(0.92, 0.88, 0.90)
		_build_head(head)
	if torso != null:
		torso.position += Vector3(0.0, -0.08, 0.03)
		torso.scale = Vector3.ONE
		_build_torso(torso)
		_build_wings(torso)
	if left_leg != null:
		left_leg.position += Vector3(0.10, -0.12, 0.02)
		left_leg.scale = Vector3.ONE * 0.58
	if right_leg != null:
		right_leg.position += Vector3(-0.10, -0.12, 0.02)
		right_leg.scale = Vector3.ONE * 0.58

	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or str(mesh.name).contains("Outline"):
			continue
		var part_name := str(mesh.name)
		_apply_color(mesh, _color_for_part(part_name), part_name)


static func _build_head(head: Node3D) -> void:
	if head.get_node_or_null("AevilokEye_Left") != null:
		return
	var source := head.get_node_or_null("Head_Core") as MeshInstance3D
	if source == null:
		return
	for old_eye_name in ["Eye_Left_Upper", "Eye_Left_Lower", "Eye_Right_Upper", "Eye_Right_Lower"]:
		var old_eye := head.get_node_or_null(old_eye_name) as MeshInstance3D
		if old_eye != null:
			old_eye.visible = false
	# Two white vertical pixel eyes. Each eye is exactly 2:1 in height-to-width,
	# so it reads as a clean two-pixel-tall bar rather than one wide rectangle.
	_add_box(head, "AevilokEye_Left", Vector3(-0.17, -0.055, -0.365), Vector3(0.09, 0.18, 0.075), source)
	_add_box(head, "AevilokEye_Right", Vector3(0.17, -0.055, -0.365), Vector3(0.09, 0.18, 0.075), source)
	# Aggressive brow bars angle down toward the center so the two white eyes read
	# as a permanent hostile glare instead of a neutral rectangular face.
	_add_box(head, "AevilokBrow_Left", Vector3(-0.17, 0.055, -0.407), Vector3(0.25, 0.065, 0.065), source, Vector3(0.0, 0.0, -15.0))
	_add_box(head, "AevilokBrow_Right", Vector3(0.17, 0.055, -0.407), Vector3(0.25, 0.065, 0.065), source, Vector3(0.0, 0.0, 15.0))
	# Blocky wedge jaw: two slanted cheek/jaw rails taper toward a narrow lower
	# chin, then a smaller final block extends the silhouette into a sharp point.
	_add_box(head, "AevilokCheek_Left", Vector3(-0.32, -0.19, -0.315), Vector3(0.24, 0.13, 0.22), source, Vector3(0.0, 0.0, -18.0))
	_add_box(head, "AevilokCheek_Right", Vector3(0.32, -0.19, -0.315), Vector3(0.24, 0.13, 0.22), source, Vector3(0.0, 0.0, 18.0))
	_add_box(head, "AevilokJaw_Left", Vector3(-0.17, -0.33, -0.305), Vector3(0.14, 0.34, 0.22), source, Vector3(0.0, 0.0, -29.0))
	_add_box(head, "AevilokJaw_Right", Vector3(0.17, -0.33, -0.305), Vector3(0.14, 0.34, 0.22), source, Vector3(0.0, 0.0, 29.0))
	_add_box(head, "AevilokChin_Base", Vector3(0.0, -0.48, -0.305), Vector3(0.22, 0.17, 0.23), source)
	_add_box(head, "AevilokChin_Point", Vector3(0.0, -0.61, -0.305), Vector3(0.10, 0.17, 0.20), source)
	_add_box(head, "AevilokHorn_Left", Vector3(-0.31, 0.27, 0.01), Vector3(0.12, 0.34, 0.14), source, Vector3(0.0, 0.0, -22.0))
	_add_box(head, "AevilokHorn_Right", Vector3(0.31, 0.27, 0.01), Vector3(0.12, 0.34, 0.14), source, Vector3(0.0, 0.0, 22.0))


static func _build_torso(torso: Node3D) -> void:
	if torso.get_node_or_null("AevilokTorsoCore") != null:
		return
	var source := torso.get_node_or_null("Torso_Upper") as MeshInstance3D
	if source == null:
		return
	for part_name in ["Torso_Upper", "Torso_Step", "Torso_Lower", "Torso_Tip", "ShaderInkOutline"]:
		var part := torso.get_node_or_null(part_name) as MeshInstance3D
		if part != null:
			part.visible = false
	_add_box(torso, "AevilokTorsoCore", Vector3(0.0, 0.00, 0.02), Vector3(0.60, 0.80, 0.38), source)
	_add_box(torso, "AevilokSpine", Vector3(0.0, 0.00, -0.225), Vector3(0.14, 0.73, 0.11), source)
	_add_box(torso, "AevilokRibTop", Vector3(0.0, 0.265, -0.22), Vector3(0.79, 0.11, 0.14), source)
	_add_box(torso, "AevilokRibMid", Vector3(0.0, 0.055, -0.22), Vector3(0.70, 0.11, 0.14), source)
	_add_box(torso, "AevilokRibLow", Vector3(0.0, -0.155, -0.22), Vector3(0.61, 0.11, 0.14), source)
	_add_box(torso, "AevilokChestSlit", Vector3(0.0, 0.020, -0.305), Vector3(0.10, 0.47, 0.06), source)


static func _build_wings(torso: Node3D) -> void:
	if torso.get_node_or_null("AevilokWingRoot") != null:
		return
	var source := torso.get_node_or_null("Torso_Upper") as MeshInstance3D
	if source == null:
		return
	var root := Node3D.new()
	root.name = "AevilokWingRoot"
	root.position = Vector3(0.0, 0.08, 0.07)
	root.set_meta("visual_only", true)
	root.set_meta("gameplay_hitbox", false)
	torso.add_child(root)
	_build_wing_side(root, source, -1.0, "Left")
	_build_wing_side(root, source, 1.0, "Right")
	_remember_wing_rest(root)


static func animate_wings(
	model: Node3D,
	delta: float,
	time: float,
	walk_phase: float,
	horizontal_speed: float,
	vertical_velocity: float,
	grounded: bool
) -> void:
	if model == null:
		return
	var wing_root := model.get_node_or_null("TorsoRig/AevilokWingRoot") as Node3D
	if wing_root == null:
		return

	# The whole wing motion is procedural so it follows locomotion immediately.
	# The important part is that the wing now behaves like an articulated surface:
	# the shoulder drives the stroke, the outer span follows with a small delay, and
	# the tips exaggerate the motion instead of rotating as one rigid board.
	var speed_blend := clampf(horizontal_speed / 7.5, 0.0, 1.35)
	var target_lift := 0.0
	var target_sweep := 0.0
	var target_fold := 0.0
	var target_curl := 0.0
	var flutter := 0.0

	if grounded:
		if speed_blend > 0.05:
			# One broad flap per gait cycle with a slightly sharper power stroke.  The
			# second harmonic stops the motion from looking like a simple sine pendulum.
			var raw_beat := sin(walk_phase - 0.38)
			var beat := signf(raw_beat) * pow(absf(raw_beat), 0.72)
			var second := sin(walk_phase * 2.0 + 0.85)
			target_lift = deg_to_rad(10.0 + speed_blend * (14.0 + beat * 18.0))
			# Keep a little rearward rake while moving; sprinting opens the wings more.
			target_sweep = deg_to_rad(-17.0 + speed_blend * (7.0 + cos(walk_phase + 0.25) * 5.5))
			# Outer sections fold more on the upstroke and spread on the downstroke.
			target_fold = deg_to_rad(7.0 + speed_blend * (7.0 + beat * 5.0 + second * 3.0))
			target_curl = deg_to_rad(-9.0 + speed_blend * (4.0 - beat * 3.0))
			flutter = speed_blend * 0.72
		else:
			# Idle: fold the wings visibly behind the body instead of leaving the full
			# span sticking sideways.  A tiny breathing pulse keeps them alive.
			target_lift = deg_to_rad(7.5 + sin(time * 1.55) * 1.6)
			target_sweep = deg_to_rad(-34.0 + sin(time * 1.15) * 2.2)
			target_fold = deg_to_rad(16.0 + sin(time * 1.45 + 0.8) * 2.0)
			target_curl = deg_to_rad(-22.0 + sin(time * 1.10 + 0.35) * 2.0)
			flutter = 0.08
	else:
		if vertical_velocity > 1.0:
			# Ascending: a strong, fast power flap.  The wing folds on the high
			# recovery stroke and opens during the downward drive.
			var jump_raw := sin(time * 10.2)
			var jump_beat := signf(jump_raw) * pow(absf(jump_raw), 0.68)
			target_lift = deg_to_rad(31.0 + jump_beat * 22.0)
			target_sweep = deg_to_rad(-7.0 + cos(time * 10.2 + 0.45) * 4.0)
			target_fold = deg_to_rad(13.0 + jump_beat * 9.0)
			target_curl = deg_to_rad(-4.0 - maxf(jump_beat, 0.0) * 7.0)
			flutter = 1.0
		elif vertical_velocity < -1.0:
			# Falling: spread into a broad glide.  The span stays open and only the
			# outer membrane/tips ripple in the airflow.
			target_lift = deg_to_rad(18.0 + sin(time * 3.8) * 2.8)
			target_sweep = deg_to_rad(-2.0 + sin(time * 2.9) * 2.0)
			target_fold = deg_to_rad(-3.0 + sin(time * 4.2) * 2.2)
			target_curl = deg_to_rad(-1.5)
			flutter = 0.32
		else:
			# Apex: flare high and wide for the suspended silhouette before the glide.
			target_lift = deg_to_rad(40.0 + sin(time * 4.8) * 4.0)
			target_sweep = deg_to_rad(-3.0)
			target_fold = deg_to_rad(7.0)
			target_curl = deg_to_rad(-4.0)
			flutter = 0.40

	var dt := clampf(delta, 0.0, 0.10)
	var response := 1.0 - exp(-dt * (10.5 if grounded else 15.5))
	var lift := lerp_angle(float(wing_root.get_meta("anim_lift", target_lift)), target_lift, response)
	var sweep := lerp_angle(float(wing_root.get_meta("anim_sweep", target_sweep)), target_sweep, response)
	var fold := lerp_angle(float(wing_root.get_meta("anim_fold", target_fold)), target_fold, response)
	var curl := lerp_angle(float(wing_root.get_meta("anim_curl", target_curl)), target_curl, response)
	wing_root.set_meta("anim_lift", lift)
	wing_root.set_meta("anim_sweep", sweep)
	wing_root.set_meta("anim_fold", fold)
	wing_root.set_meta("anim_curl", curl)

	for child in wing_root.get_children():
		var part := child as MeshInstance3D
		if part == null or not part.has_meta("aevilok_wing_rest_transform"):
			continue
		var rest := part.get_meta("aevilok_wing_rest_transform") as Transform3D
		var side := float(part.get_meta("aevilok_wing_side",1.0))
		var outer_blend := float(part.get_meta("aevilok_wing_outer_blend",0.0))
		var outer_curve := float(part.get_meta("aevilok_wing_outer_curve",0.0))
		var tip_blend := float(part.get_meta("aevilok_wing_tip_blend",0.0))
		# The actual hinge sits at the shoulder rather than the torso centre.  Keeping
		# this point stable makes the frame feel attached while the span beats around it.
		var shoulder := part.get_meta("aevilok_wing_shoulder",Vector3(side*0.44,0.20,-0.07)) as Vector3
		# Membranes follow a little behind the frame; tips exaggerate secondary motion.
		var drag := float(part.get_meta("aevilok_wing_drag",1.0))
		var flex_wave := sin(
			(time * (9.2 if not grounded else 6.2))
			- outer_blend * 1.35
			+ (0.22 if side > 0.0 else 0.0)
		)
		var part_lift := lift * drag + fold * outer_blend + deg_to_rad(7.5) * flutter * outer_blend * flex_wave
		var part_sweep := sweep + curl * outer_curve
		# Tip joints get one last delayed flick at the end of each stroke.
		part_lift += deg_to_rad(6.0) * flutter * tip_blend * sin(time * (10.8 if not grounded else 7.0) - 1.15)
		var articulated := Basis(Vector3.FORWARD, side * part_lift)
		articulated = articulated * Basis(Vector3.UP, side * part_sweep)
		var from_shoulder := part.get_meta("aevilok_wing_from_shoulder",rest.origin-shoulder) as Vector3
		var articulated_origin := shoulder + articulated * from_shoulder
		var new_transform:=Transform3D(articulated*rest.basis,articulated_origin)
		part.transform=new_transform
		var batch_mm: MultiMesh=null
		if part.has_meta("aevilok_wing_batch_multimesh"):
			batch_mm=part.get_meta("aevilok_wing_batch_multimesh") as MultiMesh
		if batch_mm!=null:
			var batch_index:=int(part.get_meta("aevilok_wing_batch_index",-1))
			var batch_size:=part.get_meta("aevilok_wing_batch_size",Vector3.ONE) as Vector3
			if batch_index>=0:batch_mm.set_instance_transform(batch_index,new_transform*Transform3D(Basis.from_scale(batch_size),Vector3.ZERO))


static func enable_wing_batch(model: Node3D) -> int:
	if model==null:return 0
	var wing_root:=model.get_node_or_null("TorsoRig/AevilokWingRoot") as Node3D
	if wing_root==null:return 0
	if bool(wing_root.get_meta("aevilok_wing_batch_enabled",false)):
		return int(wing_root.get_meta("aevilok_wing_batch_count",0))
	var groups: Dictionary={}
	for child in wing_root.get_children():
		var part:=child as MeshInstance3D
		if part==null or part.mesh==null or not part.visible:continue
		var mat:=part.material_override as ShaderMaterial
		if mat==null:continue
		var color_value: Variant=mat.get_shader_parameter("base_color")
		var color: Color=color_value as Color if color_value is Color else Color.WHITE
		var key: String=color.to_html(true)
		if not groups.has(key):groups[key]={"material":mat,"parts":[]}
		(groups[key].parts as Array).append(part)
	var batches: Array=[]
	for key in groups:
		var group: Dictionary=groups[key]
		var parts: Array=group.parts as Array
		var cube:=BoxMesh.new();cube.size=Vector3.ONE;cube.material=group.material as Material
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=cube;mm.instance_count=parts.size()
		var instance:=MultiMeshInstance3D.new();instance.name="AevilokWingBatch_"+str(key);instance.multimesh=mm
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;instance.visibility_range_end=72.0;instance.visibility_range_end_margin=8.0
		instance.set_meta("kw_batch_material_source",str((parts[0] as MeshInstance3D).name))
		wing_root.add_child(instance)
		var sizes: Array=[]
		for index in range(parts.size()):
			var mesh_part:=parts[index] as MeshInstance3D
			var size:=mesh_part.mesh.get_aabb().size
			sizes.append(size)
			mm.set_instance_transform(index,mesh_part.transform*Transform3D(Basis.from_scale(size),Vector3.ZERO))
			mesh_part.set_meta("aevilok_wing_batch_multimesh",mm)
			mesh_part.set_meta("aevilok_wing_batch_index",index)
			mesh_part.set_meta("aevilok_wing_batch_size",size)
			mesh_part.visible=false
		batches.append({"multimesh":mm,"parts":parts,"sizes":sizes})
	wing_root.set_meta("aevilok_wing_batches",batches)
	wing_root.set_meta("aevilok_wing_batch_enabled",true)
	wing_root.set_meta("aevilok_wing_batch_count",batches.size())
	return batches.size()


static func _sync_wing_batches(wing_root: Node3D) -> void:
	if wing_root==null or not bool(wing_root.get_meta("aevilok_wing_batch_enabled",false)):return
	var batches:=wing_root.get_meta("aevilok_wing_batches",[]) as Array
	for batch in batches:
		var mm:=batch.multimesh as MultiMesh
		var parts:=batch.parts as Array
		var sizes:=batch.sizes as Array
		for i in range(parts.size()):
			var part:=parts[i] as MeshInstance3D
			if part==null:continue
			mm.set_instance_transform(i,part.transform*Transform3D(Basis.from_scale(sizes[i] as Vector3),Vector3.ZERO))


static func _remember_wing_rest(root: Node3D) -> void:
	for child in root.get_children():
		var part := child as MeshInstance3D
		if part != null:
			var rest:=part.transform
			var part_name:=str(part.name)
			var side:=-1.0 if "Left" in part_name else 1.0
			var outer_blend:=smoothstep(0.85,2.90,absf(rest.origin.x))
			var tip_blend:=smoothstep(2.45,2.95,absf(rest.origin.x))
			var drag:=1.0
			if "Membrane" in part_name:drag=0.90
			elif "Stripe" in part_name:drag=0.94
			elif "Tip" in part_name:drag=1.16
			var shoulder:=Vector3(side*0.44,0.20,-0.07)
			part.set_meta("aevilok_wing_rest_transform",rest)
			part.set_meta("aevilok_wing_side",side)
			part.set_meta("aevilok_wing_outer_blend",outer_blend)
			part.set_meta("aevilok_wing_outer_curve",pow(outer_blend,1.35))
			part.set_meta("aevilok_wing_tip_blend",tip_blend)
			part.set_meta("aevilok_wing_drag",drag)
			part.set_meta("aevilok_wing_shoulder",shoulder)
			part.set_meta("aevilok_wing_from_shoulder",rest.origin-shoulder)


static func _build_wing_side(root: Node3D, source: MeshInstance3D, side: float, label: String) -> void:
	var prefix := "AevilokWing%s" % label
	_add_box(root, "%s_ShoulderFrame" % prefix, Vector3(side * 0.68, 0.32, -0.05), Vector3(1.00, 0.18, 0.15), source, Vector3(0.0, 0.0, side * 21.0))
	_add_box(root, "%s_UpperFrame" % prefix, Vector3(side * 1.48, 0.67, -0.05), Vector3(1.08, 0.16, 0.14), source, Vector3(0.0, 0.0, side * 17.0))
	_add_box(root, "%s_OuterFrame" % prefix, Vector3(side * 2.28, 0.60, -0.05), Vector3(0.95, 0.16, 0.14), source, Vector3(0.0, 0.0, -side * 12.0))
	_add_box(root, "%s_LowerFrame" % prefix, Vector3(side * 1.67, -0.29, -0.05), Vector3(1.55, 0.16, 0.135), source, Vector3(0.0, 0.0, -side * 17.0))
	_add_box(root, "%s_InnerBrace" % prefix, Vector3(side * 0.91, -0.02, -0.055), Vector3(0.92, 0.13, 0.11), source, Vector3(0.0, 0.0, -side * 31.0))
	_add_box(root, "%s_MidBrace" % prefix, Vector3(side * 1.75, 0.21, -0.055), Vector3(1.02, 0.12, 0.11), source, Vector3(0.0, 0.0, side * 4.0))
	_add_box(root, "%s_MembraneInner" % prefix, Vector3(side * 0.95, 0.17, 0.025), Vector3(0.92, 0.48, 0.060), source, Vector3(0.0, 0.0, side * 13.0))
	_add_box(root, "%s_MembraneMid" % prefix, Vector3(side * 1.63, 0.16, 0.025), Vector3(1.02, 0.60, 0.060), source, Vector3(0.0, 0.0, side * 2.0))
	_add_box(root, "%s_MembraneOuter" % prefix, Vector3(side * 2.30, 0.11, 0.025), Vector3(0.80, 0.52, 0.060), source, Vector3(0.0, 0.0, -side * 15.0))
	_add_box(root, "%s_MembraneLower" % prefix, Vector3(side * 1.74, -0.24, 0.028), Vector3(1.12, 0.34, 0.058), source, Vector3(0.0, 0.0, -side * 16.0))
	_add_box(root, "%s_StripeInner" % prefix, Vector3(side * 1.00, 0.25, -0.032), Vector3(0.68, 0.075, 0.075), source, Vector3(0.0, 0.0, side * 13.0))
	_add_box(root, "%s_StripeMid" % prefix, Vector3(side * 1.66, 0.20, -0.032), Vector3(0.76, 0.075, 0.075), source, Vector3(0.0, 0.0, side * 2.0))
	_add_box(root, "%s_StripeOuter" % prefix, Vector3(side * 2.28, 0.13, -0.032), Vector3(0.57, 0.075, 0.075), source, Vector3(0.0, 0.0, -side * 15.0))
	_add_box(root, "%s_TipUpper" % prefix, Vector3(side * 2.84, 0.83, -0.045), Vector3(0.58, 0.12, 0.11), source, Vector3(0.0, 0.0, side * 29.0))
	_add_box(root, "%s_TipMid" % prefix, Vector3(side * 2.91, 0.36, -0.045), Vector3(0.54, 0.12, 0.11), source, Vector3(0.0, 0.0, -side * 7.0))
	_add_box(root, "%s_TipLow" % prefix, Vector3(side * 2.76, -0.39, -0.045), Vector3(0.70, 0.12, 0.11), source, Vector3(0.0, 0.0, -side * 28.0))


static func _add_box(parent: Node3D, part_name: String, pos: Vector3, size: Vector3, source: MeshInstance3D, rot_degrees: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = part_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	mesh.rotation_degrees = rot_degrees
	var source_plain: StandardMaterial3D = null
	if source.has_meta("plain_material") and source.get_meta("plain_material") is StandardMaterial3D:
		source_plain = source.get_meta("plain_material") as StandardMaterial3D
	elif source.material_override is StandardMaterial3D:
		source_plain = source.material_override as StandardMaterial3D
	if source_plain != null:
		var plain := source_plain.duplicate(true) as StandardMaterial3D
		plain.resource_local_to_scene = true
		mesh.set_meta("plain_material", plain)
		mesh.material_override = plain
	var source_toon: ShaderMaterial = null
	if source.has_meta("toon_material") and source.get_meta("toon_material") is ShaderMaterial:
		source_toon = source.get_meta("toon_material") as ShaderMaterial
	if source_toon != null:
		var toon := source_toon.duplicate(true) as ShaderMaterial
		toon.resource_local_to_scene = true
		mesh.set_meta("toon_material", toon)
	parent.add_child(mesh)
	return mesh


static func _color_for_part(part_name: String) -> Color:
	if part_name.begins_with("AevilokEye_"):
		return EYE_WHITE
	if part_name.begins_with("AevilokBrow_"):
		return HEAD_BLACK
	if part_name.begins_with("AevilokCheek_") or part_name.begins_with("AevilokJaw_"):
		return HEAD_HIGHLIGHT
	if part_name == "AevilokChin_Base":
		return HEAD_HIGHLIGHT
	if part_name == "AevilokChin_Point":
		return HEAD_BLACK
	if part_name.begins_with("AevilokHorn_"):
		return HEAD_HIGHLIGHT
	if part_name == "Head_Core":
		return HEAD_BLACK
	if part_name in ["Head_Top_Cap", "Head_Bottom_Cap"]:
		return HEAD_HIGHLIGHT
	if part_name == "AevilokTorsoCore":
		return BODY_BLACK
	if part_name == "AevilokSpine":
		return BODY_EDGE
	if part_name.begins_with("AevilokRib"):
		return BODY_RIB
	if part_name == "AevilokChestSlit":
		return WING_CRIMSON_BRIGHT
	if part_name.begins_with("AevilokWing"):
		if "Stripe" in part_name:
			return WING_CRIMSON_BRIGHT
		if "MembraneOuter" in part_name or "MembraneLower" in part_name:
			return WING_CRIMSON_DARK
		if "Membrane" in part_name:
			return WING_CRIMSON
		if "Brace" in part_name:
			return WING_FRAME_HIGHLIGHT
		return WING_FRAME
	if part_name.begins_with("Foot_"):
		return FOOT_DARK
	if part_name.begins_with("Torso_"):
		return BODY_BLACK
	if part_name.begins_with("Eye_"):
		return HEAD_BLACK
	return BODY_BLACK


static func _apply_color(mesh: MeshInstance3D, color: Color, part_name: String) -> void:
	var source_plain: StandardMaterial3D = null
	if mesh.has_meta("plain_material") and mesh.get_meta("plain_material") is StandardMaterial3D:
		source_plain = mesh.get_meta("plain_material") as StandardMaterial3D
	elif mesh.material_override is StandardMaterial3D:
		source_plain = mesh.material_override as StandardMaterial3D
	var plain := StandardMaterial3D.new()
	if source_plain != null:
		plain = source_plain.duplicate(true) as StandardMaterial3D
	plain.resource_local_to_scene = true
	plain.albedo_texture = null
	plain.albedo_color = color
	plain.metallic = 0.30 if ("Frame" in part_name or "Brace" in part_name or part_name == "AevilokSpine") else 0.08
	plain.roughness = 0.46 if part_name.begins_with("AevilokWing") else 0.64
	if part_name.begins_with("AevilokEye_"):
		plain.emission_enabled = true
		plain.emission = EYE_WHITE
		plain.emission_energy_multiplier = 1.8
	mesh.set_meta("plain_material", plain)

	var source_toon: ShaderMaterial = null
	if mesh.has_meta("toon_material") and mesh.get_meta("toon_material") is ShaderMaterial:
		source_toon = mesh.get_meta("toon_material") as ShaderMaterial
	if source_toon != null:
		var toon := source_toon.duplicate(true) as ShaderMaterial
		toon.resource_local_to_scene = true
		toon.set_shader_parameter("use_texture", false)
		toon.set_shader_parameter("albedo_texture", null)
		toon.set_shader_parameter("base_color", color)
		mesh.set_meta("toon_material", toon)
		mesh.material_override = toon
	else:
		mesh.material_override = plain
