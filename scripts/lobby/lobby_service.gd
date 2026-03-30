extends RefCounted
class_name LobbyService

const TEAM_RED := 0
const TEAM_BLUE := 1
const TEAM_SIZE_LIMIT := 2
const GAME_MODE_DEATHMATCH := "deathmatch"
const GAME_MODE_BATTLE_ROYALE := "battle_royale"
const GAME_MODE_CTF := "ctf"
const GAME_MODE_TDTH := "tdth"

var lobby_config: LobbyConfig
static var _global_server_lobbies: Dictionary = {}
static var _global_peer_lobby_by_peer: Dictionary = {}
static var _global_peer_weapon_by_peer: Dictionary = {}
static var _global_peer_weapon_skin_by_peer: Dictionary = {}
static var _global_peer_character_by_peer: Dictionary = {}
static var _global_peer_skin_by_peer: Dictionary = {}
static var _global_peer_display_name_by_peer: Dictionary = {}
static var _global_local_selected_weapon := "ak47"
static var _global_local_selected_weapon_skin_by_weapon: Dictionary = {}
static var _global_local_selected_character := "outrage"
static var _global_local_selected_skin_by_character: Dictionary = {}
static var _global_next_lobby_id := 1

func _init(config: LobbyConfig = null) -> void:
	lobby_config = config if config != null else LobbyConfig.new()

func reset(keep_local_selection: bool = false) -> void:
	var saved_weapon := _global_local_selected_weapon
	var saved_weapon_skins := _global_local_selected_weapon_skin_by_weapon.duplicate(true)
	var saved_character := _global_local_selected_character
	var saved_skins := _global_local_selected_skin_by_character.duplicate(true)

	_global_server_lobbies.clear()
	_global_peer_lobby_by_peer.clear()
	_global_peer_weapon_by_peer.clear()
	_global_peer_weapon_skin_by_peer.clear()
	_global_peer_character_by_peer.clear()
	_global_peer_skin_by_peer.clear()
	_global_peer_display_name_by_peer.clear()
	_global_next_lobby_id = 1

	if keep_local_selection:
		_global_local_selected_weapon = str(saved_weapon).strip_edges().to_lower()
		_global_local_selected_weapon_skin_by_weapon = saved_weapon_skins
		var normalized_saved := str(saved_character).strip_edges().to_lower()
		if normalized_saved == "erebus":
			_global_local_selected_character = "erebus"
		elif normalized_saved == "tasko":
			_global_local_selected_character = "tasko"
		else:
			_global_local_selected_character = "outrage"
		_global_local_selected_skin_by_character = saved_skins
	else:
		_global_local_selected_weapon = "ak47"
		_global_local_selected_weapon_skin_by_weapon.clear()
		_global_local_selected_character = "outrage"
		_global_local_selected_skin_by_character.clear()

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
			"map_id": map_id,
			"mode_id": str(lobby.get("mode_id", GAME_MODE_DEATHMATCH)).strip_edges().to_lower()
		})
	return payload

func create_lobby(
	peer_id: int,
	requested_name: String,
	requested_map_id: String = "classic",
	requested_max_players: int = 0,
	requested_mode_id: String = GAME_MODE_DEATHMATCH
) -> Dictionary:
	var lobby_id := _global_next_lobby_id
	_global_next_lobby_id += 1
	var lobby_name := requested_name.strip_edges()
	if lobby_name.is_empty():
		lobby_name = "Lobby %d" % lobby_id
	var map_id := requested_map_id.strip_edges().to_lower()
	if map_id.is_empty():
		map_id = "classic"
	var mode_id := requested_mode_id.strip_edges().to_lower()
	if mode_id != GAME_MODE_CTF and mode_id != GAME_MODE_TDTH and mode_id != GAME_MODE_BATTLE_ROYALE:
		mode_id = GAME_MODE_DEATHMATCH
	var max_players := requested_max_players
	if max_players <= 0:
		max_players = lobby_config.max_players_for_new_lobby(lobby_name)
	max_players = maxi(1, max_players)

	_global_server_lobbies[lobby_id] = {
		"name": lobby_name,
		"members": [peer_id],
		"max_players": max_players,
		"map_id": map_id,
		"mode_id": mode_id,
		"owner_peer_id": peer_id,
		"started": false,
		"ready_by_peer": {peer_id: false},
		"add_bots": false,
		"show_starting_animation": false,
		"team_by_peer": {peer_id: TEAM_RED} if _is_team_mode(mode_id) else {},
		"chat_history": []
	}
	_global_peer_lobby_by_peer[peer_id] = lobby_id
	return {
		"lobby_id": lobby_id,
		"lobby_name": lobby_name,
		"map_id": map_id,
		"mode_id": mode_id
	}

