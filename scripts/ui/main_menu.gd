extends Control

const DATA := preload("res://scripts/ui/main_menu/data.gd")
const CURSOR_MANAGER_SCRIPT := preload("res://scripts/ui/cursor_manager.gd")
const CURSOR_MANAGER_NAME := "CursorManager"
const WARRIOR_UI_SCRIPT := preload("res://scripts/ui/main_menu/warrior_ui.gd")
const WEAPON_UI_SCRIPT := preload("res://scripts/ui/main_menu/weapon_ui.gd")
const STATE_STORE_SCRIPT := preload("res://scripts/ui/main_menu/state_store.gd")
const INTRO_FX_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/intro_fx_controller.gd")
const CONFIRM_OVERLAY_SCRIPT := preload("res://scripts/ui/main_menu/confirm_overlay.gd")
const LOBBY_OVERLAY_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/lobby_overlay_controller.gd")
const AUTH_FLOW_SCRIPT := preload("res://scripts/ui/main_menu/auth_flow.gd")
const UI_ANIMATOR_SCRIPT := preload("res://scripts/ui/main_menu/ui_animator.gd")
const MENU_TRANSITION_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/menu_transition_controller.gd")
const IDLE_ANIMATOR_SCRIPT := preload("res://scripts/ui/main_menu/idle_animator.gd")
const SHOP_CONTROLLER_SCRIPT := preload("res://scripts/ui/main_menu/shop_controller.gd")
const MENU_SFX_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/audio/menu_sfx_controller.gd")
const MENU_LOADING_OVERLAY_SCRIPT := preload("res://scripts/ui/main_menu/loading/menu_loading_overlay.gd")
const MENU_THEME_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/main_menu_theme_controller.gd")
const MENU_META_UI_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/main_menu_meta_ui_controller.gd")
const MENU_NAV_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/main_menu_navigation_controller.gd")
const MENU_PALETTE := preload("res://scripts/ui/main_menu/menu_palette.gd")
const AUTH_API_BASE_URL_DEFAULT := "http://127.0.0.1:8081/auth"
const ENABLE_MENU_LOADING_OVERLAY := false
var MENU_CLR_BASE := MENU_PALETTE.base()
var MENU_CLR_ACCENT := MENU_PALETTE.accent()
var MENU_CLR_HOT := MENU_PALETTE.hot()
var MENU_CLR_HIGHLIGHT := MENU_PALETTE.highlight()

const WEAPON_UZI := DATA.WEAPON_UZI
const WEAPON_GRENADE := DATA.WEAPON_GRENADE
const WEAPON_AK47 := DATA.WEAPON_AK47
const WEAPON_KAR := DATA.WEAPON_KAR
const WEAPON_SHOTGUN := DATA.WEAPON_SHOTGUN

@export var enable_intro_animation := true
@export var intro_timeout_sec := 6.0
@export var intro_failfast_quit := true
@export var intro_fx_enabled := true
@export var intro_fx_particles_per_burst := 12

@export var warriors_menu_preview_scale_mult := 1.25
@export var weapons_menu_preview_scale_mult := 0.95
@export var weapon_icon_max_height_ratio := 0.42
@export var rainbow_skin_cost := 5000
@export var play_lobby_expand_duration := 0.56
@export var play_lobby_border_fade_duration := 0.22
@export var play_lobby_shrink_duration := 0.48

var _warrior_ui := WARRIOR_UI_SCRIPT.new()
var _weapon_ui := WEAPON_UI_SCRIPT.new()
var _state_store := STATE_STORE_SCRIPT.new()
var _intro_fx := INTRO_FX_CTRL_SCRIPT.new()
var _lobby_overlay_ctrl := LOBBY_OVERLAY_CTRL_SCRIPT.new()
var _auth_flow := AUTH_FLOW_SCRIPT.new()
var _ui_anim := UI_ANIMATOR_SCRIPT.new()
var _menu_transition_ctrl := MENU_TRANSITION_CTRL_SCRIPT.new()
var _idle_anim := IDLE_ANIMATOR_SCRIPT.new()
var _shop_controller := SHOP_CONTROLLER_SCRIPT.new()
var _menu_sfx = MENU_SFX_CTRL_SCRIPT.new()
var _menu_loading_overlay = MENU_LOADING_OVERLAY_SCRIPT.new()
var _menu_theme := MENU_THEME_CTRL_SCRIPT.new()
var _meta_ui := MENU_META_UI_CTRL_SCRIPT.new()
var _menu_nav := MENU_NAV_CTRL_SCRIPT.new()

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
@onready var warriors_panel: PanelContainer = $Screens/ScreenWarriors/WarriorsPanel
@onready var warriors_body_row: HBoxContainer = $Screens/ScreenWarriors/WarriorsPanel/Margin/OuterVBox/BodyRow
@onready var warrior_shop_preview: Node = %WarriorShopPreview
@onready var warrior_name_label: Label = %WarriorNameLabel
@onready var warrior_action_button: Button = %WarriorActionButton

@onready var weapon_grid: GridContainer = %WeaponGrid
@onready var weapon_scroll: ScrollContainer = $Screens/ScreenWeapons/WeaponsPanel/Margin/OuterVBox/BodyRow/ListCol/WeaponScroll
@onready var weapons_panel: PanelContainer = $Screens/ScreenWeapons/WeaponsPanel
@onready var weapons_body_row: HBoxContainer = $Screens/ScreenWeapons/WeaponsPanel/Margin/OuterVBox/BodyRow
@onready var weapon_shop_preview: Sprite2D = %WeaponShopPreview
@onready var weapon_name_label: Label = %WeaponNameLabel
@onready var weapon_action_button: Button = %WeaponActionButton

var wallet_coins := 0
var wallet_clk := 0

var owned_warriors := PackedStringArray()
var owned_warrior_skins := PackedInt32Array([0])
var owned_warrior_skins_by_warrior: Dictionary = {}
var equipped_warrior_skin_by_warrior: Dictionary = {}
var selected_warrior_id := "outrage"
var selected_warrior_skin := 0
var _pending_warrior_id := "outrage"
var _pending_warrior_skin := 0

var owned_weapons := PackedStringArray([WEAPON_UZI])
var owned_weapon_skins_by_weapon: Dictionary = {
	WEAPON_UZI: PackedInt32Array([0]),
	WEAPON_GRENADE: PackedInt32Array([0]),
	WEAPON_AK47: PackedInt32Array([0]),
	WEAPON_KAR: PackedInt32Array([0]),
	WEAPON_SHOTGUN: PackedInt32Array([0]),
}
var equipped_weapon_skin_by_weapon: Dictionary = {
	WEAPON_UZI: 0,
	WEAPON_AK47: 0,
	WEAPON_KAR: 0,
	WEAPON_SHOTGUN: 0,
	WEAPON_GRENADE: 0,
}
var selected_weapon_id := WEAPON_UZI
var selected_weapon_skin := 0
var _pending_weapon_id := WEAPON_UZI
var _pending_weapon_skin := 0
var _visible_weapon_id := WEAPON_UZI
var _visible_weapon_skin := 0
var player_username := ""
var _warrior_username_label: Label

var _weapon_filter_weapon_id := ""
var _weapon_filter_category := ""
var _weapon_filter_weapon_buttons: Dictionary = {}
var _weapon_filter_category_buttons: Dictionary = {}
var _warrior_filter_warrior_id := ""
var _warrior_filter_warrior_buttons: Dictionary = {}
var _warrior_filters_row: HBoxContainer
var _warrior_filters_bridge_holder: Control
var _warrior_filters_bridge: Panel

var _current_screen: Control
var _transition_tween: Tween
var _fx_layer: Control
var _play_lobby_tween: Tween
var _play_lobby_panel: PanelContainer
var _play_lobby_transition_running := false
var _play_lobby_fade_targets: Array[CanvasItem] = []
var _play_lobby_fade_base_alpha: Dictionary = {}
var _main_warrior_preview_base_scale := Vector2.ONE
var _warrior_shop_preview_base_scale := Vector2.ONE
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

var _auth_api_base_url := AUTH_API_BASE_URL_DEFAULT
var _auth_profile := "default"
var _auth_login_base_url_candidates := PackedStringArray()
var _auth_login_base_url_index := 0
var _auth_login_payload := ""
var _auth_token := ""
var _auth_logged_in := false
var _auth_pending_action := ""
var _auth_pending_purchase_skin_index := -1
var _auth_wallet_sync_queued := false
var _auth_wallet_sync_endpoint_candidates: Array = ["/wallet/update", "/wallet/update/", "/wallet"]
var _auth_wallet_sync_endpoint_index := 0
var _auth_wallet_sync_supported := true
var _auth_wallet_sync_snapshot_active := false
var _auth_wallet_sync_snapshot: Dictionary = {}
var _auth_wallet_retry_timer: Timer
var _auth_request_watchdog_timer: Timer
var _auth_http: HTTPRequest
var _auth_overlay: Control
var _auth_status_label: Label
var _auth_user_input: LineEdit
var _auth_pass_input: LineEdit
var _auth_login_button: Button
var _auth_logout_button: Button
var _auth_footer_panel: PanelContainer
var _auth_footer_label: Label
var _meta_username_tween: Tween
var _meta_footer_tween: Tween

