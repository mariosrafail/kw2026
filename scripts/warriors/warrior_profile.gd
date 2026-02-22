## Base class for all characters/warriors
##
## Each warrior (Outrage, Erebus) has:
## - skill1 (Q key) - Ability 1
## - skill2 (E key) - Ability 2
## - identity (name, ID, visuals)
## - stats/constants

extends RefCounted
class_name WarriorProfile

var warrior_id: String = ""
var warrior_name: String = ""

var skill1: Skill  # Q key ability
var skill2: Skill  # E key ability

# Shared game systems
var players: Dictionary = {}
var multiplayer: MultiplayerAPI
var projectile_system: ProjectileSystem
var hit_damage_resolver: HitDamageResolver
var camera_shake: CameraShake

# Callbacks
var get_peer_lobby_cb: Callable = Callable()
var get_lobby_members_cb: Callable = Callable()
var send_skill_cast_cb: Callable = Callable()

func _init(id: String, name: String) -> void:
	warrior_id = id
	warrior_name = name

## Configure warrior and its skills
func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	players = state_refs.get("players", {})
	multiplayer = state_refs.get("multiplayer", null)
	projectile_system = state_refs.get("projectile_system", null)
	hit_damage_resolver = state_refs.get("hit_damage_resolver", null)
	camera_shake = state_refs.get("camera_shake", null)
	
	get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable())
	get_lobby_members_cb = callbacks.get("get_lobby_members", Callable())
	send_skill_cast_cb = callbacks.get("send_skill_cast", Callable())
	
	_init_skills()
	
	if skill1 != null:
		skill1.configure(state_refs, callbacks)
	if skill2 != null:
		skill2.configure(state_refs, callbacks)

## Subclasses create their skill instances here
func _init_skills() -> void:
	push_error("Warrior %s must implement _init_skills()" % warrior_id)

## Server-side skill cast
func server_cast_skill(skill_number: int, caster_peer_id: int, target_world: Vector2) -> void:
	if not multiplayer.is_server():
		return
	
	var skill: Skill = null
	if skill_number == 1:
		skill = skill1
	elif skill_number == 2:
		skill = skill2
	else:
		return
	
	if skill == null:
		push_error("Warrior %s has no skill%d" % [warrior_id, skill_number])
		return
	
	skill.server_cast(caster_peer_id, target_world)

## Client receives skill effect
func client_receive_skill_cast(skill_number: int, caster_peer_id: int, target_world: Vector2) -> void:
	var skill: Skill = null
	if skill_number == 1:
		skill = skill1
	elif skill_number == 2:
		skill = skill2
	else:
		return
	
	if skill == null:
		return
	
	skill.client_receive_cast(caster_peer_id, target_world)

## Server tick all skill cooldowns
func server_tick_cooldowns(delta: float) -> void:
	if skill1 != null:
		skill1.server_tick_cooldowns(delta)
	if skill2 != null:
		skill2.server_tick_cooldowns(delta)

## Check if player can cast skill
func can_cast_skill(skill_number: int, caster_peer_id: int) -> bool:
	var skill: Skill = null
	if skill_number == 1:
		skill = skill1
	elif skill_number == 2:
		skill = skill2
	else:
		return false
	
	if skill == null:
		return false
	
	return skill.can_cast(caster_peer_id)

## Get remaining cooldown time (for UI)
func get_skill_cooldown_remaining(skill_number: int, caster_peer_id: int) -> float:
	var skill: Skill = null
	if skill_number == 1:
		skill = skill1
	elif skill_number == 2:
		skill = skill2
	else:
		return 0.0
	
	if skill == null:
		return 0.0
	
	return skill.skill_cooldown_remaining.get(caster_peer_id, 0.0)

## Get skill cooldown max (for UI progress bar)
func get_skill_cooldown_max(skill_number: int) -> float:
	var skill: Skill = null
	if skill_number == 1:
		skill = skill1
	elif skill_number == 2:
		skill = skill2
	else:
		return 0.0
	
	if skill == null:
		return 0.0
	
	return skill.cooldown_sec
