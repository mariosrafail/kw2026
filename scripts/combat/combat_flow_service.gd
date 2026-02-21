extends RefCounted
class_name CombatFlowService

const SKILLS_SERVICE_SCRIPT := preload("res://scripts/skills/skills_service.gd")

var players: Dictionary = {}
var input_states: Dictionary = {}
var fire_cooldowns: Dictionary = {}
var ammo_by_peer: Dictionary = {}
var reload_remaining_by_peer: Dictionary = {}
var peer_weapon_ids: Dictionary = {}
var multiplayer: MultiplayerAPI
var projectile_system: ProjectileSystem
var combat_effects: CombatEffects
var camera_shake: CameraShake
var hit_damage_resolver: HitDamageResolver
var player_replication: PlayerReplication

var skills_service: SkillsService
var send_spawn_outrage_bomb_cb: Callable = Callable()
var send_spawn_erebus_immunity_cb: Callable = Callable()
var warrior_id_for_peer_cb: Callable = Callable()

var get_world_2d_cb: Callable = Callable()
var get_peer_lobby_cb: Callable = Callable()
var get_lobby_members_cb: Callable = Callable()
var weapon_profile_for_id_cb: Callable = Callable()
var weapon_profile_for_peer_cb: Callable = Callable()
var weapon_id_for_peer_cb: Callable = Callable()
var weapon_shot_sfx_cb: Callable = Callable()
var weapon_reload_sfx_cb: Callable = Callable()
var send_player_ammo_cb: Callable = Callable()
var send_reload_sfx_cb: Callable = Callable()
var send_spawn_projectile_cb: Callable = Callable()
var send_spawn_blood_particles_cb: Callable = Callable()
var send_spawn_surface_particles_cb: Callable = Callable()
var send_projectile_impact_cb: Callable = Callable()
var send_despawn_projectile_cb: Callable = Callable()
var broadcast_player_state_cb: Callable = Callable()

var max_reported_rtt_ms := 300
var snapshot_rate := 30.0
var weapon_id_ak47 := "ak47"
var max_input_stale_ms := 120

func configure(state_refs: Dictionary, callbacks: Dictionary, config: Dictionary = {}) -> void:
	players = state_refs.get("players", {}) as Dictionary
	input_states = state_refs.get("input_states", {}) as Dictionary
	fire_cooldowns = state_refs.get("fire_cooldowns", {}) as Dictionary
	ammo_by_peer = state_refs.get("ammo_by_peer", {}) as Dictionary
	reload_remaining_by_peer = state_refs.get("reload_remaining_by_peer", {}) as Dictionary
	peer_weapon_ids = state_refs.get("peer_weapon_ids", {}) as Dictionary
	multiplayer = state_refs.get("multiplayer", null) as MultiplayerAPI
	projectile_system = state_refs.get("projectile_system", null) as ProjectileSystem
	combat_effects = state_refs.get("combat_effects", null) as CombatEffects
	camera_shake = state_refs.get("camera_shake", null) as CameraShake
	hit_damage_resolver = state_refs.get("hit_damage_resolver", null) as HitDamageResolver
	player_replication = state_refs.get("player_replication", null) as PlayerReplication

	get_world_2d_cb = callbacks.get("get_world_2d", Callable()) as Callable
	get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable()) as Callable
	get_lobby_members_cb = callbacks.get("get_lobby_members", Callable()) as Callable
	weapon_profile_for_id_cb = callbacks.get("weapon_profile_for_id", Callable()) as Callable
	weapon_profile_for_peer_cb = callbacks.get("weapon_profile_for_peer", Callable()) as Callable
	weapon_id_for_peer_cb = callbacks.get("weapon_id_for_peer", Callable()) as Callable
	weapon_shot_sfx_cb = callbacks.get("weapon_shot_sfx", Callable()) as Callable
	weapon_reload_sfx_cb = callbacks.get("weapon_reload_sfx", Callable()) as Callable
	send_player_ammo_cb = callbacks.get("send_player_ammo", Callable()) as Callable
	send_reload_sfx_cb = callbacks.get("send_reload_sfx", Callable()) as Callable
	send_spawn_projectile_cb = callbacks.get("send_spawn_projectile", Callable()) as Callable
	send_spawn_blood_particles_cb = callbacks.get("send_spawn_blood_particles", Callable()) as Callable
	send_spawn_surface_particles_cb = callbacks.get("send_spawn_surface_particles", Callable()) as Callable
	send_projectile_impact_cb = callbacks.get("send_projectile_impact", Callable()) as Callable
	send_despawn_projectile_cb = callbacks.get("send_despawn_projectile", Callable()) as Callable
	broadcast_player_state_cb = callbacks.get("broadcast_player_state", Callable()) as Callable
	send_spawn_outrage_bomb_cb = callbacks.get("send_spawn_outrage_bomb", Callable()) as Callable
	send_spawn_erebus_immunity_cb = callbacks.get("send_spawn_erebus_immunity", Callable()) as Callable
	warrior_id_for_peer_cb = callbacks.get("warrior_id_for_peer", Callable()) as Callable

	max_reported_rtt_ms = int(config.get("max_reported_rtt_ms", max_reported_rtt_ms))
	snapshot_rate = float(config.get("snapshot_rate", snapshot_rate))
	weapon_id_ak47 = str(config.get("weapon_id_ak47", weapon_id_ak47))
	max_input_stale_ms = int(config.get("max_input_stale_ms", max_input_stale_ms))

	if skills_service == null:
		skills_service = SKILLS_SERVICE_SCRIPT.new() as SkillsService
	if skills_service != null:
		skills_service.configure(
			{
				"players": players,
				"multiplayer": multiplayer,
				"projectile_system": projectile_system,
				"hit_damage_resolver": hit_damage_resolver,
				"camera_shake": camera_shake
			},
			{
				"get_peer_lobby": get_peer_lobby_cb,
				"get_lobby_members": get_lobby_members_cb,
				"warrior_id_for_peer": warrior_id_for_peer_cb,
				"send_spawn_outrage_bomb": send_spawn_outrage_bomb_cb,
				"send_spawn_erebus_immunity": send_spawn_erebus_immunity_cb
			}
		)

