extends Control

const DATA := preload("res://scripts/ui/test_menu/data.gd")
const CURSOR_MANAGER_SCRIPT := preload("res://scripts/ui/cursor_manager.gd")
const CURSOR_MANAGER_NAME := "CursorManager"
const WEAPON_UI_SCRIPT := preload("res://scripts/ui/test_menu/weapon_ui.gd")
const STATE_STORE_SCRIPT := preload("res://scripts/ui/test_menu/state_store.gd")
const INTRO_FX_CTRL_SCRIPT := preload("res://scripts/ui/test_menu/intro_fx_controller.gd")
const CONFIRM_OVERLAY_SCRIPT := preload("res://scripts/ui/test_menu/confirm_overlay.gd")

const WEAPON_UZI := DATA.WEAPON_UZI
const WEAPON_GRENADE := DATA.WEAPON_GRENADE

@export var enable_intro_animation := true
@export var intro_timeout_sec := 6.0
@export var intro_failfast_quit := true
@export var intro_fx_enabled := true
@export var intro_fx_particles_per_burst := 12

@export var warriors_menu_preview_scale_mult := 1.25
@export var weapons_menu_preview_scale_mult := 0.95
@export var weapon_icon_max_height_ratio := 0.42
@export var rainbow_skin_cost := 5000

var _weapon_ui := WEAPON_UI_SCRIPT.new()
var _state_store := STATE_STORE_SCRIPT.new()
var _intro_fx := INTRO_FX_CTRL_SCRIPT.new()

@onready var coins_label: Label = %CoinsLabel
@onready var clk_label: Label = %ClkLabel
@onready var wallet_panel: Control = $WalletPanel
@onready var wallet_click: Button = %WalletClick

@onready var screens: Control = $Screens
@onready var screen_main: Control = %ScreenMain
@onready var screen_options: Control = %ScreenOptions
@onready var screen_warriors: Control = %ScreenWarriors
@onready var screen_weapons: Control = %ScreenWeapons

var logo_node: Node = null
@onready var warrior_area: Control = %WarriorArea
@onready var weapon_area: Control = %WeaponArea

@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var exit_button: Button = %ExitButton
@onready var warrior_button: Button = %WarriorButton
@onready var weapon_button: Button = %WeaponButton

@onready var main_warrior_preview: Node = %MainWarriorPreview
@onready var main_weapon_icon: Sprite2D = %MainWeaponIcon

@onready var options_back_button: Button = %OptionsBackButton
@onready var warriors_back_button: Button = %WarriorsBackButton
@onready var weapons_back_button: Button = %WeaponsBackButton

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider

@onready var intro: Control = %Intro
@onready var intro_fade: ColorRect = $Intro/IntroFade
@onready var intro_plate: PanelContainer = $Intro/IntroPlate
@onready var intro_label: Label = $Intro/IntroLabel

@onready var warrior_grid: GridContainer = %WarriorGrid
@onready var warrior_scroll: ScrollContainer = $Screens/ScreenWarriors/WarriorsPanel/Margin/OuterVBox/BodyRow/ListCol/WarriorScroll
@onready var warrior_shop_preview: Node = %WarriorShopPreview
@onready var warrior_name_label: Label = %WarriorNameLabel
@onready var warrior_action_button: Button = %WarriorActionButton

@onready var weapon_grid: GridContainer = %WeaponGrid
@onready var weapon_scroll: ScrollContainer = $Screens/ScreenWeapons/WeaponsPanel/Margin/OuterVBox/BodyRow/ListCol/WeaponScroll
@onready var weapon_shop_preview: Sprite2D = %WeaponShopPreview
@onready var weapon_name_label: Label = %WeaponNameLabel
@onready var weapon_action_button: Button = %WeaponActionButton

var wallet_coins := 0
var wallet_clk := 0

var owned_warrior_skins := PackedInt32Array([0])
var selected_warrior_skin := 0
var _pending_warrior_skin := 0

var owned_weapons := PackedStringArray([WEAPON_UZI])
var owned_weapon_skins_by_weapon: Dictionary = {
	WEAPON_UZI: PackedInt32Array([0]),
	WEAPON_GRENADE: PackedInt32Array([0]),
}
var selected_weapon_id := WEAPON_UZI
var selected_weapon_skin := 0
var _pending_weapon_id := WEAPON_UZI
var _pending_weapon_skin := 0

var _current_screen: Control
var _transition_tween: Tween
var _idle_tween: Tween
var _fx_layer: Control
var _open_menu_tween: Tween
var _warrior_open_transition: Node2D
var _main_warrior_preview_base_scale := Vector2.ONE
var _warrior_shop_preview_base_scale := Vector2.ONE
var _weapon_open_transition: Node2D
var _weapon_shop_preview_base_scale := Vector2.ONE
var _confirm_overlay_ui: Control

var _logo_base_pos := Vector2.ZERO
var _warrior_area_base_pos := Vector2.ZERO
var _weapon_area_base_pos := Vector2.ZERO
var _bgnoise_base_alpha := 0.06

var _slider_grabber: Texture2D = null
var _slider_grabber_hi: Texture2D = null
var _scroll_sb: StyleBoxFlat = null
var _scroll_grabber: StyleBoxFlat = null
var _scroll_grabber_hi: StyleBoxFlat = null
var _scroll_grabber_pressed: StyleBoxFlat = null

func _ready() -> void:
	_ensure_cursor_manager()
	_current_screen = screen_main
	randomize()
	_weapon_ui.weapon_icon_max_height_ratio = weapon_icon_max_height_ratio
	_weapon_ui.weapons_menu_preview_scale_mult = weapons_menu_preview_scale_mult
	_weapon_ui.rainbow_skin_cost = rainbow_skin_cost
	_load_state_or_defaults()
	set_process_input(true)
	set_process_unhandled_input(true)
	_init_confirm_dialog()
	_intro_fx.configure(self, intro, intro_fade, intro_plate, intro_label, Callable(self, "_pixel_burst_at"))
	_intro_fx.enable_intro_animation = enable_intro_animation
	_intro_fx.intro_timeout_sec = intro_timeout_sec
	_intro_fx.intro_fx_enabled = intro_fx_enabled

	logo_node = get_node_or_null("Screens/ScreenMain/LogoSlot/Logo")
	if logo_node == null:
		logo_node = get_node_or_null("Screens/ScreenMain/Logo")
	if logo_node == null:
		logo_node = get_node_or_null("Screens/ScreenMain/TextLogo")

	_fx_layer = Control.new()
	_fx_layer.name = "FxLayer"
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.z_index = 900
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fx_layer)

	_logo_base_pos = _node_pos(logo_node)
	_warrior_area_base_pos = warrior_area.position
	_weapon_area_base_pos = weapon_area.position
	var bg := $BgNoise as CanvasItem
	if bg != null:
		_bgnoise_base_alpha = bg.modulate.a

	call_deferred("_apply_center_pivots")
	_apply_pixel_slider_style(music_slider)
	_apply_pixel_slider_style(sfx_slider)
	_apply_pixel_scroll_style(warrior_scroll)
	_apply_pixel_scroll_style(weapon_scroll)
	_apply_grid_spacing(warrior_grid)
	_apply_grid_spacing(weapon_grid)
	if enable_intro_animation:
		call_deferred("_play_intro_animation_safe")
	elif intro != null:
		intro.visible = false

	_prepare_player_preview(main_warrior_preview)
	_prepare_player_preview(warrior_shop_preview)

	if main_warrior_preview is Node2D:
		_main_warrior_preview_base_scale = (main_warrior_preview as Node2D).scale
	if warrior_shop_preview is Node2D:
		_warrior_shop_preview_base_scale = (warrior_shop_preview as Node2D).scale
	if weapon_shop_preview != null:
		_weapon_shop_preview_base_scale = weapon_shop_preview.scale

	_apply_warrior_skin_to_player(main_warrior_preview, selected_warrior_skin)
	_apply_warrior_skin_to_player(warrior_shop_preview, selected_warrior_skin)

	_set_weapon_icon_sprite(main_weapon_icon, selected_weapon_id)
	_apply_weapon_skin_visual(main_weapon_icon, selected_weapon_id, selected_weapon_skin)
	_set_weapon_icon_sprite(weapon_shop_preview, selected_weapon_id)
	_apply_weapon_skin_visual(weapon_shop_preview, selected_weapon_id, selected_weapon_skin)

	_update_wallet_labels(true)
	_build_warrior_shop_grid()
	_build_weapon_shop_grid()

	_select_warrior_skin(selected_warrior_skin, true)
	_select_weapon_skin(selected_weapon_id, selected_weapon_skin, true)

	_connect_signals()
	_start_idle_loop()

