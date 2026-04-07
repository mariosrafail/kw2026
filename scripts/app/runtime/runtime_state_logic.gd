extends "res://scripts/app/runtime/runtime_spawn_logic.gd"

const SERVER_SKIN_BLOOD_COLORS_RESOURCE_PATH := "res://config/server_skin_blood_colors.tres"
const DEFAULT_BLOOD_COLOR := Color(0.98, 0.02, 0.07, 1.0)
const DEFAULT_SKILL_COLOR := Color(0.98, 0.02, 0.07, 1.0)
const DEFAULT_BLOOD_COLOR_BY_CHARACTER := {
	"outrage": Color(0.98, 0.02, 0.07, 1.0),
	"erebus": Color(0.72, 0.78, 1.0, 1.0),
	"tasko": Color(1.0, 0.65, 0.92, 1.0),
	"juice": Color(0.95, 1.0, 0.56, 1.0),
	"madam": Color(0.86, 0.48, 0.42, 1.0),
	"celler": Color(0.63, 0.74, 1.0, 1.0),
	"kotro": Color(0.47, 0.92, 0.86, 1.0),
}
const DEFAULT_SKILL_COLOR_BY_CHARACTER := {
	"outrage": Color(0.98, 0.02, 0.07, 1.0),
	"erebus": Color(0.72, 0.78, 1.0, 1.0),
	"tasko": Color(1.0, 0.65, 0.92, 1.0),
	"juice": Color(0.95, 1.0, 0.56, 1.0),
	"madam": Color(0.86, 0.48, 0.42, 1.0),
	"celler": Color(0.63, 0.74, 1.0, 1.0),
	"kotro": Color(0.47, 0.92, 0.86, 1.0),
}

var server_skin_blood_color_config: Dictionary = {}

func _reset_runtime_state() -> void:
	snapshot_accumulator = 0.0
	escape_return_pending = false
	escape_return_nonce += 1
	if dropped_mag_service != null:
		dropped_mag_service.reset()
	for controller in bot_controllers:
		if controller != null:
			controller.reset()
	if ctf_match_controller != null:
		ctf_match_controller.reset()
	_clear_players()
	projectile_system.clear()
	input_states.clear()
	fire_cooldowns.clear()
	player_history.clear()
	input_rate_window_start_ms.clear()
	input_rate_counts.clear()
	spawn_slots.clear()
	player_stats.clear()
	player_display_names.clear()
	ammo_by_peer.clear()
	reload_remaining_by_peer.clear()
	pending_reload_delay_by_peer.clear()
	skill_charge_points_by_peer.clear()
	skill_charge_required_by_peer.clear()
	peer_weapon_ids.clear()
	peer_weapon_skin_indices_by_peer.clear()
	peer_character_ids.clear()
	peer_skin_indices_by_peer.clear()
	_reset_spawn_request_state()
	_reset_ping_state()
	client_input_controller.reset()
	camera_shake.reset()
	if _uses_lobby_scene_flow():
		lobby_service.reset(true)
		lobby_entries.clear()
		lobby_map_by_id.clear()
		lobby_mode_by_id.clear()
		client_lobby_id = 0
		lobby_auto_action_inflight = false
	_update_score_labels()
	_update_peer_labels()

func _clear_players() -> void:
	for value in players.values():
		var player := value as NetPlayer
		if is_instance_valid(player):
			player.queue_free()
	players.clear()

func _reset_ping_state() -> void:
	ping_accumulator = 0.0
	last_ping_ms = -1

func _reset_spawn_request_state() -> void:
	spawn_request_sent = false

func _set_client_lobby_id(value: int) -> void:
	client_lobby_id = maxi(0, value)
	_refresh_lobby_buttons()
	_refresh_ctf_room_ui()

func _set_lobby_auto_action_inflight(value: bool) -> void:
	lobby_auto_action_inflight = value
	_refresh_lobby_buttons()