func server_cast_skill1(caster_peer_id: int, target_world: Vector2) -> void:
	if skills_service != null:
		skills_service.server_cast_skill(1, caster_peer_id, target_world)

func server_cast_skill2(caster_peer_id: int, target_world: Vector2) -> void:
	if skills_service != null:
		skills_service.server_cast_skill(2, caster_peer_id, target_world)

func client_spawn_outrage_bomb(world_position: Vector2, fuse_sec: float) -> void:
	if skills_service != null:
		skills_service.client_spawn_outrage_bomb(world_position, fuse_sec)

func client_spawn_erebus_immunity(peer_id: int, duration_sec: float) -> void:
	if skills_service != null:
		skills_service.client_spawn_erebus_immunity(peer_id, duration_sec)

func default_input_state() -> Dictionary:
	return {
		"axis": 0.0,
		"jump_pressed": false,
		"jump_held": false,
		"aim_world": Vector2.ZERO,
		"shoot_held": false,
		"boost_damage": false,
		"reported_rtt_ms": 0,
		"last_packet_msec": 0
	}

func server_sync_player_ammo(peer_id: int, target_peer_id: int = 0) -> void:
	var weapon_profile := _weapon_profile_for_peer(peer_id)
	var default_ammo := weapon_profile.magazine_size() if weapon_profile != null else 0
	var ammo := int(ammo_by_peer.get(peer_id, default_ammo))
	var is_reloading := float(reload_remaining_by_peer.get(peer_id, 0.0)) > 0.0
	if target_peer_id > 0:
		_server_send_player_ammo(target_peer_id, peer_id, ammo, is_reloading)
		return
	var lobby_id := _peer_lobby(peer_id)
	if lobby_id <= 0:
		return
	for member_value in _lobby_members(lobby_id):
		_server_send_player_ammo(int(member_value), peer_id, ammo, is_reloading)

func server_broadcast_reload_audio(peer_id: int, weapon_id: String) -> void:
	var lobby_id := _peer_lobby(peer_id)
	if lobby_id <= 0:
		return
	for member_value in _lobby_members(lobby_id):
		if send_reload_sfx_cb.is_valid():
			send_reload_sfx_cb.call(int(member_value), peer_id, weapon_id)

