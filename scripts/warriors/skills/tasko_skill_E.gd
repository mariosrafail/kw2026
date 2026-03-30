## Tasko Skill E: Cloak
## Makes Tasko invisible (and silent) for 5 seconds.

extends Skill

const CHARACTER_ID_TASKO := "tasko"
const INVIS_DURATION_SEC := 5.0
const STATUS_TEXT := "Invisible"
const VFX_NAME := "TaskoSkillEInvisVfx"
const VFX_COLOR := Color(1.0, 0.35, 0.85, 0.9)
const FORCE_HIDE_REASON := "tasko_skill_e"

var character_id_for_peer_cb: Callable = Callable()

func _init() -> void:
	super._init("tasko_cloak", "Cloak", 0.0, "Become invisible for 5 seconds")

func configure(state_refs: Dictionary, callbacks: Dictionary) -> void:
	super.configure(state_refs, callbacks)
	character_id_for_peer_cb = callbacks.get("character_id_for_peer", Callable()) as Callable

func _execute_cast(caster_peer_id: int, target_world: Vector2) -> void:
	if _character_id_for_peer(caster_peer_id) != CHARACTER_ID_TASKO:
		return
	var lobby_id := _get_peer_lobby(caster_peer_id)
	if lobby_id <= 0:
		return
	var player := players.get(caster_peer_id, null) as NetPlayer
	var cast_position := player.global_position if player != null else target_world

	for member_value in _get_lobby_members(lobby_id):
		if send_skill_cast_cb.is_valid():
			send_skill_cast_cb.call(int(member_value), 2, caster_peer_id, cast_position)

func _execute_client_visual(caster_peer_id: int, target_world: Vector2) -> void:
	_apply_client_invisibility(caster_peer_id, INVIS_DURATION_SEC)

func _apply_client_invisibility(peer_id: int, duration_sec: float) -> void:
	var player := players.get(peer_id, null) as NetPlayer
	if player == null:
		return
	if player.has_method("start_ulti_duration_bar"):
		player.call("start_ulti_duration_bar", duration_sec, "Invisible")
	var should_hide := _should_hide_for_local_viewer(peer_id)
	if should_hide:
		_set_player_hidden_state(player, true)
	else:
		_set_player_hidden_state(player, false)
	_set_local_invisible_status(peer_id, true)
	_spawn_invisibility_vfx(player, peer_id, maxf(0.05, duration_sec))
	_schedule_release(player, peer_id, maxf(0.05, duration_sec))

func _set_player_hidden_state(player: NetPlayer, enabled: bool) -> void:
	if player == null:
		return
	if player.has_method("set_forced_hidden"):
		player.call("set_forced_hidden", FORCE_HIDE_REASON, enabled)
	elif player.visual_root != null:
		player.visual_root.visible = not enabled

	if player.has_method("set_forced_sfx_suppressed"):
		player.call("set_forced_sfx_suppressed", FORCE_HIDE_REASON, enabled)
	elif player.has_method("set_sfx_suppressed"):
		player.call("set_sfx_suppressed", enabled)

func _spawn_invisibility_vfx(player: NetPlayer, peer_id: int, duration_sec: float) -> void:
	if player == null:
		return
	var existing := player.get_node_or_null(VFX_NAME) as Node
	if existing != null:
		existing.queue_free()

	var vfx := Node2D.new()
	vfx.name = VFX_NAME
	player.add_child(vfx)
	vfx.global_position = player.global_position
	vfx.z_index = 40

	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = VFX_COLOR
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = mat

	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.72, 0.86, 1.0])
	gradient.colors = PackedColorArray([
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.0),
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.0),
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 1.0),
		Color(VFX_COLOR.r, VFX_COLOR.g, VFX_COLOR.b, 0.0)
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 96
	tex.height = 96
	sprite.texture = tex
	sprite.scale = Vector2.ONE * 1.55
	vfx.add_child(sprite)

	var tween := vfx.create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "scale", Vector2.ONE * 1.85, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2.ONE * 1.55, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "rotation", TAU, 1.0).as_relative()

	var tree_for_cleanup := vfx.get_tree()
	if tree_for_cleanup == null:
		return
	var cleanup_timer := tree_for_cleanup.create_timer(duration_sec)
	cleanup_timer.timeout.connect(func() -> void:
		if vfx != null and is_instance_valid(vfx):
			vfx.queue_free()
	)

func _schedule_release(player: NetPlayer, peer_id: int, duration_sec: float) -> void:
	var tree := player.get_tree()
	if tree == null:
		return
	var timer := tree.create_timer(duration_sec)
	timer.timeout.connect(func() -> void:
		if player != null and is_instance_valid(player):
			_set_player_hidden_state(player, false)
		_set_local_invisible_status(peer_id, false)
	)

func _should_hide_for_local_viewer(caster_peer_id: int) -> bool:
	var local_peer_id := multiplayer.get_unique_id() if multiplayer != null else 0
	if local_peer_id <= 0:
		return true
	if local_peer_id == caster_peer_id:
		return false
	var tree := _scene_tree()
	var root := tree.current_scene if tree != null else null
	if root != null and root.has_method("_team_for_peer"):
		var local_team := int(root.call("_team_for_peer", local_peer_id))
		var caster_team := int(root.call("_team_for_peer", caster_peer_id))
		if local_team >= 0 and local_team == caster_team:
			return false
	return true

func _set_local_invisible_status(caster_peer_id: int, enabled: bool) -> void:
	var local_peer_id := multiplayer.get_unique_id() if multiplayer != null else 0
	if local_peer_id != caster_peer_id:
		return
	var tree := _scene_tree()
	var root := tree.current_scene if tree != null else null
	if root == null or not root.has_method("client_set_status_text"):
		return
	root.call("client_set_status_text", STATUS_TEXT if enabled else "")

func _scene_tree() -> SceneTree:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		return loop as SceneTree
	return null

func _character_id_for_peer(peer_id: int) -> String:
	if character_id_for_peer_cb.is_valid():
		return str(character_id_for_peer_cb.call(peer_id))
	return CHARACTER_ID_TASKO
