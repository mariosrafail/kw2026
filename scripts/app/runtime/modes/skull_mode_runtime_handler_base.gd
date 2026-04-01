extends RefCounted

func mode_id() -> String:
	return "base"

func ruleset_id(host: Node) -> String:
	return ""

func should_show_round_wins_scoreboard(host: Node) -> bool:
	return false

func handle_special_respawn(host: Node, peer_id: int, player) -> bool:
	return false

func handle_kill_event(host: Node, attacker_peer_id: int, _target_peer_id: int) -> void:
	pass