func server_begin_reload(peer_id: int, weapon_profile: WeaponProfile) -> void:
	if weapon_profile == null:
		weapon_profile = _weapon_profile_for_id(weapon_id_ak47)
	var existing := float(reload_remaining_by_peer.get(peer_id, 0.0))
	if existing > 0.0:
		return
	reload_remaining_by_peer[peer_id] = maxf(0.05, weapon_profile.reload_duration())
	var weapon_id := _weapon_id_for_peer(peer_id)
	var player := players.get(peer_id, null) as NetPlayer
	if player != null:
		player.set_reload_audio_stream(_weapon_reload_sfx(weapon_id))
		player.play_reload_audio()
	server_broadcast_reload_audio(peer_id, weapon_id)
	server_sync_player_ammo(peer_id)

func server_fire_projectile(peer_id: int, player: NetPlayer, weapon_profile: WeaponProfile) -> void:
	var lobby_id := _peer_lobby(peer_id)
	if lobby_id <= 0 or projectile_system == null:
		return
	if weapon_profile == null:
		weapon_profile = _weapon_profile_for_id(weapon_id_ak47)
	var state: Dictionary = input_states.get(peer_id, default_input_state()) as Dictionary
	var world_2d := _world_2d()
	var shot_data := projectile_system.fire_from_weapon(
		peer_id,
		player,
		state,
		weapon_profile,
		max_reported_rtt_ms,
		world_2d,
		lobby_id
	)
	if shot_data.is_empty():
		return
	var weapon_id := _weapon_id_for_peer(peer_id)
	var projectile_id := int(shot_data.get("projectile_id", 0))
	var spawn_position := shot_data.get("spawn_position", player.global_position) as Vector2
	# Temporarily disabled server-side offset override.
	# Use weapon-provided spawn data as-is to avoid left/right offset drift.
	var velocity := shot_data.get("velocity", Vector2.ZERO) as Vector2
	var lag_comp_ms := int(shot_data.get("lag_comp_ms", 0))
	var trail_origin := shot_data.get("trail_origin", spawn_position) as Vector2
	player.set_shot_audio_stream(_weapon_shot_sfx(weapon_id))
	player.play_shot_recoil()
	for member_value in _lobby_members(lobby_id):
		if send_spawn_projectile_cb.is_valid():
			send_spawn_projectile_cb.call(
				int(member_value),
				projectile_id,
				peer_id,
				spawn_position,
				velocity,
				lag_comp_ms,
				trail_origin,
				weapon_id
			)

func server_tick_projectiles(delta: float) -> void:
	if skills_service != null:
		skills_service.server_tick(delta)
	if projectile_system == null:
		return
	projectile_system.server_tick(
		delta,
		Callable(self, "_peer_lobby"),
		Callable(self, "_server_projectile_world_hit"),
		Callable(self, "_server_projectile_player_hit"),
		Callable(self, "_on_server_projectile_player_hit"),
		Callable(self, "_on_server_projectile_wall_hit"),
		Callable(self, "_on_server_projectile_impact"),
		Callable(self, "_on_server_projectile_despawn")
	)

func client_tick_projectiles(delta: float) -> void:
	if projectile_system == null:
		return
	projectile_system.client_tick(delta)

func _on_server_projectile_player_hit(
	projectile_id: int,
	target_peer_id: int,
	hit_position: Vector2,
	impact_velocity: Vector2,
	projectile_lobby_id: int
) -> void:
	var target_player := players.get(target_peer_id, null) as NetPlayer
	if target_player != null:
		server_apply_projectile_damage(projectile_id, target_peer_id, target_player)
	if combat_effects != null:
		combat_effects.spawn_blood_particles(hit_position, impact_velocity)
	for member_value in _lobby_members(projectile_lobby_id):
		if send_spawn_blood_particles_cb.is_valid():
			send_spawn_blood_particles_cb.call(int(member_value), hit_position, impact_velocity)

func _on_server_projectile_wall_hit(
	_projectile_id: int,
	wall_position: Vector2,
	wall_impact_velocity: Vector2,
	projectile_lobby_id: int
) -> void:
	if combat_effects == null:
		return
	var impact_color := combat_effects.sample_map_front_color(wall_position)
	if impact_color.a <= 0.01:
		return
	for member_value in _lobby_members(projectile_lobby_id):
		if send_spawn_surface_particles_cb.is_valid():
			send_spawn_surface_particles_cb.call(
				int(member_value),
				wall_position,
				wall_impact_velocity,
				impact_color
			)

