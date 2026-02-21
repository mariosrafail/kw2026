extends RefCounted
class_name LobbyService

var lobby_config: LobbyConfig
static var _global_server_lobbies: Dictionary = {}
static var _global_peer_lobby_by_peer: Dictionary = {}
static var _global_peer_weapon_by_peer: Dictionary = {}
static var _global_peer_character_by_peer: Dictionary = {}
static var _global_local_selected_weapon := "ak47"
static var _global_local_selected_character := "outrage"
static var _global_next_lobby_id := 1

func _init(config: LobbyConfig = null) -> void:
	lobby_config = config if config != null else LobbyConfig.new()

func reset() -> void:
	_global_server_lobbies.clear()
	_global_peer_lobby_by_peer.clear()
	_global_peer_weapon_by_peer.clear()
	_global_peer_character_by_peer.clear()
	_global_local_selected_weapon = "ak47"
	_global_local_selected_character = "outrage"
	_global_next_lobby_id = 1

func get_peer_lobby(peer_id: int) -> int:
	return int(_global_peer_lobby_by_peer.get(peer_id, 0))

func has_active_lobbies() -> bool:
	return not _global_server_lobbies.is_empty()

func has_lobby(lobby_id: int) -> bool:
	return _global_server_lobbies.has(lobby_id)

func get_lobby_data(lobby_id: int) -> Dictionary:
	return _global_server_lobbies.get(lobby_id, {}) as Dictionary

func get_lobby_members(lobby_id: int) -> Array:
	if lobby_id <= 0:
		return []
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return []
	var members_untyped := lobby.get("members", []) as Array
	var members: Array = []
	for member in members_untyped:
		members.append(int(member))
	return members

func get_lobby_name(lobby_id: int) -> String:
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return ""
	return str(lobby.get("name", "Lobby %d" % lobby_id))

func max_players_for_lobby(lobby_id: int) -> int:
	var lobby := get_lobby_data(lobby_id)
	return lobby_config.max_players_for_lobby(lobby_id, lobby)

func pack_lobby_list() -> Array:
	var payload: Array = []
	var lobby_ids := _global_server_lobbies.keys()
	lobby_ids.sort()
	for lobby_id_value in lobby_ids:
		var lobby_id := int(lobby_id_value)
		var members := get_lobby_members(lobby_id)
		var lobby := get_lobby_data(lobby_id)
		var map_id := str(lobby.get("map_id", "classic")).strip_edges().to_lower()
		if map_id.is_empty():
			map_id = "classic"
		payload.append({
			"id": lobby_id,
			"name": get_lobby_name(lobby_id),
			"players": members.size(),
			"max_players": max_players_for_lobby(lobby_id),
			"map_id": map_id
		})
	return payload

func create_lobby(
	peer_id: int,
	requested_name: String,
	requested_map_id: String = "classic",
	requested_max_players: int = 0
) -> Dictionary:
	var lobby_id := _global_next_lobby_id
	_global_next_lobby_id += 1
	var lobby_name := requested_name.strip_edges()
	if lobby_name.is_empty():
		lobby_name = "Lobby %d" % lobby_id
	var map_id := requested_map_id.strip_edges().to_lower()
	if map_id.is_empty():
		map_id = "classic"
	var max_players := requested_max_players
	if max_players <= 0:
		max_players = lobby_config.max_players_for_new_lobby(lobby_name)
	max_players = maxi(1, max_players)

	_global_server_lobbies[lobby_id] = {
		"name": lobby_name,
		"members": [peer_id],
		"max_players": max_players,
		"map_id": map_id
	}
	_global_peer_lobby_by_peer[peer_id] = lobby_id
	return {
		"lobby_id": lobby_id,
		"lobby_name": lobby_name,
		"map_id": map_id
	}

func assign_peer_to_lobby(peer_id: int, lobby_id: int) -> void:
	_global_peer_lobby_by_peer[peer_id] = lobby_id

func remove_peer_from_lobby(peer_id: int) -> void:
	_global_peer_lobby_by_peer.erase(peer_id)

func set_peer_weapon(peer_id: int, weapon_id: String) -> void:
	if peer_id <= 0:
		return
	var normalized := str(weapon_id).strip_edges().to_lower()
	if normalized.is_empty():
		_global_peer_weapon_by_peer.erase(peer_id)
		return
	_global_peer_weapon_by_peer[peer_id] = normalized

func get_peer_weapon(peer_id: int, fallback: String = "") -> String:
	var weapon_id := str(_global_peer_weapon_by_peer.get(peer_id, "")).strip_edges().to_lower()
	if weapon_id.is_empty():
		return fallback.strip_edges().to_lower()
	return weapon_id

func set_local_selected_weapon(weapon_id: String) -> void:
	var normalized := str(weapon_id).strip_edges().to_lower()
	if normalized.is_empty():
		return
	_global_local_selected_weapon = normalized

func get_local_selected_weapon(fallback: String = "ak47") -> String:
	var normalized := _global_local_selected_weapon.strip_edges().to_lower()
	if normalized.is_empty():
		return fallback.strip_edges().to_lower()
	return normalized

func set_peer_character(peer_id: int, character_id: String) -> void:
	if peer_id <= 0:
		return
	var normalized := str(character_id).strip_edges().to_lower()
	if normalized != "erebus":
		normalized = "outrage"
	_global_peer_character_by_peer[peer_id] = normalized

func get_peer_character(peer_id: int, fallback: String = "outrage") -> String:
	var character_id := str(_global_peer_character_by_peer.get(peer_id, "")).strip_edges().to_lower()
	if character_id.is_empty():
		var normalized_fallback := fallback.strip_edges().to_lower()
		return "erebus" if normalized_fallback == "erebus" else "outrage"
	return "erebus" if character_id == "erebus" else "outrage"

func set_local_selected_character(character_id: String) -> void:
	var normalized := str(character_id).strip_edges().to_lower()
	if normalized != "erebus":
		normalized = "outrage"
	_global_local_selected_character = normalized

func get_local_selected_character(fallback: String = "outrage") -> String:
	var normalized := _global_local_selected_character.strip_edges().to_lower()
	if normalized.is_empty():
		var normalized_fallback := fallback.strip_edges().to_lower()
		return "erebus" if normalized_fallback == "erebus" else "outrage"
	return "erebus" if normalized == "erebus" else "outrage"

func set_lobby_members(lobby_id: int, members: Array) -> void:
	if not _global_server_lobbies.has(lobby_id):
		return
	var lobby := _global_server_lobbies.get(lobby_id, {}) as Dictionary
	lobby["members"] = members
	_global_server_lobbies[lobby_id] = lobby

func remove_lobby(lobby_id: int) -> void:
	_global_server_lobbies.erase(lobby_id)