func assign_peer_to_lobby(peer_id: int, lobby_id: int) -> void:
	_global_peer_lobby_by_peer[peer_id] = lobby_id

func remove_peer_from_lobby(peer_id: int) -> void:
	_global_peer_lobby_by_peer.erase(peer_id)

func owner_peer_for_lobby(lobby_id: int) -> int:
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return 0
	return int(lobby.get("owner_peer_id", 0))

func is_ctf_lobby(lobby_id: int) -> bool:
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return false
	return str(lobby.get("mode_id", GAME_MODE_DEATHMATCH)).strip_edges().to_lower() == GAME_MODE_CTF

func is_battle_royale_lobby(lobby_id: int) -> bool:
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return false
	return str(lobby.get("mode_id", GAME_MODE_DEATHMATCH)).strip_edges().to_lower() == GAME_MODE_BATTLE_ROYALE

func is_deathmatch_lobby(lobby_id: int) -> bool:
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return false
	return str(lobby.get("mode_id", GAME_MODE_DEATHMATCH)).strip_edges().to_lower() == GAME_MODE_DEATHMATCH

func is_tdth_lobby(lobby_id: int) -> bool:
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return false
	return str(lobby.get("mode_id", GAME_MODE_DEATHMATCH)).strip_edges().to_lower() == GAME_MODE_TDTH

func is_team_lobby(lobby_id: int) -> bool:
	return is_ctf_lobby(lobby_id) or is_tdth_lobby(lobby_id)

func lobby_started(lobby_id: int) -> bool:
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return false
	return bool(lobby.get("started", false))

func set_lobby_started(lobby_id: int, started: bool) -> void:
	if not _global_server_lobbies.has(lobby_id):
		return
	var lobby := _global_server_lobbies.get(lobby_id, {}) as Dictionary
	lobby["started"] = started
	_global_server_lobbies[lobby_id] = lobby

func ready_for_peer(lobby_id: int, peer_id: int) -> bool:
	if peer_id <= 0:
		return false
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return false
	var ready_by_peer := lobby.get("ready_by_peer", {}) as Dictionary
	return bool(ready_by_peer.get(peer_id, false))

func set_peer_ready(lobby_id: int, peer_id: int, ready: bool) -> bool:
	if peer_id <= 0:
		return false
	if not _global_server_lobbies.has(lobby_id):
		return false
	var lobby := _global_server_lobbies.get(lobby_id, {}) as Dictionary
	var members := get_lobby_members(lobby_id)
	if not members.has(peer_id):
		return false
	var ready_by_peer := (lobby.get("ready_by_peer", {}) as Dictionary).duplicate(true)
	ready_by_peer[peer_id] = bool(ready)
	lobby["ready_by_peer"] = ready_by_peer
	_global_server_lobbies[lobby_id] = lobby
	return true

func all_humans_ready(lobby_id: int) -> bool:
	var members := get_lobby_members(lobby_id)
	if members.is_empty():
		return false
	for member_value in members:
		var peer_id := int(member_value)
		if peer_id <= 0:
			continue
		if not ready_for_peer(lobby_id, peer_id):
			return false
	return true

func all_non_owner_humans_ready(lobby_id: int) -> bool:
	var members := get_lobby_members(lobby_id)
	if members.is_empty():
		return false
	var owner_peer_id := owner_peer_for_lobby(lobby_id)
	for member_value in members:
		var peer_id := int(member_value)
		if peer_id <= 0:
			continue
		if peer_id == owner_peer_id:
			continue
		if not ready_for_peer(lobby_id, peer_id):
			return false
	return true