func _ready() -> void:
	_ensure_cursor_manager()
	_menu_sfx.configure(self)
	_menu_loading_overlay.configure(self)
	_current_screen = screen_main
	randomize()
	_weapon_ui.weapon_icon_max_height_ratio = weapon_icon_max_height_ratio
	_weapon_ui.weapons_menu_preview_scale_mult = weapons_menu_preview_scale_mult
	_weapon_ui.rainbow_skin_cost = rainbow_skin_cost
	_load_state_or_defaults()
	_ensure_warrior_username_label()
	_refresh_warrior_username_label()
	_weapon_filter_weapon_id = selected_weapon_id
	set_process_input(true)
	set_process_unhandled_input(true)
	_init_confirm_dialog()
	_lobby_overlay_ctrl.configure(
		self,
		Callable(self, "_make_shop_button"),
		Callable(self, "_add_hover_pop"),
		Callable(self, "_bind_menu_sfx_option"),
		Callable(self, "_center_pivot"),
		Callable(self, "_pixel_burst_at"),
		Callable(self, "_center_of"),
		Callable(self, "_on_lobby_overlay_closed")
	)
	_intro_fx.configure(self, intro, intro_fade, intro_plate, intro_label, Callable(self, "_pixel_burst_at"))
	_intro_fx.enable_intro_animation = enable_intro_animation
	_intro_fx.intro_timeout_sec = intro_timeout_sec
	_intro_fx.intro_fx_enabled = intro_fx_enabled
	_on_music_slider_changed(music_slider.value if music_slider != null else 1.0)
	_on_sfx_slider_changed(sfx_slider.value if sfx_slider != null else 1.0)

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

	_menu_transition_ctrl.configure(
		{
			"host": self,
			"screen_main": screen_main,
			"screen_warriors": screen_warriors,
			"screen_weapons": screen_weapons,
			"main_warrior_preview": main_warrior_preview,
			"warrior_shop_preview": warrior_shop_preview,
			"main_weapon_icon": main_weapon_icon,
			"weapon_shop_preview": weapon_shop_preview,
			"fx_layer": _fx_layer,
			"weapon_ui": _weapon_ui,
		},
		{
			"set_current_screen": Callable(self, "_set_current_screen_ref"),
			"stop_idle_loop": Callable(self, "_stop_idle_loop"),
			"start_idle_loop": Callable(self, "_start_idle_loop"),
			"set_weapon_icon_sprite": Callable(self, "_set_weapon_icon_sprite"),
			"apply_weapon_skin_visual": Callable(self, "_apply_weapon_skin_visual"),
		}
	)

	_idle_anim.configure(
		{
			"host": self,
			"screen_main": screen_main,
			"screen_warriors": screen_warriors,
			"screen_weapons": screen_weapons,
			"main_weapon_icon": main_weapon_icon,
			"warrior_area": warrior_area,
			"weapon_area": weapon_area,
			"play_button": play_button,
			"bg_noise": $BgNoise,
			"logo_node": logo_node,
			"warrior_shop_preview": warrior_shop_preview,
			"weapon_shop_preview": weapon_shop_preview,
		}
	)

	_logo_base_pos = _idle_anim.node_pos(logo_node)
	_warrior_area_base_pos = warrior_area.position
	_weapon_area_base_pos = weapon_area.position
	var warrior_shop_preview_base_pos := _idle_anim.node_pos(warrior_shop_preview)
	var weapon_shop_preview_base_pos := _idle_anim.node_pos(weapon_shop_preview)
	var bg := $BgNoise as CanvasItem
	if bg != null:
		_bgnoise_base_alpha = bg.modulate.a
	_idle_anim.set_base_state(_logo_base_pos, _warrior_area_base_pos, _weapon_area_base_pos, _bgnoise_base_alpha)
	_idle_anim.set_shop_base_state(warrior_shop_preview_base_pos, weapon_shop_preview_base_pos)

	call_deferred("_apply_center_pivots")
	_apply_pixel_slider_style(music_slider)
	_apply_pixel_slider_style(sfx_slider)
	_apply_pixel_scroll_style(warrior_scroll)
	_apply_pixel_scroll_style(weapon_scroll)
	_apply_grid_spacing(warrior_grid)
	_apply_grid_spacing(weapon_grid)
	if warrior_grid != null:
		warrior_grid.add_theme_constant_override("h_separation", 6)
		warrior_grid.add_theme_constant_override("v_separation", 6)
	_ensure_auth_logout_button()
	if warrior_action_button != null:
		warrior_action_button.visible = false
		warrior_action_button.disabled = true
	if weapon_action_button != null:
		weapon_action_button.visible = false
		weapon_action_button.disabled = true
	_prepare_player_preview(main_warrior_preview)
	_prepare_player_preview(warrior_shop_preview)

	if main_warrior_preview is Node2D:
		_main_warrior_preview_base_scale = (main_warrior_preview as Node2D).scale
	if warrior_shop_preview is Node2D:
		_warrior_shop_preview_base_scale = (warrior_shop_preview as Node2D).scale
	if weapon_shop_preview != null:
		_weapon_shop_preview_base_scale = weapon_shop_preview.scale

	_apply_warrior_skin_to_player(main_warrior_preview, selected_warrior_id, selected_warrior_skin)
	_apply_warrior_skin_to_player(warrior_shop_preview, selected_warrior_id, selected_warrior_skin)

	_set_weapon_icon_sprite(main_weapon_icon, _pending_weapon_id, 1.0, _pending_weapon_skin)
	_apply_weapon_skin_visual(main_weapon_icon, _pending_weapon_id, _pending_weapon_skin)
	_set_weapon_icon_sprite(weapon_shop_preview, selected_weapon_id, 1.0, selected_weapon_skin)
	_apply_weapon_skin_visual(weapon_shop_preview, selected_weapon_id, selected_weapon_skin)

	_update_wallet_labels(true)
	_apply_menu_background_palette()
	_ensure_warrior_filter_ui()
	_build_warrior_shop_grid()
	_ensure_weapon_filter_ui()
	_build_weapon_shop_grid()

	_select_warrior_skin(selected_warrior_id, selected_warrior_skin, true)
	_select_weapon_skin(selected_weapon_id, selected_weapon_skin, true)
	_refresh_selection_context_visuals()

	_connect_signals()
	_setup_auth_gate()
	_play_intro_animation_safe()
	_apply_uniform_button_outlines(self, 0)
	_apply_main_category_button_brightness()
	_apply_runtime_palette()
	if _auth_logged_in:
		_start_idle_loop()

func _auth_url(path: String) -> String:
	return _auth_flow.auth_url(self, path)

func _apply_menu_background_palette() -> void:
	_menu_theme.apply_menu_background_palette(self)

func _apply_runtime_palette(root: Node = null) -> void:
	_menu_theme.apply_runtime_palette(self, root)

func _refresh_selection_context_visuals() -> void:
	# Keep warriors/weapons panels on their native theme style (hex-driven),
	# without extra per-selection panel tint/bridge overlays.
	_clear_panel_selection_style(warriors_panel)
	_clear_panel_selection_style(weapons_panel)
	_remove_selection_bridge(warriors_body_row)
	_remove_selection_bridge(weapons_body_row)

func _clear_panel_selection_style(panel: PanelContainer) -> void:
	if panel == null:
		return
	panel.remove_theme_stylebox_override("panel")

func _remove_selection_bridge(row: HBoxContainer) -> void:
	if row == null:
		return
	var bridge := row.get_node_or_null("SelectionBridge") as Panel
	if bridge != null and is_instance_valid(bridge):
		bridge.queue_free()

func _auth_login_current_base_url() -> String:
	return _auth_flow.auth_login_current_base_url(self)

func _auth_build_base_url_with_port(base_url: String, port: int) -> String:
	return _auth_flow.auth_build_base_url_with_port(base_url, port)

func _auth_trim_suffix(url: String, suffix: String) -> String:
	return _auth_flow.auth_trim_suffix(url, suffix)

func _auth_rebuild_login_base_candidates() -> void:
	_auth_flow.auth_rebuild_login_base_candidates(self)

func _auth_request_login_with_current_candidate() -> int:
	return _auth_flow.auth_request_login_with_current_candidate(self)

func _setup_auth_gate() -> void:
	_auth_flow.setup_auth_gate(self, AUTH_API_BASE_URL_DEFAULT)

func _auth_set_ui_locked(locked: bool) -> void:
	_auth_flow.auth_set_ui_locked(self, locked)

func _auth_submit_login() -> void:
	_auth_flow.auth_submit_login(self)

func _auth_request_profile() -> void:
	_auth_flow.auth_request_profile(self)

func _auth_restore_runtime_session() -> bool:
	return _auth_flow.auth_restore_runtime_session(self)

func _auth_save_runtime_session() -> void:
	_auth_flow.auth_save_runtime_session(self)

func _auth_clear_runtime_session() -> void:
	_auth_flow.auth_clear_runtime_session(self)

func _auth_restore_persisted_session() -> bool:
	return _auth_flow.auth_restore_persisted_session(self)

func _auth_save_persisted_session() -> void:
	_auth_flow.auth_save_persisted_session(self)

func _auth_clear_persisted_session() -> void:
	_auth_flow.auth_clear_persisted_session(self)

func _auth_sync_wallet() -> void:
	_auth_flow.auth_sync_wallet(self)

func _copy_weapon_skins_dict(src: Dictionary) -> Dictionary:
	return _auth_flow.copy_weapon_skins_dict(src)

func _copy_warrior_skins_dict(src: Dictionary) -> Dictionary:
	return _auth_flow.copy_warrior_skins_dict(src)

func _auth_capture_wallet_sync_snapshot() -> void:
	_auth_flow.auth_capture_wallet_sync_snapshot(self)

func _auth_restore_wallet_sync_snapshot() -> void:
	_auth_flow.auth_restore_wallet_sync_snapshot(self)

func _auth_purchase_warrior_skin(skin_index: int) -> void:
	_auth_flow.auth_purchase_warrior_skin(self, skin_index)

func _auth_schedule_wallet_retry() -> void:
	_auth_flow.auth_schedule_wallet_retry(self)

func _on_auth_wallet_retry_timeout() -> void:
	_auth_maybe_flush_wallet_sync()

func _on_auth_request_watchdog_timeout() -> void:
	_auth_flow.auth_on_request_watchdog_timeout(self)

func _auth_maybe_flush_wallet_sync() -> void:
	_auth_flow.auth_maybe_flush_wallet_sync(self)

func _default_warrior_id() -> String:
	return _warrior_ui.default_warrior_id()

func _default_owned_warriors() -> PackedStringArray:
	return _warrior_ui.default_owned_warriors()

func _default_owned_warrior_skins_by_warrior() -> Dictionary:
	return _warrior_ui.default_owned_warrior_skins_by_warrior()

func _default_equipped_warrior_skin_by_warrior() -> Dictionary:
	return _warrior_ui.default_equipped_warrior_skin_by_warrior()

func _normalize_owned_warrior_skins_dict(src: Dictionary) -> Dictionary:
	var out := _default_owned_warrior_skins_by_warrior()
	for wid in _warrior_ui.warrior_ids():
		var normalized := str(wid).strip_edges().to_lower()
		var source: Variant = src.get(normalized, src.get(wid, [0]))
		var arr := PackedInt32Array([0])
		if source is PackedInt32Array:
			for value in source:
				var idx := maxi(0, int(value))
				if not arr.has(idx):
					arr.append(idx)
		elif source is Array:
			for value in source:
				var idx := maxi(0, int(value))
				if not arr.has(idx):
					arr.append(idx)
		arr.sort()
		out[normalized] = arr
	return out

