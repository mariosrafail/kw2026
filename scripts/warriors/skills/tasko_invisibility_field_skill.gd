## Tasko Skill 1 (Q): Invisibility Field
## Spawns a large pink circle at aim position. While Tasko is inside:
## - Enemies cannot see Tasko (visual hidden)
## - Enemies do not hear Tasko gun/reload/death sounds
## Local player still sees themselves; HUD shows "Invisible".

extends Skill

const FIELD_DURATION_SEC := 6.0
const FIELD_RADIUS_PX := 150.0
const FIELD_COLOR := Color(1.0, 0.35, 0.85, 0.9)

var _fields_by_peer: Dictionary = {}

func _init() -> void:
	super._init("tasko_invis_field", "Invisibility Field", 10.0, "Pink field: hide & silence while inside")

func _execute_cast(caster_peer_id: int, target_world: Vector2) -> void:
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return

	_fields_by_peer[caster_peer_id] = {
		"center": target_world,
		"remaining": FIELD_DURATION_SEC,
		"lobby_id": lobby_id
	}

	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 1, caster_peer_id, target_world)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	_spawn_field_vfx(caster_peer_id, target_world)

func server_tick(delta: float) -> void:
	if not multiplayer.is_server():
		return
	if _fields_by_peer.is_empty():
		return

	for peer_value in _fields_by_peer.keys():
		var peer_id := int(peer_value)
		var data := _fields_by_peer.get(peer_id, {}) as Dictionary
		var remaining := float(data.get("remaining", 0.0)) - delta
		if remaining > 0.0:
			data["remaining"] = remaining
			_fields_by_peer[peer_id] = data
		else:
			_fields_by_peer.erase(peer_id)

func _spawn_field_vfx(caster_peer_id: int, center: Vector2) -> void:
	if projectile_system == null or projectile_system.projectiles_root == null:
		return

	var existing := projectile_system.projectiles_root.get_node_or_null("TaskoInvisField_%d" % caster_peer_id) as Node
	if existing != null:
		existing.queue_free()

	var vfx := TaskoInvisibilityFieldVfx.new()
	vfx.name = "TaskoInvisField_%d" % caster_peer_id
	vfx.caster_peer_id = caster_peer_id
	vfx.center = center
	vfx.radius = FIELD_RADIUS_PX
	vfx.duration_sec = FIELD_DURATION_SEC
	vfx.color = FIELD_COLOR
	vfx.players = players
	vfx.local_peer_id = multiplayer.get_unique_id() if multiplayer != null else 0
	projectile_system.projectiles_root.add_child(vfx)