func _clear_lobby_list() -> void:
	lobby_entries.clear()
	lobby_map_by_id.clear()
	lobby_mode_by_id.clear()
	peer_team_by_peer.clear()
	active_lobby_room_state.clear()
	if ctf_match_controller != null:
		ctf_match_controller.reset()
	ui_controller.clear_lobby_list()
	ui_controller.hide_ctf_room()
	_refresh_lobby_buttons()

func _set_lobby_status(text: String) -> void:
	ui_controller.set_lobby_status(text)

func _refresh_lobby_list_ui(entries: Array, active_lobby_id: int) -> void:
	lobby_entries = entries.duplicate(true)
	ui_controller.refresh_lobby_list_ui(entries, active_lobby_id, map_catalog.max_players_for_id(selected_map_id))
	_refresh_ctf_room_ui()
	_refresh_lobby_buttons()

func _refresh_lobby_buttons() -> void:
	ui_controller.update_lobby_buttons_state(_is_client_connected(), client_lobby_id > 0)
	if not lobby_auto_action_inflight:
		return
	if lobby_create_button != null:
		lobby_create_button.disabled = true
	if lobby_join_button != null:
		lobby_join_button.disabled = true
	if lobby_refresh_button != null:
		lobby_refresh_button.disabled = true
	if lobby_leave_button != null:
		lobby_leave_button.disabled = true

func _update_buttons() -> void:
	startup_mode = session_controller.get_startup_mode()
	var has_active_session := role != Role.NONE
	var server_allowed := startup_mode != Role.CLIENT
	var client_allowed := startup_mode != Role.SERVER
	ui_controller.update_buttons(
		has_active_session,
		server_allowed,
		client_allowed,
		role == Role.SERVER,
		role == Role.CLIENT
	)
	_refresh_lobby_buttons()

func _update_peer_labels() -> void:
	var spawned_ids: Array = []
	for peer_value in players.keys():
		var peer_id := int(peer_value)
		if _is_target_dummy_peer(peer_id):
			continue
		spawned_ids.append(peer_id)
	spawned_ids.sort()
	var local_peer_id := 0
	var net_peers := PackedInt32Array()
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		local_peer_id = multiplayer.get_unique_id()
		net_peers = multiplayer.get_peers()
	ui_controller.update_peer_labels(
		local_peer_id,
		net_peers,
		spawned_ids,
		ui_controller.local_ping_text(role == Role.SERVER, role == Role.CLIENT, last_ping_ms)
	)

func _update_ping_label() -> void:
	ui_controller.update_ping_label(ui_controller.local_ping_text(role == Role.SERVER, role == Role.CLIENT, last_ping_ms))

func _update_ui_visibility() -> void:
	var auth_blocking := auth_panel != null and auth_panel.visible
	ui_controller.update_ui_visibility(
		_uses_lobby_scene_flow(),
		role == Role.SERVER,
		role == Role.CLIENT,
		_is_local_player_spawned(),
		scoreboard_visible,
		true,
		true,
		auth_blocking
	)
	_refresh_ctf_room_ui()

func _update_score_labels() -> void:
	var local_peer_id := 0
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		local_peer_id = multiplayer.get_unique_id()
	if _ctf_enabled() and ctf_match_controller != null:
		_merge_team_assignments_from_room_state()
		_merge_team_assignments_from_lobby_service(local_peer_id)
		if peer_team_by_peer.is_empty() and role == Role.SERVER:
			var server_lobby_id := _peer_lobby(local_peer_id)
			if server_lobby_id <= 0:
				server_lobby_id = _target_dummy_lobby_id()
			if server_lobby_id > 0:
				_assign_ctf_teams(server_lobby_id)
		var mode_label := "CTF" if _ctf_objective_enabled() else "TDTH"
		if kd_label != null:
			kd_label.text = ctf_match_controller.hud_score_text_for_mode(mode_label)
		ui_controller.update_scoreboard_label(player_stats, player_display_names)
	else:
		ui_controller.update_kd_label(local_peer_id, player_stats)
		ui_controller.update_scoreboard_label(player_stats, player_display_names)

