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
const MENU_AMBIENT_FX_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/main_menu_ambient_fx_controller.gd")
const MENU_OPTIONS_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/main_menu_options_controller.gd")
const MENU_PREVIEW_FILTER_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/main_menu_preview_filter_controller.gd")
const MENU_SHOP_GRID_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/main_menu_shop_grid_controller.gd")
const MENU_LOBBY_FLOW_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/main_menu_lobby_flow_controller.gd")
const MENU_LAYOUT_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/main_menu_layout_controller.gd")
const MENU_LOADOUT_STATE_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/main_menu_loadout_state_controller.gd")
const MENU_DIALOG_CTRL_SCRIPT := preload("res://scripts/ui/main_menu/main_menu_dialog_controller.gd")
const MENU_PALETTE := preload("res://scripts/ui/main_menu/menu_palette.gd")
const PIXEL_FONT_BOLD := preload("res://assets/fonts/pixel_operator/PixelOperator-Bold.ttf")
const PIXEL_FONT_CHAT := preload("res://assets/fonts/pixel_operator/PixelOperator.ttf")
const TOXIC_CHAT_BOX_SIZE := Vector2(196.0, 82.0)
const TOXIC_CHAT_MARGIN_X := 5
const TOXIC_CHAT_MARGIN_Y := 4
const TOXIC_CHAT_ROW_SEPARATION := 1
const AUTH_API_BASE_URL_DEFAULT := "http://updates.outrage.ink:8081/auth"
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
const TOXIC_BUBBLE_LINES := [
	"GIT GUD",
	"U SUCK LOL",
	"TRASH AIM!",
	"1V1 ME IRL",
	"EZ NOOB!!!",
	"L + RATIO + CRY",
	"TOXIC TRASH!!",
	"SPAM SPAM",
	"SKILL ISSUE",
	"ALT+F4",
	"GG EZ",
	"@#$% YOU!",
	"@!$#%!",
	"UNINSTALL",
	"WHO BOOSTED U?",
	"AIM.EXE OFF",
	"BOT LOBBY HERO",
	"CLIP IT... NOT",
	"CRY MORE",
	"TOUCH GRASS",
	"COPE HARDER",
	"NICE TRY LOL",
	"PING DIFF?",
	"HIT UR SHOTS",
	"REPORT THIS GUY",
	"#@!$ NO WAY",
	"$%#@ GET REKT",
]
const TOXIC_CHAT_USERS := [
	"BLACKSHADOW",
	"KRYPTON",
	"VOIDCAT",
	"RAGEBYTE",
	"PIXEL_KID",
	"LAGLORD",
	"AIMBOT_404",
]

@export var enable_intro_animation := true
@export var intro_timeout_sec := 6.0
@export var intro_failfast_quit := true
@export var intro_fx_enabled := true
@export var intro_fx_particles_per_burst := 12
@export var cracked_background_enabled := true
@export var cracked_background_impacts := 3
@export var toxic_bubbles_enabled := true

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
var _ambient_fx := MENU_AMBIENT_FX_CTRL_SCRIPT.new()
var _menu_options := MENU_OPTIONS_CTRL_SCRIPT.new()
var _preview_filter_ctrl := MENU_PREVIEW_FILTER_CTRL_SCRIPT.new()
var _shop_grid_ctrl := MENU_SHOP_GRID_CTRL_SCRIPT.new()
var _lobby_flow_ctrl := MENU_LOBBY_FLOW_CTRL_SCRIPT.new()
var _layout_ctrl := MENU_LAYOUT_CTRL_SCRIPT.new()
var _loadout_state_ctrl := MENU_LOADOUT_STATE_CTRL_SCRIPT.new()
var _dialog_ctrl := MENU_DIALOG_CTRL_SCRIPT.new()

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
@onready var warriors_title: Label = %WarriorsTitle
@onready var weapons_back_button: Button = %WeaponsBackButton
@onready var warriors_right_spacer: Control = %WarriorsRightSpacer
@onready var warriors_top_row: HBoxContainer = $Screens/ScreenWarriors/WarriorsPanel/Margin/OuterVBox/TopRow
@onready var weapons_right_spacer: Control = %WeaponsRightSpacer
@onready var weapons_top_row: HBoxContainer = $Screens/ScreenWeapons/WeaponsPanel/Margin/OuterVBox/TopRow

