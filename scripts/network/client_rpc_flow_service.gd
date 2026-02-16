extends RefCounted
class_name ClientRpcFlowService

var players: Dictionary = {}
var multiplayer: MultiplayerAPI
var projectile_system: ProjectileSystem
var combat_effects: CombatEffects
var camera_shake: CameraShake
var ammo_by_peer: Dictionary = {}
var reload_remaining_by_peer: Dictionary = {}

var weapon_profile_for_id_cb: Callable = Callable()
var weapon_shot_sfx_cb: Callable = Callable()
var weapon_reload_sfx_cb: Callable = Callable()

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	players = state_refs.get("players", {}) as Dictionary
	multiplayer = state_refs.get("multiplayer", null) as MultiplayerAPI
	projectile_system = state_refs.get("projectile_system", null) as ProjectileSystem
	combat_effects = state_refs.get("combat_effects", null) as CombatEffects
	camera_shake = state_refs.get("camera_shake", null) as CameraShake
	ammo_by_peer = state_refs.get("ammo_by_peer", {}) as Dictionary
	reload_remaining_by_peer = state_refs.get("reload_remaining_by_peer", {}) as Dictionary

	weapon_profile_for_id_cb = callbacks.get("weapon_profile_for_id", Callable()) as Callable
	weapon_shot_sfx_cb = callbacks.get("weapon_shot_sfx", Callable()) as Callable
	weapon_reload_sfx_cb = callbacks.get("weapon_reload_sfx", Callable()) as Callable

func rpc_play_death_sfx(impact_position: Vector2) -> void:
	if combat_effects == null:
		return
	combat_effects.play_death_sfx(impact_position)

func rpc_play_reload_sfx(peer_id: int, weapon_id: String) -> void:
	var player := players.get(peer_id, null) as NetPlayer
	if player == null:
		return
	player.set_reload_audio_stream(_weapon_reload_sfx(weapon_id))
	player.play_reload_audio()

func rpc_sync_player_ammo(peer_id: int, ammo: int, is_reloading: bool) -> void:
	ammo_by_peer[peer_id] = maxi(0, ammo)
	reload_remaining_by_peer[peer_id] = 1.0 if is_reloading else 0.0
	var player := players.get(peer_id, null) as NetPlayer
	if player != null:
		player.set_ammo(maxi(0, ammo), is_reloading)

func rpc_spawn_projectile(
	projectile_id: int,
	owner_peer_id: int,
	spawn_position: Vector2,
	velocity: Vector2,
	lag_comp_ms: int,
	trail_origin: Vector2,
	weapon_id: String,
	last_ping_ms: int
) -> void:
	if projectile_system == null:
		return
	var projectile_weapon := _weapon_profile_for_id(weapon_id)
	var projectile := projectile_system.spawn_projectile(
		projectile_id,
		owner_peer_id,
		spawn_position,
		velocity,
		lag_comp_ms,
		trail_origin,
		projectile_weapon
	)
	if projectile == null:
		return
	var owner_player := players.get(owner_peer_id, null) as NetPlayer
	if owner_player != null:
		owner_player.set_shot_audio_stream(_weapon_shot_sfx(weapon_id))
		owner_player.set_reload_audio_stream(_weapon_reload_sfx(weapon_id))
		owner_player.play_shot_recoil()

	var local_peer_id := multiplayer.get_unique_id() if multiplayer != null else 0
	var local_visual_advance_ms := projectile_weapon.visual_advance_ms(
		last_ping_ms,
		lag_comp_ms,
		owner_peer_id == local_peer_id
	)
	if owner_peer_id == local_peer_id and camera_shake != null:
		camera_shake.add_shake(projectile_weapon.camera_shake_per_shot())
	if local_visual_advance_ms > 0:
		projectile.step(float(local_visual_advance_ms) / 1000.0)

func rpc_despawn_projectile(projectile_id: int) -> void:
	if projectile_system == null:
		return
	projectile_system.despawn_local(projectile_id)

func rpc_projectile_impact(projectile_id: int, impact_position: Vector2) -> void:
	if projectile_system == null or combat_effects == null:
		return
	var impact_data := projectile_system.mark_impact(projectile_id, impact_position)
	if impact_data.is_empty():
		return
	combat_effects.play_bullet_touch_sfx(impact_position)

func rpc_spawn_blood_particles(impact_position: Vector2, incoming_velocity: Vector2) -> void:
	if combat_effects == null:
		return
	combat_effects.spawn_blood_particles(impact_position, incoming_velocity)

func rpc_spawn_surface_particles(impact_position: Vector2, incoming_velocity: Vector2, particle_color: Color) -> void:
	if combat_effects == null:
		return
	combat_effects.spawn_surface_particles(impact_position, incoming_velocity, particle_color)

func _weapon_profile_for_id(weapon_id: String) -> WeaponProfile:
	if weapon_profile_for_id_cb.is_valid():
		return weapon_profile_for_id_cb.call(weapon_id) as WeaponProfile
	return null

func _weapon_shot_sfx(weapon_id: String) -> AudioStream:
	if weapon_shot_sfx_cb.is_valid():
		return weapon_shot_sfx_cb.call(weapon_id) as AudioStream
	return null

func _weapon_reload_sfx(weapon_id: String) -> AudioStream:
	if weapon_reload_sfx_cb.is_valid():
		return weapon_reload_sfx_cb.call(weapon_id) as AudioStream
	return null
