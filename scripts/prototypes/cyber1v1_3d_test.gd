extends "res://scripts/prototypes/kw_3d_prototype.gd"
## Experimental 3D translation of the legacy cyber1v1 map.
##
## The major ledges use the real GroundTiles silhouette recovered from the
## archived cybernew scene. The original cyber foreground/background art is
## retained as a deep layered facade so the 3D test reads like the source map
## instead of becoming a generic cyber arena.

const CYBER_FRONT := preload("res://assets/maps/cyber1v1/1v1MapFront.png")
const CYBER_BG1 := preload("res://assets/maps/cyber1v1/1v1Mapbg1.png")
const CYBER_BG2 := preload("res://assets/maps/cyber1v1/1v1Mapbg2.png")

const NAVY := Color("263047")
const NAVY_DARK := Color("111723")
const STEEL := Color("393a49")
const MAGENTA_DARK := Color("2d0d32")
const MAGENTA := Color("7a205e")
const ORANGE := Color("df6c57")
const ORANGE_DARK := Color("763e19")
const CYAN := Color("55e9ff")
const HOT_PINK := Color("ff3fa8")


func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	world_env.name = "Cyber1v1Environment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d1424")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("53698f")
	env.ambient_light_energy = 1.72
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("263653")
	env.fog_light_energy = 0.48
	env.fog_density = 0.007
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.name = "CyberMoonKey"
	sun.rotation_degrees = Vector3(-58.0, -24.0, 0.0)
	sun.light_color = Color("b8c8ff")
	sun.light_energy = 1.62
	sun.shadow_enabled = true
	add_child(sun)

	# Broad, shadowless arena fills keep the playable space readable while the
	# cyan/pink/orange lights retain the cyber color separation.
	_add_cyber_fill_light("CyberCenterFill", Vector3(0.0, 5.8, -3.5), Color("d8e4ff"), 4.8, 15.0)
	_add_cyber_fill_light("CyberFrontFill", Vector3(0.0, 4.2, 3.5), Color("a8c7ff"), 3.6, 13.0)
	_add_cyber_fill_light("CyberRearFill", Vector3(0.0, 5.0, -10.5), Color("ffd1be"), 3.8, 13.5)
	_add_cyber_fill_light("CyberLeftFill", Vector3(-8.0, 4.0, -4.5), CYAN, 4.6, 11.5)
	_add_cyber_fill_light("CyberRightFill", Vector3(8.0, 4.0, -4.5), HOT_PINK, 4.6, 11.5)

	_add_neon_light(Vector3(-8.5, 4.2, -8.0), CYAN, 11.5)
	_add_neon_light(Vector3(8.5, 3.8, -7.0), HOT_PINK, 11.5)
	_add_neon_light(Vector3(0.0, 5.8, -12.5), ORANGE, 10.0)


