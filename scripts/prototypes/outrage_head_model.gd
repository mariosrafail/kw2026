extends RefCounted
## Authored head only: a true cube, not an extruded side-view sprite.
## +Y is up; -Z is the face / movement-forward direction.
const SIDE := 0.88
const CELL := SIDE / 8.0
const EYE_RECESS := 0.018
const INK := Color("080507")
const RED := Color("8f1d27")
const SHADE := Color("6a161d")
const LIGHT := Color("99323b")
const FRONT_ROWS := [
	"KKKKKKKK", "KMMMMLLK", "KMMMMLLK", "KMMMMMLK",
	"KMMMMMMK", "KMEMMEMK", "KDDDDDDK", "KKKKKKKK"
]

static func create() -> Node3D:
	var model := Node3D.new()
	model.name = "AuthoredHead"
	model.position = Vector3(0.0, -0.10, 0.0)
	model.set_meta("cube_dimensions", Vector3.ONE * SIDE)
	model.set_meta("design", "Cubic Outrage: two horns, two front eyes")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := [
		[Vector3.FORWARD, Vector3.LEFT, Vector3.DOWN],
		[Vector3.BACK, Vector3.RIGHT, Vector3.DOWN],
		[Vector3.LEFT, Vector3.BACK, Vector3.DOWN],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.DOWN],
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD]
	]
	for face_id in range(faces.size()):
		var normal: Vector3 = faces[face_id][0]
		var right: Vector3 = faces[face_id][1]
		var down: Vector3 = faces[face_id][2]
		var origin := (normal - right - down) * SIDE * 0.5
		for row in range(8):
			for col in range(8):
				var p := origin + right * (col * CELL) + down * (row * CELL)
				if face_id == 0 and row == 5 and (col == 2 or col == 5):
					_eye_socket(surface, model, p, right, down, col)
				else:
					var color := _face_color(face_id, col, row)
					_quad(surface, p, p + right * CELL, p + (right + down) * CELL, p + down * CELL, normal, color)
	var cube := MeshInstance3D.new()
	cube.name = "HeadCube"
	surface.index()
	cube.mesh = surface.commit()
	var mat := _material(Color.WHITE)
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	cube.material_override = mat
	model.add_child(cube)
	_add_horn(model, "HornLeft", -1.0)
	_add_horn(model, "HornRight", 1.0)
	return model

static func _face_color(face_id: int, col: int, row: int) -> Color:
	if face_id == 0:
		match String(FRONT_ROWS[row]).substr(col, 1):
			"K": return INK
			"D": return SHADE
			"L": return LIGHT
			_: return RED
	# Every side is a full square, with continuous dark cube edges.
	if col == 0 or col == 7 or row == 0 or row == 7:
		return INK
	if face_id == 5:
		return SHADE
	if face_id == 4:
		return LIGHT if row < 3 and col < 5 else RED
	if row >= 5:
		return SHADE
	if col >= 5 and row < 4:
		return LIGHT
	return RED

static func _eye_socket(surface: SurfaceTool, model: Node3D, p: Vector3, right: Vector3, down: Vector3, col: int) -> void:
	var rim := [p, p + right * CELL, p + (right + down) * CELL, p + down * CELL]
	var inset := Vector3.BACK * EYE_RECESS
	for i in range(4):
		var a: Vector3 = rim[i]
		var b: Vector3 = rim[(i + 1) % 4]
		var normal := -(b - a).cross(inset).normalized()
		_quad(surface, a, b, b + inset, a + inset, normal, Color("310004"))
	var eye_pos := p + (right + down) * (CELL * 0.5) + inset + Vector3.BACK * 0.012
	var eye_name := "EyeLeft" if col == 2 else "EyeRight"
	_box(model, eye_name, eye_pos, Vector3(CELL, CELL, 0.024), Color("020203"))

static func _add_horn(model: Node3D, node_name: String, side_sign: float) -> void:
	var horn := Node3D.new()
	horn.name = node_name
	model.add_child(horn)
	var unit := CELL * 1.2
	var x := side_sign * CELL * 2.8
	var z := -CELL * 1.2
	# Three touching cubes form one stepped horn; no floating pixels.
	_box(horn, "Base", Vector3(x, SIDE * 0.5 + unit * 0.5, z), Vector3.ONE * unit, Color("cf0012"))
	_box(horn, "Stem", Vector3(x, SIDE * 0.5 + unit * 1.5, z), Vector3.ONE * unit, Color("ed0015"))
	_box(horn, "Tip", Vector3(x - side_sign * unit * 0.5, SIDE * 0.5 + unit * 2.5, z), Vector3.ONE * unit, Color("ff0016"))

static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	# Godot's front faces use clockwise winding; normals stay flat.
	surface.set_normal(normal)
	surface.set_color(color)
	for vertex: Vector3 in [a, b, c, a, c, d]:
		surface.add_vertex(vertex)

static func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.0
	mat.roughness = 0.9
	return mat

static func _box(parent: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = pos
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _material(color)
	parent.add_child(instance)