@onready var music_slider: HSlider = %MusicSlider
@onready var sfx_slider: HSlider = %SfxSlider
@onready var particles_toggle_button: Button = %ParticlesToggleButton
@onready var screen_shake_toggle_button: Button = %ScreenShakeToggleButton

@onready var intro: Control = %Intro
@onready var intro_fade: ColorRect = $Intro/IntroFade
@onready var intro_plate: PanelContainer = $Intro/IntroPlate
@onready var intro_label: Label = $Intro/IntroLabel

const WARRIORS_BACK_BUTTON_SCREEN_POS := Vector2(16.0, 16.0)
const WARRIORS_TITLE_SCREEN_Y := 44.0
const WARRIOR_PREVIEW_ZOOM_STEP := 0.1
const WARRIOR_PREVIEW_ZOOM_MIN := 0.85
const WARRIOR_PREVIEW_ZOOM_MAX := 2.4

@onready var warrior_grid: GridContainer = %WarriorGrid
@onready var warrior_scroll: ScrollContainer = $Screens/ScreenWarriors/WarriorsPanel/Margin/OuterVBox/BodyRow/ListCol/WarriorCenter/WarriorScroll
@onready var warrior_skin_grid: GridContainer = %WarriorSkinGrid
@onready var warrior_skin_scroll: ScrollContainer = %WarriorSkinScroll
@onready var warriors_panel: PanelContainer = $Screens/ScreenWarriors/WarriorsPanel
@onready var warriors_body_row: HBoxContainer = $Screens/ScreenWarriors/WarriorsPanel/Margin/OuterVBox/BodyRow
@onready var warrior_preview_col: Control = $Screens/ScreenWarriors/WarriorsPanel/Margin/OuterVBox/BodyRow/PreviewCol
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
var _weapon_filters_row: HFlowContainer
var _weapon_filters_bridge_holder: Control
var _weapon_filters_bridge: Panel
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
var _warrior_preview_zoom_mult := 1.0
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
var _auth_timeout_retry_attempts := 0
var _auth_timeout_retry_limit := 1
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
var particles_enabled := true
var screen_shake_enabled := true

func _ready() -> void:
	_ensure_cursor_manager()
	_menu_sfx.configure(self)
	_menu_options.configure(self, _menu_sfx, _intro_fx)
	_preview_filter_ctrl.configure(self)
	_shop_grid_ctrl.configure(self)
	_lobby_flow_ctrl.configure(self)
	_layout_ctrl.configure(self)
	_loadout_state_ctrl.configure(self)
	_dialog_ctrl.configure(self, CONFIRM_OVERLAY_SCRIPT, CURSOR_MANAGER_NAME, ENABLE_MENU_LOADING_OVERLAY)
	_menu_loading_overlay.configure(self)
	_current_screen = screen_main
	_ambient_fx.configure(
		self,
		PIXEL_FONT_BOLD,
		PIXEL_FONT_CHAT,
		screen_main,
		TOXIC_CHAT_USERS,
		TOXIC_BUBBLE_LINES,
		Callable(self, "_get_current_screen"),
		Callable(self, "_get_warrior_username_label"),
		Callable(self, "_get_warrior_area"),
		Callable(self, "_get_main_warrior_preview")
	)
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
	enable_intro_animation = false
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
	_ensure_background_crack_layer()
	_rebuild_background_cracks()
	# Temporary: keep the scripted auto-chat hidden on the main menu.
	# _ensure_toxic_bubble_layer()
	# _start_toxic_bubble_loop()
	set_process(true)

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
	call_deferred("_sync_wallet_size_to_back_button")
	call_deferred("_sync_warriors_header_centering")
	call_deferred("_sync_weapons_header_centering")
	call_deferred("_pin_warriors_back_button")
	var viewport := get_viewport()
	if viewport != null:
		var size_cb := Callable(self, "_on_viewport_size_changed")
		if not viewport.size_changed.is_connected(size_cb):
			viewport.size_changed.connect(size_cb)
	_apply_pixel_slider_style(music_slider)
	_apply_pixel_slider_style(sfx_slider)
	_apply_pixel_scroll_style(warrior_scroll)
	_apply_pixel_scroll_style(warrior_skin_scroll)
	_apply_pixel_scroll_style(weapon_scroll)
	_apply_grid_spacing(warrior_grid)
	_apply_grid_spacing(warrior_skin_grid)
	_apply_grid_spacing(weapon_grid)
	if warrior_grid != null:
		warrior_grid.add_theme_constant_override("h_separation", 8)
		warrior_grid.add_theme_constant_override("v_separation", 8)
	if warrior_skin_grid != null:
		warrior_skin_grid.add_theme_constant_override("h_separation", 6)
		warrior_skin_grid.add_theme_constant_override("v_separation", 6)
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
	return _auth_flow.default_warrior_id(self)

