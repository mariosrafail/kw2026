extends RefCounted
class_name MapFlowService

func normalize_mode_id(mode_id: String) -> String:
	var normalized := mode_id.strip_edges().to_lower()
	if normalized == "battle_royale":
		return "battle_royale"
	if normalized == "ctf":
		return "ctf"
	if normalized == "tdth":
		return "tdth"
	return "deathmatch"

func mode_label_for_id(mode_id: String) -> String:
	var normalized := normalize_mode_id(mode_id)
	if normalized == "battle_royale":
		return "Battle Royale"
	if normalized == "ctf":
		return "Capture The Flag"
	if normalized == "tdth":
		return "Team Deathmatch (TDTH)"
	return "Free For All (FFA)"

func supported_modes_for_map(map_catalog: MapCatalog, map_id: String) -> Array[String]:
	if map_catalog == null:
		return ["deathmatch"]
	return map_catalog.supported_modes_for_id(map_id)

func select_mode_for_map(map_catalog: MapCatalog, map_id: String, requested_mode: String) -> String:
	var normalized_mode := normalize_mode_id(requested_mode)
	var supported_modes := supported_modes_for_map(map_catalog, map_id)
	if supported_modes.has(normalized_mode):
		return normalized_mode
	return str(supported_modes[0]) if not supported_modes.is_empty() else "deathmatch"

func normalize_map_id(map_catalog: MapCatalog, map_id: String) -> String:
	if map_catalog == null:
		var normalized := map_id.strip_edges().to_lower()
		return "classic" if normalized.is_empty() else normalized
	return map_catalog.normalize_map_id(map_id)

func map_label_for_id(map_catalog: MapCatalog, map_id: String) -> String:
	if map_catalog == null:
		var normalized := normalize_map_id(map_catalog, map_id)
		return normalized.capitalize()
	return map_catalog.label_for_id(map_id)

func scene_path_for_id(map_catalog: MapCatalog, map_id: String) -> String:
	if map_catalog == null:
		return ""
	return map_catalog.scene_path_for_id(map_id)

func setup_lobby_map_picker(option: OptionButton, map_catalog: MapCatalog, selected_map_id: String) -> void:
	if option == null or map_catalog == null:
		return
	option.clear()
	for map_id in map_catalog.all_map_ids():
		option.add_item(map_label_for_id(map_catalog, map_id))
		option.set_item_metadata(option.item_count - 1, map_id)
	sync_lobby_map_picker_selection(option, map_catalog, selected_map_id)

func setup_lobby_mode_picker(option: OptionButton, map_catalog: MapCatalog, selected_map_id: String, selected_mode_id: String) -> void:
	if option == null:
		return
	option.clear()
	var normalized_map := normalize_map_id(map_catalog, selected_map_id)
	var supported_modes := supported_modes_for_map(map_catalog, normalized_map)
	for mode_id in supported_modes:
		option.add_item(mode_label_for_id(mode_id))
		option.set_item_metadata(option.item_count - 1, mode_id)
	var resolved_mode := select_mode_for_map(map_catalog, normalized_map, selected_mode_id)
	for index in range(option.item_count):
		if normalize_mode_id(str(option.get_item_metadata(index))) == resolved_mode:
			option.select(index)
			return
	if option.item_count > 0:
		option.select(0)

func sync_lobby_map_picker_selection(option: OptionButton, map_catalog: MapCatalog, selected_map_id: String) -> void:
	if option == null:
		return
	var normalized := normalize_map_id(map_catalog, selected_map_id)
	for index in range(option.item_count):
		var item_map_id := normalize_map_id(map_catalog, str(option.get_item_metadata(index)))
		if item_map_id == normalized:
			option.select(index)
			return
	if option.item_count > 0:
		option.select(0)

func select_map(
	map_catalog: MapCatalog,
	current_target_map_id: String,
	map_id: String,
	set_target_map: bool
) -> Dictionary:
	var normalized := normalize_map_id(map_catalog, map_id)
	var next_target := current_target_map_id
	if set_target_map:
		next_target = normalized
	return {
		"selected_map_id": normalized,
		"client_target_map_id": next_target
	}