func _normalize_equipped_warrior_skins_dict(src: Dictionary) -> Dictionary:
	var out := _default_equipped_warrior_skin_by_warrior()
	for wid in _warrior_ui.warrior_ids():
		var normalized := str(wid).strip_edges().to_lower()
		out[normalized] = maxi(0, int(src.get(normalized, src.get(wid, 0))))
	return out

func _auth_apply_profile(profile: Dictionary) -> void:
	wallet_coins = int(profile.get("coins", wallet_coins))
	wallet_clk = int(profile.get("clk", wallet_clk))
	player_username = str(profile.get("username", player_username)).strip_edges()
	if player_username.is_empty():
		player_username = "Player"

	if profile.has("owned_warriors"):
		var incoming_owned_warriors := PackedStringArray()
		for item in profile.get("owned_warriors", []) as Array:
			var wid := str(item).strip_edges().to_lower()
			if not wid.is_empty() and not incoming_owned_warriors.has(wid):
				incoming_owned_warriors.append(wid)
		var default_warrior := _default_warrior_id()
		if not incoming_owned_warriors.has(default_warrior):
			incoming_owned_warriors.append(default_warrior)
		owned_warriors = incoming_owned_warriors

	var incoming_warrior_skins := _default_owned_warrior_skins_by_warrior()
	if profile.has("owned_warrior_skins_by_warrior"):
		var incoming_skin_dict := profile.get("owned_warrior_skins_by_warrior", {}) as Dictionary
		for key in incoming_skin_dict.keys():
			var wid := str(key).strip_edges().to_lower()
			var source := incoming_skin_dict.get(key, [0]) as Array
			var arr := PackedInt32Array([0])
			if source != null:
				for v in source:
					var idx := maxi(0, int(v))
					if not arr.has(idx):
						arr.append(idx)
			arr.sort()
			incoming_warrior_skins[wid] = arr
	elif profile.has("owned_skins"):
		for item in profile.get("owned_skins", []) as Array:
			if not (item is Dictionary):
				continue
			var d := item as Dictionary
			var wid := str(d.get("character_id", "")).strip_edges().to_lower()
			if wid.is_empty():
				continue
			var arr := incoming_warrior_skins.get(wid, PackedInt32Array([0])) as PackedInt32Array
			var idx := maxi(0, int(d.get("skin_index", 0)))
			if not arr.has(idx):
				arr.append(idx)
				arr.sort()
			incoming_warrior_skins[wid] = arr
			if not owned_warriors.has(wid):
				owned_warriors.append(wid)
	owned_warrior_skins_by_warrior = incoming_warrior_skins
	owned_warrior_skins = owned_warrior_skins_by_warrior.get(_default_warrior_id(), PackedInt32Array([0])) as PackedInt32Array
	if profile.has("equipped_warrior_skin_by_warrior"):
		equipped_warrior_skin_by_warrior = _normalize_equipped_warrior_skins_dict((profile.get("equipped_warrior_skin_by_warrior", {}) as Dictionary).duplicate(true))
	var next_selected_warrior_id := selected_warrior_id
	if profile.has("selected_warrior_id"):
		next_selected_warrior_id = str(profile.get("selected_warrior_id", selected_warrior_id)).strip_edges().to_lower()
	selected_warrior_id = next_selected_warrior_id
	if not owned_warriors.has(selected_warrior_id):
		selected_warrior_id = _default_warrior_id()
	var next_selected_warrior_skin := selected_warrior_skin
	if profile.has("selected_warrior_skin"):
		next_selected_warrior_skin = maxi(0, int(profile.get("selected_warrior_skin", selected_warrior_skin)))
	elif profile.has("equipped_warrior_skin_by_warrior"):
		next_selected_warrior_skin = _equipped_warrior_skin(selected_warrior_id)
	if not _warrior_skin_is_owned(selected_warrior_id, next_selected_warrior_skin):
		next_selected_warrior_skin = 0
	selected_warrior_skin = next_selected_warrior_skin
	_set_equipped_warrior_skin(selected_warrior_id, selected_warrior_skin)

	if profile.has("owned_weapons"):
		var allowed := PackedStringArray([WEAPON_UZI, WEAPON_AK47, WEAPON_KAR, WEAPON_SHOTGUN, WEAPON_GRENADE])
		var from_api := PackedStringArray()
		for w in profile.get("owned_weapons", []) as Array:
			var wid := str(w).strip_edges().to_lower()
			if allowed.has(wid) and not from_api.has(wid):
				from_api.append(wid)
		if not from_api.has(WEAPON_UZI):
			from_api.append(WEAPON_UZI)
		if not from_api.has(WEAPON_GRENADE):
			from_api.append(WEAPON_GRENADE)
		owned_weapons = from_api

	if profile.has("owned_weapon_skins_by_weapon"):
		var allowed_skins := PackedStringArray([WEAPON_UZI, WEAPON_AK47, WEAPON_KAR, WEAPON_SHOTGUN, WEAPON_GRENADE])
		var incoming := profile.get("owned_weapon_skins_by_weapon", {}) as Dictionary
		var out: Dictionary = {}
		for wid in allowed_skins:
			var arr_src := incoming.get(wid, [0]) as Array
			var arr_out := PackedInt32Array([0])
			if arr_src != null:
				for v in arr_src:
					var idx := maxi(0, int(v))
					if not arr_out.has(idx):
						arr_out.append(idx)
			arr_out.sort()
			if not owned_weapons.has(wid):
				arr_out = PackedInt32Array([0])
			out[wid] = arr_out
		owned_weapon_skins_by_weapon = out
	if profile.has("equipped_weapon_skin_by_weapon"):
		var incoming_equipped_weapon := profile.get("equipped_weapon_skin_by_weapon", {}) as Dictionary
		for wid in PackedStringArray([WEAPON_UZI, WEAPON_AK47, WEAPON_KAR, WEAPON_SHOTGUN, WEAPON_GRENADE]):
			equipped_weapon_skin_by_weapon[wid] = maxi(0, int(incoming_equipped_weapon.get(wid, equipped_weapon_skin_by_weapon.get(wid, 0))))
	var next_selected_weapon_id := selected_weapon_id
	if profile.has("selected_weapon_id"):
		next_selected_weapon_id = str(profile.get("selected_weapon_id", selected_weapon_id)).strip_edges().to_lower()
	selected_weapon_id = next_selected_weapon_id
	if not _weapon_is_owned(selected_weapon_id):
		selected_weapon_id = WEAPON_UZI
	var next_selected_weapon_skin := selected_weapon_skin
	if profile.has("selected_weapon_skin"):
		next_selected_weapon_skin = maxi(0, int(profile.get("selected_weapon_skin", selected_weapon_skin)))
	elif profile.has("equipped_weapon_skin_by_weapon"):
		next_selected_weapon_skin = _equipped_weapon_skin(selected_weapon_id)
	if not _weapon_skin_is_owned(selected_weapon_id, next_selected_weapon_skin):
		next_selected_weapon_skin = 0
	selected_weapon_skin = next_selected_weapon_skin
	_set_equipped_weapon_skin(selected_weapon_id, selected_weapon_skin)
	_auth_dev_unlock_all_for_mario()
	_pending_warrior_id = selected_warrior_id
	_pending_warrior_skin = selected_warrior_skin
	_pending_weapon_id = selected_weapon_id
	_pending_weapon_skin = selected_weapon_skin
	_weapon_filter_weapon_id = selected_weapon_id
	_apply_warrior_skin_to_player(main_warrior_preview, selected_warrior_id, selected_warrior_skin)
	_apply_warrior_skin_to_player(warrior_shop_preview, _pending_warrior_id, _pending_warrior_skin)
	_set_weapon_icon_sprite(main_weapon_icon, selected_weapon_id, 1.0, selected_weapon_skin)
	_apply_weapon_skin_visual(main_weapon_icon, selected_weapon_id, selected_weapon_skin)
	_set_weapon_icon_sprite(weapon_shop_preview, _pending_weapon_id, 1.0, _pending_weapon_skin)
	_apply_weapon_skin_visual(weapon_shop_preview, _pending_weapon_id, _pending_weapon_skin)
	warrior_name_label.text = "%s - %s" % [_warrior_ui.warrior_display_name(_pending_warrior_id), _warrior_ui.warrior_skin_label(_pending_warrior_id, _pending_warrior_skin)]
	weapon_name_label.text = "%s - %s" % [_weapon_ui.weapon_display_name(_pending_weapon_id), _weapon_skin_label(_pending_weapon_id, _pending_weapon_skin)]

	_update_wallet_labels(true)
	_refresh_warrior_username_label()
	_refresh_auth_footer()
	_refresh_warrior_grid_texts()
	_refresh_warrior_action()
	_refresh_weapon_grid_texts()
	_refresh_weapon_action()
	_save_state()

func _auth_finalize_without_remote_profile(reason: String = "") -> void:
	if player_username.is_empty():
		player_username = "Player"
	_auth_logged_in = true
	_auth_wallet_sync_supported = false
	_auth_dev_unlock_all_for_mario()
	_update_wallet_labels(true)
	_refresh_warrior_username_label()
	_refresh_warrior_grid_texts()
	_refresh_warrior_action()
	_refresh_weapon_grid_texts()
	_refresh_weapon_action()
	_auth_save_runtime_session()
	_auth_save_persisted_session()
	_auth_set_ui_locked(false)
	_refresh_auth_footer()
	if _auth_status_label != null:
		_auth_status_label.text = reason
	if _auth_login_button != null:
		_auth_login_button.disabled = false
	_start_idle_loop()
	_save_state()

