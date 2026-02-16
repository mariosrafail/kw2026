extends RefCounted
class_name MapFlowService

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
	map_id: String
) -> String:
	var normalized_weapon := weapon_id
	if normalize_weapon_id_cb.is_valid():
		normalized_weapon = str(normalize_weapon_id_cb.call(weapon_id))
	return "%s|%s" % [normalized_weapon, normalize_map_id(map_catalog, map_id)]

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
	if normalized_payload.is_empty():
		return {
			"weapon_id": fallback_weapon_id,
			"map_id": fallback_map_id
		}

	var sep_index := normalized_payload.find("|")
	if sep_index < 0:
		var weapon_only := normalized_payload
		if normalize_weapon_id_cb.is_valid():
			weapon_only = str(normalize_weapon_id_cb.call(normalized_payload))
		return {
			"weapon_id": weapon_only,
			"map_id": fallback_map_id
		}

	var weapon_part := normalized_payload.substr(0, sep_index)
	var map_part := normalized_payload.substr(sep_index + 1)
	var raw_map_id := map_part.strip_edges().to_lower()
	if raw_map_id.is_empty():
		raw_map_id = fallback_map_id

	var normalized_weapon_part := weapon_part
	if normalize_weapon_id_cb.is_valid():
		normalized_weapon_part = str(normalize_weapon_id_cb.call(weapon_part))
	return {
		"weapon_id": normalized_weapon_part,
		"map_id": raw_map_id
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
		if normalized == fallback_map_id and raw_map_id != fallback_map_id:
			entry["map_name"] = raw_map_id.capitalize()
		else:
			entry["map_name"] = map_label_for_id(map_catalog, normalized)
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
	for entry_value in entries:
		if not (entry_value is Dictionary):
			continue
		var entry := (entry_value as Dictionary).duplicate()
		var map_id := normalize_map_id(map_catalog, str(entry.get("map_id", fallback_map_id)))
		entry["map_id"] = map_id
		entry["map_name"] = map_label_for_id(map_catalog, map_id)
		var lobby_id := int(entry.get("id", 0))
		if lobby_id > 0:
			lobby_map_by_id[lobby_id] = map_id
		normalized_entries.append(entry)

	return {
		"entries": normalized_entries,
		"lobby_map_by_id": lobby_map_by_id,
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