func _default_owned_warriors() -> PackedStringArray:
	return _auth_flow.default_owned_warriors(self)

func _default_owned_warrior_skins_by_warrior() -> Dictionary:
	return _auth_flow.default_owned_warrior_skins_by_warrior(self)

func _default_equipped_warrior_skin_by_warrior() -> Dictionary:
	return _auth_flow.default_equipped_warrior_skin_by_warrior(self)

func _warrior_ui_warrior_ids() -> PackedStringArray:
	return _warrior_ui.warrior_ids()

func _warrior_ui_available_skin_indices_for(warrior_id: String) -> PackedInt32Array:
	return _warrior_ui.available_skin_indices_for(warrior_id)

func _warrior_ui_warrior_display_name(warrior_id: String) -> String:
	return _warrior_ui.warrior_display_name(warrior_id)

func _warrior_ui_warrior_skin_label(warrior_id: String, skin_index: int) -> String:
	return _warrior_ui.warrior_skin_label(warrior_id, skin_index)

func _weapon_ui_weapon_display_name(weapon_id: String) -> String:
	return _weapon_ui.weapon_display_name(weapon_id)

func _normalize_owned_warrior_skins_dict(src: Dictionary) -> Dictionary:
	return _auth_flow.normalize_owned_warrior_skins_dict(self, src)

func _normalize_equipped_warrior_skins_dict(src: Dictionary) -> Dictionary:
	return _auth_flow.normalize_equipped_warrior_skins_dict(self, src)

func _auth_apply_profile(profile: Dictionary) -> void:
	_auth_flow.auth_apply_profile(self, profile)

func _auth_finalize_without_remote_profile(reason: String = "") -> void:
	_auth_flow.auth_finalize_without_remote_profile(self, reason)

func _auth_dev_unlock_all_for_mario() -> void:
	_auth_flow.auth_dev_unlock_all_for_mario(self)

func _on_auth_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_auth_flow.auth_handle_http_completed(self, response_code, body)

func _ensure_cursor_manager() -> void:
	_menu_nav.ensure_cursor_manager(self, CURSOR_MANAGER_SCRIPT, CURSOR_MANAGER_NAME)

func _apply_menu_cursor_context() -> void:
	_menu_nav.apply_menu_cursor_context(self, CURSOR_MANAGER_NAME)

func _input(event: InputEvent) -> void:
	if intro != null and intro.visible:
		return
	if _handle_warrior_preview_zoom_input(event):
		return
	_menu_nav.handle_input(self, event)

func _unhandled_input(event: InputEvent) -> void:
	if intro != null and intro.visible:
		return
	_menu_nav.handle_unhandled_input(self, event)

func _toggle_fullscreen() -> void:
	_menu_nav.toggle_fullscreen()

func _apply_center_pivots() -> void:
	_layout_ctrl.apply_center_pivots()

func _sync_wallet_size_to_back_button() -> void:
	_layout_ctrl.sync_wallet_size_to_back_button()

func _sync_warriors_header_centering() -> void:
	_layout_ctrl.sync_warriors_header_centering()

func _sync_weapons_header_centering() -> void:
	_layout_ctrl.sync_weapons_header_centering()

func _on_viewport_size_changed() -> void:
	_layout_ctrl.on_viewport_size_changed()

func _pin_warriors_back_button() -> void:
	_layout_ctrl.pin_warriors_back_button()

func _center_pivot(c: Control) -> void:
	_layout_ctrl.center_pivot(c)

func _play_intro_animation_safe() -> void:
	_intro_fx.enable_intro_animation = enable_intro_animation
	_intro_fx.intro_timeout_sec = intro_timeout_sec
	_intro_fx.intro_fx_enabled = intro_fx_enabled
	_intro_fx.play_intro_animation_safe()
	enable_intro_animation = _intro_fx.enable_intro_animation
	_refresh_global_overlay_ui_state()

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
	if particles_toggle_button != null:
		var particles_cb := Callable(self, "_on_particles_toggle_pressed")
		if not particles_toggle_button.pressed.is_connected(particles_cb):
			particles_toggle_button.pressed.connect(particles_cb)
		_bind_menu_sfx_button(particles_toggle_button)
	if screen_shake_toggle_button != null:
		var shake_cb := Callable(self, "_on_screen_shake_toggle_pressed")
		if not screen_shake_toggle_button.pressed.is_connected(shake_cb):
			screen_shake_toggle_button.pressed.connect(shake_cb)
		_bind_menu_sfx_button(screen_shake_toggle_button)