func _merge_team_assignments_from_room_state() -> void:
	if active_lobby_room_state.is_empty():
		return
	var raw_team_by_peer := active_lobby_room_state.get("team_by_peer", {}) as Dictionary
	for peer_value in raw_team_by_peer.keys():
		var peer_id := int(peer_value)
		if peer_id == 0:
			continue
		peer_team_by_peer[peer_id] = int(raw_team_by_peer.get(peer_value, -1))

func _merge_team_assignments_from_lobby_service(local_peer_id: int) -> void:
	if lobby_service == null:
		return
	var lobby_id := client_lobby_id
	if lobby_id <= 0 and local_peer_id > 0:
		lobby_id = _peer_lobby(local_peer_id)
	if lobby_id <= 0:
		lobby_id = _target_dummy_lobby_id()
	if lobby_id <= 0:
		return
	var planned := lobby_service.team_assignments_for_lobby(lobby_id)
	for peer_value in planned.keys():
		var peer_id := int(peer_value)
		if peer_id == 0:
			continue
		peer_team_by_peer[peer_id] = int(planned.get(peer_value, -1))

func _cooldown_text(prefix: String, remaining_sec: float) -> String:
	if remaining_sec <= 0.0:
		return "%s: Ready" % prefix
	return "%s: %.1fs" % [prefix, remaining_sec]

func _update_skill_cooldowns_hud(q_remaining: float, e_remaining: float) -> void:
	if ui_controller == null:
		return
	ui_controller.update_skill_cooldowns(_cooldown_text("Q", q_remaining), _cooldown_text("E", e_remaining))

func client_set_status_text(text: String) -> void:
	if ui_controller == null:
		return
	if ui_controller.has_method("set_status_text"):
		ui_controller.call("set_status_text", text)

func _show_local_ip() -> void:
	var ips := PackedStringArray()
	for address in IP.get_local_addresses():
		if address.contains(".") and not address.begins_with("127."):
			ips.append(address)
	if ips.is_empty():
		local_ip_label.text = "Local IP: 127.0.0.1"
	else:
		local_ip_label.text = "Local IP(s): %s" % ", ".join(ips)

func _append_log(message: String) -> void:
	print("[runtime] %s" % message)
	if log_label == null:
		return
	log_label.append_text("%s\n" % message)
	log_label.scroll_to_line(max(log_label.get_line_count() - 1, 0))

func _client_ping_tick(delta: float) -> void:
	if role != Role.CLIENT:
		return
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	var peer := multiplayer.multiplayer_peer
	if peer is OfflineMultiplayerPeer:
		return
	if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return
	ping_accumulator += delta
	if ping_accumulator < PING_INTERVAL:
		return
	ping_accumulator = 0.0
	_rpc_ping_request.rpc_id(1, Time.get_ticks_msec())

