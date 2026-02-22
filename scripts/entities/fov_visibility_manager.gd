extends Node
class_name FOVVisibilityManager

## Manages player visibility based on FOV detection

const INVISIBLE_ALPHA := 0.0
const VISIBLE_ALPHA := 1.0
const FADE_SPEED := 8.0

var local_player: NetPlayer
var all_players: Dictionary = {}
var player_target_alpha: Dictionary = {}

func configure(local: NetPlayer, players_dict: Dictionary) -> void:
	local_player = local as NetPlayer
	all_players = players_dict
	var existing_keys := player_target_alpha.keys()
	for peer_id in existing_keys:
		if local_player != null and peer_id == local_player.peer_id:
			player_target_alpha.erase(peer_id)
			continue
		if not all_players.has(peer_id):
			player_target_alpha.erase(peer_id)

func update(delta: float) -> void:
	if local_player == null or not local_player.has_method("get_visible_players") or local_player.fov_detector == null:
		return
	
	var visible_peer_ids: Array = local_player.get_visible_players(all_players) as Array
	var local_id: int = int(local_player.peer_id)
	
	for peer_id in all_players.keys():
		if peer_id == local_id:
			continue
		
		var player: NetPlayer = all_players.get(peer_id, null) as NetPlayer
		if player == null:
			continue
		
		var is_visible: bool = visible_peer_ids.has(peer_id)
		var target_alpha: float = VISIBLE_ALPHA if is_visible else INVISIBLE_ALPHA
		
		if not player_target_alpha.has(peer_id):
			player_target_alpha[peer_id] = VISIBLE_ALPHA
		
		var current_alpha: float = float(player_target_alpha.get(peer_id, VISIBLE_ALPHA))
		var new_alpha: float = lerpf(current_alpha, target_alpha, minf(1.0, delta * FADE_SPEED))
		player_target_alpha[peer_id] = new_alpha
		
		if player.visual_root != null:
			var current_color: Color = player.visual_root.modulate
			player.visual_root.modulate = Color(current_color.r, current_color.g, current_color.b, new_alpha)


func reset() -> void:
	player_target_alpha.clear()
	for player_value in all_players.values():
		var player: NetPlayer = player_value as NetPlayer
		if player != null and player.visual_root != null:
			player.visual_root.modulate.a = VISIBLE_ALPHA
