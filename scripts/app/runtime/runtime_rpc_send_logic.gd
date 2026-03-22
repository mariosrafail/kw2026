extends "res://scripts/app/runtime/runtime_state_logic.gd"

func _request_lobby_list() -> void:
	if not _is_client_connected():
		return
	_rpc_request_lobby_list.rpc_id(1)

func _request_spawn_from_server() -> void:
	if role != Role.CLIENT:
		return
	if multiplayer.multiplayer_peer == null:
		return
	if spawn_request_sent:
		return
	spawn_request_sent = true
	_rpc_request_spawn.rpc_id(1)

func _set_role(new_role: int) -> void:
	role = new_role
	if role == Role.SERVER and multiplayer.is_server() and not _uses_lobby_scene_flow():
		call_deferred("_spawn_server_local_if_needed")
	_update_buttons()
	_update_ui_visibility()

func _spawn_server_local_if_needed() -> void:
	if role != Role.SERVER:
		return
	if multiplayer.multiplayer_peer == null:
		return
	if not _should_spawn_local_server_player():
		return
	_server_spawn_peer_if_needed(multiplayer.get_unique_id(), 1)

func _should_spawn_local_server_player() -> bool:
	if OS.has_feature("dedicated_server") or OS.has_feature("server"):
		return false
	return DisplayServer.get_name().to_lower() != "headless"

func _get_role() -> int:
	return role

func _send_spawn_player_rpc(target_peer_id: int, peer_id: int, spawn_position: Vector2, display_name: String) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	var warrior_id = _warrior_id_for_peer(peer_id)
	print("[DBG SPAWN] Sending spawn RPC to peer %d for peer_id %d with warrior_id=%s (from peer_character_ids[%d]=%s)" % [target_peer_id, peer_id, warrior_id, peer_id, peer_character_ids.get(peer_id, "NOT SET")])
	var skin_index: int = 0
	if lobby_service != null:
		skin_index = int(lobby_service.get_peer_skin(peer_id, 0))
	if skin_index <= 0:
		skin_index = int(peer_skin_indices_by_peer.get(peer_id, 0))
	var weapon_skin_index: int = 0
	if lobby_service != null:
		weapon_skin_index = int(lobby_service.get_peer_weapon_skin(peer_id, 0))
	if peer_weapon_skin_indices_by_peer.has(peer_id):
		weapon_skin_index = int(peer_weapon_skin_indices_by_peer.get(peer_id, weapon_skin_index))
	_rpc_spawn_player.rpc_id(
		target_peer_id,
		peer_id,
		spawn_position,
		display_name,
		_weapon_id_for_peer(peer_id),
		warrior_id,
		skin_index,
		weapon_skin_index
	)

func _broadcast_despawn_player_rpc(peer_id: int) -> void:
	_rpc_despawn_player.rpc(peer_id)

func _send_despawn_player_rpc_to_peer(target_peer_id: int, peer_id: int) -> void:
	_rpc_despawn_player.rpc_id(target_peer_id, peer_id)

func _send_sync_player_state_rpc(target_peer_id: int, peer_id: int, new_position: Vector2, new_velocity: Vector2, aim_angle: float, health: int, part_animation_state: Dictionary = {}) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_sync_player_state.rpc_id(target_peer_id, peer_id, new_position, new_velocity, aim_angle, health, part_animation_state)

func _send_sync_player_stats_rpc(target_peer_id: int, peer_id: int, kills: int, deaths: int) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_sync_player_stats.rpc_id(target_peer_id, peer_id, kills, deaths)

func _send_kill_feed_rpc(target_peer_id: int, attacker_name: String, victim_name: String) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		_rpc_kill_feed(attacker_name, victim_name)
		return
	_rpc_kill_feed.rpc_id(target_peer_id, attacker_name, victim_name)

func _send_input_rpc(axis: float, jump_pressed: bool, jump_held: bool, aim_world: Vector2, shoot_held: bool, boost_damage: bool, reported_rtt_ms: int) -> void:
	_rpc_submit_input.rpc_id(1, axis, jump_pressed, jump_held, aim_world, shoot_held, boost_damage, reported_rtt_ms)

func _send_player_ammo_rpc(target_peer_id: int, peer_id: int, ammo: int, is_reloading: bool) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_sync_player_ammo.rpc_id(target_peer_id, peer_id, ammo, is_reloading)

func _send_spawn_dropped_mag_rpc(target_peer_id: int, mag_id: int, texture_path: String, tint: Color, spawn_position: Vector2, linear_velocity: Vector2, angular_velocity: float) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_spawn_dropped_mag.rpc_id(target_peer_id, mag_id, texture_path, tint, spawn_position, linear_velocity, angular_velocity)

func _send_sync_dropped_mag_rpc(target_peer_id: int, mag_id: int, world_position: Vector2, world_rotation: float, linear_velocity: Vector2, angular_velocity: float) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_sync_dropped_mag.rpc_id(target_peer_id, mag_id, world_position, world_rotation, linear_velocity, angular_velocity)

