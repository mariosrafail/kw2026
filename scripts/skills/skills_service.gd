extends RefCounted
class_name SkillsService

const WARRIOR_OUTRAGE := "outrage"
const WARRIOR_EREBUS := "erebus"

const OUTRAGE_BOMB_SKILL_SCRIPT := preload("res://scripts/skills/outrage_bomb_skill.gd")
const EREBUS_IMMUNITY_SKILL_SCRIPT := preload("res://scripts/skills/erebus_immunity_skill.gd")

var players: Dictionary = {}
var multiplayer: MultiplayerAPI
var projectile_system: ProjectileSystem
var hit_damage_resolver: HitDamageResolver
var camera_shake: CameraShake

var get_peer_lobby_cb: Callable = Callable()
var get_lobby_members_cb: Callable = Callable()
var warrior_id_for_peer_cb: Callable = Callable()
var send_spawn_outrage_bomb_cb: Callable = Callable()
var send_spawn_erebus_immunity_cb: Callable = Callable()

var _outrage_bomb_skill
var _erebus_immunity_skill

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	players = state_refs.get("players", {}) as Dictionary
	multiplayer = state_refs.get("multiplayer", null) as MultiplayerAPI
	projectile_system = state_refs.get("projectile_system", null) as ProjectileSystem
	hit_damage_resolver = state_refs.get("hit_damage_resolver", null) as HitDamageResolver
	camera_shake = state_refs.get("camera_shake", null) as CameraShake

	get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable()) as Callable
	get_lobby_members_cb = callbacks.get("get_lobby_members", Callable()) as Callable
	warrior_id_for_peer_cb = callbacks.get("warrior_id_for_peer", Callable()) as Callable
	send_spawn_outrage_bomb_cb = callbacks.get("send_spawn_outrage_bomb", Callable()) as Callable
	send_spawn_erebus_immunity_cb = callbacks.get("send_spawn_erebus_immunity", Callable()) as Callable

	if _outrage_bomb_skill == null:
		_outrage_bomb_skill = OUTRAGE_BOMB_SKILL_SCRIPT.new()
	if _erebus_immunity_skill == null:
		_erebus_immunity_skill = EREBUS_IMMUNITY_SKILL_SCRIPT.new()

	if _outrage_bomb_skill != null and _outrage_bomb_skill.has_method("configure"):
		_outrage_bomb_skill.call(
			"configure",
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
				"character_id_for_peer": Callable(self, "_warrior_id_for_peer"),
				"send_spawn_outrage_bomb": send_spawn_outrage_bomb_cb
			}
		)

	if _erebus_immunity_skill != null and _erebus_immunity_skill.has_method("configure"):
		_erebus_immunity_skill.call(
			"configure",
			{
				"players": players,
				"multiplayer": multiplayer
			},
			{
				"get_peer_lobby": get_peer_lobby_cb,
				"get_lobby_members": get_lobby_members_cb,
				"character_id_for_peer": Callable(self, "_warrior_id_for_peer"),
				"send_spawn_erebus_immunity": send_spawn_erebus_immunity_cb
			}
		)

func server_tick(delta: float) -> void:
	if _outrage_bomb_skill != null and _outrage_bomb_skill.has_method("server_tick"):
		_outrage_bomb_skill.call("server_tick", delta)

func server_cast_skill(slot: int, caster_peer_id: int, target_world: Vector2) -> void:
	var warrior_id := _warrior_id_for_peer(caster_peer_id)
	if warrior_id == WARRIOR_OUTRAGE:
		if slot == 1:
			if _outrage_bomb_skill != null and _outrage_bomb_skill.has_method("server_cast_skill1"):
				_outrage_bomb_skill.call("server_cast_skill1", caster_peer_id, target_world)
		return

	if warrior_id == WARRIOR_EREBUS:
		if slot == 1:
			if _erebus_immunity_skill != null and _erebus_immunity_skill.has_method("server_cast_skill1"):
				_erebus_immunity_skill.call("server_cast_skill1", caster_peer_id)
		return

func client_spawn_outrage_bomb(world_position: Vector2, fuse_sec: float) -> void:
	if _outrage_bomb_skill != null and _outrage_bomb_skill.has_method("client_spawn_bomb"):
		_outrage_bomb_skill.call("client_spawn_bomb", world_position, fuse_sec)

func client_spawn_erebus_immunity(peer_id: int, duration_sec: float) -> void:
	if _erebus_immunity_skill != null and _erebus_immunity_skill.has_method("client_spawn_immunity"):
		_erebus_immunity_skill.call("client_spawn_immunity", peer_id, duration_sec)

func _warrior_id_for_peer(peer_id: int) -> String:
	if warrior_id_for_peer_cb.is_valid():
		return str(warrior_id_for_peer_cb.call(peer_id))
	return WARRIOR_OUTRAGE