func _ensure_cursor_manager() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.get_root()
	if root == null:
		return
	if root.get_node_or_null(CURSOR_MANAGER_NAME) != null:
		return
	var cm := CURSOR_MANAGER_SCRIPT.new()
	cm.name = CURSOR_MANAGER_NAME
	root.call_deferred("add_child", cm)

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			if _confirm_overlay_ui != null and _confirm_overlay_ui.visible:
				_confirm_overlay_ui.visible = false
				return
			if _current_screen == screen_weapons:
				_close_weapons_menu()
				return
			if _current_screen == screen_warriors:
				_close_warriors_menu()
				return
			if _current_screen == screen_options:
				_switch_to(screen_main, -1)
				return
			get_tree().quit()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_F4:
			_toggle_fullscreen()

func _unhandled_input(event: InputEvent) -> void:
	# Fallback in case UI consumes events on some editor runs.
	_input(event)

func _toggle_fullscreen() -> void:
	var current_mode := DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _apply_center_pivots() -> void:
	_center_pivot(warrior_area)
	_center_pivot(weapon_area)
	_center_pivot(play_button)
	_center_pivot(options_button)
	_center_pivot(exit_button)
	_center_pivot(options_back_button)
	_center_pivot(warriors_back_button)
	_center_pivot(weapons_back_button)
	_center_pivot(warrior_action_button)
	_center_pivot(weapon_action_button)

func _center_pivot(c: Control) -> void:
	if c == null:
		return
	if c.size.x <= 0.0 or c.size.y <= 0.0:
		call_deferred("_center_pivot", c)
		return
	c.pivot_offset = c.size * 0.5

func _play_intro_animation_safe() -> void:
	_intro_fx.enable_intro_animation = enable_intro_animation
	_intro_fx.intro_timeout_sec = intro_timeout_sec
	_intro_fx.intro_fx_enabled = intro_fx_enabled
	_intro_fx.play_intro_animation_safe()
	enable_intro_animation = _intro_fx.enable_intro_animation

func _connect_signals() -> void:
	warrior_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	weapon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if wallet_click != null:
		wallet_click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		wallet_click.pressed.connect(func() -> void:
			_pop(wallet_panel)
		)

	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(func() -> void:
		_button_press_anim(options_button)
		_switch_to(screen_options, 1)
	)
	exit_button.pressed.connect(_on_exit_pressed)

	warrior_button.pressed.connect(_open_warriors_menu)
	weapon_button.pressed.connect(_open_weapons_menu)

	options_back_button.pressed.connect(func() -> void:
		_button_press_anim(options_back_button)
		_switch_to(screen_main, -1)
	)
	warriors_back_button.pressed.connect(_close_warriors_menu)
	weapons_back_button.pressed.connect(_close_weapons_menu)

	warrior_action_button.pressed.connect(_on_warrior_action_pressed)
	weapon_action_button.pressed.connect(_on_weapon_action_pressed)

	_add_hover_pop(play_button)
	_add_hover_pop(options_button)
	_add_hover_pop(exit_button)
	_add_hover_pop(options_back_button)
	_add_hover_pop(warriors_back_button)
	_add_hover_pop(weapons_back_button)
	_add_hover_pop(warrior_action_button)
	_add_hover_pop(weapon_action_button)

	warrior_button.mouse_entered.connect(func() -> void: _hover_area(warrior_area, true))
	warrior_button.mouse_exited.connect(func() -> void: _hover_area(warrior_area, false))
	weapon_button.mouse_entered.connect(func() -> void: _hover_area(weapon_area, true))
	weapon_button.mouse_exited.connect(func() -> void: _hover_area(weapon_area, false))

func _on_play_pressed() -> void:
	_button_press_anim(play_button)
	if ResourceLoader.exists("res://scenes/main.tscn"):
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_exit_pressed() -> void:
	_button_press_anim(exit_button)
	get_tree().quit()

