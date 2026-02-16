extends RefCounted
class_name SpawnIdentity

var spawn_points: Array = []
var spawn_slots: Dictionary = {}
var players: Dictionary = {}
var player_display_names: Dictionary = {}
var get_peer_lobby_cb: Callable = Callable()

func configure(state_refs: Dictionary, callbacks: Dictionary, config: Dictionary = {}) -> void:
	spawn_slots = state_refs.get("spawn_slots", {}) as Dictionary
	players = state_refs.get("players", {}) as Dictionary
	player_display_names = state_refs.get("player_display_names", {}) as Dictionary
	get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable()) as Callable
	spawn_points = config.get("spawn_points", []) as Array

func spawn_position_for_peer(peer_id: int) -> Vector2:
	var slot := get_spawn_slot_for_peer(peer_id)
	return spawn_position_for_slot(slot)

func spawn_position_for_slot(slot: int) -> Vector2:
	if spawn_points.is_empty():
		return Vector2.ZERO
	var wrapped_slot := posmod(slot, spawn_points.size())
	return spawn_points[wrapped_slot] as Vector2

func random_spawn_position() -> Vector2:
	if spawn_points.is_empty():
		return Vector2.ZERO
	var random_index := int(randi() % spawn_points.size())
	return spawn_points[random_index] as Vector2

func get_spawn_slot_for_peer(peer_id: int) -> int:
	if spawn_slots.has(peer_id):
		return int(spawn_slots[peer_id])

	var lobby_id := _peer_lobby(peer_id)
	var used_slots: Dictionary = {}
	for other_key in players.keys():
		var other_peer_id := int(other_key)
		if other_peer_id == peer_id:
			continue
		if _peer_lobby(other_peer_id) != lobby_id:
			continue
		if spawn_slots.has(other_peer_id):
			used_slots[int(spawn_slots[other_peer_id])] = true

	var slot_count := maxi(1, spawn_points.size())
	var assigned_slot := 0
	for i in range(slot_count):
		if not used_slots.has(i):
			assigned_slot = i
			break
	spawn_slots[peer_id] = assigned_slot
	return assigned_slot

func ensure_player_display_name(peer_id: int) -> String:
	if player_display_names.has(peer_id):
		return str(player_display_names[peer_id])
	var display_name := "P%d" % (get_spawn_slot_for_peer(peer_id) + 1)
	player_display_names[peer_id] = display_name
	return display_name

func player_color(peer_id: int) -> Color:
	var hue := fmod(float(peer_id) * 0.173, 1.0)
	return Color.from_hsv(hue, 0.62, 0.95)

func _peer_lobby(peer_id: int) -> int:
	if get_peer_lobby_cb.is_valid():
		return int(get_peer_lobby_cb.call(peer_id))
	return 0