func _auth_dev_unlock_all_for_mario() -> void:
	var dev_user := player_username.strip_edges().to_lower()
	if dev_user != "mario" and dev_user != "blackshadow":
		return

	var warrior_ids := _warrior_ui.warrior_ids()
	var all_owned_warriors := PackedStringArray()
	for wid in warrior_ids:
		var normalized := str(wid).strip_edges().to_lower()
		if normalized.is_empty() or all_owned_warriors.has(normalized):
			continue
		all_owned_warriors.append(normalized)
	owned_warriors = all_owned_warriors

	var all_warrior_skins: Dictionary = {}
	for wid in all_owned_warriors:
		all_warrior_skins[wid] = _warrior_ui.available_skin_indices_for(wid)
	owned_warrior_skins_by_warrior = all_warrior_skins

	var all_weapons := PackedStringArray([WEAPON_UZI, WEAPON_AK47, WEAPON_KAR, WEAPON_SHOTGUN, WEAPON_GRENADE])
	owned_weapons = all_weapons

	var all_weapon_skins: Dictionary = {}
	for wid in all_weapons:
		var arr := PackedInt32Array([0])
		for skin in _weapon_skins_for(wid):
			var idx := maxi(0, int((skin as Dictionary).get("skin", 0)))
			if not arr.has(idx):
				arr.append(idx)
		arr.sort()
		all_weapon_skins[wid] = arr
	owned_weapon_skins_by_weapon = all_weapon_skins

	for wid in warrior_ids:
		var normalized := str(wid).strip_edges().to_lower()
		var owned_arr := owned_warrior_skins_by_warrior.get(normalized, PackedInt32Array([0])) as PackedInt32Array
		var equipped := maxi(0, int(equipped_warrior_skin_by_warrior.get(normalized, 0)))
		if not owned_arr.has(equipped):
			equipped_warrior_skin_by_warrior[normalized] = 0

	for wid in all_weapons:
		var owned_arr := owned_weapon_skins_by_weapon.get(wid, PackedInt32Array([0])) as PackedInt32Array
		var equipped := maxi(0, int(equipped_weapon_skin_by_weapon.get(wid, 0)))
		if not owned_arr.has(equipped):
			equipped_weapon_skin_by_weapon[wid] = 0

	if not owned_warriors.has(selected_warrior_id):
		selected_warrior_id = _default_warrior_id()
	if not _warrior_skin_is_owned(selected_warrior_id, selected_warrior_skin):
		selected_warrior_skin = _equipped_warrior_skin(selected_warrior_id)
	if not _warrior_skin_is_owned(selected_warrior_id, selected_warrior_skin):
		selected_warrior_skin = 0
	_set_equipped_warrior_skin(selected_warrior_id, selected_warrior_skin)
	owned_warrior_skins = owned_warrior_skins_by_warrior.get(selected_warrior_id, PackedInt32Array([0])) as PackedInt32Array

	if not owned_weapons.has(selected_weapon_id):
		selected_weapon_id = WEAPON_UZI
	if not _weapon_skin_is_owned(selected_weapon_id, selected_weapon_skin):
		selected_weapon_skin = _equipped_weapon_skin(selected_weapon_id)
	if not _weapon_skin_is_owned(selected_weapon_id, selected_weapon_skin):
		selected_weapon_skin = 0
	_set_equipped_weapon_skin(selected_weapon_id, selected_weapon_skin)

func _on_auth_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_auth_flow.auth_handle_http_completed(self, response_code, body)

func _ensure_cursor_manager() -> void:
	_menu_nav.ensure_cursor_manager(self, CURSOR_MANAGER_SCRIPT, CURSOR_MANAGER_NAME)

func _apply_menu_cursor_context() -> void:
	_menu_nav.apply_menu_cursor_context(self, CURSOR_MANAGER_NAME)

func _input(event: InputEvent) -> void:
	if intro != null and intro.visible:
		return
	_menu_nav.handle_input(self, event)

func _unhandled_input(event: InputEvent) -> void:
	if intro != null and intro.visible:
		return
	_menu_nav.handle_unhandled_input(self, event)

func _toggle_fullscreen() -> void:
	_menu_nav.toggle_fullscreen()

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

func _ensure_auth_logout_button() -> void:
	_meta_ui.ensure_auth_logout_button(self)

func _connect_signals() -> void:
	warrior_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	weapon_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	if wallet_click != null:
		wallet_click.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_bind_menu_sfx_button(wallet_click)
		wallet_click.pressed.connect(func() -> void:
			_pop(wallet_panel)
		)

	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(func() -> void:
		_button_press_anim(options_button)
		_switch_to(screen_options, 1)
	)
	exit_button.pressed.connect(_on_exit_pressed)
	if _auth_logout_button != null:
		_auth_logout_button.pressed.connect(_on_auth_logout_pressed)

	warrior_button.pressed.connect(_open_warriors_menu)
	weapon_button.pressed.connect(_open_weapons_menu)
	_bind_menu_sfx_button(warrior_button)
	_bind_menu_sfx_button(weapon_button)

	options_back_button.pressed.connect(_on_options_back_pressed)
	warriors_back_button.pressed.connect(_on_warriors_back_pressed)
	weapons_back_button.pressed.connect(_on_weapons_back_pressed)

	warrior_action_button.pressed.connect(_on_warrior_action_pressed)
	weapon_action_button.pressed.connect(_on_weapon_action_pressed)

	_add_hover_pop(play_button)
	_add_hover_pop(options_button)
	_add_hover_pop(exit_button)
	if _auth_logout_button != null:
		_add_hover_pop(_auth_logout_button)
	_add_hover_pop(options_back_button)
	_add_hover_pop(warriors_back_button)
	_add_hover_pop(weapons_back_button)
	_add_hover_pop(warrior_action_button)
	_add_hover_pop(weapon_action_button)

	warrior_button.mouse_entered.connect(func() -> void: _hover_area(warrior_area, true))
	warrior_button.mouse_exited.connect(func() -> void: _hover_area(warrior_area, false))
	weapon_button.mouse_entered.connect(func() -> void: _hover_area(weapon_area, true))
	weapon_button.mouse_exited.connect(func() -> void: _hover_area(weapon_area, false))
	if music_slider != null:
		var music_cb := Callable(self, "_on_music_slider_changed")
		if not music_slider.value_changed.is_connected(music_cb):
			music_slider.value_changed.connect(music_cb)
	if sfx_slider != null:
		var sfx_cb := Callable(self, "_on_sfx_slider_changed")
		if not sfx_slider.value_changed.is_connected(sfx_cb):
			sfx_slider.value_changed.connect(sfx_cb)

func _on_play_pressed() -> void:
	if _play_lobby_transition_running:
		return
	_button_press_anim(play_button)
	await _run_play_lobby_transition()
	_open_lobby_menu_flow()
	_fade_out_play_lobby_transition()

func _open_lobby_menu_flow() -> void:
	if _intro_fx != null and _intro_fx.has_method("set_lobby_music_active"):
		_intro_fx.call("set_lobby_music_active", true, 0.55)
	if _lobby_overlay_ctrl != null:
		_lobby_overlay_ctrl.open(play_button)
	_sync_lobby_overlay_interaction_state()
	_refresh_meta_ui_visibility()

func _run_play_lobby_transition() -> void:
	if _fx_layer == null or play_button == null:
		return
	_cleanup_play_lobby_transition()
	_play_lobby_transition_running = true
	_cache_play_lobby_fade_targets()

	var panel := PanelContainer.new()
	panel.name = "PlayLobbyTransition"
	panel.z_index = 980
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate = Color(1, 1, 1, 1)
	panel.top_level = true

	var source_rect := play_button.get_global_rect()
	panel.global_position = source_rect.position
	panel.size = source_rect.size

	var style := StyleBoxFlat.new()
	style.bg_color = Color(MENU_CLR_BASE.r, MENU_CLR_BASE.g, MENU_CLR_BASE.b, 0.0)
	style.border_color = MENU_CLR_HIGHLIGHT
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 5
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)
	_fx_layer.add_child(panel)
	_play_lobby_panel = panel

	var viewport_rect := get_viewport_rect()
	var duration := maxf(0.12, play_lobby_expand_duration)
	_play_lobby_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_play_lobby_tween.parallel().tween_property(panel, "global_position", viewport_rect.position, duration)
	_play_lobby_tween.parallel().tween_property(panel, "size", viewport_rect.size, duration)
	_play_lobby_tween.parallel().tween_property(style, "bg_color", Color(MENU_CLR_ACCENT.r, MENU_CLR_ACCENT.g, MENU_CLR_ACCENT.b, 0.0), duration * 0.75)
	for target in _play_lobby_fade_targets:
		if target == null or not is_instance_valid(target):
			continue
		var item_path := str(target.get_path())
		var base_alpha := float(_play_lobby_fade_base_alpha.get(item_path, target.modulate.a))
		target.modulate.a = clampf(base_alpha, 0.0, 1.0)
		_play_lobby_tween.parallel().tween_property(target, "modulate:a", 0.0, duration * 0.82)
	await _play_lobby_tween.finished
	_play_lobby_tween = null

func _fade_out_play_lobby_transition() -> void:
	if _play_lobby_panel == null or not is_instance_valid(_play_lobby_panel):
		_cleanup_play_lobby_transition()
		return
	var fade_duration := maxf(0.08, play_lobby_border_fade_duration)
	var fade := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_property(_play_lobby_panel, "modulate:a", 0.0, fade_duration)
	fade.finished.connect(_cleanup_play_lobby_transition)

func _cleanup_play_lobby_transition() -> void:
	if _play_lobby_tween != null:
		_play_lobby_tween.kill()
		_play_lobby_tween = null
	if _play_lobby_panel != null and is_instance_valid(_play_lobby_panel):
		_play_lobby_panel.queue_free()
	_play_lobby_panel = null
	_play_lobby_transition_running = false

func _cache_play_lobby_fade_targets() -> void:
	_play_lobby_fade_targets.clear()
	_play_lobby_fade_base_alpha.clear()
	var targets: Array[CanvasItem] = []
	# Keep menu background visible during lobby transition to avoid
	# revealing the engine's default gray clear color.
	if wallet_panel != null:
		targets.append(wallet_panel)
	if play_button != null:
		targets.append(play_button)
	if options_button != null:
		targets.append(options_button)
	if exit_button != null:
		targets.append(exit_button)
	if _auth_footer_panel != null and is_instance_valid(_auth_footer_panel):
		targets.append(_auth_footer_panel)
	elif _auth_logout_button != null and is_instance_valid(_auth_logout_button):
		targets.append(_auth_logout_button)
	if logo_node != null and logo_node is CanvasItem:
		targets.append(logo_node as CanvasItem)

	for item in targets:
		if item == null or not is_instance_valid(item):
			continue
		if _play_lobby_fade_targets.has(item):
			continue
		_play_lobby_fade_targets.append(item)
		_play_lobby_fade_base_alpha[str(item.get_path())] = item.modulate.a