func _on_server_projectile_impact(
	projectile_id: int,
	projectile_lobby_id: int,
	impact_position: Vector2,
	_trail_start_position: Vector2
) -> void:
	for member_value in _lobby_members(projectile_lobby_id):
		if send_projectile_impact_cb.is_valid():
			send_projectile_impact_cb.call(int(member_value), projectile_id, impact_position)

func _on_server_projectile_despawn(projectile_id: int, lobby_id: int) -> void:
	var recipients := _lobby_members(lobby_id)
	if recipients.is_empty() and multiplayer != null:
		recipients = multiplayer.get_peers()
	for member_value in recipients:
		if send_despawn_projectile_cb.is_valid():
			send_despawn_projectile_cb.call(int(member_value), projectile_id)

func _server_projectile_world_hit(from_position: Vector2, to_position: Vector2) -> Dictionary:
	if hit_damage_resolver == null:
		return {}
	return hit_damage_resolver.server_projectile_world_hit(from_position, to_position, _world_2d())

func _server_projectile_player_hit(
	projectile: NetProjectile,
	from_position: Vector2,
	to_position: Vector2,
	projectile_lobby_id: int
) -> Dictionary:
	if hit_damage_resolver == null:
		return {}
	return hit_damage_resolver.server_projectile_player_hit(
		projectile,
		from_position,
		to_position,
		projectile_lobby_id
	)

func record_player_history(peer_id: int, position: Vector2) -> void:
	if hit_damage_resolver == null:
		return
	hit_damage_resolver.record_player_history(peer_id, position)

func server_apply_projectile_damage(projectile_id: int, target_peer_id: int, target_player: NetPlayer) -> void:
	if hit_damage_resolver == null:
		return
	var fallback_weapon := _weapon_profile_for_id(weapon_id_ak47)
	var base_damage := fallback_weapon.base_damage() if fallback_weapon != null else 25
	hit_damage_resolver.server_apply_projectile_damage(
		projectile_id,
		target_peer_id,
		target_player,
		base_damage
	)

func server_respawn_player(peer_id: int, player: NetPlayer) -> void:
	if player_replication != null:
		player_replication.server_respawn_player(peer_id, player)
	var weapon_profile := _weapon_profile_for_peer(peer_id)
	var ammo := weapon_profile.magazine_size() if weapon_profile != null else 0
	ammo_by_peer[peer_id] = ammo
	reload_remaining_by_peer[peer_id] = 0.0
	player.set_ammo(ammo, false)
	server_sync_player_ammo(peer_id)

func server_spawn_peer_if_needed(peer_id: int, lobby_id: int) -> void:
	if not peer_weapon_ids.has(peer_id):
		peer_weapon_ids[peer_id] = weapon_id_ak47
	if player_replication != null:
		player_replication.server_spawn_peer_if_needed(peer_id, lobby_id)
	if not ammo_by_peer.has(peer_id):
		var weapon_profile := _weapon_profile_for_peer(peer_id)
		ammo_by_peer[peer_id] = weapon_profile.magazine_size() if weapon_profile != null else 0
	if not reload_remaining_by_peer.has(peer_id):
		reload_remaining_by_peer[peer_id] = 0.0
	server_sync_player_ammo(peer_id)
	if lobby_id > 0:
		for member_value in _lobby_members(lobby_id):
			server_sync_player_ammo(int(member_value), peer_id)

