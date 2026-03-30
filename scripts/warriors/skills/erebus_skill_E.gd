## Erebus Skill E: Immunity
##
## Grants temporary full damage immunity for 5 seconds.

extends Skill

const CHARACTER_ID_EREBUS := "erebus"

const IMMUNITY_DURATION_SEC := 5.0
const STATUS_TEXT := "Immune"
const VFX_NAME := "ErebusSkillEImmunityVfx"
const VFX_COLOR := Color(0.55, 0.85, 1.0, 0.78)

var character_id_for_peer_cb: Callable = Callable()

func _init() -> void:
	super._init("erebus_immunity_e", "Immunity Surge", 0.0, "Become immune to damage for 5 seconds")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_EREBUS:
		return
	var lobby_id := _peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var player: NetPlayer = players.get(caster_peer_id, null) as NetPlayer
	if player != null and player.has_method("set_damage_immune"):
		player.call("set_damage_immune", IMMUNITY_DURATION_SEC)
	if player != null and player.has_method("set_erebus_immune_visual"):
		player.call("set_erebus_immune_visual", IMMUNITY_DURATION_SEC)

	for member_value in _lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, target_world)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	client_spawn_immunity(caster_peer_id, IMMUNITY_DURATION_SEC)
	_set_local_immunity_status(caster_peer_id, IMMUNITY_DURATION_SEC)

func client_spawn_immunity(peer_id: int, duration_sec: float) -> void:
	var player: NetPlayer = players.get(peer_id, null) as NetPlayer
	if player == null:
		return
	if player.has_method("start_ulti_duration_bar"):
		player.call("start_ulti_duration_bar", duration_sec, "Immune")
	if player.has_method("set_erebus_immune_visual"):
		player.call("set_erebus_immune_visual", duration_sec)
	var visual_root := player.get_node_or_null("VisualRoot") as Node2D
	if visual_root == null:
		return

	var existing := visual_root.get_node_or_null(VFX_NAME) as Node
	if existing != null:
		existing.queue_free()

	# Legacy bubble/ring VFX removed in favor of per-pixel immune shimmer on player sprites.

func _peer_lobby(peer_id: int) -> int:
	return _get_peer_lobby(peer_id)

func _lobby_members(lobby_id: int) -> Array:
	return _get_lobby_members(lobby_id)

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id))
	return CHARACTER_ID_EREBUS

func _set_local_immunity_status(caster_peer_id: int, duration_sec: float) -> void:
	var local_peer_id := multiplayer.get_unique_id() if multiplayer != null else 0
	if local_peer_id != caster_peer_id:
		return
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var tree := loop as SceneTree
	var root := tree.current_scene
	if root == null or not root.has_method("client_set_status_text"):
		return
	root.call("client_set_status_text", STATUS_TEXT)
	var timer := tree.create_timer(maxf(0.05, duration_sec))
	timer.timeout.connect(func() -> void:
		var current_root := tree.current_scene
		if current_root != null and current_root.has_method("client_set_status_text"):
			current_root.call("client_set_status_text", "")
	)