func _restore_play_lobby_fade_targets() -> void:
	for item in _play_lobby_fade_targets:
		if item == null or not is_instance_valid(item):
			continue
		var item_path := str(item.get_path())
		item.modulate.a = clampf(float(_play_lobby_fade_base_alpha.get(item_path, 1.0)), 0.0, 1.0)
	_play_lobby_fade_targets.clear()
	_play_lobby_fade_base_alpha.clear()

func _run_play_lobby_reverse_transition() -> void:
	if _play_lobby_fade_targets.is_empty():
		return
	if _fx_layer == null or play_button == null:
		_restore_play_lobby_fade_targets()
		return
	_cleanup_play_lobby_transition()
	_play_lobby_transition_running = true

	var panel := PanelContainer.new()
	panel.name = "PlayLobbyTransitionReverse"
	panel.z_index = 980
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate = Color(1, 1, 1, 1)
	panel.top_level = true

	var viewport_rect := get_viewport_rect()
	panel.global_position = viewport_rect.position
	panel.size = viewport_rect.size

	var style := StyleBoxFlat.new()
	style.bg_color = Color(MENU_CLR_ACCENT.r, MENU_CLR_ACCENT.g, MENU_CLR_ACCENT.b, 0.0)
	style.border_color = MENU_CLR_HIGHLIGHT
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 5
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)
	_fx_layer.add_child(panel)
	_play_lobby_panel = panel

	var target_rect := play_button.get_global_rect()
	var duration := maxf(0.12, play_lobby_shrink_duration)
	_play_lobby_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_play_lobby_tween.parallel().tween_property(panel, "global_position", target_rect.position, duration)
	_play_lobby_tween.parallel().tween_property(panel, "size", target_rect.size, duration)
	_play_lobby_tween.parallel().tween_property(style, "bg_color", Color(MENU_CLR_BASE.r, MENU_CLR_BASE.g, MENU_CLR_BASE.b, 0.0), duration * 0.86)

	for target in _play_lobby_fade_targets:
		if target == null or not is_instance_valid(target):
			continue
		var item_path := str(target.get_path())
		var base_alpha := clampf(float(_play_lobby_fade_base_alpha.get(item_path, 1.0)), 0.0, 1.0)
		target.modulate.a = 0.0
		_play_lobby_tween.parallel().tween_property(target, "modulate:a", base_alpha, duration * 0.92)

	await _play_lobby_tween.finished
	_play_lobby_tween = null
	_cleanup_play_lobby_transition()
	_restore_play_lobby_fade_targets()

func _run_lobby_menu_loading_sequence() -> void:
	if _lobby_overlay_ctrl != null:
		_show_menu_loading_overlay("LOADING LOBBIES...")
		await _lobby_overlay_ctrl.run_loading_sequence()
		_hide_menu_loading_overlay()

func _on_lobby_overlay_closed() -> void:
	if _intro_fx != null and _intro_fx.has_method("set_lobby_music_active"):
		_intro_fx.call("set_lobby_music_active", false, 0.55)
	_hide_menu_loading_overlay()
	await _run_play_lobby_reverse_transition()
	_restore_play_lobby_fade_targets()
	_sync_lobby_overlay_interaction_state()
	_refresh_meta_ui_visibility()

func _on_exit_pressed() -> void:
	_button_press_anim(exit_button)
	get_tree().quit()

func _on_auth_logout_pressed() -> void:
	_auth_flow.auth_on_logout_pressed(self)

func _on_options_back_pressed() -> void:
	_button_press_anim(options_back_button)
	_switch_to(screen_main, -1)

func _on_warriors_back_pressed() -> void:
	_button_press_anim(warriors_back_button)
	_close_warriors_menu()

func _on_weapons_back_pressed() -> void:
	_button_press_anim(weapons_back_button)
	_close_weapons_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_auth_logout_button()

func _layout_auth_logout_button() -> void:
	_meta_ui.layout_auth_logout_button(self)

func _refresh_auth_footer() -> void:
	_meta_ui.refresh_auth_footer(self)

func _is_main_menu_meta_ui_visible() -> bool:
	return _meta_ui.is_main_menu_meta_ui_visible(self)

func _refresh_meta_ui_visibility() -> void:
	_meta_ui.refresh_meta_ui_visibility(self)

func _apply_meta_ui_visibility(show_on_main: bool) -> void:
	_meta_ui.apply_meta_ui_visibility(self, show_on_main)

func _tween_meta_visibility(item: CanvasItem, should_show: bool, tween_slot: String) -> void:
	_meta_ui.tween_meta_visibility(self, item, should_show, tween_slot)

func _show_menu_loading_overlay(message: String = "LOADING...") -> void:
	if not ENABLE_MENU_LOADING_OVERLAY:
		return
	_set_menu_cursor_hover_blocked(true)
	if _menu_loading_overlay != null:
		_menu_loading_overlay.show(message)

func _hide_menu_loading_overlay() -> void:
	if not ENABLE_MENU_LOADING_OVERLAY:
		return
	if _menu_loading_overlay != null:
		_menu_loading_overlay.hide()

func _on_menu_loading_overlay_shown() -> void:
	_set_menu_cursor_hover_blocked(true)

func _on_menu_loading_overlay_hidden() -> void:
	_set_menu_cursor_hover_blocked(false)

func _set_menu_cursor_hover_blocked(blocked: bool) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var root := tree.get_root()
	if root == null:
		return
	var cm := root.get_node_or_null(CURSOR_MANAGER_NAME)
	if cm != null and cm.has_method("set_menu_hover_blocked"):
		cm.call("set_menu_hover_blocked", blocked)

func _switch_to(target: Control, direction: int) -> void:
	if target == null:
		return
	if _current_screen == target:
		return
	_apply_meta_ui_visibility(target == screen_main)

	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	if _menu_transition_ctrl != null:
		_menu_transition_ctrl.abort_transitions()

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
			_sync_lobby_overlay_interaction_state()
			_refresh_warrior_username_label()
			_refresh_auth_footer()
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
			_sync_lobby_overlay_interaction_state()
			_refresh_warrior_username_label()
			_refresh_auth_footer()
			if _current_screen == screen_main:
				_start_idle_loop()
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
		_sync_lobby_overlay_interaction_state()
		_refresh_warrior_username_label()
		_refresh_auth_footer()
		if _current_screen == screen_main or _current_screen == screen_warriors or _current_screen == screen_weapons:
			_start_idle_loop()
	)

func _open_warriors_menu() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	_apply_meta_ui_visibility(false)
	_menu_transition_ctrl.open_warriors_menu()

func _open_warriors_menu_stage2() -> void:
	_menu_transition_ctrl.open_warriors_menu_stage2(warriors_menu_preview_scale_mult, _warrior_shop_preview_base_scale)

func _close_warriors_menu() -> void:
	if _current_screen != screen_warriors:
		return
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	_menu_transition_ctrl.close_warriors_menu()

func _close_warriors_menu_stage2() -> void:
	_menu_transition_ctrl.close_warriors_menu_stage2(_warrior_shop_preview_base_scale)

func _open_weapons_menu() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	_apply_meta_ui_visibility(false)
	_menu_transition_ctrl.open_weapons_menu(_pending_weapon_id, _pending_weapon_skin)

func _open_weapons_menu_stage2() -> void:
	_menu_transition_ctrl.open_weapons_menu_stage2(_pending_weapon_id, _pending_weapon_skin, WEAPON_UZI)

func _close_weapons_menu() -> void:
	if _current_screen != screen_weapons:
		return
	_sync_visible_weapon_from_preview()
	_pending_weapon_id = _visible_weapon_id
	_pending_weapon_skin = _visible_weapon_skin
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	_menu_transition_ctrl.close_weapons_menu()

func _close_weapons_menu_stage2() -> void:
	_menu_transition_ctrl.close_weapons_menu_stage2(_visible_weapon_id, _visible_weapon_skin, WEAPON_UZI)

func _set_current_screen_ref(target: Control) -> void:
	_current_screen = target
	_sync_lobby_overlay_interaction_state()
	_refresh_warrior_username_label()
	_refresh_auth_footer()

func _sync_lobby_overlay_interaction_state() -> void:
	if _lobby_overlay_ctrl == null:
		return
	if not _lobby_overlay_ctrl.is_visible():
		_lobby_overlay_ctrl.set_interaction_enabled(true)
		return
	var allow_interaction := _current_screen == screen_main
	_lobby_overlay_ctrl.set_interaction_enabled(allow_interaction)

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

func _apply_warrior_skin_to_player(player: Node, warrior_id: String, skin_index: int) -> void:
	_warrior_ui.apply_warrior_menu_preview(player, warrior_id, skin_index)

func _set_weapon_icon_sprite(target: Sprite2D, weapon_id: String, extra_mult: float = 1.0, skin_index: int = 0) -> void:
	var normalized := weapon_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	if target != null:
		target.set_meta("weapon_id", normalized)
		target.set_meta("skin_index", idx)
	if target == weapon_shop_preview:
		_visible_weapon_id = normalized
		_visible_weapon_skin = idx
	_weapon_ui.set_weapon_icon_sprite(target, normalized, extra_mult, weapon_shop_preview, idx)

func _sync_visible_weapon_from_preview() -> void:
	if weapon_shop_preview == null:
		return
	if weapon_shop_preview.has_meta("weapon_id"):
		_visible_weapon_id = str(weapon_shop_preview.get_meta("weapon_id")).strip_edges().to_lower()
	if weapon_shop_preview.has_meta("skin_index"):
		_visible_weapon_skin = maxi(0, int(weapon_shop_preview.get_meta("skin_index")))

func _make_filter_button(text: String) -> Button:
	var btn := _make_shop_button()
	btn.custom_minimum_size = Vector2(0, 28)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = text
	return btn

func _set_filter_btn_selected(btn: Button, selected: bool) -> void:
	if btn == null:
		return
	btn.modulate = Color(1, 1, 1, 1) if selected else Color(1, 1, 1, 0.9)

