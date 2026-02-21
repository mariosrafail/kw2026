extends RefCounted

const CHARACTER_ID_EREBUS := "erebus"

const DURATION_SEC := 5.0
const VFX_NAME := "ErebusImmunityVfx"
const VFX_COLOR := Color(0.55, 0.85, 1.0, 0.75)

var players: Dictionary = {}
var multiplayer: MultiplayerAPI

var get_peer_lobby_cb: Callable = Callable()
var get_lobby_members_cb: Callable = Callable()
var character_id_for_peer_cb: Callable = Callable()
var send_spawn_immunity_cb: Callable = Callable()

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	players = state_refs.get("players", {}) as Dictionary
	multiplayer = state_refs.get("multiplayer", null) as MultiplayerAPI

	get_peer_lobby_cb = callbacks.get("get_peer_lobby", Callable()) as Callable
	get_lobby_members_cb = callbacks.get("get_lobby_members", Callable()) as Callable
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable
	send_spawn_immunity_cb = callbacks.get("send_spawn_erebus_immunity", Callable()) as Callable

func server_cast_skill1(caster_peer_id: int) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_EREBUS:
		return
	var lobby_id := _peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var player: NetPlayer = players.get(caster_peer_id, null) as NetPlayer
	if player != null and player.has_method("set_damage_immune"):
		player.call("set_damage_immune", DURATION_SEC)

	for member_value in _lobby_members(lobby_id):
		if send_spawn_immunity_cb.is_valid():
			send_spawn_immunity_cb.call(int(member_value), caster_peer_id, DURATION_SEC)

func client_spawn_immunity(peer_id: int, duration_sec: float) -> void:
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

	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = VFX_COLOR
	sprite.z_index = 20
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	sprite.material = mat

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.65, 1.0])
	gradient.colors = PackedColorArray([
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.0),
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, VFX_COLOR.a),
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.0)
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	sprite.texture = tex
	sprite.scale = Vector2.ONE * 2.0

	vfx.add_child(sprite)

	var tween := vfx.create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "scale", Vector2.ONE * 2.35, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE * 2.0, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "rotation", TAU, 1.4).as_relative()

	var tree := vfx.get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(maxf(0.05, duration_sec))
	timer.timeout.connect(func() -> void:
		if vfx != null and is_instance_valid(vfx):
			vfx.queue_free()
	)

func _peer_lobby(peer_id: int) -> int:
	if get_peer_lobby_cb.is_valid():
		return int(get_peer_lobby_cb.call(peer_id))
	return 0

func _lobby_members(lobby_id: int) -> Array:
	if get_lobby_members_cb.is_valid():
		return get_lobby_members_cb.call(lobby_id) as Array
	return []

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id))
	return CHARACTER_ID_EREBUS