func set_add_bots_enabled(lobby_id: int, owner_peer_id: int, enabled: bool) -> bool:
	if not _global_server_lobbies.has(lobby_id):
		return false
	var lobby := _global_server_lobbies.get(lobby_id, {}) as Dictionary
	if int(lobby.get("owner_peer_id", 0)) != owner_peer_id:
		return false
	lobby["add_bots"] = bool(enabled)
	_global_server_lobbies[lobby_id] = lobby
	return true

func add_bots_enabled(lobby_id: int) -> bool:
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return false
	return bool(lobby.get("add_bots", false))

func set_show_starting_animation_enabled(lobby_id: int, owner_peer_id: int, enabled: bool) -> bool:
	if not _global_server_lobbies.has(lobby_id):
		return false
	var lobby := _global_server_lobbies.get(lobby_id, {}) as Dictionary
	if int(lobby.get("owner_peer_id", 0)) != owner_peer_id:
		return false
	lobby["show_starting_animation"] = bool(enabled)
	_global_server_lobbies[lobby_id] = lobby
	return true

func show_starting_animation_enabled(lobby_id: int) -> bool:
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return false
	return bool(lobby.get("show_starting_animation", false))

func can_start_deathmatch_lobby(lobby_id: int) -> bool:
	if not is_deathmatch_lobby(lobby_id):
		return false
	if lobby_started(lobby_id):
		return false
	if not all_non_owner_humans_ready(lobby_id):
		return false
	return get_lobby_members(lobby_id).size() > 0

func can_start_battle_royale_lobby(lobby_id: int) -> bool:
	if not is_battle_royale_lobby(lobby_id):
		return false
	if lobby_started(lobby_id):
		return false
	if not all_non_owner_humans_ready(lobby_id):
		return false
	return get_lobby_members(lobby_id).size() > 0

func can_start_ctf_lobby(lobby_id: int) -> bool:
	if not is_ctf_lobby(lobby_id):
		return false
	if lobby_started(lobby_id):
		return false
	if not all_non_owner_humans_ready(lobby_id):
		return false
	return get_lobby_members(lobby_id).size() > 0

func can_start_tdth_lobby(lobby_id: int) -> bool:
	if not is_tdth_lobby(lobby_id):
		return false
	if lobby_started(lobby_id):
		return false
	if not all_non_owner_humans_ready(lobby_id):
		return false
	return get_lobby_members(lobby_id).size() > 0

func team_assignments_for_lobby(lobby_id: int) -> Dictionary:
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return {}
	var raw := lobby.get("team_by_peer", {}) as Dictionary
	return raw.duplicate(true)

func team_for_peer(lobby_id: int, peer_id: int) -> int:
	var teams := team_assignments_for_lobby(lobby_id)
	if not teams.has(peer_id):
		return -1
	return _normalized_team_id(int(teams.get(peer_id, -1)))

func auto_assign_team_for_peer(lobby_id: int, peer_id: int) -> int:
	if not is_team_lobby(lobby_id):
		return -1
	var existing := team_for_peer(lobby_id, peer_id)
	if existing >= 0:
		return existing
	var preferred := _preferred_team_for_lobby(lobby_id)
	if set_peer_team(lobby_id, peer_id, preferred):
		return preferred
	var fallback := TEAM_BLUE if preferred == TEAM_RED else TEAM_RED
	if set_peer_team(lobby_id, peer_id, fallback):
		return fallback
	return -1

func set_peer_team(lobby_id: int, peer_id: int, team_id: int) -> bool:
	if not _global_server_lobbies.has(lobby_id):
		return false
	if not is_team_lobby(lobby_id):
		return false
	var normalized_team := _normalized_team_id(team_id)
	if normalized_team < 0:
		return false
	var lobby := _global_server_lobbies.get(lobby_id, {}) as Dictionary
	var members := get_lobby_members(lobby_id)
	var teams := (lobby.get("team_by_peer", {}) as Dictionary).duplicate(true)
	var is_bot := peer_id < 0
	if not is_bot and not members.has(peer_id):
		return false
	var team_count := 0
	for assigned_peer_value in teams.keys():
		var assigned_peer_id := int(assigned_peer_value)
		if assigned_peer_id == peer_id:
			continue
		if _normalized_team_id(int(teams.get(assigned_peer_id, -1))) == normalized_team:
			team_count += 1
	if team_count >= TEAM_SIZE_LIMIT:
		return false
	teams[peer_id] = normalized_team
	lobby["team_by_peer"] = teams
	_global_server_lobbies[lobby_id] = lobby
	return true

