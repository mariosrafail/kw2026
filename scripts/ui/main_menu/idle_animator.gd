extends RefCounted

var _host: Node
var _screen_main: Control
var _screen_warriors: Control
var _screen_weapons: Control
var _main_weapon_icon: Sprite2D
var _warrior_area: Control
var _weapon_area: Control
var _play_button: Control
var _bg_noise: CanvasItem
var _logo_node: Node
var _warrior_shop_preview: Node
var _weapon_shop_preview: Node

var _logo_base_pos := Vector2.ZERO
var _warrior_area_base_pos := Vector2.ZERO
var _weapon_area_base_pos := Vector2.ZERO
var _bgnoise_base_alpha := 0.06
var _warrior_shop_preview_base_pos := Vector2.ZERO
var _weapon_shop_preview_base_pos := Vector2.ZERO

var _idle_tween: Tween

func configure(refs: Dictionary) -> void:
	_host = refs.get("host", null)
	_screen_main = refs.get("screen_main", null) as Control
	_screen_warriors = refs.get("screen_warriors", null) as Control
	_screen_weapons = refs.get("screen_weapons", null) as Control
	_main_weapon_icon = refs.get("main_weapon_icon", null) as Sprite2D
	_warrior_area = refs.get("warrior_area", null) as Control
	_weapon_area = refs.get("weapon_area", null) as Control
	_play_button = refs.get("play_button", null) as Control
	_bg_noise = refs.get("bg_noise", null) as CanvasItem
	_logo_node = refs.get("logo_node", null)
	_warrior_shop_preview = refs.get("warrior_shop_preview", null)
	_weapon_shop_preview = refs.get("weapon_shop_preview", null)

func set_base_state(logo_base_pos: Vector2, warrior_area_base_pos: Vector2, weapon_area_base_pos: Vector2, bgnoise_base_alpha: float) -> void:
	_logo_base_pos = logo_base_pos
	_warrior_area_base_pos = warrior_area_base_pos
	_weapon_area_base_pos = weapon_area_base_pos
	_bgnoise_base_alpha = bgnoise_base_alpha

func set_shop_base_state(warrior_shop_preview_base_pos: Vector2, weapon_shop_preview_base_pos: Vector2) -> void:
	_warrior_shop_preview_base_pos = warrior_shop_preview_base_pos
	_weapon_shop_preview_base_pos = weapon_shop_preview_base_pos

func node_pos(n: Node) -> Vector2:
	if n == null:
		return Vector2.ZERO
	if n is Node2D:
		return (n as Node2D).position
	if n is Control:
		return (n as Control).position
	return Vector2.ZERO

func _node_set_pos(n: Node, p: Vector2) -> void:
	if n == null:
		return
	if n is Node2D:
		(n as Node2D).position = p
	elif n is Control:
		(n as Control).position = p

func start_idle_loop(
	current_screen: Control,
	visible_weapon_id: String,
	visible_weapon_skin: int,
	set_weapon_icon_sprite: Callable,
	apply_weapon_skin_visual: Callable
) -> void:
	var on_main := current_screen == _screen_main
	var on_warriors := current_screen == _screen_warriors
	var on_weapons := current_screen == _screen_weapons
	if not on_main and not on_warriors and not on_weapons:
		stop_idle_loop()
		return

	if on_main and _main_weapon_icon != null:
		if set_weapon_icon_sprite.is_valid():
			set_weapon_icon_sprite.call(_main_weapon_icon, visible_weapon_id, 1.0, visible_weapon_skin)
		if apply_weapon_skin_visual.is_valid():
			apply_weapon_skin_visual.call(_main_weapon_icon, visible_weapon_id, visible_weapon_skin)

	# Keep the running idle tween alive to avoid visible reset/pop when
	# login/profile refresh triggers start_idle_loop while already on main menu.
	if _idle_tween != null:
		return

	if _host == null:
		return
	_idle_tween = _host.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if on_main:
		if _logo_node != null:
			_idle_tween.parallel().tween_property(_logo_node, "position", _logo_base_pos + Vector2(0, -4), 1.1)
		if _warrior_area != null:
			_idle_tween.parallel().tween_property(_warrior_area, "position", _warrior_area_base_pos + Vector2(0, -4), 1.1)
		if _weapon_area != null:
			_idle_tween.parallel().tween_property(_weapon_area, "position", _weapon_area_base_pos + Vector2(0, 4), 1.1)
		if _play_button != null:
			_idle_tween.parallel().tween_property(_play_button, "scale", Vector2(1.03, 1.03), 1.1)
		if _bg_noise != null:
			_idle_tween.parallel().tween_property(_bg_noise, "modulate:a", minf(0.16, _bgnoise_base_alpha + 0.05), 1.1)
	elif on_warriors and _warrior_shop_preview != null:
		_idle_tween.parallel().tween_property(_warrior_shop_preview, "position", _warrior_shop_preview_base_pos + Vector2(0, -4), 1.1)
	elif on_weapons and _weapon_shop_preview != null:
		_idle_tween.parallel().tween_property(_weapon_shop_preview, "position", _weapon_shop_preview_base_pos + Vector2(0, -4), 1.1)
	_idle_tween.tween_interval(0.02)
	if on_main:
		if _logo_node != null:
			_idle_tween.parallel().tween_property(_logo_node, "position", _logo_base_pos, 1.1)
		if _warrior_area != null:
			_idle_tween.parallel().tween_property(_warrior_area, "position", _warrior_area_base_pos, 1.1)
		if _weapon_area != null:
			_idle_tween.parallel().tween_property(_weapon_area, "position", _weapon_area_base_pos, 1.1)
		if _play_button != null:
			_idle_tween.parallel().tween_property(_play_button, "scale", Vector2(1, 1), 1.1)
		if _bg_noise != null:
			_idle_tween.parallel().tween_property(_bg_noise, "modulate:a", _bgnoise_base_alpha, 1.1)
	elif on_warriors and _warrior_shop_preview != null:
		_idle_tween.parallel().tween_property(_warrior_shop_preview, "position", _warrior_shop_preview_base_pos, 1.1)
	elif on_weapons and _weapon_shop_preview != null:
		_idle_tween.parallel().tween_property(_weapon_shop_preview, "position", _weapon_shop_preview_base_pos, 1.1)

func stop_idle_loop() -> void:
	if _idle_tween != null:
		_idle_tween.kill()
		_idle_tween = null
	_node_set_pos(_logo_node, _logo_base_pos)
	if _warrior_area != null:
		_warrior_area.position = _warrior_area_base_pos
	if _weapon_area != null:
		_weapon_area.position = _weapon_area_base_pos
	_node_set_pos(_warrior_shop_preview, _warrior_shop_preview_base_pos)
	_node_set_pos(_weapon_shop_preview, _weapon_shop_preview_base_pos)
	if _bg_noise != null:
		_bg_noise.modulate.a = _bgnoise_base_alpha
	if _play_button != null:
		_play_button.scale = Vector2(1, 1)