func encode_create_lobby_payload(
	map_catalog: MapCatalog,
	normalize_weapon_id_cb: Callable,
	weapon_id: String,
	map_id: String,
	character_id: String = "",
	mode_id: String = "deathmatch"
) -> String:
	var normalized_weapon := weapon_id
	if normalize_weapon_id_cb.is_valid():
		normalized_weapon = str(normalize_weapon_id_cb.call(weapon_id))
	var normalized_character := character_id.strip_edges().to_lower()
	if normalized_character != "erebus" and normalized_character != "tasko" and normalized_character != "juice" and normalized_character != "madam":
		normalized_character = "outrage"
	var normalized_map := normalize_map_id(map_catalog, map_id)
	var normalized_mode := select_mode_for_map(map_catalog, normalized_map, mode_id)
	# v3 payload: weapon|character|map|mode (still supports v2/v1)
	return "%s|%s|%s|%s" % [normalized_weapon, normalized_character, normalized_map, normalized_mode]

func decode_create_lobby_payload(
	map_catalog: MapCatalog,
	normalize_weapon_id_cb: Callable,
	default_weapon_id: String,
	payload: String
) -> Dictionary:
	var normalized_payload := payload.strip_edges()
	var fallback_map_id := _default_map_id(map_catalog)
	var fallback_weapon_id := default_weapon_id
	if normalize_weapon_id_cb.is_valid():
		fallback_weapon_id = str(normalize_weapon_id_cb.call(default_weapon_id))
	var fallback_character_id := "outrage"
	if normalized_payload.is_empty():
		return {
			"weapon_id": fallback_weapon_id,
			"character_id": fallback_character_id,
			"map_id": fallback_map_id,
			"mode_id": "deathmatch"
		}

	var sep_index := normalized_payload.find("|")
	if sep_index < 0:
		var weapon_only := normalized_payload
		if normalize_weapon_id_cb.is_valid():
			weapon_only = str(normalize_weapon_id_cb.call(normalized_payload))
		return {
			"weapon_id": weapon_only,
			"character_id": fallback_character_id,
			"map_id": fallback_map_id,
			"mode_id": "deathmatch"
		}

	var parts := normalized_payload.split("|", false)
	if parts.size() == 2:
		# v1 payload: weapon|map
		var weapon_part_v1 := parts[0]
		var map_part_v1 := parts[1]
		var raw_map_id_v1 := map_part_v1.strip_edges().to_lower()
		if raw_map_id_v1.is_empty():
			raw_map_id_v1 = fallback_map_id
		var normalized_weapon_part_v1 := weapon_part_v1
		if normalize_weapon_id_cb.is_valid():
			normalized_weapon_part_v1 = str(normalize_weapon_id_cb.call(weapon_part_v1))
		return {
			"weapon_id": normalized_weapon_part_v1,
			"character_id": fallback_character_id,
			"map_id": raw_map_id_v1,
			"mode_id": "deathmatch"
		}

	var weapon_part := parts[0] if parts.size() > 0 else ""
	var character_part := parts[1] if parts.size() > 1 else fallback_character_id
	var map_part := parts[2] if parts.size() > 2 else fallback_map_id
	var mode_part := parts[3] if parts.size() > 3 else "deathmatch"
	var raw_map_id := str(map_part).strip_edges().to_lower()
	if raw_map_id.is_empty():
		raw_map_id = fallback_map_id
	var normalized_character_part := str(character_part).strip_edges().to_lower()
	if normalized_character_part != "erebus" and normalized_character_part != "tasko" and normalized_character_part != "juice" and normalized_character_part != "madam":
		normalized_character_part = "outrage"

	var normalized_weapon_part := weapon_part
	if normalize_weapon_id_cb.is_valid():
		normalized_weapon_part = str(normalize_weapon_id_cb.call(weapon_part))
	return {
		"weapon_id": normalized_weapon_part,
		"character_id": normalized_character_part,
		"map_id": raw_map_id,
		"mode_id": select_mode_for_map(map_catalog, raw_map_id, str(mode_part))
	}

