extends RefCounted

func on_lobby_weapon_selected(host: Node, index: int) -> void:
	var lobby_weapon_option: OptionButton = host.get("lobby_weapon_option") as OptionButton
	if lobby_weapon_option == null:
		return
	var selected_weapon_id: String = str(host.call("_normalize_weapon_id", str(lobby_weapon_option.get_item_metadata(index))))
	host.set("selected_weapon_id", selected_weapon_id)
	persist_local_weapon_selection(host)
	if bool(host.call("_is_client_connected")) and int(host.get("client_lobby_id")) > 0:
		host.rpc_id(1, "_rpc_lobby_set_weapon", selected_weapon_id)

func on_lobby_character_selected(host: Node, index: int) -> void:
	var lobby_character_option: OptionButton = host.get("lobby_character_option") as OptionButton
	if lobby_character_option == null:
		return
	if index < 0 or index >= lobby_character_option.item_count:
		print("[DBG CHAR] Invalid character index: %d (item_count: %d)" % [index, lobby_character_option.item_count])
		return
	var metadata: Variant = lobby_character_option.get_item_metadata(index)
	if metadata == null:
		print("[DBG CHAR] Character metadata at index %d is null!" % index)
		return
	var selected_character_id: String = str(host.call("_normalize_character_id", str(metadata)))
	host.set("selected_character_id", selected_character_id)
	print("[DBG CHAR] ===>>> SELECTED CHARACTER: %s (index: %d, metadata: %s, client_lobby_id: %d)" % [
		selected_character_id,
		index,
		metadata,
		int(host.get("client_lobby_id"))
	])
	persist_local_character_selection(host)
	host.call("_setup_skin_picker")
	if bool(host.call("_is_client_connected")) and int(host.get("client_lobby_id")) > 0:
		print("[DBG CHAR] Sending RPC to server for character: %s" % selected_character_id)
		host.rpc_id(1, "_rpc_lobby_set_character", selected_character_id)
	else:
		print("[DBG CHAR] Not sending RPC yet (connected=%s, lobby_id=%d)" % [bool(host.call("_is_client_connected")), int(host.get("client_lobby_id"))])

func on_lobby_skin_selected(host: Node, index: int, character_id_outrage: String) -> void:
	var lobby_skin_option: OptionButton = host.get("lobby_skin_option") as OptionButton
	if lobby_skin_option == null:
		return
	var selected_character_id: String = str(host.get("selected_character_id"))
	if selected_character_id != character_id_outrage:
		return
	if index < 0 or index >= lobby_skin_option.item_count:
		return
	var meta: Variant = lobby_skin_option.get_item_metadata(index)
	if meta == null:
		return
	var skin_index: int = int(meta)
	if not bool(host.call("_is_skin_owned", selected_character_id, skin_index)):
		var previous: int = 1
		var lobby_service: Object = host.get("lobby_service") as Object
		if lobby_service != null:
			previous = int(lobby_service.call("get_local_selected_skin", selected_character_id, 1))
		if not bool(host.call("_is_skin_owned", selected_character_id, previous)):
			previous = 1
		for i in range(lobby_skin_option.item_count):
			if int(lobby_skin_option.get_item_metadata(i)) == previous:
				lobby_skin_option.select(i)
				break
		host.call("_prompt_purchase_skin", selected_character_id, skin_index, lobby_skin_option.get_item_text(index))
		return
	persist_local_skin_selection(host, selected_character_id, skin_index)
	if bool(host.call("_can_issue_lobby_actions")):
		host.rpc_id(1, "_rpc_lobby_set_skin", skin_index)

func on_lobby_map_selected(host: Node, index: int) -> void:
	var lobby_map_option: OptionButton = host.get("lobby_map_option") as OptionButton
	if lobby_map_option == null:
		return
	var map_flow_service: Object = host.get("map_flow_service") as Object
	var map_catalog: Variant = host.get("map_catalog")
	var selected_map_id: String = str(map_flow_service.call("normalize_map_id", map_catalog, str(lobby_map_option.get_item_metadata(index))))
	host.set("selected_map_id", selected_map_id)
	var selected_game_mode: String = str(map_flow_service.call("select_mode_for_map", map_catalog, selected_map_id, str(host.get("selected_game_mode"))))
	host.set("selected_game_mode", selected_game_mode)
	host.call("_setup_mode_picker")
	if int(host.get("client_lobby_id")) <= 0:
		host.set("client_target_map_id", selected_map_id)
		host.set("client_target_game_mode", selected_game_mode)

