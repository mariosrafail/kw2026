extends RefCounted
class_name CtfVisuals

var world_root: Node2D
var flag_texture: Texture2D

var _visual_root: Node2D
var _base_nodes_by_team: Dictionary = {}
var _neutral_flag_node: Sprite2D
var _neutral_flag_glow_node: Sprite2D

func configure(root: Node2D, texture: Texture2D) -> void:
	world_root = root
	flag_texture = texture

func reset() -> void:
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()
	_visual_root = null
	_base_nodes_by_team.clear()
	_neutral_flag_node = null
	_neutral_flag_glow_node = null

func rebuild(teams_by_id: Dictionary, objective_position: Vector2) -> void:
	_ensure_visual_root()
	if _visual_root == null:
		return
	for child in _visual_root.get_children():
		child.queue_free()
	_base_nodes_by_team.clear()
	_neutral_flag_node = null
	_neutral_flag_glow_node = null

	for team_id in teams_by_id.keys():
		var team := teams_by_id.get(team_id, null) as CtfTeam
		if team == null:
			continue
		var base_node := Polygon2D.new()
		base_node.polygon = PackedVector2Array([
			Vector2(-38.0, -16.0),
			Vector2(38.0, -16.0),
			Vector2(38.0, 16.0),
			Vector2(-38.0, 16.0)
		])
		base_node.color = Color(team.color.r, team.color.g, team.color.b, 0.28)
		base_node.z_index = 8
		base_node.global_position = team.base_position
		_visual_root.add_child(base_node)
		_base_nodes_by_team[int(team_id)] = base_node

	var objective_glow := Sprite2D.new()
	objective_glow.texture = flag_texture
	objective_glow.centered = true
	objective_glow.modulate = Color(0.14, 0.95, 0.28, 0.18)
	objective_glow.scale = Vector2(1.2, 1.2)
	objective_glow.z_as_relative = false
	objective_glow.z_index = 98
	objective_glow.global_position = objective_position
	_visual_root.add_child(objective_glow)
	_neutral_flag_glow_node = objective_glow

	var objective_node := Sprite2D.new()
	objective_node.texture = flag_texture
	objective_node.centered = true
	objective_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
	objective_node.scale = Vector2(1.0, 1.0)
	objective_node.z_as_relative = false
	objective_node.z_index = 99
	objective_node.global_position = objective_position
	_visual_root.add_child(objective_node)
	_neutral_flag_node = objective_node

func update(teams_by_id: Dictionary, objective_position: Vector2) -> void:
	if _visual_root == null:
		return
	for team_id in teams_by_id.keys():
		var team := teams_by_id.get(team_id, null) as CtfTeam
		var base_node := _base_nodes_by_team.get(int(team_id), null) as Polygon2D
		if team != null and base_node != null:
			base_node.global_position = team.base_position
	if _neutral_flag_node != null and is_instance_valid(_neutral_flag_node):
		_neutral_flag_node.global_position = objective_position
		if _neutral_flag_glow_node != null and is_instance_valid(_neutral_flag_glow_node):
			_neutral_flag_glow_node.global_position = objective_position

func set_visible(visible: bool) -> void:
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.visible = visible

func _ensure_visual_root() -> void:
	if world_root == null:
		return
	if _visual_root != null and is_instance_valid(_visual_root):
		return
	_visual_root = Node2D.new()
	_visual_root.name = "CtfMode"
	world_root.add_child(_visual_root)