func _switch_to(target: Control, direction: int) -> void:
	if target == null:
		return
	if _current_screen == target:
		return

	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	if _open_menu_tween != null:
		_open_menu_tween.kill()
		_open_menu_tween = null

	var from := _current_screen
	var viewport_size := get_viewport_rect().size
	var viewport_w := float(viewport_size.x)
	var viewport_h := float(viewport_size.y)
	if viewport_w <= 0.0:
		viewport_w = 640.0
	if viewport_h <= 0.0:
		viewport_h = 360.0

	var opening_options := target == screen_options and from != screen_options
	var closing_options := from == screen_options and target == screen_main
	var bl := Vector2(-viewport_w * 0.35, viewport_h * 0.55)

	# Options behaves like an overlay: keep the main menu unchanged underneath.
	if opening_options:
		target.visible = true
		target.modulate = Color(1, 1, 1, 0)
		target.position = bl
		target.scale = Vector2(0.96, 0.96)

		_transition_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_transition_tween.parallel().tween_property(target, "position", Vector2.ZERO, 0.32)
		_transition_tween.parallel().tween_property(target, "modulate:a", 1.0, 0.18)
		_transition_tween.parallel().tween_property(target, "scale", Vector2(1, 1), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_transition_tween.tween_callback(func() -> void:
			target.position = Vector2.ZERO
			target.modulate = Color(1, 1, 1, 1)
			_current_screen = target
		)
		return

	if closing_options:
		_transition_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		_transition_tween.parallel().tween_property(from, "position", bl, 0.32)
		_transition_tween.parallel().tween_property(from, "modulate:a", 0.0, 0.16)
		_transition_tween.tween_callback(func() -> void:
			from.visible = false
			from.position = Vector2.ZERO
			from.modulate = Color(1, 1, 1, 1)
			_current_screen = target
		)
		return

	_stop_idle_loop()

	var in_from := Vector2(direction * viewport_w, 0)
	var out_to := Vector2(-direction * viewport_w * 0.25, 0)

	target.visible = true
	target.modulate = Color(1, 1, 1, 0)
	target.position = in_from
	target.scale = Vector2(0.96, 0.96)

	_transition_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_transition_tween.parallel().tween_property(target, "position", Vector2.ZERO, 0.32)
	_transition_tween.parallel().tween_property(target, "modulate:a", 1.0, 0.18)
	_transition_tween.parallel().tween_property(target, "scale", Vector2(1, 1), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	if from != null:
		_transition_tween.parallel().tween_property(from, "position", out_to, 0.32)
		_transition_tween.parallel().tween_property(from, "modulate:a", 0.0, 0.16)

	_transition_tween.tween_callback(func() -> void:
		if from != null:
			from.visible = false
			from.position = Vector2.ZERO
			from.modulate = Color(1, 1, 1, 1)
		target.position = Vector2.ZERO
		target.modulate = Color(1, 1, 1, 1)
		_current_screen = target
		if _current_screen == screen_main:
			_start_idle_loop()
	)

func _open_warriors_menu() -> void:
	if screen_warriors == null or screen_main == null:
		return
	if _open_menu_tween != null:
		_open_menu_tween.kill()
		_open_menu_tween = null
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	if _warrior_open_transition != null and is_instance_valid(_warrior_open_transition):
		_warrior_open_transition.queue_free()
	_warrior_open_transition = null

	_stop_idle_loop()

	screen_warriors.visible = true
	screen_warriors.position = Vector2.ZERO
	screen_warriors.scale = Vector2.ONE
	screen_warriors.modulate = Color(1, 1, 1, 0)

	# Hide the real menu preview during the transition; we'll reveal it after the fade.
	if warrior_shop_preview != null and warrior_shop_preview is CanvasItem:
		(warrior_shop_preview as CanvasItem).visible = false

	# Defer so Control layout updates and global positions are accurate.
	call_deferred("_open_warriors_menu_stage2")

func _open_warriors_menu_stage2() -> void:
	if screen_warriors == null or screen_main == null:
		return
	var src_preview := main_warrior_preview as Node2D
	var dst_preview := warrior_shop_preview as Node2D
	if src_preview == null or dst_preview == null or _fx_layer == null:
		# Fallback: just fade in menu.
		_open_menu_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_open_menu_tween.tween_property(screen_warriors, "modulate:a", 1.0, 0.18)
		_open_menu_tween.tween_callback(func() -> void:
			screen_main.visible = false
			_current_screen = screen_warriors
			if dst_preview != null:
				dst_preview.visible = true
		)
		return

	var start_pos := src_preview.global_position
	var target_pos := dst_preview.global_position
	var start_scale := src_preview.scale
	var target_scale := dst_preview.scale * clampf(warriors_menu_preview_scale_mult, 0.01, 3.0)

	# Do NOT duplicate the full player node: it can run scripts/_ready() and change visuals.
	# Instead, duplicate only the visual subtree exactly as it looks right now.
	var src_visual := src_preview.get_node_or_null("VisualRoot") as Node2D
	if src_visual == null:
		return
	_warrior_open_transition = Node2D.new()
	_warrior_open_transition.global_position = start_pos
	_warrior_open_transition.scale = start_scale
	_warrior_open_transition.z_index = 950
	_warrior_open_transition.add_child(src_visual.duplicate())
	_fx_layer.add_child(_warrior_open_transition)

	src_preview.visible = false

	_open_menu_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_menu_tween.parallel().tween_property(_warrior_open_transition, "global_position", target_pos, 0.18)
	_open_menu_tween.parallel().tween_property(_warrior_open_transition, "scale", start_scale * 1.35, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_property(_warrior_open_transition, "scale", target_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_property(screen_warriors, "modulate:a", 1.0, 0.18)

	_open_menu_tween.tween_callback(func() -> void:
		screen_main.visible = false
		screen_main.position = Vector2.ZERO
		screen_main.modulate = Color(1, 1, 1, 1)
		_current_screen = screen_warriors
		if _warrior_open_transition != null and is_instance_valid(_warrior_open_transition):
			_warrior_open_transition.queue_free()
		_warrior_open_transition = null
		src_preview.visible = true
		if dst_preview != null:
			dst_preview.scale = _warrior_shop_preview_base_scale * clampf(warriors_menu_preview_scale_mult, 0.01, 3.0)
			dst_preview.visible = true
	)

func _close_warriors_menu() -> void:
	if screen_warriors == null or screen_main == null:
		return
	if _open_menu_tween != null:
		_open_menu_tween.kill()
		_open_menu_tween = null
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	if _warrior_open_transition != null and is_instance_valid(_warrior_open_transition):
		_warrior_open_transition.queue_free()
	_warrior_open_transition = null
	if warrior_shop_preview != null and warrior_shop_preview is CanvasItem:
		(warrior_shop_preview as CanvasItem).visible = true
	# Defer so Control layout updates and global positions are accurate.
	call_deferred("_close_warriors_menu_stage2")

func _close_warriors_menu_stage2() -> void:
	if screen_warriors == null or screen_main == null:
		return
	if _fx_layer == null:
		return
	var src_preview := warrior_shop_preview as Node2D
	var dst_preview := main_warrior_preview as Node2D
	if src_preview == null or dst_preview == null:
		return

	var src_visual := src_preview.get_node_or_null("VisualRoot") as Node2D
	if src_visual == null:
		return

	var start_pos := src_preview.global_position
	var target_pos := dst_preview.global_position
	var start_scale := src_preview.scale
	var target_scale := dst_preview.scale

	_warrior_open_transition = Node2D.new()
	_warrior_open_transition.global_position = start_pos
	_warrior_open_transition.scale = start_scale
	_warrior_open_transition.z_index = 950
	_warrior_open_transition.add_child(src_visual.duplicate())
	_fx_layer.add_child(_warrior_open_transition)

	src_preview.visible = false
	dst_preview.visible = false

	screen_main.visible = true
	screen_main.position = Vector2.ZERO
	screen_main.modulate = Color(1, 1, 1, 1)

	_open_menu_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_open_menu_tween.parallel().tween_property(screen_warriors, "modulate:a", 0.0, 0.14)
	_open_menu_tween.parallel().tween_property(_warrior_open_transition, "global_position", target_pos, 0.18)
	_open_menu_tween.parallel().tween_property(_warrior_open_transition, "scale", target_scale * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_property(_warrior_open_transition, "scale", target_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_callback(func() -> void:
		screen_warriors.visible = false
		screen_warriors.modulate = Color(1, 1, 1, 1)
		_current_screen = screen_main
		if _warrior_open_transition != null and is_instance_valid(_warrior_open_transition):
			_warrior_open_transition.queue_free()
		_warrior_open_transition = null
		dst_preview.visible = true
		src_preview.visible = true
		src_preview.scale = _warrior_shop_preview_base_scale
		_start_idle_loop()
	)

func _open_weapons_menu() -> void:
	if screen_weapons == null or screen_main == null:
		return
	if _open_menu_tween != null:
		_open_menu_tween.kill()
		_open_menu_tween = null
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	if _weapon_open_transition != null and is_instance_valid(_weapon_open_transition):
		_weapon_open_transition.queue_free()
	_weapon_open_transition = null

	_stop_idle_loop()

	screen_weapons.visible = true
	screen_weapons.position = Vector2.ZERO
	screen_weapons.scale = Vector2.ONE
	screen_weapons.modulate = Color(1, 1, 1, 0)

	# Hide the real menu preview during the transition; we'll reveal it after the fade.
	if weapon_shop_preview != null:
		_set_weapon_icon_sprite(weapon_shop_preview, _pending_weapon_id)
		_apply_weapon_skin_visual(weapon_shop_preview, _pending_weapon_id, _pending_weapon_skin)
		weapon_shop_preview.visible = true
		weapon_shop_preview.modulate.a = 0.0

	call_deferred("_open_weapons_menu_stage2")

func _open_weapons_menu_stage2() -> void:
	if screen_weapons == null or screen_main == null:
		return
	if _fx_layer == null:
		return
	var src_icon := main_weapon_icon
	var dst_icon := weapon_shop_preview
	if src_icon == null or dst_icon == null:
		_open_menu_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_open_menu_tween.tween_property(screen_weapons, "modulate:a", 1.0, 0.18)
		_open_menu_tween.tween_callback(func() -> void:
			screen_main.visible = false
			_current_screen = screen_weapons
			if dst_icon != null:
				dst_icon.visible = true
		)
		return

	# Sprite2D transitions need to animate using the *visual* center of the weapon,
	# not the geometric center of its cropped texture. UZI happens to be closer to
	# centered, while AK/SHOTGUN have asymmetric silhouettes, so the motion looks off
	# unless we compensate.
	var delta := (DATA.WEAPON_UI_OFFSET_BY_ID.get(_pending_weapon_id, Vector2.ZERO) as Vector2)
	var start_center := src_icon.global_position + delta * src_icon.global_scale
	var target_center := dst_icon.global_position + delta * dst_icon.global_scale

	var tex := src_icon.texture
	if tex == null:
		return

	var start_scale := src_icon.global_scale
	var target_scale := dst_icon.global_scale

	_weapon_open_transition = Node2D.new()
	_weapon_open_transition.global_position = start_center
	_weapon_open_transition.z_index = 950
	var spr := Sprite2D.new()
	spr.centered = true
	spr.texture = tex
	spr.modulate = src_icon.modulate
	spr.material = src_icon.material
	spr.offset = -delta
	spr.scale = start_scale
	_weapon_open_transition.add_child(spr)
	_fx_layer.add_child(_weapon_open_transition)

	src_icon.visible = false

	_open_menu_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_open_menu_tween.parallel().tween_property(_weapon_open_transition, "global_position", target_center, 0.18)
	_open_menu_tween.parallel().tween_property(spr, "scale", start_scale * 1.35, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_property(spr, "scale", target_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_property(screen_weapons, "modulate:a", 1.0, 0.18)

	_open_menu_tween.tween_callback(func() -> void:
		screen_main.visible = false
		screen_main.position = Vector2.ZERO
		screen_main.modulate = Color(1, 1, 1, 1)
		_current_screen = screen_weapons
		if _weapon_open_transition != null and is_instance_valid(_weapon_open_transition):
			_weapon_open_transition.queue_free()
		_weapon_open_transition = null
		src_icon.visible = true
		if dst_icon != null:
			_set_weapon_icon_sprite(dst_icon, _pending_weapon_id)
			_apply_weapon_skin_visual(dst_icon, _pending_weapon_id, _pending_weapon_skin)
			dst_icon.visible = true
			dst_icon.modulate.a = 1.0
	)

func _close_weapons_menu() -> void:
	if screen_weapons == null or screen_main == null:
		return
	if _open_menu_tween != null:
		_open_menu_tween.kill()
		_open_menu_tween = null
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	if _weapon_open_transition != null and is_instance_valid(_weapon_open_transition):
		_weapon_open_transition.queue_free()
	_weapon_open_transition = null
	if weapon_shop_preview != null:
		weapon_shop_preview.visible = true
		weapon_shop_preview.modulate.a = 1.0

	call_deferred("_close_weapons_menu_stage2")

func _close_weapons_menu_stage2() -> void:
	if screen_weapons == null or screen_main == null:
		return
	if _fx_layer == null:
		return
	var src_icon := weapon_shop_preview
	var dst_icon := main_weapon_icon
	if src_icon == null or dst_icon == null:
		return

	var delta := (DATA.WEAPON_UI_OFFSET_BY_ID.get(_pending_weapon_id, Vector2.ZERO) as Vector2)
	var start_center := src_icon.global_position + delta * src_icon.global_scale
	var target_center := dst_icon.global_position + delta * dst_icon.global_scale

	var tex := src_icon.texture
	if tex == null:
		return

	var start_scale := src_icon.global_scale
	var target_scale := dst_icon.global_scale

	_weapon_open_transition = Node2D.new()
	_weapon_open_transition.global_position = start_center
	_weapon_open_transition.z_index = 950
	var spr := Sprite2D.new()
	spr.centered = true
	spr.texture = tex
	spr.modulate = src_icon.modulate
	spr.material = src_icon.material
	spr.offset = -delta
	spr.scale = start_scale
	_weapon_open_transition.add_child(spr)
	_fx_layer.add_child(_weapon_open_transition)

	src_icon.modulate.a = 0.0
	dst_icon.visible = false

	screen_main.visible = true
	screen_main.position = Vector2.ZERO
	screen_main.modulate = Color(1, 1, 1, 1)

	_open_menu_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_open_menu_tween.parallel().tween_property(screen_weapons, "modulate:a", 0.0, 0.14)
	_open_menu_tween.parallel().tween_property(_weapon_open_transition, "global_position", target_center, 0.18)
	_open_menu_tween.parallel().tween_property(spr, "scale", target_scale * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_property(spr, "scale", target_scale, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_open_menu_tween.tween_callback(func() -> void:
		screen_weapons.visible = false
		screen_weapons.modulate = Color(1, 1, 1, 1)
		_current_screen = screen_main
		if _weapon_open_transition != null and is_instance_valid(_weapon_open_transition):
			_weapon_open_transition.queue_free()
		_weapon_open_transition = null
		dst_icon.visible = true
		src_icon.modulate.a = 1.0
		_set_weapon_icon_sprite(src_icon, _pending_weapon_id)
		_apply_weapon_skin_visual(src_icon, _pending_weapon_id, _pending_weapon_skin)
		_start_idle_loop()
	)

func _prepare_player_preview(player: Node) -> void:
	if player == null:
		return
	player.process_mode = Node.PROCESS_MODE_DISABLED

	var visual_root := player.get_node_or_null("VisualRoot") as Node
	if visual_root == null:
		return

	var gun_pivot := visual_root.get_node_or_null("GunPivot") as CanvasItem
	if gun_pivot != null:
		gun_pivot.visible = false

	for label_name in ["HealthLabel", "AmmoLabel", "NameLabel"]:
		var label := visual_root.get_node_or_null(label_name) as CanvasItem
		if label != null:
			label.visible = false

func _apply_warrior_skin_to_player(player: Node, skin_index: int) -> void:
	if player == null:
		return
	var visual_root := player.get_node_or_null("VisualRoot") as Node
	if visual_root == null:
		return

	var idx := maxi(0, skin_index)
	var region := Rect2(float(idx * 64), 0.0, 64.0, 64.0)

	var head := visual_root.get_node_or_null("head") as Sprite2D
	if head != null:
		head.texture = DATA.HEADS_TEXTURE
		head.region_enabled = true
		head.region_rect = region

	var torso := visual_root.get_node_or_null("torso") as Sprite2D
	if torso != null:
		torso.texture = DATA.TORSO_TEXTURE
		torso.region_enabled = true
		torso.region_rect = region

	for leg_name in ["leg1", "leg2"]:
		var leg := visual_root.get_node_or_null(leg_name) as Sprite2D
		if leg != null:
			leg.texture = DATA.LEGS_TEXTURE
			leg.region_enabled = true
			leg.region_rect = region

func _set_weapon_icon_sprite(target: Sprite2D, weapon_id: String, extra_mult: float = 1.0) -> void:
	_weapon_ui.set_weapon_icon_sprite(target, weapon_id, extra_mult, weapon_shop_preview)

func _icon_global_rect(icon: CanvasItem) -> Rect2:
	if icon == null:
		return Rect2()
	if icon is Control:
		return (icon as Control).get_global_rect()
	if icon is Sprite2D:
		var s := icon as Sprite2D
		if s.texture == null:
			return Rect2(s.global_position, Vector2.ZERO)
		var sz := s.texture.get_size() * s.global_scale
		return Rect2(s.global_position - sz * 0.5, sz)
	return Rect2(icon.get_global_transform().origin, Vector2.ZERO)

func _weapon_skins_for(weapon_id: String) -> Array:
	return _weapon_ui.weapon_skins_for(weapon_id)

func _weapon_skin_label(weapon_id: String, skin_index: int) -> String:
	return _weapon_ui.weapon_skin_label(weapon_id, skin_index)

func _weapon_skin_cost(weapon_id: String, skin_index: int) -> int:
	return _weapon_ui.weapon_skin_cost(weapon_id, skin_index)

func _apply_weapon_skin_visual(target: CanvasItem, weapon_id: String, skin_index: int) -> void:
	_weapon_ui.apply_weapon_skin_visual(target, weapon_id, skin_index)

func _apply_weapon_skin_tint(target: CanvasItem, skin_index: int) -> void:
	push_warning("_apply_weapon_skin_tint is deprecated. Use _apply_weapon_skin_visual(target, weapon_id, skin_index).")
	_apply_weapon_skin_visual(target, _pending_weapon_id, skin_index)

func _build_warrior_shop_grid() -> void:
	_clear_children(warrior_grid)
	# 12 test skins (0..11) - enough to feel like a shop.
	for skin_index in range(12):
		var btn := _make_shop_button()
		btn.text = _warrior_skin_button_text(skin_index)
		btn.pressed.connect(Callable(self, "_on_warrior_skin_button_pressed").bind(skin_index))
		warrior_grid.add_child(btn)
		_center_pivot(btn)

func _build_weapon_shop_grid() -> void:
	_clear_children(weapon_grid)
	for weapon_id in [WEAPON_UZI, WEAPON_GRENADE]:
		for skin in _weapon_skins_for(weapon_id):
			var skin_index := int(skin.get("skin", 0))
			var btn := _weapon_ui.make_weapon_item_button(self, Callable(self, "_make_shop_button"), weapon_id, skin_index)
			btn.pressed.connect(Callable(self, "_on_weapon_item_button_pressed").bind(weapon_id, skin_index))
			weapon_grid.add_child(btn)
			_center_pivot(btn)

func _make_shop_button() -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# GridContainer sizes columns from children's minimum widths; keep this non-zero
	# so cells don't collapse into tiny boxes (which also hides the text).
	btn.custom_minimum_size = Vector2(170, 32)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.clip_text = true
	btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	btn.clip_contents = true

	# Clone the look from an existing styled button in the scene.
	_copy_button_look(options_button, btn)
	btn.add_theme_font_size_override("font_size", 11)
	_add_hover_pop(btn)
	return btn

func _copy_button_look(src: Button, dst: Button) -> void:
	if src == null or dst == null:
		return
	for sb_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		if src.has_theme_stylebox_override(sb_name):
			var sb := src.get_theme_stylebox(sb_name)
			dst.add_theme_stylebox_override(sb_name, sb)
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		if src.has_theme_color_override(color_name):
			var c := src.get_theme_color(color_name)
			dst.add_theme_color_override(color_name, c)
	if src.has_theme_font_override("font"):
		var f := src.get_theme_font("font")
		if f != null:
			dst.add_theme_font_override("font", f)

	# Ensure readable text even if the source doesn't override all states.
	dst.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98, 1))
	dst.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	dst.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	dst.add_theme_color_override("font_disabled_color", Color(0.65, 0.7, 0.75, 0.9))
	dst.add_theme_constant_override("outline_size", 0)

func _init_confirm_dialog() -> void:
	var overlay := CONFIRM_OVERLAY_SCRIPT.new()
	overlay.name = "ConfirmOverlay"
	add_child(overlay)
	overlay.configure(Callable(self, "_make_shop_button"), Callable(self, "_set_weapon_icon_sprite"), Callable(self, "_apply_weapon_skin_visual"))
	_confirm_overlay_ui = overlay

func _ask_confirm(title: String, text: String, on_confirm: Callable, weapon_id: String = "", skin_index: int = 0) -> void:
	if _confirm_overlay_ui == null:
		return
	_confirm_overlay_ui.call("ask", title, text, on_confirm, weapon_id, skin_index)

func _apply_pixel_slider_style(slider: HSlider) -> void:
	if slider == null:
		return
	_ensure_slider_grabbers()

	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	slider.add_theme_icon_override("grabber", _slider_grabber)
	slider.add_theme_icon_override("grabber_highlight", _slider_grabber_hi)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.11, 0.16, 0.95)
	track.border_width_left = 3
	track.border_width_top = 3
	track.border_width_right = 3
	track.border_width_bottom = 3
	track.border_color = Color(0.06, 0.05, 0.08, 1)
	track.content_margin_left = 6.0
	track.content_margin_right = 6.0
	track.content_margin_top = 4.0
	track.content_margin_bottom = 4.0
	slider.add_theme_stylebox_override("slider", track)

	var area := StyleBoxFlat.new()
	area.bg_color = Color(0.28, 0.24, 0.38, 0.25)
	area.border_width_left = 2
	area.border_width_top = 2
	area.border_width_right = 2
	area.border_width_bottom = 2
	area.border_color = Color(0.9, 0.74, 0.27, 0.5)
	slider.add_theme_stylebox_override("grabber_area_highlight", area)

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0.25, 0.6, 0.85, 0.18)
	focus.border_width_left = 2
	focus.border_width_top = 2
	focus.border_width_right = 2
	focus.border_width_bottom = 2
	focus.border_color = Color(0.25, 0.6, 0.85, 0.45)
	slider.add_theme_stylebox_override("focus", focus)

func _ensure_slider_grabbers() -> void:
	if _slider_grabber != null and _slider_grabber_hi != null:
		return
	var border := Color(0.06, 0.05, 0.08, 1)
	var fill := Color(0.9, 0.74, 0.27, 1)
	var fill_hi := Color(0.98, 0.9, 0.35, 1)

	var img := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	for x in range(9):
		img.set_pixel(x, 0, border)
		img.set_pixel(x, 8, border)
	for y in range(9):
		img.set_pixel(0, y, border)
		img.set_pixel(8, y, border)
	_slider_grabber = ImageTexture.create_from_image(img)

	var img_hi := Image.create(9, 9, false, Image.FORMAT_RGBA8)
	img_hi.fill(fill_hi)
	for x in range(9):
		img_hi.set_pixel(x, 0, border)
		img_hi.set_pixel(x, 8, border)
	for y in range(9):
		img_hi.set_pixel(0, y, border)
		img_hi.set_pixel(8, y, border)
	_slider_grabber_hi = ImageTexture.create_from_image(img_hi)

func _apply_grid_spacing(grid: GridContainer) -> void:
	if grid == null:
		return
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)

func _apply_pixel_scroll_style(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	_ensure_scrollbar_styleboxes()
	var vsb := scroll.get_v_scroll_bar()
	if vsb != null:
		_apply_pixel_scrollbar(vsb)
	var hsb := scroll.get_h_scroll_bar()
	if hsb != null:
		_apply_pixel_scrollbar(hsb)

	# Give the scroll area a subtle framed panel feel (if the theme key exists).
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.08, 0.08, 0.12, 0.35)
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.border_color = Color(0.06, 0.05, 0.08, 0.85)
	panel.content_margin_left = 6.0
	panel.content_margin_top = 6.0
	panel.content_margin_right = 6.0
	panel.content_margin_bottom = 6.0
	scroll.add_theme_stylebox_override("panel", panel)

func _apply_pixel_scrollbar(sb: ScrollBar) -> void:
	if sb == null:
		return
	sb.add_theme_stylebox_override("scroll", _scroll_sb)
	sb.add_theme_stylebox_override("scroll_focus", _scroll_sb)
	sb.add_theme_stylebox_override("grabber", _scroll_grabber)
	sb.add_theme_stylebox_override("grabber_highlight", _scroll_grabber_hi)
	sb.add_theme_stylebox_override("grabber_pressed", _scroll_grabber_pressed)

	sb.add_theme_constant_override("scrollbar_width", 12)
	sb.add_theme_constant_override("grabber_min_size", 28)

	# Hide arrows for a cleaner pixel look.
	sb.add_theme_icon_override("increment", _pixel_empty_icon())
	sb.add_theme_icon_override("decrement", _pixel_empty_icon())

func _ensure_scrollbar_styleboxes() -> void:
	if _scroll_sb != null:
		return
	var border := Color(0.06, 0.05, 0.08, 1)

	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.12, 0.11, 0.16, 0.85)
	track.border_width_left = 3
	track.border_width_top = 3
	track.border_width_right = 3
	track.border_width_bottom = 3
	track.border_color = border
	track.content_margin_left = 2.0
	track.content_margin_right = 2.0
	track.content_margin_top = 2.0
	track.content_margin_bottom = 2.0
	_scroll_sb = track

	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.22, 0.19, 0.3, 1)
	grab.border_width_left = 3
	grab.border_width_top = 3
	grab.border_width_right = 3
	grab.border_width_bottom = 3
	grab.border_color = border
	_scroll_grabber = grab

	var grab_hi := StyleBoxFlat.new()
	grab_hi.bg_color = Color(0.28, 0.24, 0.38, 1)
	grab_hi.border_width_left = 3
	grab_hi.border_width_top = 3
	grab_hi.border_width_right = 3
	grab_hi.border_width_bottom = 3
	grab_hi.border_color = Color(0.9, 0.74, 0.27, 1)
	_scroll_grabber_hi = grab_hi

	var grab_pressed := StyleBoxFlat.new()
	grab_pressed.bg_color = Color(0.14, 0.12, 0.2, 1)
	grab_pressed.border_width_left = 3
	grab_pressed.border_width_top = 3
	grab_pressed.border_width_right = 3
	grab_pressed.border_width_bottom = 3
	grab_pressed.border_color = border
	_scroll_grabber_pressed = grab_pressed

func _pixel_empty_icon() -> Texture2D:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _warrior_skin_cost(skin_index: int) -> int:
	if skin_index <= 0:
		return 0
	return 250 + skin_index * 120

func _warrior_skin_button_text(skin_index: int) -> String:
	var base := "Skin %d" % skin_index
	if _is_warrior_skin_owned(skin_index):
		if skin_index == selected_warrior_skin:
			return "%s  [EQUIPPED]" % base
		return "%s" % base
	return "%s  (%d)  [LOCKED]" % [base, _warrior_skin_cost(skin_index)]

func _select_warrior_skin(skin_index: int, silent: bool) -> void:
	_pending_warrior_skin = maxi(0, skin_index)
	_apply_warrior_skin_to_player(warrior_shop_preview, _pending_warrior_skin)
	warrior_name_label.text = "Skin %d" % _pending_warrior_skin
	_refresh_warrior_grid_texts()
	if not silent:
		_pop(warrior_shop_preview)

func _equip_warrior_skin(skin_index: int) -> void:
	selected_warrior_skin = maxi(0, skin_index)
	_pending_warrior_skin = selected_warrior_skin
	_apply_warrior_skin_to_player(main_warrior_preview, selected_warrior_skin)
	_apply_warrior_skin_to_player(warrior_shop_preview, selected_warrior_skin)
	warrior_name_label.text = "Skin %d" % selected_warrior_skin
	_save_state()
	_refresh_warrior_grid_texts()
	_pop(warrior_shop_preview)

func _try_buy_and_equip_warrior_skin(skin_index: int) -> void:
	var idx := maxi(0, skin_index)
	if _is_warrior_skin_owned(idx):
		_equip_warrior_skin(idx)
		return
	var cost := _warrior_skin_cost(idx)
	if wallet_coins < cost:
		_shake(wallet_panel)
		return
	wallet_coins -= cost
	owned_warrior_skins.append(idx)
	owned_warrior_skins.sort()
	_update_wallet_labels(false)
	_equip_warrior_skin(idx)
	_pixel_burst_at(_center_of(wallet_panel), Color(0.25, 1, 0.85, 1))

func _on_warrior_skin_button_pressed(skin_index: int) -> void:
	var idx := maxi(0, skin_index)
	_pending_warrior_skin = idx
	_apply_warrior_skin_to_player(warrior_shop_preview, idx)
	warrior_name_label.text = "Skin %d" % idx
	_refresh_warrior_grid_texts()

	if _is_warrior_skin_owned(idx):
		_equip_warrior_skin(idx)
		return
	var cost := _warrior_skin_cost(idx)
	_ask_confirm("Buy skin?", "Buy Skin %d for %d coins?" % [idx, cost], Callable(self, "_try_buy_and_equip_warrior_skin").bind(idx))

func _refresh_warrior_grid_texts() -> void:
	var i := 0
	for child in warrior_grid.get_children():
		var b := child as Button
		if b != null:
			b.text = _warrior_skin_button_text(i)
		i += 1

func _refresh_warrior_action() -> void:
	if _is_warrior_skin_owned(_pending_warrior_skin):
		if _pending_warrior_skin == selected_warrior_skin:
			warrior_action_button.text = "EQUIPPED"
			warrior_action_button.disabled = true
		else:
			warrior_action_button.text = "EQUIP"
			warrior_action_button.disabled = false
		return

	warrior_action_button.disabled = false
	warrior_action_button.text = "BUY  (%d)" % _warrior_skin_cost(_pending_warrior_skin)

func _on_warrior_action_pressed() -> void:
	_button_press_anim(warrior_action_button)
	if _is_warrior_skin_owned(_pending_warrior_skin):
		_equip_warrior_skin(_pending_warrior_skin)
		return

	var cost := _warrior_skin_cost(_pending_warrior_skin)
	if wallet_coins < cost:
		_shake(wallet_panel)
		return

	_try_buy_and_equip_warrior_skin(_pending_warrior_skin)

func _is_warrior_skin_owned(skin_index: int) -> bool:
	return owned_warrior_skins.has(skin_index)

func _weapon_is_owned(weapon_id: String) -> bool:
	return owned_weapons.has(weapon_id.strip_edges().to_lower())

func _weapon_skin_is_owned(weapon_id: String, skin_index: int) -> bool:
	var normalized := weapon_id.strip_edges().to_lower()
	if not owned_weapon_skins_by_weapon.has(normalized):
		return skin_index == 0
	var arr := owned_weapon_skins_by_weapon[normalized] as PackedInt32Array
	if arr == null:
		return skin_index == 0
	return arr.has(skin_index)

func _weapon_item_button_text(weapon_id: String, skin_index: int) -> String:
	var w := weapon_id.to_upper()
	var skin_name := _weapon_skin_label(weapon_id, skin_index)

	var base := "%s  -  %s" % [w, skin_name]
	if not _weapon_is_owned(weapon_id):
		var weapon_cost := int(DATA.WEAPON_BASE_COST_BY_ID.get(weapon_id, 0))
		if weapon_cost <= 0:
			return "%s  [LOCKED]" % base
		return "%s  (%d)  [LOCKED]" % [base, weapon_cost]

	if _weapon_skin_is_owned(weapon_id, skin_index):
		if weapon_id == selected_weapon_id and skin_index == selected_weapon_skin:
			return "%s  [EQUIPPED]" % base
		return base

	return "%s  (%d)  [LOCKED]" % [base, _weapon_skin_cost(weapon_id, skin_index)]

func _select_weapon_skin(weapon_id: String, skin_index: int, silent: bool) -> void:
	_pending_weapon_id = weapon_id.strip_edges().to_lower()
	_pending_weapon_skin = maxi(0, skin_index)

	_set_weapon_icon_sprite(weapon_shop_preview, _pending_weapon_id)
	_apply_weapon_skin_visual(weapon_shop_preview, _pending_weapon_id, _pending_weapon_skin)

	weapon_name_label.text = "%s - %s" % [_pending_weapon_id.to_upper(), _weapon_skin_label(_pending_weapon_id, _pending_weapon_skin)]
	_refresh_weapon_grid_texts()
	if not silent:
		_pop(weapon_shop_preview)

func _equip_weapon_item(weapon_id: String, skin_index: int) -> void:
	selected_weapon_id = weapon_id.strip_edges().to_lower()
	selected_weapon_skin = maxi(0, skin_index)
	_pending_weapon_id = selected_weapon_id
	_pending_weapon_skin = selected_weapon_skin
	_set_weapon_icon_sprite(main_weapon_icon, selected_weapon_id)
	_apply_weapon_skin_visual(main_weapon_icon, selected_weapon_id, selected_weapon_skin)
	_set_weapon_icon_sprite(weapon_shop_preview, selected_weapon_id)
	_apply_weapon_skin_visual(weapon_shop_preview, selected_weapon_id, selected_weapon_skin)
	weapon_name_label.text = "%s - %s" % [selected_weapon_id.to_upper(), _weapon_skin_label(selected_weapon_id, selected_weapon_skin)]
	_save_state()
	_refresh_weapon_grid_texts()
	_pop(main_weapon_icon)
	_pop(weapon_shop_preview)

func _buy_weapon_if_needed(weapon_id: String) -> bool:
	var normalized := weapon_id.strip_edges().to_lower()
	if _weapon_is_owned(normalized):
		return true
	var cost := int(DATA.WEAPON_BASE_COST_BY_ID.get(normalized, 0))
	if cost <= 0:
		return false
	if wallet_coins < cost:
		_shake(wallet_panel)
		return false
	wallet_coins -= cost
	owned_weapons.append(normalized)
	_update_wallet_labels(false)
	_save_state()
	return true

func _buy_weapon_skin_if_needed(weapon_id: String, skin_index: int) -> bool:
	var normalized := weapon_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	if _weapon_skin_is_owned(normalized, idx):
		return true
	var cost := _weapon_skin_cost(normalized, idx)
	if cost <= 0:
		return false
	if wallet_coins < cost:
		_shake(wallet_panel)
		return false
	wallet_coins -= cost
	var arr := owned_weapon_skins_by_weapon.get(normalized, PackedInt32Array([0])) as PackedInt32Array
	if not arr.has(idx):
		arr.append(idx)
		arr.sort()
	owned_weapon_skins_by_weapon[normalized] = arr
	_update_wallet_labels(false)
	_save_state()
	return true

func _confirm_buy_weapon_skin_and_equip(weapon_id: String, skin_index: int) -> void:
	var normalized := weapon_id.strip_edges().to_lower()
	if not _buy_weapon_skin_if_needed(normalized, skin_index):
		return
	_equip_weapon_item(normalized, skin_index)

func _confirm_buy_weapon_then_maybe_skin(weapon_id: String, skin_index: int) -> void:
	var normalized := weapon_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	if not _buy_weapon_if_needed(normalized):
		return
	if _weapon_skin_is_owned(normalized, idx):
		_equip_weapon_item(normalized, idx)
		return
	var skin_cost := _weapon_skin_cost(normalized, idx)
	var skin_name := _weapon_skin_label(normalized, idx)
	_ask_confirm("Buy skin?", "Buy %s - %s for %d coins?" % [normalized.to_upper(), skin_name, skin_cost], Callable(self, "_confirm_buy_weapon_skin_and_equip").bind(normalized, idx), normalized, idx)

func _on_weapon_item_button_pressed(weapon_id: String, skin_index: int) -> void:
	var normalized := weapon_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)

	var needs_weapon := not _weapon_is_owned(normalized)
	var needs_skin := not _weapon_skin_is_owned(normalized, idx)

	# Don't alter the currently equipped weapon UI while we're still confirming a purchase.
	if needs_weapon or needs_skin:
		if needs_weapon:
			var weapon_cost := int(DATA.WEAPON_BASE_COST_BY_ID.get(normalized, 0))
			_ask_confirm("Buy gun?", "Buy %s for %d coins?" % [normalized.to_upper(), weapon_cost], Callable(self, "_confirm_buy_weapon_then_maybe_skin").bind(normalized, idx), normalized, idx)
		else:
			var skin_cost := _weapon_skin_cost(normalized, idx)
			var skin_name := _weapon_skin_label(normalized, idx)
			_ask_confirm("Buy skin?", "Buy %s - %s for %d coins?" % [normalized.to_upper(), skin_name, skin_cost], Callable(self, "_confirm_buy_weapon_skin_and_equip").bind(normalized, idx), normalized, idx)
		return

	_pending_weapon_id = normalized
	_pending_weapon_skin = idx
	_set_weapon_icon_sprite(weapon_shop_preview, normalized)
	_apply_weapon_skin_visual(weapon_shop_preview, normalized, idx)
	weapon_name_label.text = "%s - %s" % [normalized.to_upper(), _weapon_skin_label(normalized, idx)]
	_refresh_weapon_grid_texts()

	if not needs_weapon and not needs_skin:
		_equip_weapon_item(normalized, idx)
		return

func _refresh_weapon_grid_texts() -> void:
	for child in weapon_grid.get_children():
		var b := child as Button
		if b != null:
			_weapon_ui.update_weapon_item_button(self, b)

func _refresh_weapon_action() -> void:
	if not _weapon_is_owned(_pending_weapon_id):
		var weapon_cost := int(DATA.WEAPON_BASE_COST_BY_ID.get(_pending_weapon_id, 0))
		weapon_action_button.disabled = weapon_cost <= 0
		weapon_action_button.text = "BUY GUN  (%d)" % weapon_cost
		return

	if _weapon_skin_is_owned(_pending_weapon_id, _pending_weapon_skin):
		if _pending_weapon_id == selected_weapon_id and _pending_weapon_skin == selected_weapon_skin:
			weapon_action_button.text = "EQUIPPED"
			weapon_action_button.disabled = true
		else:
			weapon_action_button.text = "EQUIP"
			weapon_action_button.disabled = false
		return

	weapon_action_button.disabled = false
	weapon_action_button.text = "BUY SKIN  (%d)" % _weapon_skin_cost(_pending_weapon_id, _pending_weapon_skin)

func _on_weapon_action_pressed() -> void:
	_button_press_anim(weapon_action_button)

	if not _weapon_is_owned(_pending_weapon_id):
		_confirm_buy_weapon_then_maybe_skin(_pending_weapon_id, _pending_weapon_skin)
		return

	if _weapon_skin_is_owned(_pending_weapon_id, _pending_weapon_skin):
		_equip_weapon_item(_pending_weapon_id, _pending_weapon_skin)
		return

	var cost := _weapon_skin_cost(_pending_weapon_id, _pending_weapon_skin)
	if wallet_coins < cost:
		_shake(wallet_panel)
		return

	_confirm_buy_weapon_skin_and_equip(_pending_weapon_id, _pending_weapon_skin)

func _center_of(ci: CanvasItem) -> Vector2:
	if ci == null:
		return Vector2.ZERO
	if ci is Control:
		var c := ci as Control
		return c.global_position + c.size * 0.5
	return ci.get_global_transform().origin

func _pixel_burst_at(global_pos: Vector2, color: Color) -> void:
	if _fx_layer == null:
		return
	var count := maxi(0, intro_fx_particles_per_burst)
	if count <= 0:
		return
	# Guard against runaway node creation if something goes wrong.
	if _fx_layer.get_child_count() > 400:
		push_error("FxLayer overflow during intro (children=%d). Disabling FX." % int(_fx_layer.get_child_count()))
		intro_fx_enabled = false
		for child in _fx_layer.get_children():
			child.queue_free()
		return
	for i in range(count):
		var p := TextureRect.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.texture = DATA.BULLET_TEXTURE
		p.modulate = Color(color.r, color.g, color.b, 0.9)
		p.custom_minimum_size = Vector2(6, 6)
		p.size = Vector2(6, 6)
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_fx_layer.add_child(p)
		p.global_position = global_pos - Vector2(3, 3)

		var angle := randf() * TAU
		var dist := randf_range(18.0, 70.0)
		var drift := Vector2(cos(angle), sin(angle)) * dist + Vector2(randf_range(-10, 10), randf_range(-10, 10))

		var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(p, "global_position", p.global_position + drift, 0.5)
		t.parallel().tween_property(p, "modulate:a", 0.0, 0.5)
		t.parallel().tween_property(p, "rotation", randf_range(-2.5, 2.5), 0.5)
		t.parallel().tween_property(p, "scale", Vector2(1.8, 1.8), 0.5)
		t.tween_callback(func() -> void: p.queue_free())

func _load_state_or_defaults() -> void:
	var defaults := {
		"coins": 1000000,
		"clk": 50000,
		"owned_warrior_skins": [0],
		"selected_warrior_skin": 0,
		"owned_weapons": [WEAPON_UZI],
		"owned_weapon_skins_by_weapon": {WEAPON_UZI: [0], WEAPON_GRENADE: [0]},
		"selected_weapon_id": WEAPON_UZI,
		"selected_weapon_skin": 0,
	}
	var st := _state_store.load_state_or_defaults(DATA.SHOP_STATE_PATH, defaults, WEAPON_UZI)

	wallet_coins = int(st.get("coins", 0))
	wallet_clk = int(st.get("clk", 0))

	owned_warrior_skins = PackedInt32Array(st.get("owned_warrior_skins", [0]) as Array)
	selected_warrior_skin = maxi(0, int(st.get("selected_warrior_skin", 0)))

	owned_weapons = PackedStringArray(st.get("owned_weapons", [WEAPON_UZI]) as Array)
	selected_weapon_id = str(st.get("selected_weapon_id", WEAPON_UZI)).strip_edges().to_lower()
	selected_weapon_skin = maxi(0, int(st.get("selected_weapon_skin", 0)))

	# Sanitize weapon ids (remove weapons that no longer exist in this menu).
	var allowed := PackedStringArray([WEAPON_UZI, WEAPON_GRENADE])
	var filtered_owned := PackedStringArray()
	for wid in owned_weapons:
		var w := str(wid).strip_edges().to_lower()
		if allowed.has(w):
			filtered_owned.append(w)
	owned_weapons = filtered_owned
	if not owned_weapons.has(WEAPON_UZI):
		owned_weapons.append(WEAPON_UZI)

	var out := {}
	var skins_dict := st.get("owned_weapon_skins_by_weapon", {}) as Dictionary
	for key in skins_dict.keys():
		var wid := str(key).strip_edges().to_lower()
		if not allowed.has(wid):
			continue
		var arr := skins_dict.get(key, [0]) as Array
		out[wid] = PackedInt32Array(arr)
	owned_weapon_skins_by_weapon = out

	# Ensure required dictionaries exist for current weapons.
	for wid in allowed:
		if not owned_weapon_skins_by_weapon.has(wid):
			owned_weapon_skins_by_weapon[wid] = PackedInt32Array([0])

	# Clamp selections to owned.
	if not _is_warrior_skin_owned(selected_warrior_skin):
		selected_warrior_skin = 0
	if not _weapon_is_owned(selected_weapon_id):
		selected_weapon_id = WEAPON_UZI
	if not _weapon_skin_is_owned(selected_weapon_id, selected_weapon_skin):
		selected_weapon_skin = 0

func _save_state() -> void:
	var owned_warrior_list: Array = []
	for v in owned_warrior_skins:
		owned_warrior_list.append(int(v))

	var owned_weapons_list: Array = []
	for w in owned_weapons:
		owned_weapons_list.append(str(w))

	var owned_weapon_skins_dict: Dictionary = {}
	for wid in owned_weapon_skins_by_weapon.keys():
		var arr := owned_weapon_skins_by_weapon.get(wid, PackedInt32Array([0])) as PackedInt32Array
		var out_arr: Array = []
		if arr != null:
			for s in arr:
				out_arr.append(int(s))
		owned_weapon_skins_dict[str(wid)] = out_arr

	var d := {
		"coins": wallet_coins,
		"clk": wallet_clk,
		"owned_warrior_skins": owned_warrior_list,
		"selected_warrior_skin": selected_warrior_skin,
		"owned_weapons": owned_weapons_list,
		"owned_weapon_skins_by_weapon": owned_weapon_skins_dict,
		"selected_weapon_id": selected_weapon_id,
		"selected_weapon_skin": selected_weapon_skin,
	}
	_state_store.save_state(DATA.SHOP_STATE_PATH, d)

func _update_wallet_labels(silent: bool) -> void:
	coins_label.text = "Coins: %d" % wallet_coins
	clk_label.text = "CLK: %d" % wallet_clk
	if not silent:
		_pop(wallet_panel)

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()

func _add_hover_pop(btn: Button) -> void:
	if btn == null:
		return
	btn.mouse_entered.connect(func() -> void:
		btn.set_meta("kw_hovered", true)
		_tween_scale(btn, Vector2(1.04, 1.04), 0.12)
	)
	btn.mouse_exited.connect(func() -> void:
		btn.set_meta("kw_hovered", false)
		_tween_scale(btn, Vector2(1, 1), 0.14)
	)
	btn.button_down.connect(func() -> void: _press_in(btn, 0.94))
	btn.button_up.connect(func() -> void: _release_to_hover(btn, btn))

func _hover_area(area: Control, hovered: bool) -> void:
	if area == null:
		return
	var target := Vector2(1.045, 1.045) if hovered else Vector2(1, 1)
	_tween_scale(area, target, 0.12)

func _press_in(ci: CanvasItem, target_mult: float) -> void:
	if ci == null:
		return
	_tween_scale(ci, ci.scale * target_mult, 0.06)

func _release_to_hover(ci: CanvasItem, btn: Button) -> void:
	if ci == null:
		return
	var hovered := false
	if btn != null and btn.has_meta("kw_hovered"):
		hovered = bool(btn.get_meta("kw_hovered"))
	var target := Vector2(1.04, 1.04) if hovered else Vector2(1, 1)
	_tween_scale(ci, target, 0.08)

func _button_press_anim(ci: CanvasItem, extra_scale: float = 0.06) -> void:
	if ci == null:
		return
	var start_scale: Vector2 = Vector2.ONE
	if ci is Node2D:
		start_scale = (ci as Node2D).scale
	elif ci is Control:
		start_scale = (ci as Control).scale
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ci, "scale", start_scale * (1.0 - extra_scale * 0.6), 0.06)
	t.tween_property(ci, "scale", start_scale * (1.0 + extra_scale), 0.12)
	t.tween_property(ci, "scale", start_scale, 0.08)

func _tween_scale(ci: CanvasItem, target_scale: Vector2, duration: float) -> void:
	if ci == null:
		return
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(ci, "scale", target_scale, duration)

func _pop(ci: CanvasItem) -> void:
	if ci == null:
		return
	var start_scale: Vector2 = Vector2.ONE
	if ci is Node2D:
		start_scale = (ci as Node2D).scale
	elif ci is Control:
		start_scale = (ci as Control).scale
	var t := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(ci, "scale", start_scale * 1.08, 0.12)
	t.tween_property(ci, "scale", start_scale, 0.16)

func _shake(ci: CanvasItem) -> void:
	if ci == null:
		return
	var base := Vector2.ZERO
	if ci is Control:
		base = (ci as Control).position
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(ci, "position", base + Vector2(-6, 0), 0.05)
	t.tween_property(ci, "position", base + Vector2(6, 0), 0.05)
	t.tween_property(ci, "position", base + Vector2(-4, 0), 0.05)
	t.tween_property(ci, "position", base + Vector2(4, 0), 0.05)
	t.tween_property(ci, "position", base, 0.05)

func _start_idle_loop() -> void:
	_stop_idle_loop()
	if _current_screen != screen_main:
		return

	_idle_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if logo_node != null:
		_idle_tween.parallel().tween_property(logo_node, "position", _logo_base_pos + Vector2(0, -4), 1.1)
	_idle_tween.parallel().tween_property(warrior_area, "position", _warrior_area_base_pos + Vector2(0, -4), 1.1)
	_idle_tween.parallel().tween_property(weapon_area, "position", _weapon_area_base_pos + Vector2(0, 4), 1.1)
	_idle_tween.parallel().tween_property(play_button, "scale", Vector2(1.03, 1.03), 1.1)
	_idle_tween.parallel().tween_property($BgNoise, "modulate:a", minf(0.16, _bgnoise_base_alpha + 0.05), 1.1)
	_idle_tween.tween_interval(0.02)
	if logo_node != null:
		_idle_tween.parallel().tween_property(logo_node, "position", _logo_base_pos, 1.1)
	_idle_tween.parallel().tween_property(warrior_area, "position", _warrior_area_base_pos, 1.1)
	_idle_tween.parallel().tween_property(weapon_area, "position", _weapon_area_base_pos, 1.1)
	_idle_tween.parallel().tween_property(play_button, "scale", Vector2(1, 1), 1.1)
	_idle_tween.parallel().tween_property($BgNoise, "modulate:a", _bgnoise_base_alpha, 1.1)

func _stop_idle_loop() -> void:
	if _idle_tween != null:
		_idle_tween.kill()
		_idle_tween = null
	_node_set_pos(logo_node, _logo_base_pos)
	if warrior_area != null:
		warrior_area.position = _warrior_area_base_pos
	if weapon_area != null:
		weapon_area.position = _weapon_area_base_pos
	var bg := $BgNoise as CanvasItem
	if bg != null:
		bg.modulate.a = _bgnoise_base_alpha
	if play_button != null:
		play_button.scale = Vector2(1, 1)

func _node_pos(n: Node) -> Vector2:
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
