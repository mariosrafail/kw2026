## Erebus Skill 2: Shield (E key)
##
## Creates protective barrier that absorbs damage
## 30 damage absorption, 6 second duration

extends Skill

const CHARACTER_ID_EREBUS := "erebus"

const SHIELD_HEALTH := 30
const SHIELD_DURATION_SEC := 6.0
const VFX_NAME := "ErebusShieldVfx"
const VFX_COLOR := Color(0.0, 0.7, 1.0, 0.85)

var character_id_for_peer_cb: Callable = Callable()

func _init() -> void:
	super._init("erebus_shield", "Shield", 8.0, "Creates protective barrier that absorbs 30 damage")

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
	if player != null and player.has_method("set_shield"):
		player.call("set_shield", SHIELD_HEALTH, SHIELD_DURATION_SEC)

	for member_value in _lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, target_world)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	client_spawn_shield(caster_peer_id, SHIELD_DURATION_SEC)

func client_spawn_shield(peer_id: int, duration_sec: float) -> void:
	var player: NetPlayer = players.get(peer_id, null) as NetPlayer
	if player == null:
		return
	var visual_root := player.get_node_or_null("VisualRoot") as Node2D
	if visual_root == null:
		return

	var existing := visual_root.get_node_or_null(VFX_NAME) as Node
	if existing != null:
		existing.queue_free()

	var vfx := Node2D.new()
	vfx.name = VFX_NAME
	visual_root.add_child(vfx)

	var base_mat := CanvasItemMaterial.new()
	base_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	base_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# More visible shield: inner bubble + outer ring.
	var bubble := Sprite2D.new()
	bubble.centered = true
	bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bubble.modulate = Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.95)
	bubble.z_index = 15
	bubble.material = base_mat

	var bubble_gradient := Gradient.new()
	bubble_gradient.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
	bubble_gradient.colors = PackedColorArray([
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.0),
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.75),
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.0)
	])
	var bubble_tex := GradientTexture2D.new()
	bubble_tex.gradient = bubble_gradient
	bubble_tex.fill = GradientTexture2D.FILL_RADIAL
	bubble_tex.fill_from = Vector2(0.5, 0.5)
	bubble_tex.fill_to = Vector2(1.0, 0.5)
	bubble_tex.width = 96
	bubble_tex.height = 96
	bubble.texture = bubble_tex
	bubble.scale = Vector2.ONE * 1.95
	vfx.add_child(bubble)

	var ring := Sprite2D.new()
	ring.centered = true
	ring.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring.modulate = Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.85)
	ring.z_index = 16
	ring.material = base_mat

	var ring_gradient := Gradient.new()
	ring_gradient.offsets = PackedFloat32Array([0.0, 0.78, 0.86, 1.0])
	ring_gradient.colors = PackedColorArray([
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.0),
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.0),
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 1.0),
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.0)
	])
	var ring_tex := GradientTexture2D.new()
	ring_tex.gradient = ring_gradient
	ring_tex.fill = GradientTexture2D.FILL_RADIAL
	ring_tex.fill_from = Vector2(0.5, 0.5)
	ring_tex.fill_to = Vector2(1.0, 0.5)
	ring_tex.width = 128
	ring_tex.height = 128
	ring.texture = ring_tex
	ring.scale = Vector2.ONE * 1.55
	vfx.add_child(ring)

	var tween := vfx.create_tween()
	tween.set_loops()
	tween.tween_property(bubble, "scale", Vector2.ONE * 2.15, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(bubble, "scale", Vector2.ONE * 1.95, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(ring, "rotation", TAU, 1.1).as_relative()
	tween.parallel().tween_property(ring, "scale", Vector2.ONE * 1.75, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(ring, "scale", Vector2.ONE * 1.55, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var tree := vfx.get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(maxf(0.05, duration_sec))
	timer.timeout.connect(func() -> void:
		if vfx != null and is_instance_valid(vfx):
			vfx.queue_free()
	)

func _peer_lobby(peer_id: int) -> int:
	return _get_peer_lobby(peer_id)

func _lobby_members(lobby_id: int) -> Array:
	return _get_lobby_members(lobby_id)

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id))
	return CHARACTER_ID_EREBUS