func clear_non_member_teams(lobby_id: int) -> void:
	if not _global_server_lobbies.has(lobby_id):
		return
	var lobby := _global_server_lobbies.get(lobby_id, {}) as Dictionary
	var members := get_lobby_members(lobby_id)
	var teams := (lobby.get("team_by_peer", {}) as Dictionary).duplicate(true)
	for peer_value in teams.keys():
		var peer_id := int(peer_value)
		if peer_id < 0:
			continue
		if members.has(peer_id):
			continue
		teams.erase(peer_id)
	lobby["team_by_peer"] = teams
	_global_server_lobbies[lobby_id] = lobby

func set_bot_team_assignments(lobby_id: int, bot_team_by_peer: Dictionary) -> void:
	if not _global_server_lobbies.has(lobby_id):
		return
	var lobby := _global_server_lobbies.get(lobby_id, {}) as Dictionary
	var teams := (lobby.get("team_by_peer", {}) as Dictionary).duplicate(true)
	for peer_value in teams.keys():
		var peer_id := int(peer_value)
		if peer_id < 0:
			teams.erase(peer_id)
	for peer_value in bot_team_by_peer.keys():
		var peer_id := int(peer_value)
		if peer_id >= 0:
			continue
		var team_id := _normalized_team_id(int(bot_team_by_peer.get(peer_id, -1)))
		if team_id < 0:
			continue
		teams[peer_id] = team_id
	lobby["team_by_peer"] = teams
	_global_server_lobbies[lobby_id] = lobby

func clear_bot_team_assignments(lobby_id: int) -> void:
	set_bot_team_assignments(lobby_id, {})

func pack_lobby_room_state(lobby_id: int) -> Dictionary:
	var lobby := get_lobby_data(lobby_id)
	if lobby.is_empty():
		return {
			"lobby_id": 0,
			"mode_id": GAME_MODE_DEATHMATCH,
			"ready_by_peer": {},
			"members": [],
			"all_ready": false,
			"can_start": false,
			"add_bots": false,
			"show_starting_animation": false,
			"human_count": 0,
			"max_players": 0,
			"teams": {"red": [], "blue": []}
		}
	var members := get_lobby_members(lobby_id)
	var teams := team_assignments_for_lobby(lobby_id)
	var ready_by_peer := (lobby.get("ready_by_peer", {}) as Dictionary).duplicate(true)
	var red_members: Array = []
	var blue_members: Array = []
	var member_entries: Array = []
	for member_value in members:
		var peer_id := int(member_value)
		var entry := {
			"peer_id": peer_id,
			"display_name": get_peer_display_name(peer_id, "P%d" % peer_id),
			"team_id": team_for_peer(lobby_id, peer_id),
			"ready": bool(ready_by_peer.get(peer_id, false))
		}
		member_entries.append(entry)
		if int(entry.get("team_id", -1)) == TEAM_BLUE:
			blue_members.append(entry)
		else:
			red_members.append(entry)
	var mode_id := str(lobby.get("mode_id", GAME_MODE_DEATHMATCH)).strip_edges().to_lower()
	var can_start := false
	if mode_id == GAME_MODE_DEATHMATCH:
		can_start = can_start_deathmatch_lobby(lobby_id)
	elif mode_id == GAME_MODE_BATTLE_ROYALE:
		can_start = can_start_battle_royale_lobby(lobby_id)
	elif mode_id == GAME_MODE_CTF:
		can_start = can_start_ctf_lobby(lobby_id)
	elif mode_id == GAME_MODE_TDTH:
		can_start = can_start_tdth_lobby(lobby_id)
	return {
		"lobby_id": lobby_id,
		"name": str(lobby.get("name", "Lobby %d" % lobby_id)),
		"map_id": str(lobby.get("map_id", "classic")).strip_edges().to_lower(),
		"mode_id": mode_id,
		"owner_peer_id": int(lobby.get("owner_peer_id", 0)),
		"started": bool(lobby.get("started", false)),
		"ready_by_peer": ready_by_peer,
		"members": member_entries,
		"all_ready": all_non_owner_humans_ready(lobby_id),
		"can_start": can_start,
		"add_bots": bool(lobby.get("add_bots", false)),
		"show_starting_animation": bool(lobby.get("show_starting_animation", false)),
		"human_count": members.size(),
		"max_players": max_players_for_lobby(lobby_id),
		"team_by_peer": teams,
		"teams": {
			"red": red_members,
			"blue": blue_members
		}
	}