func _refresh_weapon_filter_button_state() -> void:
	for key in _weapon_filter_weapon_buttons.keys():
		_set_filter_btn_selected(_weapon_filter_weapon_buttons.get(key, null) as Button, str(key) == _weapon_filter_weapon_id)
	for key in _weapon_filter_category_buttons.keys():
		_set_filter_btn_selected(_weapon_filter_category_buttons.get(key, null) as Button, str(key) == _weapon_filter_category)

	for key in _weapon_filter_weapon_buttons.keys():
		var wid := str(key)
		var btn := _weapon_filter_weapon_buttons.get(wid, null) as Button
		if btn == null:
			continue
		if wid.is_empty():
			btn.text = "ALL"
			continue
		btn.text = _weapon_ui.weapon_display_name(wid)

func _ensure_weapon_filter_ui() -> void:
	if weapon_scroll == null:
		return
	var list_col := weapon_scroll.get_parent() as Control
	if list_col == null:
		return
	if list_col.get_node_or_null("WeaponFilters") != null:
		return

	var filters := VBoxContainer.new()
	filters.name = "WeaponFilters"
	filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_theme_constant_override("separation", 6)
	list_col.add_child(filters)
	list_col.move_child(filters, 0)

	var weapon_row := HBoxContainer.new()
	weapon_row.name = "WeaponRow"
	weapon_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_row.add_theme_constant_override("separation", 6)
	filters.add_child(weapon_row)

	_weapon_filter_weapon_buttons = {}
	var weapon_items := [
		{"label": "ALL", "id": ""},
		{"label": _weapon_ui.weapon_display_name(WEAPON_UZI), "id": WEAPON_UZI},
		{"label": _weapon_ui.weapon_display_name(WEAPON_AK47), "id": WEAPON_AK47},
		{"label": _weapon_ui.weapon_display_name(WEAPON_KAR), "id": WEAPON_KAR},
		{"label": _weapon_ui.weapon_display_name(WEAPON_SHOTGUN), "id": WEAPON_SHOTGUN},
		{"label": _weapon_ui.weapon_display_name(WEAPON_GRENADE), "id": WEAPON_GRENADE},
	]
	for it in weapon_items:
		var wid := str(it.get("id", ""))
		var btn := _make_filter_button(str(it.get("label", "")))
		btn.pressed.connect(func() -> void:
			_weapon_filter_weapon_id = wid
			if not wid.is_empty():
				_select_weapon_skin(wid, _equipped_weapon_skin(wid), true)
			_refresh_weapon_filter_button_state()
			_build_weapon_shop_grid()
		)
		weapon_row.add_child(btn)
		_weapon_filter_weapon_buttons[wid] = btn

	var cat_row := HBoxContainer.new()
	cat_row.name = "CategoryRow"
	cat_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_row.add_theme_constant_override("separation", 6)
	filters.add_child(cat_row)

	_weapon_filter_category_buttons = {}
	var cat_items := [
		{"label": "ALL", "id": ""},
		{"label": "COLORS", "id": "colors"},
		{"label": "SKINS", "id": "skins"},
	]
	for it in cat_items:
		var cid := str(it.get("id", ""))
		var btn := _make_filter_button(str(it.get("label", "")))
		btn.pressed.connect(func() -> void:
			_weapon_filter_category = cid
			_refresh_weapon_filter_button_state()
			_build_weapon_shop_grid()
		)
		cat_row.add_child(btn)
		_weapon_filter_category_buttons[cid] = btn

	_refresh_weapon_filter_button_state()

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

func _weapon_base_cost(weapon_id: String) -> int:
	return int(DATA.WEAPON_BASE_COST_BY_ID.get(weapon_id.strip_edges().to_lower(), 0))

func _weapon_skin_cost(weapon_id: String, skin_index: int) -> int:
	return _weapon_ui.weapon_skin_cost(weapon_id, skin_index)

func _apply_weapon_skin_visual(target: CanvasItem, weapon_id: String, skin_index: int) -> void:
	_weapon_ui.apply_weapon_skin_visual(target, weapon_id, skin_index)

func _apply_weapon_skin_tint(target: CanvasItem, skin_index: int) -> void:
	push_warning("_apply_weapon_skin_tint is deprecated. Use _apply_weapon_skin_visual(target, weapon_id, skin_index).")
	_apply_weapon_skin_visual(target, _pending_weapon_id, skin_index)

func _build_warrior_shop_grid() -> void:
	_clear_children(warrior_grid)
	var warrior_list := _warrior_ui.warrior_ids()
	if not _warrior_filter_warrior_id.is_empty():
		warrior_list = [_warrior_filter_warrior_id]
	for warrior_id in warrior_list:
		for skin in _warrior_ui.warrior_skins_for(warrior_id):
			var skin_index := int((skin as Dictionary).get("index", 0))
			var btn := _warrior_ui.make_warrior_item_button(self, Callable(self, "_make_shop_button"), warrior_id, skin_index)
			btn.pressed.connect(Callable(self, "_on_warrior_item_button_pressed").bind(warrior_id, skin_index))
			warrior_grid.add_child(btn)
			_center_pivot(btn)

func _build_weapon_shop_grid() -> void:
	_clear_children(weapon_grid)
	var weapon_list := [WEAPON_UZI, WEAPON_AK47, WEAPON_KAR, WEAPON_SHOTGUN, WEAPON_GRENADE]
	if not _weapon_filter_weapon_id.is_empty():
		weapon_list = [_weapon_filter_weapon_id]
	for weapon_id in weapon_list:
		for skin in _weapon_skins_for(weapon_id):
			var cat := str(skin.get("category", "")).strip_edges().to_lower()
			if not _weapon_filter_category.is_empty() and cat != _weapon_filter_category:
				continue
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
	_normalize_button_outline(btn, 0)
	btn.add_theme_font_size_override("font_size", 11)
	_add_hover_pop(btn)
	btn.pressed.connect(func() -> void:
		_button_press_anim(btn)
	)
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
	dst.add_theme_color_override("font_color", MENU_PALETTE.text_dark(1.0))
	dst.add_theme_color_override("font_hover_color", MENU_PALETTE.text_dark(1.0))
	dst.add_theme_color_override("font_pressed_color", MENU_PALETTE.text_dark(1.0))
	dst.add_theme_color_override("font_disabled_color", MENU_PALETTE.text_dark(0.9))
	dst.add_theme_constant_override("outline_size", 0)
	_normalize_button_outline(dst, 0)

func _apply_uniform_button_outlines(root: Node, border_width: int = 0) -> void:
	_menu_theme.apply_uniform_button_outlines(self, root, border_width)

func _normalize_button_outline(btn: Button, border_width: int = 0) -> void:
	_menu_theme.normalize_button_outline(self, btn, border_width)

func _apply_main_category_button_brightness() -> void:
	_menu_theme.apply_main_category_button_brightness(self)

func _apply_button_brightness_override(btn: Button) -> void:
	_menu_theme.apply_button_brightness_override(btn)

func _mix_to_color(src: Color, target: Color, blend: float) -> Color:
	return _menu_theme.mix_to_color(src, target, blend)

func _brighten_button_bg(c: Color, state: String) -> Color:
	return _menu_theme.brighten_button_bg(c, state)

func _init_confirm_dialog() -> void:
	var overlay := CONFIRM_OVERLAY_SCRIPT.new()
	overlay.name = "ConfirmOverlay"
	overlay.configure(
		Callable(self, "_make_shop_button"),
		Callable(self, "_set_weapon_icon_sprite"),
		Callable(self, "_apply_weapon_skin_visual"),
		Callable(self, "_center_pivot"),
		Callable(self, "_add_hover_pop")
	)
	add_child(overlay)
	_confirm_overlay_ui = overlay

func _ask_confirm(title: String, text: String, on_confirm: Callable, weapon_id: String = "", skin_index: int = 0) -> void:
	if _confirm_overlay_ui == null:
		return
	_confirm_overlay_ui.call("ask", title, text, on_confirm, weapon_id, skin_index)

func _apply_pixel_slider_style(slider: HSlider) -> void:
	_menu_theme.apply_pixel_slider_style(self, slider)

func _ensure_slider_grabbers() -> void:
	_menu_theme.ensure_slider_grabbers(self)

func _apply_grid_spacing(grid: GridContainer) -> void:
	_menu_theme.apply_grid_spacing(grid)

func _apply_pixel_scroll_style(scroll: ScrollContainer) -> void:
	_menu_theme.apply_pixel_scroll_style(self, scroll)

func _apply_pixel_scrollbar(sb: ScrollBar) -> void:
	_menu_theme.apply_pixel_scrollbar(self, sb)

func _ensure_scrollbar_styleboxes() -> void:
	_menu_theme.ensure_scrollbar_styleboxes(self)

func _pixel_empty_icon() -> Texture2D:
	return _menu_theme.pixel_empty_icon()

func _warrior_cost(warrior_id: String) -> int:
	return _warrior_ui.warrior_base_cost(warrior_id)

func _warrior_skin_cost(warrior_id: String, skin_index: int) -> int:
	return _warrior_ui.warrior_skin_cost(warrior_id, skin_index)

func _warrior_is_owned(warrior_id: String) -> bool:
	return owned_warriors.has(warrior_id.strip_edges().to_lower())

func _warrior_skin_is_owned(warrior_id: String, skin_index: int) -> bool:
	var normalized := warrior_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	if not _warrior_is_owned(normalized):
		return false
	if idx <= 0:
		return true
	var arr := owned_warrior_skins_by_warrior.get(normalized, PackedInt32Array([0])) as PackedInt32Array
	if arr == null:
		return false
	return arr.has(idx)

func _equipped_warrior_skin(warrior_id: String) -> int:
	var normalized := warrior_id.strip_edges().to_lower()
	if equipped_warrior_skin_by_warrior.has(normalized):
		return maxi(0, int(equipped_warrior_skin_by_warrior.get(normalized, 0)))
	return 0

func _set_equipped_warrior_skin(warrior_id: String, skin_index: int) -> void:
	equipped_warrior_skin_by_warrior[warrior_id.strip_edges().to_lower()] = maxi(0, skin_index)