func _on_play_pressed() -> void:
	await _lobby_flow_ctrl.on_play_pressed()

func _open_lobby_menu_flow() -> void:
	_lobby_flow_ctrl.open_lobby_menu_flow()

func _run_play_lobby_transition() -> void:
	await _lobby_flow_ctrl.run_play_lobby_transition()

func _fade_out_play_lobby_transition() -> void:
	_lobby_flow_ctrl.fade_out_play_lobby_transition()

func _cleanup_play_lobby_transition() -> void:
	_lobby_flow_ctrl.cleanup_play_lobby_transition()

func _cache_play_lobby_fade_targets() -> void:
	_lobby_flow_ctrl.cache_play_lobby_fade_targets()

func _restore_play_lobby_fade_targets() -> void:
	_lobby_flow_ctrl.restore_play_lobby_fade_targets()

func _run_play_lobby_reverse_transition() -> void:
	await _lobby_flow_ctrl.run_play_lobby_reverse_transition()

func _run_lobby_menu_loading_sequence() -> void:
	await _lobby_flow_ctrl.run_lobby_menu_loading_sequence()

func _on_lobby_overlay_closed() -> void:
	await _lobby_flow_ctrl.on_lobby_overlay_closed()

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
	_dialog_ctrl.show_menu_loading_overlay(message)

func _hide_menu_loading_overlay() -> void:
	_dialog_ctrl.hide_menu_loading_overlay()

func _on_menu_loading_overlay_shown() -> void:
	_dialog_ctrl.on_menu_loading_overlay_shown()

func _on_menu_loading_overlay_hidden() -> void:
	_dialog_ctrl.on_menu_loading_overlay_hidden()

func _set_menu_cursor_hover_blocked(blocked: bool) -> void:
	_dialog_ctrl.set_menu_cursor_hover_blocked(blocked)

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
	_warrior_preview_zoom_mult = 1.0
	_apply_warrior_preview_zoom()
	_apply_meta_ui_visibility(false)
	_menu_transition_ctrl.open_warriors_menu()
	call_deferred("_sync_warriors_header_centering")

func _open_warriors_menu_stage2() -> void:
	_menu_transition_ctrl.open_warriors_menu_stage2(warriors_menu_preview_scale_mult, _warrior_shop_preview_base_scale)
	call_deferred("_sync_warriors_header_centering")

func _close_warriors_menu() -> void:
	if _current_screen != screen_warriors:
		return
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	selected_warrior_id = _pending_warrior_id
	selected_warrior_skin = _pending_warrior_skin
	_set_equipped_warrior_skin(selected_warrior_id, selected_warrior_skin)
	owned_warrior_skins = owned_warrior_skins_by_warrior.get(selected_warrior_id, PackedInt32Array([0])) as PackedInt32Array
	_apply_warrior_skin_to_player(main_warrior_preview, _pending_warrior_id, _pending_warrior_skin)
	_apply_warrior_skin_to_player(warrior_shop_preview, _pending_warrior_id, _pending_warrior_skin)
	if warrior_name_label != null:
		warrior_name_label.text = "%s - %s" % [_warrior_ui.warrior_display_name(_pending_warrior_id), _warrior_ui.warrior_skin_label(_pending_warrior_id, _pending_warrior_skin)]
	_build_warrior_skin_grid(_pending_warrior_id)
	_refresh_warrior_grid_texts()
	_refresh_warrior_action()
	_save_state()
	_sync_active_lobby_loadout_selection()
	_menu_transition_ctrl.close_warriors_menu()

func _close_warriors_menu_stage2() -> void:
	_menu_transition_ctrl.close_warriors_menu_stage2(_warrior_shop_preview_base_scale)

func _open_weapons_menu() -> void:
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	_apply_meta_ui_visibility(false)
	_menu_transition_ctrl.open_weapons_menu(_pending_weapon_id, _pending_weapon_skin)
	call_deferred("_sync_weapons_header_centering")