func on_lobby_mode_selected(host: Node, index: int) -> void:
	var lobby_mode_option: OptionButton = host.get("lobby_mode_option") as OptionButton
	if lobby_mode_option == null:
		return
	var map_flow_service: Object = host.get("map_flow_service") as Object
	var map_catalog: Variant = host.get("map_catalog")
	var selected_game_mode: String = str(map_flow_service.call(
		"select_mode_for_map",
		map_catalog,
		str(host.get("selected_map_id")),
		str(lobby_mode_option.get_item_metadata(index))
	))
	host.set("selected_game_mode", selected_game_mode)
	if int(host.get("client_lobby_id")) <= 0:
		host.set("client_target_game_mode", selected_game_mode)

func persist_local_weapon_selection(host: Node) -> void:
	var lobby_service: Object = host.get("lobby_service") as Object
	if lobby_service == null:
		return
	var selected_weapon_id: String = str(host.get("selected_weapon_id"))
	lobby_service.call("set_local_selected_weapon", selected_weapon_id)
	host.call("_save_account_loadout")
	host.call("_sync_selected_loadout_to_server")
	var multiplayer_api: MultiplayerAPI = host.get("multiplayer") as MultiplayerAPI
	if multiplayer_api == null or multiplayer_api.multiplayer_peer == null:
		return
	var local_peer_id: int = multiplayer_api.get_unique_id()
	if local_peer_id <= 0:
		return
	lobby_service.call("set_peer_weapon", local_peer_id, selected_weapon_id)

func persist_local_character_selection(host: Node) -> void:
	var lobby_service: Object = host.get("lobby_service") as Object
	if lobby_service == null:
		return
	var selected_character_id: String = str(host.get("selected_character_id"))
	lobby_service.call("set_local_selected_character", selected_character_id)
	host.call("_save_account_loadout")
	host.call("_sync_selected_loadout_to_server")
	var multiplayer_api: MultiplayerAPI = host.get("multiplayer") as MultiplayerAPI
	if multiplayer_api == null or multiplayer_api.multiplayer_peer == null:
		return
	var local_peer_id: int = multiplayer_api.get_unique_id()
	if local_peer_id <= 0:
		return
	lobby_service.call("set_peer_character", local_peer_id, selected_character_id)

func persist_local_skin_selection(host: Node, character_id: String, skin_index: int) -> void:
	var lobby_service: Object = host.get("lobby_service") as Object
	if lobby_service == null:
		return
	lobby_service.call("set_local_selected_skin", character_id, skin_index)
	host.call("_save_account_loadout")
	host.call("_sync_selected_loadout_to_server")
	var multiplayer_api: MultiplayerAPI = host.get("multiplayer") as MultiplayerAPI
	if multiplayer_api == null or multiplayer_api.multiplayer_peer == null:
		return
	var local_peer_id: int = multiplayer_api.get_unique_id()
	if local_peer_id <= 0:
		return
	lobby_service.call("set_peer_skin", local_peer_id, skin_index)

func persist_local_outage_skin_if_needed(host: Node, character_id_outrage: String) -> void:
	var selected_character_id: String = str(host.get("selected_character_id"))
	if selected_character_id != character_id_outrage:
		return
	var skin_index: int = 1
	var lobby_skin_option: OptionButton = host.get("lobby_skin_option") as OptionButton
	if lobby_skin_option != null and lobby_skin_option.item_count > 0:
		var selected_index: int = int(lobby_skin_option.selected)
		if selected_index >= 0 and selected_index < lobby_skin_option.item_count:
			var meta: Variant = lobby_skin_option.get_item_metadata(selected_index)
			if meta != null:
				skin_index = int(meta)
	persist_local_skin_selection(host, selected_character_id, skin_index)
	if bool(host.call("_can_issue_lobby_actions")):
		host.rpc_id(1, "_rpc_lobby_set_skin", skin_index)
