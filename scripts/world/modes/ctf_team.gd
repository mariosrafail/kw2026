extends RefCounted
class_name CtfTeam

var team_id := 0
var team_name := ""
var color := Color.WHITE
var base_position := Vector2.ZERO
var spawn_points: Array[Vector2] = []
var score := 0

func configure(id: int, name: String, team_color: Color, base_world_position: Vector2, team_spawn_points: Array[Vector2]) -> void:
	team_id = id
	team_name = name
	color = team_color
	base_position = base_world_position
	spawn_points.clear()
	for point_value in team_spawn_points:
		if point_value is Vector2:
			spawn_points.append(point_value)

func reset_score() -> void:
	score = 0