func _add_cyber_fill_light(node_name: String, pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.25
	light.shadow_enabled = false
	add_child(light)


func _build_arena() -> void:
	# Compact duel floor, deliberately much closer to the proportions of the
	# original 1v1 screen than the standard 48x48 prototype arena.
	_add_static_box("CyberFloor", Vector3(0, -0.55, -4.5), Vector3(25.5, 1.1, 22.0), NAVY_DARK)
	_add_static_box("CyberLeftBoundary", Vector3(-12.7, 3.2, -4.5), Vector3(0.55, 7.5, 22.0), Color("171d2c"))
	_add_static_box("CyberRightBoundary", Vector3(12.7, 3.2, -4.5), Vector3(0.55, 7.5, 22.0), Color("171d2c"))
	_add_static_box("CyberBackBoundary", Vector3(0, 3.0, -15.25), Vector3(25.5, 6.8, 0.45), Color("101522"))
	_add_static_box("CyberFrontBoundary", Vector3(0, 2.0, 6.35), Vector3(25.5, 4.8, 0.35), Color("101522"))

	# Real cybernew GroundTiles silhouette translated from 8px cells:
	#   upper-left  (47..58, 38..39)
	#   mid-right   (86..91, 48)
	#   mid-left    (61..70, 50..52)
	#   lower-mid   (66..94, 62..64)
	#   right tower (100..107, 58..63)
	# plus the connected lower-left bank.
	_cyber_block("UpperLeftBridge", Vector3(-7.5, 5.15, -8.8), Vector3(3.55, 0.42, 4.3), NAVY, CYAN)
	_cyber_block("MidLeftOrange", Vector3(-4.0, 2.65, -5.8), Vector3(3.05, 1.05, 3.3), ORANGE_DARK, ORANGE)
	_cyber_block("MidRightPerch", Vector3(2.55, 3.28, -7.4), Vector3(1.85, 0.36, 3.2), STEEL, CYAN)
	_cyber_block("LowerCenterCore", Vector3(0.15, 0.65, -5.0), Vector3(8.35, 1.30, 3.8), MAGENTA_DARK, HOT_PINK)
	_cyber_block("RightTower", Vector3(7.05, 1.30, -4.7), Vector3(2.45, 2.60, 4.1), NAVY, CYAN)
	_cyber_block("LeftLowerBank", Vector3(-6.25, 0.48, -3.7), Vector3(5.85, 0.96, 3.6), ORANGE, Color("f5d8d2"))

	# Stepped/diagonal details visible in the original collision silhouette.
	_cyber_block("CoreStepLeft", Vector3(-2.85, 1.38, -6.7), Vector3(2.65, 0.46, 2.0), MAGENTA, HOT_PINK)
	_cyber_block("CoreStepRight", Vector3(3.05, 1.22, -6.2), Vector3(2.30, 0.42, 2.0), Color("43213f"), HOT_PINK)
	_cyber_block("RightTowerCap", Vector3(7.05, 2.82, -5.1), Vector3(2.10, 0.34, 3.0), Color("39465e"), CYAN)
	_add_ramp("CyberRampLeft", Vector3(-5.2, 0.34, 0.3), Vector3(4.8, 0.55, 3.2), Vector3(0, 0, -8), Color("2a3042"))
	_add_ramp("CyberRampRight", Vector3(5.2, 0.34, 0.3), Vector3(4.8, 0.55, 3.2), Vector3(0, 0, 8), Color("321d35"))

	# Front-to-back cover gives the formerly-flat 2D shapes useful 3D gameplay.
	_cyber_block("LeftDepthCover", Vector3(-8.9, 0.78, 1.6), Vector3(2.2, 1.55, 3.6), NAVY, CYAN)
	_cyber_block("RightDepthCover", Vector3(8.9, 0.92, 1.1), Vector3(2.2, 1.85, 3.7), MAGENTA_DARK, HOT_PINK)
	_cyber_block("CenterDepthCover", Vector3(0.0, 0.62, -0.2), Vector3(2.7, 1.25, 2.6), STEEL, ORANGE)

	# A few thin vertical tech columns echo the front art's pipes/towers.
	_cyber_block("PipeColumnLeft", Vector3(-10.7, 2.0, -9.0), Vector3(0.55, 4.0, 1.0), Color("49302d"), ORANGE)
	_cyber_block("PipeColumnRight", Vector3(10.4, 2.2, -8.2), Vector3(0.55, 4.4, 1.0), Color("252f46"), CYAN)

	# Original map art becomes layered architecture at the rear of the scene.
	_add_map_layer("CyberBG2", CYBER_BG2, Vector3(0, 4.8, -15.00), Vector2(13.5, 13.5), 0.76, Color("8194c9"))
	_add_map_layer("CyberBG1", CYBER_BG1, Vector3(0, 4.8, -14.78), Vector2(13.5, 13.5), 0.86, Color("c7889b"))
	_add_map_layer("CyberFrontReference", CYBER_FRONT, Vector3(0, 4.8, -14.55), Vector2(13.5, 13.5), 0.33, Color.WHITE)

	# Cyber runway lines and edge lights.
	for x in [-10.5, -7.0, -3.5, 0.0, 3.5, 7.0, 10.5]:
		_add_neon_strip(Vector3(x, 0.025, 4.7), CYAN if x <= 0.0 else HOT_PINK)
	for z in [-12.7, -9.8, -6.9, -4.0, -1.1, 1.8, 4.7]:
		_add_neon_strip(Vector3(-11.9, 0.025, z), CYAN)
		_add_neon_strip(Vector3(11.9, 0.025, z), HOT_PINK)

	_add_cyber_sign()


func _build_player() -> void:
	super._build_player()
	player.position = Vector3(0.0, 2.2, 4.0)
	yaw = PI
	body_yaw = PI
	if player_visual != null:
		player_visual.rotation.y = body_yaw
	if camera_yaw != null:
		camera_yaw.rotation.y = yaw


func _cyber_block(node_name: String, pos: Vector3, size: Vector3, color: Color, neon: Color) -> void:
	_add_static_box(node_name, pos, size, color)
	var trim := MeshInstance3D.new()
	trim.name = node_name + "NeonTrim"
	var box := BoxMesh.new()
	box.size = Vector3(maxf(0.18, size.x * 0.88), 0.055, size.z + 0.035)
	trim.mesh = box
	trim.position = pos + Vector3(0, size.y * 0.5 + 0.035, 0)
	trim.material_override = _material(neon, true, 3.4)
	trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trim)


func _add_map_layer(
		node_name: String,
		texture: Texture2D,
		pos: Vector3,
		size: Vector2,
		alpha: float,
		tint: Color
	) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var quad := QuadMesh.new()
	quad.size = size
	mesh.mesh = quad
	mesh.position = pos
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.albedo_texture = texture
	material.albedo_color = Color(tint.r, tint.g, tint.b, alpha)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 0.22
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)


func _add_cyber_sign() -> void:
	var sign := Label3D.new()
	sign.name = "Cyber1v1Sign"
	sign.text = "CYBER // 1V1"
	sign.position = Vector3(0.0, 6.4, -14.20)
	sign.font_size = 112
	sign.outline_size = 14
	sign.pixel_size = 0.006
	sign.modulate = CYAN
	sign.outline_modulate = Color("11131d")
	add_child(sign)