func _send_despawn_dropped_mag_rpc(target_peer_id: int, mag_id: int) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_despawn_dropped_mag.rpc_id(target_peer_id, mag_id)

func _send_reload_sfx_rpc(target_peer_id: int, peer_id: int, weapon_id: String) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_play_reload_sfx.rpc_id(target_peer_id, peer_id, weapon_id)

func _send_spawn_projectile_rpc(target_peer_id: int, projectile_id: int, owner_peer_id: int, spawn_position: Vector2, velocity: Vector2, lag_comp_ms: int, trail_origin: Vector2, weapon_id: String) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_spawn_projectile.rpc_id(target_peer_id, projectile_id, owner_peer_id, spawn_position, velocity, lag_comp_ms, trail_origin, weapon_id)

func _send_spawn_blood_particles_rpc(target_peer_id: int, impact_position: Vector2, incoming_velocity: Vector2, blood_color: Color = Color(0.98, 0.02, 0.07, 1.0), count_multiplier: float = 1.0) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_spawn_blood_particles.rpc_id(target_peer_id, impact_position, incoming_velocity, blood_color, count_multiplier)

func _send_spawn_surface_particles_rpc(target_peer_id: int, impact_position: Vector2, incoming_velocity: Vector2, particle_color: Color) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_spawn_surface_particles.rpc_id(target_peer_id, impact_position, incoming_velocity, particle_color)

func _send_projectile_impact_rpc(target_peer_id: int, projectile_id: int, impact_position: Vector2) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_projectile_impact.rpc_id(target_peer_id, projectile_id, impact_position)

func _send_despawn_projectile_rpc(target_peer_id: int, projectile_id: int) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_despawn_projectile.rpc_id(target_peer_id, projectile_id)

func _play_death_sfx_local(impact_position: Vector2) -> void:
	combat_effects.play_death_sfx(impact_position)

func _send_play_death_sfx_rpc(target_peer_id: int, impact_position: Vector2) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		return
	_rpc_play_death_sfx.rpc_id(target_peer_id, impact_position)

func _send_spawn_outrage_bomb_rpc(target_peer_id: int, caster_peer_id: int, world_position: Vector2, fuse_sec: float) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		_rpc_spawn_outrage_bomb(caster_peer_id, world_position, fuse_sec)
		return
	_rpc_spawn_outrage_bomb.rpc_id(target_peer_id, caster_peer_id, world_position, fuse_sec)

func _send_spawn_erebus_immunity_rpc(target_peer_id: int, caster_peer_id: int, duration_sec: float) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		_rpc_spawn_erebus_immunity(caster_peer_id, duration_sec)
		return
	_rpc_spawn_erebus_immunity.rpc_id(target_peer_id, caster_peer_id, duration_sec)

func _send_spawn_erebus_shield_rpc(target_peer_id: int, caster_peer_id: int, duration_sec: float) -> void:
	if multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id():
		_rpc_spawn_erebus_shield(caster_peer_id, duration_sec)
		return
	_rpc_spawn_erebus_shield.rpc_id(target_peer_id, caster_peer_id, duration_sec)

func _send_skill_cast_rpc(target_peer_id: int, skill_number: int, caster_peer_id: int, target_world: Vector2) -> void:
	var target_is_local_server := multiplayer != null and multiplayer.is_server() and target_peer_id == multiplayer.get_unique_id()
	var warrior_id = _warrior_id_for_peer(caster_peer_id)
	match warrior_id:
		"outrage":
			if skill_number == 1:
				if target_is_local_server:
					_rpc_spawn_outrage_bomb(caster_peer_id, target_world, 0.9)
				else:
					_rpc_spawn_outrage_bomb.rpc_id(target_peer_id, caster_peer_id, target_world, 0.9)
			elif skill_number == 2:
				if target_is_local_server:
					_rpc_spawn_outrage_boost(caster_peer_id, 4.0)
				else:
					_rpc_spawn_outrage_boost.rpc_id(target_peer_id, caster_peer_id, 4.0)
		"erebus":
			if skill_number == 1:
				if target_is_local_server:
					_rpc_spawn_erebus_immunity(caster_peer_id, 5.0)
				else:
					_rpc_spawn_erebus_immunity.rpc_id(target_peer_id, caster_peer_id, 5.0)
			elif skill_number == 2:
				if target_is_local_server:
					_rpc_spawn_erebus_shield(caster_peer_id, 6.0)
				else:
					_rpc_spawn_erebus_shield.rpc_id(target_peer_id, caster_peer_id, 6.0)
		"tasko":
			if skill_number == 1:
				if target_is_local_server:
					_rpc_spawn_tasko_invis_field(caster_peer_id, target_world)
				else:
					_rpc_spawn_tasko_invis_field.rpc_id(target_peer_id, caster_peer_id, target_world)
			elif skill_number == 2:
				if target_is_local_server:
					_rpc_spawn_tasko_mine(caster_peer_id, target_world)
				else:
					_rpc_spawn_tasko_mine.rpc_id(target_peer_id, caster_peer_id, target_world)