func server_simulate(delta: float, snapshot_accumulator: float) -> float:
	for key in players.keys():
		var peer_id := int(key)
		if _peer_lobby(peer_id) <= 0:
			continue
		var player := players[peer_id] as NetPlayer
		if player == null:
			continue

		var state: Dictionary = input_states.get(peer_id, default_input_state()) as Dictionary
		var now_msec := Time.get_ticks_msec()
		var last_packet_msec := int(state.get("last_packet_msec", 0))
		if last_packet_msec > 0 and now_msec - last_packet_msec > max_input_stale_ms:
			state["axis"] = 0.0
			state["jump_pressed"] = false
			state["jump_held"] = false
			state["shoot_held"] = false
		var aim_world: Vector2 = state.get("aim_world", player.global_position + Vector2.RIGHT * 160.0) as Vector2
		player.set_aim_world(aim_world)
		player.simulate_authoritative(
			delta,
			float(state.get("axis", 0.0)),
			bool(state.get("jump_pressed", false)),
			bool(state.get("jump_held", false))
		)
		record_player_history(peer_id, player.global_position)
		var cooldown: float = float(fire_cooldowns.get(peer_id, 0.0))
		cooldown = maxf(cooldown - delta, 0.0)
		var weapon_profile := _weapon_profile_for_peer(peer_id)
		if weapon_profile == null:
			fire_cooldowns[peer_id] = cooldown
			continue
		var ammo := int(ammo_by_peer.get(peer_id, weapon_profile.magazine_size()))
		var reload_remaining := float(reload_remaining_by_peer.get(peer_id, 0.0))
		if reload_remaining > 0.0:
			reload_remaining = maxf(reload_remaining - delta, 0.0)
			reload_remaining_by_peer[peer_id] = reload_remaining
			if reload_remaining <= 0.0:
				ammo = weapon_profile.magazine_size()
				ammo_by_peer[peer_id] = ammo
				server_sync_player_ammo(peer_id)

		if bool(state.get("shoot_held", false)) and cooldown <= 0.0 and reload_remaining <= 0.0:
			if ammo > 0:
				server_fire_projectile(peer_id, player, weapon_profile)
				ammo -= 1
				ammo_by_peer[peer_id] = ammo
				server_sync_player_ammo(peer_id)
				cooldown = weapon_profile.fire_interval()
				if ammo <= 0:
					server_begin_reload(peer_id, weapon_profile)
			else:
				server_begin_reload(peer_id, weapon_profile)
		fire_cooldowns[peer_id] = cooldown
		state["jump_pressed"] = false
		input_states[peer_id] = state

	snapshot_accumulator += delta
	if snapshot_accumulator >= 1.0 / snapshot_rate:
		snapshot_accumulator = 0.0
		for key in players.keys():
			var peer_id := int(key)
			if _peer_lobby(peer_id) <= 0:
				continue
			var player := players[peer_id] as NetPlayer
			if player == null:
				continue
			if broadcast_player_state_cb.is_valid():
				broadcast_player_state_cb.call(peer_id, player)

	return snapshot_accumulator

func _world_2d() -> World2D:
	if get_world_2d_cb.is_valid():
		return get_world_2d_cb.call() as World2D
	return null

func _peer_lobby(peer_id: int) -> int:
	if get_peer_lobby_cb.is_valid():
		return int(get_peer_lobby_cb.call(peer_id))
	return 0

func _lobby_members(lobby_id: int) -> Array:
	if get_lobby_members_cb.is_valid():
		return get_lobby_members_cb.call(lobby_id) as Array
	return []

func _weapon_profile_for_id(weapon_id: String) -> WeaponProfile:
	if weapon_profile_for_id_cb.is_valid():
		return weapon_profile_for_id_cb.call(weapon_id) as WeaponProfile
	return null

func _weapon_profile_for_peer(peer_id: int) -> WeaponProfile:
	if weapon_profile_for_peer_cb.is_valid():
		return weapon_profile_for_peer_cb.call(peer_id) as WeaponProfile
	return null

func _weapon_id_for_peer(peer_id: int) -> String:
	if weapon_id_for_peer_cb.is_valid():
		return str(weapon_id_for_peer_cb.call(peer_id))
	return weapon_id_ak47

func _weapon_shot_sfx(weapon_id: String) -> AudioStream:
	if weapon_shot_sfx_cb.is_valid():
		return weapon_shot_sfx_cb.call(weapon_id) as AudioStream
	return null

func _weapon_reload_sfx(weapon_id: String) -> AudioStream:
	if weapon_reload_sfx_cb.is_valid():
		return weapon_reload_sfx_cb.call(weapon_id) as AudioStream
	return null

func _server_send_player_ammo(target_peer_id: int, peer_id: int, ammo: int, is_reloading: bool) -> void:
	if send_player_ammo_cb.is_valid():
		send_player_ammo_cb.call(target_peer_id, peer_id, ammo, is_reloading)