func set_peer_weapon(peer_id: int, weapon_id: String) -> void:
	if peer_id <= 0:
		return
	var normalized := str(weapon_id).strip_edges().to_lower()
	if normalized.is_empty():
		_global_peer_weapon_by_peer.erase(peer_id)
		return
	_global_peer_weapon_by_peer[peer_id] = normalized

func set_peer_weapon_skin(peer_id: int, skin_index: int) -> void:
	if peer_id <= 0:
		return
	_global_peer_weapon_skin_by_peer[peer_id] = maxi(0, skin_index)

func get_peer_weapon_skin(peer_id: int, fallback: int = 0) -> int:
	if peer_id <= 0:
		return maxi(0, fallback)
	return int(_global_peer_weapon_skin_by_peer.get(peer_id, fallback))

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

func set_local_selected_weapon_skin(weapon_id: String, skin_index: int) -> void:
	var normalized_weapon := str(weapon_id).strip_edges().to_lower()
	if normalized_weapon.is_empty():
		return
	_global_local_selected_weapon_skin_by_weapon[normalized_weapon] = maxi(0, skin_index)

func get_local_selected_weapon_skin(weapon_id: String, fallback: int = 0) -> int:
	var normalized_weapon := str(weapon_id).strip_edges().to_lower()
	if normalized_weapon.is_empty():
		return maxi(0, fallback)
	return int(_global_local_selected_weapon_skin_by_weapon.get(normalized_weapon, fallback))

func set_peer_character(peer_id: int, character_id: String) -> void:
	if peer_id <= 0:
		return
	var normalized := str(character_id).strip_edges().to_lower()
	if normalized != "erebus" and normalized != "tasko":
		normalized = "outrage"
	_global_peer_character_by_peer[peer_id] = normalized

func set_peer_skin(peer_id: int, skin_index: int) -> void:
	if peer_id <= 0:
		return
	_global_peer_skin_by_peer[peer_id] = maxi(0, skin_index)

func get_peer_skin(peer_id: int, fallback: int = 0) -> int:
	if peer_id <= 0:
		return maxi(0, fallback)
	return int(_global_peer_skin_by_peer.get(peer_id, fallback))

func set_peer_display_name(peer_id: int, display_name: String) -> void:
	if peer_id <= 0:
		return
	var trimmed := str(display_name).strip_edges()
	if trimmed.is_empty():
		_global_peer_display_name_by_peer.erase(peer_id)
		return
	_global_peer_display_name_by_peer[peer_id] = trimmed

func get_peer_display_name(peer_id: int, fallback: String = "") -> String:
	if peer_id <= 0:
		return fallback
	var trimmed := str(_global_peer_display_name_by_peer.get(peer_id, "")).strip_edges()
	if trimmed.is_empty():
		return fallback
	return trimmed

func append_lobby_chat_message(lobby_id: int, peer_id: int, display_name: String, message: String, max_messages: int = 60) -> void:
	if lobby_id <= 0:
		return
	if not _global_server_lobbies.has(lobby_id):
		return
	var safe_name := str(display_name).strip_edges()
	if safe_name.is_empty():
		safe_name = "Player"
	var safe_message := str(message).strip_edges()
	if safe_message.is_empty():
		return
	var lobby := _global_server_lobbies.get(lobby_id, {}) as Dictionary
	var history := (lobby.get("chat_history", []) as Array).duplicate(true)
	history.append({
		"peer_id": peer_id,
		"display_name": safe_name,
		"message": safe_message
	})
	var safe_limit := maxi(1, max_messages)
	if history.size() > safe_limit:
		history = history.slice(history.size() - safe_limit, history.size())
	lobby["chat_history"] = history
	_global_server_lobbies[lobby_id] = lobby

func get_lobby_chat_history(lobby_id: int) -> Array:
	if lobby_id <= 0:
		return []
	if not _global_server_lobbies.has(lobby_id):
		return []
	var lobby := _global_server_lobbies.get(lobby_id, {}) as Dictionary
	return (lobby.get("chat_history", []) as Array).duplicate(true)