func _ensure_warrior_filter_ui() -> void:
	if warrior_scroll == null:
		return
	var list_col := warrior_scroll.get_parent() as Control
	if list_col == null or list_col.get_node_or_null("WarriorFilters") != null:
		return
	if list_col is VBoxContainer:
		(list_col as VBoxContainer).add_theme_constant_override("separation", 0)
	var filters := HBoxContainer.new()
	filters.name = "WarriorFilters"
	filters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_theme_constant_override("separation", 4)
	list_col.add_child(filters)
	list_col.move_child(filters, 0)
	_warrior_filters_row = filters

	var bridge_holder := Control.new()
	bridge_holder.name = "WarriorFiltersBridgeHolder"
	bridge_holder.custom_minimum_size = Vector2(0, 6)
	bridge_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bridge_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list_col.add_child(bridge_holder)
	list_col.move_child(bridge_holder, 1)
	_warrior_filters_bridge_holder = bridge_holder

	var bridge := Panel.new()
	bridge.name = "WarriorFiltersBridge"
	bridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bridge_style := StyleBoxFlat.new()
	bridge_style.bg_color = MENU_PALETTE.with_alpha(MENU_CLR_ACCENT, 1.0)
	bridge_style.border_width_left = 1
	bridge_style.border_width_top = 0
	bridge_style.border_width_right = 1
	bridge_style.border_width_bottom = 1
	bridge_style.border_color = MENU_PALETTE.with_alpha(MENU_CLR_ACCENT, 1.0)
	bridge.add_theme_stylebox_override("panel", bridge_style)
	bridge_holder.add_child(bridge)
	_warrior_filters_bridge = bridge
	filters.resized.connect(_update_warrior_filter_bridge)
	bridge_holder.resized.connect(_update_warrior_filter_bridge)
	_warrior_filter_warrior_buttons = {}
	var all_btn := _make_filter_button("ALL")
	all_btn.pressed.connect(func() -> void:
		_warrior_filter_warrior_id = ""
		_refresh_warrior_filter_button_state()
		_build_warrior_shop_grid()
	)
	filters.add_child(all_btn)
	_warrior_filter_warrior_buttons[""] = all_btn
	for warrior_id in _warrior_ui.warrior_ids():
		var wid := str(warrior_id)
		var btn := _make_filter_button(_warrior_ui.warrior_display_name(wid).to_upper())
		btn.pressed.connect(func() -> void:
			_warrior_filter_warrior_id = wid
			_select_warrior_skin(wid, _equipped_warrior_skin(wid), true)
			_refresh_warrior_filter_button_state()
			_build_warrior_shop_grid()
		)
		filters.add_child(btn)
		_warrior_filter_warrior_buttons[wid] = btn
	_refresh_warrior_filter_button_state()
	call_deferred("_update_warrior_filter_bridge")

func _refresh_warrior_filter_button_state() -> void:
	for key in _warrior_filter_warrior_buttons.keys():
		var btn := _warrior_filter_warrior_buttons.get(key, null) as Button
		_set_filter_btn_selected(btn, str(key) == _warrior_filter_warrior_id)
		if btn == null:
			continue
		if str(key).is_empty():
			btn.text = "ALL"
			continue
		var wid := str(key)
		var title := _warrior_ui.warrior_display_name(wid).to_upper()
		btn.text = title
	call_deferred("_update_warrior_filter_bridge")

func _update_warrior_filter_bridge() -> void:
	if _warrior_filters_bridge_holder == null or not is_instance_valid(_warrior_filters_bridge_holder):
		return
	if _warrior_filters_bridge == null or not is_instance_valid(_warrior_filters_bridge):
		return
	if _warrior_filters_row == null or not is_instance_valid(_warrior_filters_row):
		return
	var key := _warrior_filter_warrior_id
	if not _warrior_filter_warrior_buttons.has(key):
		key = ""
	var selected_btn := _warrior_filter_warrior_buttons.get(key, null) as Button
	if selected_btn == null or not is_instance_valid(selected_btn):
		_warrior_filters_bridge.visible = false
		return
	_warrior_filters_bridge.visible = true
	var x := _warrior_filters_row.position.x + selected_btn.position.x
	var w := selected_btn.size.x
	_warrior_filters_bridge.position = Vector2(x, 0)
	_warrior_filters_bridge.size = Vector2(maxf(1.0, w), _warrior_filters_bridge_holder.size.y)

func _select_warrior_skin(warrior_id: String, skin_index: int, silent: bool) -> void:
	_shop_controller.select_warrior_skin(self, warrior_id, skin_index, silent)
	_refresh_selection_context_visuals()

func _equip_warrior_item(warrior_id: String, skin_index: int) -> void:
	_shop_controller.equip_warrior_item(self, warrior_id, skin_index)

func _buy_warrior_if_needed(warrior_id: String) -> bool:
	return _shop_controller.buy_warrior_if_needed(self, warrior_id)

func _buy_warrior_skin_if_needed(warrior_id: String, skin_index: int) -> bool:
	return _shop_controller.buy_warrior_skin_if_needed(self, warrior_id, skin_index)

func _confirm_buy_warrior_skin_and_equip(warrior_id: String, skin_index: int) -> void:
	_shop_controller.confirm_buy_warrior_skin_and_equip(self, warrior_id, skin_index)

func _confirm_buy_warrior_then_maybe_skin(warrior_id: String, skin_index: int) -> void:
	_shop_controller.confirm_buy_warrior_then_maybe_skin(self, warrior_id, skin_index)

func _on_warrior_item_button_pressed(warrior_id: String, skin_index: int) -> void:
	_shop_controller.on_warrior_item_button_pressed(self, warrior_id, skin_index)

func _refresh_warrior_grid_texts() -> void:
	_shop_controller.refresh_warrior_grid_texts(self)

func _refresh_warrior_action() -> void:
	_shop_controller.refresh_warrior_action(self)

func _on_warrior_action_pressed() -> void:
	_shop_controller.on_warrior_action_pressed(self)

func _is_warrior_skin_owned(skin_index: int) -> bool:
	return _warrior_skin_is_owned(selected_warrior_id, skin_index)

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

func _equipped_weapon_skin(weapon_id: String) -> int:
	var normalized := weapon_id.strip_edges().to_lower()
	if equipped_weapon_skin_by_weapon.has(normalized):
		return maxi(0, int(equipped_weapon_skin_by_weapon.get(normalized, 0)))
	return 0

func _set_equipped_weapon_skin(weapon_id: String, skin_index: int) -> void:
	var normalized := weapon_id.strip_edges().to_lower()
	equipped_weapon_skin_by_weapon[normalized] = maxi(0, skin_index)

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
			return "%s  [OWNED]" % base
		return base

	return "%s  (%d)  [LOCKED]" % [base, _weapon_skin_cost(weapon_id, skin_index)]

func _select_weapon_skin(weapon_id: String, skin_index: int, silent: bool) -> void:
	_shop_controller.select_weapon_skin(self, weapon_id, skin_index, silent)
	_refresh_selection_context_visuals()

func _equip_weapon_item(weapon_id: String, skin_index: int) -> void:
	_shop_controller.equip_weapon_item(self, weapon_id, skin_index)

func _buy_weapon_if_needed(weapon_id: String) -> bool:
	return _shop_controller.buy_weapon_if_needed(self, weapon_id)

func _buy_weapon_skin_if_needed(weapon_id: String, skin_index: int) -> bool:
	return _shop_controller.buy_weapon_skin_if_needed(self, weapon_id, skin_index)

func _confirm_buy_weapon_skin_and_equip(weapon_id: String, skin_index: int) -> void:
	_shop_controller.confirm_buy_weapon_skin_and_equip(self, weapon_id, skin_index)

func _confirm_buy_weapon_then_maybe_skin(weapon_id: String, skin_index: int) -> void:
	_shop_controller.confirm_buy_weapon_then_maybe_skin(self, weapon_id, skin_index)

func _on_weapon_item_button_pressed(weapon_id: String, skin_index: int) -> void:
	_shop_controller.on_weapon_item_button_pressed(self, weapon_id, skin_index)

func _refresh_weapon_grid_texts() -> void:
	_shop_controller.refresh_weapon_grid_texts(self)

func _refresh_weapon_action() -> void:
	_shop_controller.refresh_weapon_action(self)

func _on_weapon_action_pressed() -> void:
	_shop_controller.on_weapon_action_pressed(self)

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
	var intro_active := intro != null and intro.visible
	var px_size := 24.0 if intro_active else 6.0
	var drift_min := 34.0 if intro_active else 18.0
	var drift_max := 220.0 if intro_active else 70.0
	var jitter := 28.0 if intro_active else 10.0
	var tween_time := 0.62 if intro_active else 0.5
	var scale_target := Vector2(4.0, 4.0) if intro_active else Vector2(1.8, 1.8)
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
		p.custom_minimum_size = Vector2(px_size, px_size)
		p.size = Vector2(px_size, px_size)
		p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_fx_layer.add_child(p)
		p.global_position = global_pos - Vector2(px_size * 0.5, px_size * 0.5)

		var angle := randf() * TAU
		var dist := randf_range(drift_min, drift_max)
		var drift := Vector2(cos(angle), sin(angle)) * dist + Vector2(randf_range(-jitter, jitter), randf_range(-jitter, jitter))

		var t := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.parallel().tween_property(p, "global_position", p.global_position + drift, tween_time)
		t.parallel().tween_property(p, "modulate:a", 0.0, tween_time)
		t.parallel().tween_property(p, "rotation", randf_range(-2.5, 2.5), tween_time)
		t.parallel().tween_property(p, "scale", scale_target, tween_time)
		t.tween_callback(func() -> void: p.queue_free())

