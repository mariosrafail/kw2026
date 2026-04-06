extends Skill

const CHARACTER_ID_JUICE := "juice"
const SHRINK_DURATION_SEC := 5.0
const SHRINK_SCALE := 0.46
const STATUS_TEXT := "Mini Juice"

var character_id_for_peer_cb: Callable = Callable()

func _init() -> void:
	super._init("juice_shrink", "Shrink", 0.0, "Shrink yourself for 5 seconds")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_JUICE:
		return
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player != null and player.has_method("set_juice_shrink_visual"):
		player.call("set_juice_shrink_visual", SHRINK_DURATION_SEC, SHRINK_SCALE)
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var payload := Vector2(SHRINK_DURATION_SEC, SHRINK_SCALE)
	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, payload)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	var duration_sec := maxf(0.05, target_world.x if absf(target_world.x) > 0.0001 else SHRINK_DURATION_SEC)
	var shrink_scale := clampf(target_world.y if absf(target_world.y) > 0.0001 else SHRINK_SCALE, 0.2, 1.0)
	var player := players.get(caster_peer_id, null) as NetPlayer
	if player == null:
		return
	if player.has_method("set_juice_shrink_visual"):
		player.call("set_juice_shrink_visual", duration_sec, shrink_scale)
	if player.has_method("start_ulti_duration_bar"):
		player.call("start_ulti_duration_bar", duration_sec, STATUS_TEXT)

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id)).strip_edges().to_lower()
	return CHARACTER_ID_JUICE
