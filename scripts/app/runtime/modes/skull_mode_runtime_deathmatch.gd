extends "res://scripts/app/runtime/modes/skull_mode_runtime_handler_base.gd"

func mode_id() -> String:
	return "deathmatch"

func ruleset_id(host: Node) -> String:
	return str(host.call("_resolve_deathmatch_skull_ruleset"))

func should_show_round_wins_scoreboard(_host: Node) -> bool:
	return false

func handle_special_respawn(host: Node, peer_id: int, player) -> bool:
	var ruleset := str(host.call("_active_skull_ruleset"))
	if ruleset.is_empty():
		return false
	if bool(host.get("_rt_skull_match_locked")):
		return false
	host.call("_assign_random_skull_spawn_slot", peer_id)
	host.call("_server_queue_skull_respawn", peer_id, player, 3.0)
	return true

func handle_kill_event(host: Node, attacker_peer_id: int, _target_peer_id: int) -> void:
	if attacker_peer_id <= 0:
		return
	var ruleset := str(host.call("_active_skull_ruleset"))
	if ruleset != "kill_race":
		return
	var player_stats := host.get("player_stats") as Dictionary
	var stats := player_stats.get(attacker_peer_id, {}) as Dictionary
	var kills := int(stats.get("kills", 0))
	var target := int(host.call("_skull_target_score"))
	if kills >= target:
		host.call("_server_finish_skull_match", str(host.call("_display_name_for_peer", attacker_peer_id)))
