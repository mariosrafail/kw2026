extends "res://scripts/app/runtime/runtime_rpc_send_logic.gd"

func _default_input_state() -> Dictionary:
	return {
		"axis": 0.0,
		"jump_pressed": false,
		"jump_held": false,
		"aim_world": Vector2.ZERO,
		"shoot_held": false,
		"boost_damage": false,
		"boost_damage_multiplier": 1.0,
		"reported_rtt_ms": 0
	}

func _spawn_position_for_peer(peer_id: int) -> Vector2:
	if _ctf_enabled() and ctf_match_controller != null:
		var ctf_spawn := ctf_match_controller.spawn_position_for_peer(peer_id)
		if ctf_spawn != Vector2.ZERO:
			return ctf_spawn
	return spawn_identity.spawn_position_for_peer(peer_id)

func _random_spawn_position() -> Vector2:
	return spawn_identity.random_spawn_position()

func _normalize_character_id(character_id: String) -> String:
	var normalized := character_id.strip_edges().to_lower()
	if normalized == CHARACTER_ID_EREBUS:
		return CHARACTER_ID_EREBUS
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
	if normalized == CHARACTER_ID_NOVA:
		return CHARACTER_ID_NOVA
	if normalized == CHARACTER_ID_HINDI:
		return CHARACTER_ID_HINDI
	if normalized == CHARACTER_ID_LOKER:
		return CHARACTER_ID_LOKER
	if normalized == CHARACTER_ID_GAN:
		return CHARACTER_ID_GAN
	if normalized == CHARACTER_ID_VEILA:
		return CHARACTER_ID_VEILA
	if normalized == CHARACTER_ID_KROG:
		return CHARACTER_ID_KROG
	if normalized == CHARACTER_ID_AEVILOK:
		return CHARACTER_ID_AEVILOK
	if normalized == CHARACTER_ID_FRANKY:
		return CHARACTER_ID_FRANKY
	if normalized == CHARACTER_ID_VARN:
		return CHARACTER_ID_VARN
	return CHARACTER_ID_OUTRAGE

func _lobby_name_value() -> String:
	if lobby_name_input == null:
		return ""
	return lobby_name_input.text.strip_edges()

func _uses_lobby_scene_flow() -> bool:
	return enable_lobby_scene_flow

func _get_world_2d_ref() -> World2D:
	return get_world_2d()

func _play_bounds_rect() -> Rect2i:
	if map_controller != null:
		return map_controller.runtime_play_bounds_rect()
	return Rect2i()

func _ground_tiles_ref() -> TileMapLayer:
	var world := world_root
	if world == null:
		return null
	var primary := world.get_node_or_null("GroundTiles") as TileMapLayer
	if primary != null:
		return primary
	return world.get_node_or_null("GroundTiles2") as TileMapLayer

func _first_private_ipv4() -> String:
	for address in IP.get_local_addresses():
		if not address.contains("."):
			continue
		if address.begins_with("127."):
			continue
		if address.begins_with("169.254."):
			continue
		return address
	return ""