func active_lobby_map_id(
	entries: Array,
	active_lobby_id: int,
	selected_map_id: String,
	map_catalog: MapCatalog
) -> String:
	var fallback_map_id := _default_map_id(map_catalog)
	if active_lobby_id <= 0:
		return normalize_map_id(map_catalog, selected_map_id)
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry := entry_value as Dictionary
		if int(entry.get("id", 0)) != active_lobby_id:
			continue
		return normalize_map_id(map_catalog, str(entry.get("map_id", fallback_map_id)))
	return normalize_map_id(map_catalog, selected_map_id)

func effective_target_map_id(
	map_catalog: MapCatalog,
	role_value: int,
	role_server_value: int,
	selected_map_id: String,
	client_target_map_id: String,
	client_lobby_id: int,
	lobby_map_by_id: Dictionary
) -> String:
	if client_lobby_id > 0 and lobby_map_by_id.has(client_lobby_id):
		return normalize_map_id(map_catalog, str(lobby_map_by_id[client_lobby_id]))
	if role_value == role_server_value:
		return normalize_map_id(map_catalog, selected_map_id)
	return normalize_map_id(map_catalog, client_target_map_id)

func target_game_scene_path(
	map_catalog: MapCatalog,
	role_value: int,
	role_server_value: int,
	selected_map_id: String,
	client_target_map_id: String,
	client_lobby_id: int,
	lobby_map_by_id: Dictionary
) -> String:
	var effective_map := effective_target_map_id(
		map_catalog,
		role_value,
		role_server_value,
		selected_map_id,
		client_target_map_id,
		client_lobby_id,
		lobby_map_by_id
	)
	var scene_path := scene_path_for_id(map_catalog, effective_map)
	if scene_path.strip_edges().is_empty():
		scene_path = scene_path_for_id(map_catalog, _default_map_id(map_catalog))
	return scene_path

func server_pack_lobby_entries(entries: Array, map_catalog: MapCatalog) -> Array:
	var packed_entries: Array = []
	var fallback_map_id := _default_map_id(map_catalog)
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry := (entry_value as Dictionary).duplicate()
		var raw_map_id := str(entry.get("map_id", fallback_map_id)).strip_edges().to_lower()
		if raw_map_id.is_empty():
			raw_map_id = fallback_map_id
		var normalized := normalize_map_id(map_catalog, raw_map_id)
		entry["map_id"] = raw_map_id
		entry["mode_id"] = select_mode_for_map(map_catalog, raw_map_id, str(entry.get("mode_id", "deathmatch")))
		if normalized == fallback_map_id and raw_map_id != fallback_map_id:
			entry["map_name"] = raw_map_id.capitalize()
		else:
			entry["map_name"] = map_label_for_id(map_catalog, normalized)
		entry["mode_name"] = mode_label_for_id(str(entry.get("mode_id", "deathmatch")))
		packed_entries.append(entry)
	return packed_entries

func normalize_client_lobby_entries(
	entries: Array,
	active_lobby_id: int,
	selected_map_id: String,
	map_catalog: MapCatalog
) -> Dictionary:
	var fallback_map_id := _default_map_id(map_catalog)
	var normalized_entries: Array = []
	var lobby_map_by_id: Dictionary = {}
	var lobby_mode_by_id: Dictionary = {}
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry := (entry_value as Dictionary).duplicate()
		var map_id := normalize_map_id(map_catalog, str(entry.get("map_id", fallback_map_id)))
		entry["map_id"] = map_id
		entry["map_name"] = map_label_for_id(map_catalog, map_id)
		var mode_id := select_mode_for_map(map_catalog, map_id, str(entry.get("mode_id", "deathmatch")))
		entry["mode_id"] = mode_id
		entry["mode_name"] = mode_label_for_id(mode_id)
		var lobby_id := int(entry.get("id", 0))
		if lobby_id > 0:
			lobby_map_by_id[lobby_id] = map_id
			lobby_mode_by_id[lobby_id] = mode_id
		normalized_entries.append(entry)

	return {
		"entries": normalized_entries,
		"lobby_map_by_id": lobby_map_by_id,
		"lobby_mode_by_id": lobby_mode_by_id,
		"client_target_map_id": active_lobby_map_id(
			normalized_entries,
			active_lobby_id,
			selected_map_id,
			map_catalog
		)
	}

func _default_map_id(map_catalog: MapCatalog) -> String:
	if map_catalog == null:
		return "classic"
	return map_catalog.default_map_id()