func _open_weapons_menu_stage2() -> void:
	_menu_transition_ctrl.open_weapons_menu_stage2(_pending_weapon_id, _pending_weapon_skin, WEAPON_UZI)
	call_deferred("_sync_weapons_header_centering")

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
	_refresh_global_overlay_ui_state()
	_refresh_warrior_username_label()
	_refresh_auth_footer()

func _refresh_global_overlay_ui_state() -> void:
	if wallet_panel != null:
		wallet_panel.visible = true
		wallet_panel.z_as_relative = false
		wallet_panel.z_index = 3000
	set("_meta_force_immediate_visibility", true)
	_refresh_meta_ui_visibility()

func _sync_lobby_overlay_interaction_state() -> void:
	if _lobby_overlay_ctrl == null:
		return
	if not _lobby_overlay_ctrl.is_visible():
		_lobby_overlay_ctrl.set_interaction_enabled(true)
		return
	var allow_interaction := _current_screen == screen_main
	_lobby_overlay_ctrl.set_interaction_enabled(allow_interaction)

func _sync_active_lobby_loadout_selection() -> void:
	if _lobby_overlay_ctrl == null:
		return
	if _lobby_overlay_ctrl.has_method("sync_current_loadout_to_lobby"):
		_lobby_overlay_ctrl.call("sync_current_loadout_to_lobby")

func _prepare_player_preview(player: Node) -> void:
	_preview_filter_ctrl.prepare_player_preview(player)

func _handle_warrior_preview_zoom_input(event: InputEvent) -> bool:
	return _preview_filter_ctrl.handle_warrior_preview_zoom_input(event)

func _apply_warrior_preview_zoom() -> void:
	_preview_filter_ctrl.apply_warrior_preview_zoom()

func _apply_warrior_skin_to_player(player: Node, warrior_id: String, skin_index: int) -> void:
	_preview_filter_ctrl.apply_warrior_skin_to_player(player, warrior_id, skin_index)

func _set_weapon_icon_sprite(target: Sprite2D, weapon_id: String, extra_mult: float = 1.0, skin_index: int = 0) -> void:
	_preview_filter_ctrl.set_weapon_icon_sprite(target, weapon_id, extra_mult, skin_index)

func _sync_visible_weapon_from_preview() -> void:
	_preview_filter_ctrl.sync_visible_weapon_from_preview()

func _make_filter_button(text: String) -> Button:
	return _preview_filter_ctrl.make_filter_button(text)

func _set_filter_btn_selected(btn: Button, selected: bool) -> void:
	_preview_filter_ctrl.set_filter_btn_selected(btn, selected)

func _refresh_weapon_filter_button_state() -> void:
	_preview_filter_ctrl.refresh_weapon_filter_button_state()

func _ensure_weapon_filter_ui() -> void:
	_preview_filter_ctrl.ensure_weapon_filter_ui()

func _update_weapon_filter_bridge() -> void:
	_preview_filter_ctrl.update_weapon_filter_bridge()

func _icon_global_rect(icon: CanvasItem) -> Rect2:
	return _preview_filter_ctrl.icon_global_rect(icon)

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
	_shop_grid_ctrl.build_warrior_shop_grid()

func _build_warrior_skin_grid(warrior_id: String) -> void:
	_shop_grid_ctrl.build_warrior_skin_grid(warrior_id)

func _on_warrior_select_button_pressed(warrior_id: String) -> void:
	_shop_grid_ctrl.on_warrior_select_button_pressed(warrior_id)

func _on_warrior_skin_button_pressed(warrior_id: String, skin_index: int) -> void:
	_shop_grid_ctrl.on_warrior_skin_button_pressed(warrior_id, skin_index)

func _build_weapon_shop_grid() -> void:
	_shop_grid_ctrl.build_weapon_shop_grid()

func _make_shop_button() -> Button:
	return _shop_grid_ctrl.make_shop_button()

func _copy_button_look(src: Button, dst: Button) -> void:
	_shop_grid_ctrl.copy_button_look(src, dst)

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
	_dialog_ctrl.init_confirm_dialog()

func _ask_confirm(title: String, text: String, on_confirm: Callable, weapon_id: String = "", skin_index: int = 0) -> void:
	_dialog_ctrl.ask_confirm(title, text, on_confirm, weapon_id, skin_index)

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
	return _loadout_state_ctrl.warrior_is_owned(warrior_id)

func _warrior_skin_is_owned(warrior_id: String, skin_index: int) -> bool:
	return _loadout_state_ctrl.warrior_skin_is_owned(warrior_id, skin_index)

