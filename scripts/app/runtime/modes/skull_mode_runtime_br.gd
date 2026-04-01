extends "res://scripts/app/runtime/modes/skull_mode_runtime_handler_base.gd"

func mode_id() -> String:
	return "battle_royale"

func ruleset_id(_host: Node) -> String:
	return "round_survival"

func should_show_round_wins_scoreboard(_host: Node) -> bool:
	return true

func handle_special_respawn(host: Node, peer_id: int, player) -> bool:
	if bool(host.get("_rt_skull_match_locked")):
		return false
	host.call("_server_handle_skull_round_elimination", peer_id, player)
	return true