func _warrior_id_for_peer(peer_id: int) -> String:
	var normalized := str(peer_character_ids.get(peer_id, "")).strip_edges().to_lower()
	if normalized == CHARACTER_ID_EREBUS:
		return CHARACTER_ID_EREBUS
	if normalized == CHARACTER_ID_OUTRAGE:
		return CHARACTER_ID_OUTRAGE
	if normalized == CHARACTER_ID_TASKO:
		return CHARACTER_ID_TASKO
	if normalized == CHARACTER_ID_JUICE:
		return CHARACTER_ID_JUICE
	if normalized == CHARACTER_ID_MADAM:
		return CHARACTER_ID_MADAM
	if normalized == CHARACTER_ID_CELLER:
		return CHARACTER_ID_CELLER
	if normalized == CHARACTER_ID_KOTRO:
		return CHARACTER_ID_KOTRO
	if lobby_service != null:
		var persisted := str(lobby_service.get_peer_character(peer_id, "")).strip_edges().to_lower()
		if persisted == CHARACTER_ID_EREBUS:
			peer_character_ids[peer_id] = CHARACTER_ID_EREBUS
			return CHARACTER_ID_EREBUS
		if persisted == CHARACTER_ID_OUTRAGE:
			peer_character_ids[peer_id] = CHARACTER_ID_OUTRAGE
			return CHARACTER_ID_OUTRAGE
		if persisted == CHARACTER_ID_TASKO:
			peer_character_ids[peer_id] = CHARACTER_ID_TASKO
			return CHARACTER_ID_TASKO
		if persisted == CHARACTER_ID_JUICE:
			peer_character_ids[peer_id] = CHARACTER_ID_JUICE
			return CHARACTER_ID_JUICE
		if persisted == CHARACTER_ID_MADAM:
			peer_character_ids[peer_id] = CHARACTER_ID_MADAM
			return CHARACTER_ID_MADAM
		if persisted == CHARACTER_ID_CELLER:
			peer_character_ids[peer_id] = CHARACTER_ID_CELLER
			return CHARACTER_ID_CELLER
		if persisted == CHARACTER_ID_KOTRO:
			peer_character_ids[peer_id] = CHARACTER_ID_KOTRO
			return CHARACTER_ID_KOTRO
	if multiplayer != null and multiplayer.multiplayer_peer != null and peer_id == multiplayer.get_unique_id():
		var local_normalized := str(selected_character_id).strip_edges().to_lower()
		if local_normalized == CHARACTER_ID_EREBUS:
			return CHARACTER_ID_EREBUS
		if local_normalized == CHARACTER_ID_TASKO:
			return CHARACTER_ID_TASKO
		if local_normalized == CHARACTER_ID_JUICE:
			return CHARACTER_ID_JUICE
		if local_normalized == CHARACTER_ID_MADAM:
			return CHARACTER_ID_MADAM
		if local_normalized == CHARACTER_ID_CELLER:
			return CHARACTER_ID_CELLER
		if local_normalized == CHARACTER_ID_KOTRO:
			return CHARACTER_ID_KOTRO
		return CHARACTER_ID_OUTRAGE
	return CHARACTER_ID_OUTRAGE

func _skin_index_for_peer(peer_id: int) -> int:
	if peer_skin_indices_by_peer.has(peer_id):
		return maxi(0, int(peer_skin_indices_by_peer.get(peer_id, 0)))
	if lobby_service != null:
		var persisted_skin := int(lobby_service.get_peer_skin(peer_id, 0))
		if persisted_skin >= 0:
			return persisted_skin
	if multiplayer != null and multiplayer.multiplayer_peer != null and peer_id == multiplayer.get_unique_id():
		if lobby_service != null:
			return maxi(0, int(lobby_service.get_local_selected_skin(_warrior_id_for_peer(peer_id), 0)))
	return 0

func _load_server_skin_blood_color_config() -> void:
	server_skin_blood_color_config = {}
	if _load_server_skin_blood_color_config_from_resource():
		return
	_append_log("Server color resource missing/invalid at %s; using defaults." % SERVER_SKIN_BLOOD_COLORS_RESOURCE_PATH)