func _equipped_warrior_skin(warrior_id: String) -> int:
	return _loadout_state_ctrl.equipped_warrior_skin(warrior_id)

func _set_equipped_warrior_skin(warrior_id: String, skin_index: int) -> void:
	_loadout_state_ctrl.set_equipped_warrior_skin(warrior_id, skin_index)

func _ensure_warrior_filter_ui() -> void:
	return

func _refresh_warrior_filter_button_state() -> void:
	return

func _update_warrior_filter_bridge() -> void:
	return

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
	return _loadout_state_ctrl.is_warrior_skin_owned(skin_index)

func _weapon_is_owned(weapon_id: String) -> bool:
	return _loadout_state_ctrl.weapon_is_owned(weapon_id)

func _weapon_skin_is_owned(weapon_id: String, skin_index: int) -> bool:
	return _loadout_state_ctrl.weapon_skin_is_owned(weapon_id, skin_index)

func _equipped_weapon_skin(weapon_id: String) -> int:
	return _loadout_state_ctrl.equipped_weapon_skin(weapon_id)

func _set_equipped_weapon_skin(weapon_id: String, skin_index: int) -> void:
	_loadout_state_ctrl.set_equipped_weapon_skin(weapon_id, skin_index)

func _weapon_item_button_text(weapon_id: String, skin_index: int) -> String:
	return _loadout_state_ctrl.weapon_item_button_text(weapon_id, skin_index)

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
	_state_store.apply_menu_state(self, DATA.SHOP_STATE_PATH)

func _save_state() -> void:
	_state_store.save_state(DATA.SHOP_STATE_PATH, _state_store.build_menu_state_snapshot(self))

func _ensure_warrior_username_label() -> void:
	_meta_ui.ensure_warrior_username_label(self)

func _refresh_warrior_username_label() -> void:
	_meta_ui.refresh_warrior_username_label(self)

func _update_wallet_labels(silent: bool) -> void:
	_meta_ui.update_wallet_labels(self, silent)

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()

func _add_hover_pop(btn: Button) -> void:
	_bind_menu_sfx_button(btn)
	_ui_anim.add_hover_pop(btn)

func _bind_menu_sfx_button(btn: BaseButton) -> void:
	_menu_options.bind_menu_sfx_button(btn)

func _bind_menu_sfx_slider(slider: HSlider) -> void:
	_menu_options.bind_menu_sfx_slider(slider)

func _bind_menu_sfx_option(option: OptionButton) -> void:
	_menu_options.bind_menu_sfx_option(option)

func _on_music_slider_changed(value: float) -> void:
	_menu_options.on_music_slider_changed(value)

func _on_sfx_slider_changed(value: float) -> void:
	_menu_options.on_sfx_slider_changed(value)

func _on_particles_toggle_pressed() -> void:
	_menu_options.on_particles_toggle_pressed()

func _set_particles_enabled(enabled: bool, save: bool) -> void:
	_menu_options.set_particles_enabled(enabled, save)

func _on_screen_shake_toggle_pressed() -> void:
	_menu_options.on_screen_shake_toggle_pressed()

func _set_screen_shake_enabled(enabled: bool, save: bool) -> void:
	_menu_options.set_screen_shake_enabled(enabled, save)

func _set_sound_buses_volume_linear(value: float) -> void:
	_menu_options.set_sound_buses_volume_linear(value)

func _ensure_audio_bus(bus_name: String, send_to: String = "Master") -> int:
	return _menu_options.ensure_audio_bus(bus_name, send_to)

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

func _ensure_background_crack_layer() -> void:
	_ambient_fx.ensure_background_crack_layer()

func _rebuild_background_cracks() -> void:
	_ambient_fx.rebuild_background_cracks(cracked_background_enabled, cracked_background_impacts)

func _ensure_toxic_bubble_layer() -> void:
	_ambient_fx.ensure_toxic_bubble_layer()

func _start_toxic_bubble_loop() -> void:
	_ambient_fx.start_toxic_bubble_loop(toxic_bubbles_enabled)

func _layout_toxic_chat_stack() -> void:
	_ambient_fx.layout_toxic_chat_stack()

func _process(_delta: float) -> void:
	_ambient_fx.process_tick()
func _get_current_screen() -> Control:
	return _current_screen

func _get_warrior_username_label() -> Label:
	return _warrior_username_label

func _get_warrior_area() -> Control:
	return warrior_area

func _get_main_warrior_preview() -> Node:
	return main_warrior_preview
