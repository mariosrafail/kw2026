extends TargetDummyBotController
class_name BotControllerDM

## DM (Deathmatch) bot variant.
##
## ENEMY role (default): identical to the base controller — chase and kill the
##   nearest live opponent in the same lobby.
##
## ALLY role: escort the human player (ally_peer_id).  When the ally moves far
##   away the bot treats the ally's position as a movement goal so it follows
##   them around.  It still attacks any enemy it spots along the way; the only
##   difference from an ENEMY bot is whose side it fights on (set via the
##   is_enemy_target callback in the runtime).
##
## Configuration (config dict passed to configure()):
##   "bot_role"     : BotRole.ALLY or BotRole.ENEMY  (default ENEMY)
##   "ally_peer_id" : peer id of the human to escort  (ALLY role only)
##
## Usage: instantiate this instead of TargetDummyBotController when the game
##   mode is Deathmatch and you want explicit ally/enemy semantics.

const ALLY_ESCORT_MAX_DISTANCE := 180.0   # start following when farther than this
const ALLY_ESCORT_MIN_DISTANCE := 60.0    # stop following when closer than this

## Overrides the base movement_goal so that ALLY bots shadow the human player
## instead of just patrolling.  ENEMY bots fall through to the base (no goal).
func _movement_goal() -> Vector2:
	# Let the callback-based system take priority (used by CTF runtime etc.)
	var cb_goal := super._movement_goal()
	if cb_goal != Vector2.ZERO:
		return cb_goal

	if bot_role != BotRole.ALLY or ally_peer_id <= 0:
		return Vector2.ZERO

	var ally := players.get(ally_peer_id, null) as NetPlayer
	if ally == null or ally.get_health() <= 0:
		return Vector2.ZERO

	var self_bot := players.get(bot_peer_id, null) as NetPlayer
	if self_bot == null:
		return Vector2.ZERO

	var dist := self_bot.global_position.distance_to(ally.global_position)
	if dist > ALLY_ESCORT_MAX_DISTANCE:
		return ally.global_position

	return Vector2.ZERO