func _load_server_skin_blood_color_config_from_resource() -> bool:
	if not ResourceLoader.exists(SERVER_SKIN_BLOOD_COLORS_RESOURCE_PATH):
		return false
	var resource := ResourceLoader.load(SERVER_SKIN_BLOOD_COLORS_RESOURCE_PATH)
	if resource == null:
		_append_log("Server blood-color resource load failed at %s; trying JSON fallback." % SERVER_SKIN_BLOOD_COLORS_RESOURCE_PATH)
		return false
	var entries_value: Variant = resource.get("entries")
	if not (entries_value is Array):
		_append_log("Server blood-color resource has invalid entries at %s; trying JSON fallback." % SERVER_SKIN_BLOOD_COLORS_RESOURCE_PATH)
		return false
	var characters: Dictionary = {}
	var entries := entries_value as Array
	for entry_value in entries:
		var entry := entry_value as SkinBloodColorEntry
		if entry == null:
			continue
		var character_id := str(entry.character_id).strip_edges().to_lower()
		if character_id.is_empty():
			continue
		var skin_index := int(entry.skin_index)
		var color := _color_from_variant(entry.blood_color, _default_blood_color_for_character(character_id))
		var skill_color := _color_from_variant(entry.skill_color, _default_skill_color_for_character(character_id))
		var character_entry: Dictionary = {}
		if characters.has(character_id):
			character_entry = characters.get(character_id, {}) as Dictionary
		else:
			character_entry = {
				"blood_default": _default_blood_color_for_character(character_id),
				"skill_default": _default_skill_color_for_character(character_id),
				"blood_skins": {},
				"skill_skins": {}
			}
		if skin_index < 0:
			character_entry["blood_default"] = color
			character_entry["skill_default"] = skill_color
		else:
			var blood_skins := character_entry.get("blood_skins", {}) as Dictionary
			var skill_skins := character_entry.get("skill_skins", {}) as Dictionary
			var safe_skin_index := str(maxi(0, skin_index))
			blood_skins[safe_skin_index] = color
			skill_skins[safe_skin_index] = skill_color
			character_entry["blood_skins"] = blood_skins
			character_entry["skill_skins"] = skill_skins
		characters[character_id] = character_entry
	server_skin_blood_color_config = {"characters": characters}
	_append_log("Loaded server blood/skill colors from resource (%d entries)." % entries.size())
	return true

func _authoritative_blood_color_for_peer(peer_id: int) -> Color:
	return _resolve_authoritative_character_color(peer_id, "blood")

func _authoritative_skill_color_for_peer(peer_id: int) -> Color:
	return _resolve_authoritative_character_color(peer_id, "skill")

func _resolve_authoritative_character_color(peer_id: int, channel: String) -> Color:
	var warrior_id := _warrior_id_for_peer(peer_id)
	var skin_index := _skin_index_for_peer(peer_id)
	var normalized_channel := channel.strip_edges().to_lower()
	var fallback := _default_blood_color_for_character(warrior_id)
	if normalized_channel == "skill":
		fallback = _default_skill_color_for_character(warrior_id)
	if server_skin_blood_color_config.is_empty():
		return fallback
	var characters: Dictionary = server_skin_blood_color_config.get("characters", {}) as Dictionary
	if not characters.has(warrior_id):
		return fallback
	var entry: Dictionary = characters.get(warrior_id, {}) as Dictionary
	var default_key := "blood_default"
	var skins_key := "blood_skins"
	if normalized_channel == "skill":
		default_key = "skill_default"
		skins_key = "skill_skins"
	var character_default := _color_from_variant(entry.get(default_key, fallback), fallback)
	var skins: Dictionary = entry.get(skins_key, {}) as Dictionary
	var skin_key := str(maxi(0, skin_index))
	if skins.has(skin_key):
		return _color_from_variant(skins.get(skin_key, character_default), character_default)
	if skins.has(maxi(0, skin_index)):
		return _color_from_variant(skins.get(maxi(0, skin_index), character_default), character_default)
	return character_default

func _default_blood_color_for_character(character_id: String) -> Color:
	if DEFAULT_BLOOD_COLOR_BY_CHARACTER.has(character_id):
		return DEFAULT_BLOOD_COLOR_BY_CHARACTER[character_id] as Color
	return DEFAULT_BLOOD_COLOR

func _default_skill_color_for_character(character_id: String) -> Color:
	if DEFAULT_SKILL_COLOR_BY_CHARACTER.has(character_id):
		return DEFAULT_SKILL_COLOR_BY_CHARACTER[character_id] as Color
	return DEFAULT_SKILL_COLOR

