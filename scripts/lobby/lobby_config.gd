extends RefCounted
class_name LobbyConfig

const DEFAULT_MAX_PLAYERS := 2
const ROOM_MAX_PLAYERS_BY_NAME := {}

func default_max_players() -> int:
	return DEFAULT_MAX_PLAYERS

func max_players_for_new_lobby(lobby_name: String = "") -> int:
	var trimmed_name := lobby_name.strip_edges()
	if ROOM_MAX_PLAYERS_BY_NAME.has(trimmed_name):
		return maxi(1, int(ROOM_MAX_PLAYERS_BY_NAME[trimmed_name]))
	return DEFAULT_MAX_PLAYERS

func max_players_for_lobby(_lobby_id: int, lobby_data: Dictionary = {}) -> int:
	if lobby_data.has("max_players"):
		return maxi(1, int(lobby_data.get("max_players", DEFAULT_MAX_PLAYERS)))
	var lobby_name := str(lobby_data.get("name", "")).strip_edges()
	if ROOM_MAX_PLAYERS_BY_NAME.has(lobby_name):
		return maxi(1, int(ROOM_MAX_PLAYERS_BY_NAME[lobby_name]))
	var value := int(lobby_data.get("max_players", DEFAULT_MAX_PLAYERS))
	return maxi(1, value)
