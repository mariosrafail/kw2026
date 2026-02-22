## Erebus Skill 1: Immunity Bubble (Q key)
##
## Creates temporary invulnerability bubble around the caster
## Blocks all damage for 5 seconds

extends Skill

const DURATION_SEC := 5.0
const VFX_NAME := "ErebusImmunityVfx"
const VFX_COLOR := Color(0.55, 0.85, 1.0, 0.75)

var _get_peer_lobby_cb: Callable = Callable()
var _get_lobby_members_cb: Callable = Callable()

func _init() -> void:
	super._init("erebus_immunity", "Immunity Bubble", 10.0, "Invulnerability for 5 seconds")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	_get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable())
	_get_lobby_members_cb = callbacks.get("get_lobby_members", Callable())

func _execute_cast(caster_peer_id: int, target_world: Vector2) -> void:
	var lobby_id = _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	
	# Apply immunity on server
	var player: NetPlayer = players.get(caster_peer_id) as NetPlayer
	if player != null and player.has_method("set_damage_immune"):
		player.call("set_damage_immune", DURATION_SEC)
	
	# Broadcast to lobby
	var members = _get_lobby_members(lobby_id)
	for member_value in members:
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), "client_spawn_immunity", caster_peer_id, DURATION_SEC)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	_spawn_immunity_vfx(caster_peer_id)

func _spawn_immunity_vfx(peer_id: int) -> void:
	"""Spawn visual effect for immunity bubble"""
	var player: NetPlayer = players.get(peer_id) as NetPlayer
	if player == null:
		return
	
	var visual_root = player.get_node_or_null("VisualRoot") as Node2D
	if visual_root == null:
		return
	
	# Remove existing VFX
	var existing = visual_root.get_node_or_null(VFX_NAME) as Node
	if existing != null:
		existing.queue_free()
	
	# Create new VFX node
	var vfx = Node2D.new()
	vfx.name = VFX_NAME
	visual_root.add_child(vfx)
	
	# Sprite for bubble effect
	var sprite = Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = VFX_COLOR
	sprite.z_index = 20
	
	var mat = CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material = mat
	vfx.add_child(sprite)
	
	# TODO: Animate bubble effect for DURATION_SEC

# ============================================================================
# Utility Methods
# ============================================================================

func _get_peer_lobby(peer_id: int) -> int:
	if _get_peer_lobby_cb.is_valid():
		return _get_peer_lobby_cb.call(peer_id)
	return 0

func _get_lobby_members(lobby_id: int) -> Array:
	if _get_lobby_members_cb.is_valid():
		return _get_lobby_members_cb.call(lobby_id)
	return []
