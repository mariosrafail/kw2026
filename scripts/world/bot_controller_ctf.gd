extends TargetDummyBotController
class_name BotControllerCTF

## CTF bot variant.
##
## Extends the base controller with built-in flag awareness so that bots make
## smarter decisions without needing all the logic injected through callbacks.
##
## ENEMY role: aggressively hunts the enemy flag carrier first; otherwise
##   targets the nearest enemy (including the human player).
##
## ALLY role: prioritises intercepting the enemy flag carrier to protect the
##   allied flag.  When the allied flag is dropped, the bot goes to pick it up
##   (movement goal).  When the bot itself is carrying the flag it moves toward
##   the capture goal.
##
## The runtime (runtime_ctf_logic.gd) should call update_ctf_state() every
## server tick so that the bot has current flag information.
##
## Configuration (config dict passed to configure()):
##   "bot_role"     : BotRole.ALLY or BotRole.ENEMY
##   "ally_peer_id" : peer id of the human teammate (ALLY role)
##   "own_team_id"  : team id this bot belongs to (0=red, 1=blue)

var own_team_id: int = 0

# Updated each server tick by the runtime via update_ctf_state().
var _flag_carrier_peer_id: int = 0     # 0 = no carrier (flag is at home or dropped)
var _flag_world_position: Vector2 = Vector2.ZERO
var _flag_is_home: bool = true
var _capture_goal: Vector2 = Vector2.ZERO   # where this bot should deliver the flag

func configure(state_refs: Dictionary, callbacks: Dictionary, config: Dictionary = {}) -> void:
	super.configure(state_refs, callbacks, config)
	own_team_id = int(config.get("own_team_id", 0))

## Called by the runtime every tick to provide current flag/capture state.
func update_ctf_state(
		flag_carrier: int,
		flag_position: Vector2,
		flag_home: bool,
		capture_goal: Vector2
) -> void:
	_flag_carrier_peer_id = flag_carrier
	_flag_world_position = flag_position
	_flag_is_home = flag_home
	_capture_goal = capture_goal

## Returns the peer id that is currently carrying the ENEMY flag (if any).
func _enemy_flag_carrier() -> int:
	if _flag_carrier_peer_id <= 0:
		return 0
	# If the carrier is an enemy of this bot, they are carrying our flag.
	if _is_enemy_target_cb.is_valid() and bool(_is_enemy_target_cb.call(bot_peer_id, _flag_carrier_peer_id)):
		return _flag_carrier_peer_id
	return 0

## Overrides targeting to prioritise the enemy flag carrier.
func _nearest_target(bot: NetPlayer) -> NetPlayer:
	# Flag carrier is always the top priority regardless of preferred_target_peer_id.
	var carrier_id := _enemy_flag_carrier()
	if carrier_id > 0:
		var carrier := players.get(carrier_id, null) as NetPlayer
		if carrier != null and carrier.get_health() > 0:
			return carrier

	# Fall back to base logic (preferred_target_peer_id, then nearest enemy).
	return super._nearest_target(bot)

## Overrides movement goal for flag-aware objectives.
func _movement_goal() -> Vector2:
	# Let the runtime callback take priority when set.
	var cb_goal := super._movement_goal()
	if cb_goal != Vector2.ZERO:
		return cb_goal

	var self_bot := players.get(bot_peer_id, null) as NetPlayer
	if self_bot == null:
		return Vector2.ZERO

	# Carrying the flag → go to capture goal.
	if _capture_goal != Vector2.ZERO and _flag_carrier_peer_id == bot_peer_id:
		return _capture_goal

	if bot_role == BotRole.ALLY:
		# Allied flag dropped → go pick it up (enemy team dropped our flag).
		# Here "our" flag means the flag the enemy was carrying which is now loose.
		if not _flag_is_home and _flag_carrier_peer_id == 0 and _flag_world_position != Vector2.ZERO:
			var dist := self_bot.global_position.distance_to(_flag_world_position)
			if dist > 40.0:
				return _flag_world_position

	return Vector2.ZERO