func get_peer_character(peer_id: int, fallback: String = "outrage") -> String:
	var character_id := str(_global_peer_character_by_peer.get(peer_id, "")).strip_edges().to_lower()
	if character_id.is_empty():
		var normalized_fallback := fallback.strip_edges().to_lower()
		if normalized_fallback == "erebus":
			return "erebus"
		if normalized_fallback == "tasko":
			return "tasko"
		return "outrage"
	if character_id == "erebus":
		return "erebus"
	if character_id == "tasko":
		return "tasko"
	return "outrage"

func set_local_selected_character(character_id: String) -> void:
	var normalized := str(character_id).strip_edges().to_lower()
	if normalized != "erebus" and normalized != "tasko":
		normalized = "outrage"
	_global_local_selected_character = normalized

func set_local_selected_skin(character_id: String, skin_index: int) -> void:
	var normalized_character := str(character_id).strip_edges().to_lower()
	if normalized_character.is_empty():
		return
	_global_local_selected_skin_by_character[normalized_character] = maxi(0, skin_index)

func get_local_selected_skin(character_id: String, fallback: int = 0) -> int:
	var normalized_character := str(character_id).strip_edges().to_lower()
	if normalized_character.is_empty():
		return maxi(0, fallback)
	return int(_global_local_selected_skin_by_character.get(normalized_character, fallback))

func get_local_selected_character(fallback: String = "outrage") -> String:
	var normalized := _global_local_selected_character.strip_edges().to_lower()
	if normalized.is_empty():
		var normalized_fallback := fallback.strip_edges().to_lower()
		if normalized_fallback == "erebus":
			return "erebus"
		if normalized_fallback == "tasko":
			return "tasko"
		return "outrage"
	if normalized == "erebus":
		return "erebus"
	if normalized == "tasko":
		return "tasko"
	return "outrage"

func set_lobby_members(lobby_id: int, members: Array) -> void:
	if not _global_server_lobbies.has(lobby_id):
		return
	var lobby := _global_server_lobbies.get(lobby_id, {}) as Dictionary
	lobby["members"] = members
	if int(lobby.get("owner_peer_id", 0)) <= 0 or not members.has(int(lobby.get("owner_peer_id", 0))):
		lobby["owner_peer_id"] = int(members[0]) if not members.is_empty() else 0
	var teams := (lobby.get("team_by_peer", {}) as Dictionary).duplicate(true)
	for peer_value in teams.keys():
		var peer_id := int(peer_value)
		if peer_id < 0:
			continue
		if members.has(peer_id):
			continue
		teams.erase(peer_id)
	lobby["team_by_peer"] = teams
	var ready_by_peer := (lobby.get("ready_by_peer", {}) as Dictionary).duplicate(true)
	for peer_value in ready_by_peer.keys():
		var peer_id := int(peer_value)
		if members.has(peer_id):
			continue
		ready_by_peer.erase(peer_id)
	for member_value in members:
		var member_id := int(member_value)
		ready_by_peer[member_id] = false
	lobby["ready_by_peer"] = ready_by_peer
	_global_server_lobbies[lobby_id] = lobby

func remove_lobby(lobby_id: int) -> void:
	_global_server_lobbies.erase(lobby_id)

func _normalized_team_id(team_id: int) -> int:
	if team_id == TEAM_RED:
		return TEAM_RED
	if team_id == TEAM_BLUE:
		return TEAM_BLUE
	return -1

func _preferred_team_for_lobby(lobby_id: int) -> int:
	var teams := team_assignments_for_lobby(lobby_id)
	var red_count := 0
	var blue_count := 0
	for peer_value in teams.keys():
		var peer_id := int(peer_value)
		if peer_id < 0:
			continue
		var team_id := _normalized_team_id(int(teams.get(peer_id, -1)))
		if team_id == TEAM_BLUE:
			blue_count += 1
		else:
			red_count += 1
	if red_count <= blue_count and red_count < TEAM_SIZE_LIMIT:
		return TEAM_RED
	return TEAM_BLUE

func _is_team_mode(mode_id: String) -> bool:
	var normalized := mode_id.strip_edges().to_lower()
	return normalized == GAME_MODE_CTF or normalized == GAME_MODE_TDTH
