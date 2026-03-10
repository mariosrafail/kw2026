extends RefCounted
class_name SkillsService

const WARRIOR_OUTRAGE := "outrage"
const WARRIOR_EREBUS := "erebus"
const WARRIOR_TASKO := "tasko"

const OUTRAGE_SKILL_Q_SCRIPT := preload("res://scripts/warriors/skills/outrage_skill_Q.gd")
const OUTRAGE_SKILL_E_SCRIPT := preload("res://scripts/warriors/skills/outrage_skill_E.gd")
const EREBUS_SKILL_Q_SCRIPT := preload("res://scripts/warriors/skills/erebus_skill_Q.gd")
const EREBUS_SKILL_E_SCRIPT := preload("res://scripts/warriors/skills/erebus_skill_E.gd")
const TASKO_SKILL_Q_SCRIPT := preload("res://scripts/warriors/skills/tasko_skill_Q.gd")
const TASKO_SKILL_E_SCRIPT := preload("res://scripts/warriors/skills/tasko_skill_E.gd")

var players: Dictionary = {}
var multiplayer: MultiplayerAPI
var projectile_system: ProjectileSystem
var hit_damage_resolver: HitDamageResolver
var camera_shake: CameraShake

var get_peer_lobby_cb: Callable = Callable()
var get_lobby_members_cb: Callable = Callable()
var warrior_id_for_peer_cb: Callable = Callable()
var send_skill_cast_cb: Callable = Callable()

var _outrage_skill_q
var _outrage_skill_e
var _erebus_skill_q
var _erebus_skill_e
var _tasko_skill_q
var _tasko_skill_e

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	players = state_refs.get("players", {}) as Dictionary
	multiplayer = state_refs.get("multiplayer", null) as MultiplayerAPI
	projectile_system = state_refs.get("projectile_system", null) as ProjectileSystem
	hit_damage_resolver = state_refs.get("hit_damage_resolver", null) as HitDamageResolver
	camera_shake = state_refs.get("camera_shake", null) as CameraShake

	get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable()) as Callable
	get_lobby_members_cb = callbacks.get("get_lobby_members", Callable()) as Callable
	warrior_id_for_peer_cb = callbacks.get("warrior_id_for_peer", Callable()) as Callable
	send_skill_cast_cb = callbacks.get("send_skill_cast", Callable()) as Callable

	if _outrage_skill_q == null:
		_outrage_skill_q = OUTRAGE_SKILL_Q_SCRIPT.new()
	if _outrage_skill_e == null:
		_outrage_skill_e = OUTRAGE_SKILL_E_SCRIPT.new()
	if _erebus_skill_q == null:
		_erebus_skill_q = EREBUS_SKILL_Q_SCRIPT.new()
	if _erebus_skill_e == null:
		_erebus_skill_e = EREBUS_SKILL_E_SCRIPT.new()
	if _tasko_skill_q == null:
		_tasko_skill_q = TASKO_SKILL_Q_SCRIPT.new()
	if _tasko_skill_e == null:
		_tasko_skill_e = TASKO_SKILL_E_SCRIPT.new()

	if _outrage_skill_q != null and _outrage_skill_q.has_method("configure"):
		_outrage_skill_q.call(
			"configure",
			{
				"players": players,
				"input_states": state_refs.get("input_states", {}) as Dictionary,
				"multiplayer": multiplayer,
				"projectile_system": projectile_system,
				"hit_damage_resolver": hit_damage_resolver,
				"camera_shake": camera_shake
			},
			{
				"get_peer_lobby": get_peer_lobby_cb,
				"get_lobby_members": get_lobby_members_cb,
				"character_id_for_peer": Callable(self, "_warrior_id_for_peer"),
				"send_skill_cast": send_skill_cast_cb
			}
		)

	if _outrage_skill_e != null and _outrage_skill_e.has_method("configure"):
		_outrage_skill_e.call(
			"configure",
			{
				"players": players,
				"input_states": state_refs.get("input_states", {}) as Dictionary,
				"multiplayer": multiplayer,
				"projectile_system": projectile_system
			},
			{
				"get_peer_lobby": get_peer_lobby_cb,
				"get_lobby_members": get_lobby_members_cb,
				"send_skill_cast": send_skill_cast_cb
			}
		)

	if _erebus_skill_q != null and _erebus_skill_q.has_method("configure"):
		_erebus_skill_q.call(
			"configure",
			{
				"players": players,
				"input_states": state_refs.get("input_states", {}) as Dictionary,
				"multiplayer": multiplayer
			},
			{
				"get_peer_lobby": get_peer_lobby_cb,
				"get_lobby_members": get_lobby_members_cb,
				"character_id_for_peer": Callable(self, "_warrior_id_for_peer"),
				"send_skill_cast": send_skill_cast_cb
			}
		)

	if _erebus_skill_e != null and _erebus_skill_e.has_method("configure"):
		_erebus_skill_e.call(
			"configure",
			{
				"players": players,
				"input_states": state_refs.get("input_states", {}) as Dictionary,
				"multiplayer": multiplayer
			},
			{
				"get_peer_lobby": get_peer_lobby_cb,
				"get_lobby_members": get_lobby_members_cb,
				"character_id_for_peer": Callable(self, "_warrior_id_for_peer"),
				"send_skill_cast": send_skill_cast_cb
			}
		)

	if _tasko_skill_q != null and _tasko_skill_q.has_method("configure"):
		_tasko_skill_q.call(
			"configure",
			{
				"players": players,
				"input_states": state_refs.get("input_states", {}) as Dictionary,
				"multiplayer": multiplayer,
				"projectile_system": projectile_system
			},
			{
				"get_peer_lobby": get_peer_lobby_cb,
				"get_lobby_members": get_lobby_members_cb,
				"character_id_for_peer": Callable(self, "_warrior_id_for_peer"),
				"send_skill_cast": send_skill_cast_cb
			}
		)

	if _tasko_skill_e != null and _tasko_skill_e.has_method("configure"):
		_tasko_skill_e.call(
			"configure",
			{
				"players": players,
				"input_states": state_refs.get("input_states", {}) as Dictionary,
				"multiplayer": multiplayer,
				"projectile_system": projectile_system,
				"hit_damage_resolver": hit_damage_resolver
			},
			{
				"get_peer_lobby": get_peer_lobby_cb,
				"get_lobby_members": get_lobby_members_cb,
				"character_id_for_peer": Callable(self, "_warrior_id_for_peer"),
				"send_skill_cast": send_skill_cast_cb
			}
		)