func _color_from_variant(value: Variant, fallback: Color) -> Color:
	if value is Color:
		return value as Color
	if value is String:
		return Color.from_string(str(value), fallback)
	if value is Dictionary:
		var payload := value as Dictionary
		var r := float(payload.get("r", fallback.r))
		var g := float(payload.get("g", fallback.g))
		var b := float(payload.get("b", fallback.b))
		var a := float(payload.get("a", fallback.a))
		return Color(
			clampf(r, 0.0, 1.0),
			clampf(g, 0.0, 1.0),
			clampf(b, 0.0, 1.0),
			clampf(a, 0.0, 1.0)
		)
	if value is Array:
		var arr := value as Array
		if arr.size() < 3:
			return fallback
		var r := float(arr[0])
		var g := float(arr[1])
		var b := float(arr[2])
		var a := float(arr[3]) if arr.size() > 3 else 1.0
		return Color(
			clampf(r, 0.0, 1.0),
			clampf(g, 0.0, 1.0),
			clampf(b, 0.0, 1.0),
			clampf(a, 0.0, 1.0)
		)
	return fallback

func _ensure_player_display_name(peer_id: int) -> String:
	if lobby_service != null and lobby_service.has_method("get_peer_display_name"):
		var persisted := str(lobby_service.call("get_peer_display_name", peer_id, "")).strip_edges()
		if not persisted.is_empty():
			player_display_names[peer_id] = persisted
			return persisted
	return spawn_identity.ensure_player_display_name(peer_id)

func _has_active_lobbies() -> bool:
	return lobby_service != null and lobby_service.has_active_lobbies()

func _peer_lobby(peer_id: int) -> int:
	if _is_target_dummy_peer(peer_id):
		var bot_controller := _bot_controller_for_peer(peer_id)
		if bot_controller != null and bot_controller.get_lobby_id() > 0:
			return bot_controller.get_lobby_id()
		return 0
	if lobby_service != null:
		var tracked_lobby := lobby_service.get_peer_lobby(peer_id)
		if tracked_lobby > 0:
			return tracked_lobby
		if lobby_service.has_active_lobbies():
			return 0
	if not _uses_lobby_scene_flow():
		return 1
	return 0

func _active_game_mode() -> String:
	if client_lobby_id > 0 and lobby_mode_by_id.has(client_lobby_id):
		return str(lobby_mode_by_id.get(client_lobby_id, GAME_MODE_DEATHMATCH))
	if role == Role.SERVER and multiplayer != null and multiplayer.multiplayer_peer != null:
		var local_lobby_id := _peer_lobby(multiplayer.get_unique_id())
		if local_lobby_id > 0 and lobby_service != null:
			var lobby := lobby_service.get_lobby_data(local_lobby_id)
			if not lobby.is_empty():
				return map_flow_service.normalize_mode_id(str(lobby.get("mode_id", GAME_MODE_DEATHMATCH)))
	return map_flow_service.normalize_mode_id(client_target_game_mode if not client_target_game_mode.is_empty() else selected_game_mode)

func _lobby_members(lobby_id: int) -> Array:
	if lobby_service != null and lobby_id > 0 and lobby_service.has_lobby(lobby_id):
		return lobby_service.get_lobby_members(lobby_id)
	if lobby_service != null and lobby_service.has_active_lobbies():
		return []
	if not _uses_lobby_scene_flow():
		var members: Array = []
		if multiplayer.multiplayer_peer != null:
			var self_id := multiplayer.get_unique_id()
			if self_id > 0 and not members.has(self_id):
				members.append(self_id)
			for id_value in multiplayer.get_peers():
				var id := int(id_value)
				if not members.has(id):
					members.append(id)
		return members
	return []

func _lobby_map_id(lobby_id: int) -> String:
	if lobby_id <= 0:
		return ""
	var lobby := lobby_service.get_lobby_data(lobby_id)
	if lobby.is_empty():
		return ""
	return map_flow_service.normalize_map_id(map_catalog, str(lobby.get("map_id", MAP_ID_CLASSIC)))

func _is_client_connected() -> bool:
	if role != Role.CLIENT:
		return false
	if multiplayer.multiplayer_peer == null:
		return false
	return multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func _is_local_player_spawned() -> bool:
	if multiplayer.multiplayer_peer == null:
		return false
	var local_id := multiplayer.get_unique_id()
	return local_id > 0 and players.has(local_id)

func _role_name(value: int) -> String:
	match value:
		Role.SERVER:
			return "server"
		Role.CLIENT:
			return "client"
		_:
			return "manual"
