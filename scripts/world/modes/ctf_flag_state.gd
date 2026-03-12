extends RefCounted
class_name CtfFlagState

var team_id := 0
var home_position := Vector2.ZERO
var world_position := Vector2.ZERO
var carrier_peer_id := 0
var dropped_time_sec := 0.0

func configure(flag_team_id: int, spawn_position: Vector2) -> void:
	team_id = flag_team_id
	home_position = spawn_position
	reset_to_home()

func reset_to_home() -> void:
	world_position = home_position
	carrier_peer_id = 0
	dropped_time_sec = 0.0

func is_home() -> bool:
	return carrier_peer_id <= 0 and world_position.distance_squared_to(home_position) <= 1.0

func is_dropped() -> bool:
	return carrier_peer_id <= 0 and not is_home()