func server_tick(delta: float) -> void:
	if _outrage_skill_q != null and _outrage_skill_q.has_method("server_tick"):
		_outrage_skill_q.call("server_tick", delta)
	if _outrage_skill_e != null and _outrage_skill_e.has_method("server_tick"):
		_outrage_skill_e.call("server_tick", delta)
	if _erebus_skill_q != null and _erebus_skill_q.has_method("server_tick"):
		_erebus_skill_q.call("server_tick", delta)
	if _erebus_skill_e != null and _erebus_skill_e.has_method("server_tick"):
		_erebus_skill_e.call("server_tick", delta)
	if _tasko_skill_q != null and _tasko_skill_q.has_method("server_tick"):
		_tasko_skill_q.call("server_tick", delta)
	if _tasko_skill_e != null and _tasko_skill_e.has_method("server_tick"):
		_tasko_skill_e.call("server_tick", delta)

func server_cast_skill(slot: int, caster_peer_id: int, target_world: Vector2) -> void:
	var warrior_id := _warrior_id_for_peer(caster_peer_id)
	if warrior_id == WARRIOR_OUTRAGE:
		if slot == 1:
			if _outrage_skill_q != null and _outrage_skill_q.has_method("server_cast"):
				_outrage_skill_q.call("server_cast", caster_peer_id, target_world)
		elif slot == 2:
			if _outrage_skill_e != null and _outrage_skill_e.has_method("server_cast"):
				_outrage_skill_e.call("server_cast", caster_peer_id, target_world)
		return

	if warrior_id == WARRIOR_EREBUS:
		if slot == 1:
			if _erebus_skill_q != null and _erebus_skill_q.has_method("server_cast"):
				_erebus_skill_q.call("server_cast", caster_peer_id, target_world)
		elif slot == 2:
			if _erebus_skill_e != null and _erebus_skill_e.has_method("server_cast"):
				_erebus_skill_e.call("server_cast", caster_peer_id, target_world)
		return

	if warrior_id == WARRIOR_TASKO:
		if slot == 1:
			if _tasko_skill_q != null and _tasko_skill_q.has_method("server_cast"):
				_tasko_skill_q.call("server_cast", caster_peer_id, target_world)
		elif slot == 2:
			if _tasko_skill_e != null and _tasko_skill_e.has_method("server_cast"):
				_tasko_skill_e.call("server_cast", caster_peer_id, target_world)
		return

func client_receive_skill_cast(slot: int, warrior_id: String, caster_peer_id: int, target_world: Vector2) -> void:
	if warrior_id == WARRIOR_OUTRAGE:
		if slot == 1 and _outrage_skill_q != null and _outrage_skill_q.has_method("client_receive_cast"):
			_outrage_skill_q.call("client_receive_cast", caster_peer_id, target_world)
		elif slot == 2 and _outrage_skill_e != null and _outrage_skill_e.has_method("client_receive_cast"):
			_outrage_skill_e.call("client_receive_cast", caster_peer_id, target_world)
		return

	if warrior_id == WARRIOR_EREBUS:
		if slot == 1 and _erebus_skill_q != null and _erebus_skill_q.has_method("client_receive_cast"):
			_erebus_skill_q.call("client_receive_cast", caster_peer_id, target_world)
		elif slot == 2 and _erebus_skill_e != null and _erebus_skill_e.has_method("client_receive_cast"):
			_erebus_skill_e.call("client_receive_cast", caster_peer_id, target_world)
		return

	if warrior_id == WARRIOR_TASKO:
		if slot == 1 and _tasko_skill_q != null and _tasko_skill_q.has_method("client_receive_cast"):
			_tasko_skill_q.call("client_receive_cast", caster_peer_id, target_world)
		elif slot == 2 and _tasko_skill_e != null and _tasko_skill_e.has_method("client_receive_cast"):
			_tasko_skill_e.call("client_receive_cast", caster_peer_id, target_world)

func _warrior_id_for_peer(peer_id: int) -> String:
	if warrior_id_for_peer_cb.is_valid():
		return str(warrior_id_for_peer_cb.call(peer_id))
	return WARRIOR_OUTRAGE