func _load_state_or_defaults() -> void:
	var fallback_username := OS.get_environment("USERNAME").strip_edges()
	if fallback_username.is_empty():
		fallback_username = "Player"
	var default_warrior := _default_warrior_id()
	var default_owned_warriors := _default_owned_warriors()
	var default_warrior_skins := _default_owned_warrior_skins_by_warrior()
	var default_equipped_warrior_skins := _default_equipped_warrior_skin_by_warrior()
	var defaults := {
		"coins": 1000000,
		"clk": 50000,
		"music_volume": 0.8,
		"sfx_volume": 0.4,
		"username": fallback_username,
		"owned_warriors": Array(default_owned_warriors),
		"owned_warrior_skins": [0],
		"owned_warrior_skins_by_warrior": default_warrior_skins,
		"equipped_warrior_skin_by_warrior": default_equipped_warrior_skins,
		"selected_warrior_id": default_warrior,
		"selected_warrior_skin": 0,
		"owned_weapons": [WEAPON_UZI, WEAPON_GRENADE],
		"owned_weapon_skins_by_weapon": {WEAPON_UZI: [0], WEAPON_GRENADE: [0], WEAPON_AK47: [0], WEAPON_KAR: [0], WEAPON_SHOTGUN: [0]},
		"equipped_weapon_skin_by_weapon": {WEAPON_UZI: 0, WEAPON_GRENADE: 0, WEAPON_AK47: 0, WEAPON_KAR: 0, WEAPON_SHOTGUN: 0},
		"selected_weapon_id": WEAPON_UZI,
		"selected_weapon_skin": 0,
	}
	var st := _state_store.load_state_or_defaults(DATA.SHOP_STATE_PATH, defaults, WEAPON_UZI)
	if music_slider != null:
		music_slider.value = clampf(float(st.get("music_volume", 0.8)), 0.0, 1.0)
	if sfx_slider != null:
		sfx_slider.value = clampf(float(st.get("sfx_volume", 0.4)), 0.0, 1.0)

	wallet_coins = int(st.get("coins", 0))
	wallet_clk = int(st.get("clk", 0))
	player_username = str(st.get("username", fallback_username)).strip_edges()
	if player_username.is_empty():
		player_username = fallback_username

	owned_warriors = PackedStringArray(st.get("owned_warriors", Array(default_owned_warriors)) as Array)
	owned_warrior_skins = PackedInt32Array(st.get("owned_warrior_skins", [0]) as Array)
	selected_warrior_id = str(st.get("selected_warrior_id", default_warrior)).strip_edges().to_lower()
	selected_warrior_skin = maxi(0, int(st.get("selected_warrior_skin", 0)))
	var warrior_skin_dict := st.get("owned_warrior_skins_by_warrior", default_warrior_skins) as Dictionary
	owned_warrior_skins_by_warrior = _normalize_owned_warrior_skins_dict(warrior_skin_dict)
	var equipped_warrior := st.get("equipped_warrior_skin_by_warrior", default_equipped_warrior_skins) as Dictionary
	equipped_warrior_skin_by_warrior = _normalize_equipped_warrior_skins_dict(equipped_warrior.duplicate(true))
	for wid in _warrior_ui.warrior_ids():
		if not owned_warrior_skins_by_warrior.has(wid):
			owned_warrior_skins_by_warrior[wid] = PackedInt32Array([0])
		if not equipped_warrior_skin_by_warrior.has(wid):
			equipped_warrior_skin_by_warrior[wid] = 0

	owned_weapons = PackedStringArray(st.get("owned_weapons", [WEAPON_UZI]) as Array)
	selected_weapon_id = str(st.get("selected_weapon_id", WEAPON_UZI)).strip_edges().to_lower()
	selected_weapon_skin = maxi(0, int(st.get("selected_weapon_skin", 0)))

	# Sanitize weapon ids (remove weapons that no longer exist in this menu).
	var allowed := PackedStringArray([WEAPON_UZI, WEAPON_AK47, WEAPON_KAR, WEAPON_SHOTGUN, WEAPON_GRENADE])
	var filtered_owned := PackedStringArray()
	for wid in owned_weapons:
		var w := str(wid).strip_edges().to_lower()
		if allowed.has(w):
			filtered_owned.append(w)
	owned_weapons = filtered_owned
	if not owned_weapons.has(WEAPON_UZI):
		owned_weapons.append(WEAPON_UZI)
	if not owned_weapons.has(WEAPON_GRENADE):
		owned_weapons.append(WEAPON_GRENADE)
	if not owned_warriors.has(default_warrior):
		owned_warriors.append(default_warrior)

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
		if not equipped_weapon_skin_by_weapon.has(wid):
			equipped_weapon_skin_by_weapon[wid] = 0

	var eq := st.get("equipped_weapon_skin_by_weapon", {}) as Dictionary
	if eq != null:
		for key in eq.keys():
			var wid := str(key).strip_edges().to_lower()
			if not allowed.has(wid):
				continue
			equipped_weapon_skin_by_weapon[wid] = maxi(0, int(eq.get(key, 0)))

	# Clamp selections to owned.
	if not _warrior_is_owned(selected_warrior_id):
		selected_warrior_id = default_warrior
	if not _warrior_skin_is_owned(selected_warrior_id, selected_warrior_skin):
		selected_warrior_skin = 0
	_set_equipped_warrior_skin(selected_warrior_id, selected_warrior_skin)
	_pending_warrior_id = selected_warrior_id
	_pending_warrior_skin = selected_warrior_skin
	if not _weapon_is_owned(selected_weapon_id):
		selected_weapon_id = WEAPON_UZI
	if not _weapon_skin_is_owned(selected_weapon_id, selected_weapon_skin):
		selected_weapon_skin = 0
	_set_equipped_weapon_skin(selected_weapon_id, selected_weapon_skin)
	_pending_weapon_id = selected_weapon_id
	_pending_weapon_skin = selected_weapon_skin

func _save_state() -> void:
	var owned_warriors_list: Array = []
	for wid in owned_warriors:
		owned_warriors_list.append(str(wid))

	var owned_warrior_skins_dict: Dictionary = {}
	for wid in owned_warrior_skins_by_warrior.keys():
		var warrior_arr := owned_warrior_skins_by_warrior.get(wid, PackedInt32Array([0])) as PackedInt32Array
		var warrior_out: Array = []
		if warrior_arr != null:
			for s in warrior_arr:
				warrior_out.append(int(s))
		owned_warrior_skins_dict[str(wid)] = warrior_out

	var owned_warrior_skin_list: Array = []
	for v in owned_warrior_skins:
		owned_warrior_skin_list.append(int(v))

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
		"music_volume": music_slider.value if music_slider != null else 0.8,
		"sfx_volume": sfx_slider.value if sfx_slider != null else 0.4,
		"username": player_username,
		"owned_warriors": owned_warriors_list,
		"owned_warrior_skins": owned_warrior_skin_list,
		"owned_warrior_skins_by_warrior": owned_warrior_skins_dict,
		"equipped_warrior_skin_by_warrior": equipped_warrior_skin_by_warrior,
		"selected_warrior_id": selected_warrior_id,
		"selected_warrior_skin": selected_warrior_skin,
		"owned_weapons": owned_weapons_list,
		"owned_weapon_skins_by_weapon": owned_weapon_skins_dict,
		"equipped_weapon_skin_by_weapon": equipped_weapon_skin_by_weapon,
		"selected_weapon_id": selected_weapon_id,
		"selected_weapon_skin": selected_weapon_skin,
	}
	_state_store.save_state(DATA.SHOP_STATE_PATH, d)

func _ensure_warrior_username_label() -> void:
	_meta_ui.ensure_warrior_username_label(self)

func _refresh_warrior_username_label() -> void:
	_meta_ui.refresh_warrior_username_label(self)

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
	_bind_menu_sfx_button(btn)
	_ui_anim.add_hover_pop(btn)

func _bind_menu_sfx_button(btn: BaseButton) -> void:
	if _menu_sfx == null:
		return
	_menu_sfx.bind_button(btn)

func _bind_menu_sfx_slider(slider: HSlider) -> void:
	if _menu_sfx == null:
		return
	_menu_sfx.bind_slider(slider)

func _bind_menu_sfx_option(option: OptionButton) -> void:
	if _menu_sfx == null:
		return
	_menu_sfx.bind_option(option)

func _on_music_slider_changed(value: float) -> void:
	if _intro_fx == null:
		return
	if _intro_fx.has_method("set_menu_music_volume_linear"):
		_intro_fx.call("set_menu_music_volume_linear", clampf(value, 0.0, 1.0))
	_save_state()

func _on_sfx_slider_changed(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	_set_sound_buses_volume_linear(clamped)
	if _menu_sfx != null and _menu_sfx.has_method("set_output_volume_linear"):
		_menu_sfx.call("set_output_volume_linear", clamped)
	if _intro_fx != null and _intro_fx.has_method("set_menu_sfx_volume_linear"):
		_intro_fx.call("set_menu_sfx_volume_linear", clamped)
	_save_state()

func _set_sound_buses_volume_linear(value: float) -> void:
	var db := -80.0 if value <= 0.001 else linear_to_db(value)
	var sfx_idx := _ensure_audio_bus("SFX", "Master")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, db)
	var target_names := {
		"sounds": true,
		"gamesfx": true,
		"game_sfx": true,
		"gameplay_sfx": true,
	}
	for i in range(AudioServer.get_bus_count()):
		var bus_name := AudioServer.get_bus_name(i).to_lower()
		if target_names.has(bus_name):
			AudioServer.set_bus_volume_db(i, db)

func _ensure_audio_bus(name: String, send_to: String = "Master") -> int:
	var wanted := name.strip_edges()
	if wanted.is_empty():
		return -1
	for i in range(AudioServer.get_bus_count()):
		if AudioServer.get_bus_name(i).to_lower() == wanted.to_lower():
			return i
	AudioServer.add_bus(AudioServer.get_bus_count())
	var idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, wanted)
	if not send_to.strip_edges().is_empty():
		AudioServer.set_bus_send(idx, send_to)
	return idx

func _hover_area(area: Control, hovered: bool) -> void:
	_ui_anim.hover_area(area, hovered)

func _press_in(ci: CanvasItem, target_mult: float) -> void:
	_ui_anim.press_in(ci, target_mult)

func _release_to_hover(ci: CanvasItem, btn: Button) -> void:
	_ui_anim.release_to_hover(ci, btn)

func _button_press_anim(ci: CanvasItem, extra_scale: float = 0.06) -> void:
	_ui_anim.button_press_anim(self, ci, extra_scale)

func _tween_scale(ci: CanvasItem, target_scale: Vector2, duration: float) -> void:
	_ui_anim.tween_scale(ci, target_scale, duration)

func _pop(ci: CanvasItem) -> void:
	_ui_anim.pop(self, ci)

func _shake(ci: CanvasItem) -> void:
	_ui_anim.shake(self, ci)

func _start_idle_loop() -> void:
	_idle_anim.start_idle_loop(
		_current_screen,
		_visible_weapon_id,
		_visible_weapon_skin,
		Callable(self, "_set_weapon_icon_sprite"),
		Callable(self, "_apply_weapon_skin_visual")
	)

func _stop_idle_loop() -> void:
	_idle_anim.stop_idle_loop()
