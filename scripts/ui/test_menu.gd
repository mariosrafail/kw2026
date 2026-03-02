extends Control

const DATA := preload("res://scripts/ui/test_menu/data.gd")
const CURSOR_MANAGER_SCRIPT := preload("res://scripts/ui/cursor_manager.gd")
const CURSOR_MANAGER_NAME := "CursorManager"
const WEAPON_UI_SCRIPT := preload("res://scripts/ui/test_menu/weapon_ui.gd")
const STATE_STORE_SCRIPT := preload("res://scripts/ui/test_menu/state_store.gd")
const INTRO_FX_CTRL_SCRIPT := preload("res://scripts/ui/test_menu/intro_fx_controller.gd")
const CONFIRM_OVERLAY_SCRIPT := preload("res://scripts/ui/test_menu/confirm_overlay.gd")
const LOBBY_OVERLAY_CTRL_SCRIPT := preload("res://scripts/ui/test_menu/lobby_overlay_controller.gd")
const UI_ANIMATOR_SCRIPT := preload("res://scripts/ui/test_menu/ui_animator.gd")
const MENU_TRANSITION_CTRL_SCRIPT := preload("res://scripts/ui/test_menu/menu_transition_controller.gd")
const IDLE_ANIMATOR_SCRIPT := preload("res://scripts/ui/test_menu/idle_animator.gd")
const AUTH_API_BASE_URL_DEFAULT := "http://127.0.0.1:8090"

const WEAPON_UZI := DATA.WEAPON_UZI
const WEAPON_GRENADE := DATA.WEAPON_GRENADE
const WEAPON_AK47 := DATA.WEAPON_AK47
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

var _weapon_ui := WEAPON_UI_SCRIPT.new()
var _state_store := STATE_STORE_SCRIPT.new()
var _intro_fx := INTRO_FX_CTRL_SCRIPT.new()
var _lobby_overlay_ctrl := LOBBY_OVERLAY_CTRL_SCRIPT.new()
var _ui_anim := UI_ANIMATOR_SCRIPT.new()
var _menu_transition_ctrl := MENU_TRANSITION_CTRL_SCRIPT.new()
var _idle_anim := IDLE_ANIMATOR_SCRIPT.new()

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
	WEAPON_AK47: PackedInt32Array([0]),
	WEAPON_SHOTGUN: PackedInt32Array([0]),
}
var equipped_weapon_skin_by_weapon: Dictionary = {
	WEAPON_UZI: 0,
	WEAPON_AK47: 0,
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

var _current_screen: Control
var _transition_tween: Tween
var _fx_layer: Control
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
var _auth_http: HTTPRequest
var _auth_overlay: Control
var _auth_status_label: Label
var _auth_user_input: LineEdit
var _auth_pass_input: LineEdit
var _auth_login_button: Button

func _ready() -> void:
	_ensure_cursor_manager()
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
		Callable(self, "_center_pivot"),
		Callable(self, "_pixel_burst_at"),
		Callable(self, "_center_of"),
		Callable(self, "_on_lobby_overlay_closed")
	)
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
			"main_weapon_icon": main_weapon_icon,
			"warrior_area": warrior_area,
			"weapon_area": weapon_area,
			"play_button": play_button,
			"bg_noise": $BgNoise,
			"logo_node": logo_node,
		}
	)

	_logo_base_pos = _idle_anim.node_pos(logo_node)
	_warrior_area_base_pos = warrior_area.position
	_weapon_area_base_pos = weapon_area.position
	var bg := $BgNoise as CanvasItem
	if bg != null:
		_bgnoise_base_alpha = bg.modulate.a
	_idle_anim.set_base_state(_logo_base_pos, _warrior_area_base_pos, _weapon_area_base_pos, _bgnoise_base_alpha)

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

	_set_weapon_icon_sprite(main_weapon_icon, _pending_weapon_id, 1.0, _pending_weapon_skin)
	_apply_weapon_skin_visual(main_weapon_icon, _pending_weapon_id, _pending_weapon_skin)
	_set_weapon_icon_sprite(weapon_shop_preview, selected_weapon_id, 1.0, selected_weapon_skin)
	_apply_weapon_skin_visual(weapon_shop_preview, selected_weapon_id, selected_weapon_skin)

	_update_wallet_labels(true)
	_build_warrior_shop_grid()
	_ensure_weapon_filter_ui()
	_build_weapon_shop_grid()

	_select_warrior_skin(selected_warrior_skin, true)
	_select_weapon_skin(selected_weapon_id, selected_weapon_skin, true)

	_connect_signals()
	_setup_auth_gate()
	if _auth_logged_in:
		_start_idle_loop()

func _auth_url(path: String) -> String:
	return "%s%s" % [_auth_api_base_url, path]

func _auth_login_current_base_url() -> String:
	if _auth_login_base_url_candidates.is_empty():
		return _auth_api_base_url
	return str(_auth_login_base_url_candidates[_auth_login_base_url_index])

func _auth_build_base_url_with_port(base_url: String, port: int) -> String:
	var trimmed := base_url.strip_edges()
	var scheme_idx := trimmed.find("://")
	if scheme_idx < 0:
		return trimmed
	var scheme := trimmed.substr(0, scheme_idx)
	var rest := trimmed.substr(scheme_idx + 3)
	var slash_idx := rest.find("/")
	var host_port := rest
	var suffix := ""
	if slash_idx >= 0:
		host_port = rest.substr(0, slash_idx)
		suffix = rest.substr(slash_idx)
	var host := host_port
	if host_port.find("]") < 0:
		var colon_idx := host_port.rfind(":")
		if colon_idx >= 0:
			host = host_port.substr(0, colon_idx)
	return "%s://%s:%d%s" % [scheme, host, port, suffix]

func _auth_trim_suffix(url: String, suffix: String) -> String:
	var trimmed := url.strip_edges()
	if trimmed.ends_with(suffix):
		return trimmed.substr(0, trimmed.length() - suffix.length())
	return trimmed

func _auth_rebuild_login_base_candidates() -> void:
	_auth_login_base_url_candidates = PackedStringArray()
	var base_variants := PackedStringArray([_auth_api_base_url])
	var without_auth := _auth_trim_suffix(_auth_api_base_url, "/auth")
	if without_auth != _auth_api_base_url:
		base_variants.append(without_auth)

	var candidates := PackedStringArray()
	for base in base_variants:
		candidates.append(base)
		candidates.append(_auth_build_base_url_with_port(base, 8080))
		candidates.append(_auth_build_base_url_with_port(base, 8081))
		candidates.append(_auth_build_base_url_with_port(base, 8090))

	for c in candidates:
		var v := str(c).strip_edges()
		if v.is_empty() or _auth_login_base_url_candidates.has(v):
			continue
		_auth_login_base_url_candidates.append(v)
	_auth_login_base_url_index = 0

func _auth_request_login_with_current_candidate() -> int:
	var url := "%s/login" % _auth_login_current_base_url()
	print("[AUTH][LOGIN] request url=%s user=%s" % [url, (_auth_user_input.text.strip_edges() if _auth_user_input != null else "")])
	return _auth_http.request(
		url,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		_auth_login_payload
	)

func _setup_auth_gate() -> void:
	_auth_api_base_url = str(ProjectSettings.get_setting("kw/auth_api_base_url", AUTH_API_BASE_URL_DEFAULT)).strip_edges()
	if _auth_api_base_url.is_empty():
		_auth_api_base_url = AUTH_API_BASE_URL_DEFAULT
	if _auth_api_base_url.ends_with("/"):
		_auth_api_base_url = _auth_api_base_url.substr(0, _auth_api_base_url.length() - 1)
	_auth_rebuild_login_base_candidates()

	_auth_http = HTTPRequest.new()
	_auth_http.name = "AuthHttp"
	add_child(_auth_http)
	_auth_http.request_completed.connect(_on_auth_http_completed)

	_auth_wallet_retry_timer = Timer.new()
	_auth_wallet_retry_timer.name = "AuthWalletRetryTimer"
	_auth_wallet_retry_timer.one_shot = true
	_auth_wallet_retry_timer.wait_time = 1.5
	add_child(_auth_wallet_retry_timer)
	_auth_wallet_retry_timer.timeout.connect(_on_auth_wallet_retry_timeout)

	var overlay := Control.new()
	overlay.name = "AuthOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 2000
	add_child(overlay)
	_auth_overlay = overlay

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.07, 0.94)
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 240)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220, -120)
	overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "LOGIN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	var user_input := LineEdit.new()
	user_input.placeholder_text = "Username or Email"
	user_input.text = player_username
	box.add_child(user_input)
	_auth_user_input = user_input

	var pass_input := LineEdit.new()
	pass_input.placeholder_text = "Password"
	pass_input.secret = true
	pass_input.text = "1234"
	box.add_child(pass_input)
	_auth_pass_input = pass_input

	var login_btn := _make_shop_button()
	login_btn.text = "LOG IN"
	login_btn.custom_minimum_size = Vector2(0, 34)
	login_btn.pressed.connect(_auth_submit_login)
	box.add_child(login_btn)
	_auth_login_button = login_btn
	_add_hover_pop(login_btn)

	var status := Label.new()
	status.text = "Enter your account to continue"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 12)
	box.add_child(status)
	_auth_status_label = status

	_auth_set_ui_locked(true)

func _auth_set_ui_locked(locked: bool) -> void:
	if _auth_overlay != null:
		_auth_overlay.visible = locked
	if play_button != null:
		play_button.disabled = locked
	if options_button != null:
		options_button.disabled = locked
	if warrior_button != null:
		warrior_button.disabled = locked
	if weapon_button != null:
		weapon_button.disabled = locked

func _auth_submit_login() -> void:
	if _auth_http == null:
		return
	var user_raw := ""
	var password := ""
	if _auth_user_input != null:
		user_raw = _auth_user_input.text.strip_edges()
	if _auth_pass_input != null:
		password = _auth_pass_input.text
	if user_raw.is_empty() or password.is_empty():
		if _auth_status_label != null:
			_auth_status_label.text = "Fill username/email and password"
		return

	var payload: Dictionary = {"password": password, "force": false}
	if user_raw.contains("@"):
		payload["email"] = user_raw
	else:
		payload["username"] = user_raw
	var body := JSON.stringify(payload)
	_auth_login_payload = body
	_auth_login_base_url_index = 0
	_auth_pending_action = "login"
	if _auth_status_label != null:
		_auth_status_label.text = "Logging in..."
	if _auth_login_button != null:
		_auth_login_button.disabled = true
	var err := _auth_request_login_with_current_candidate()
	if err != OK:
		_auth_pending_action = ""
		if _auth_status_label != null:
			_auth_status_label.text = "Login request failed (%s)" % str(err)
		if _auth_login_button != null:
			_auth_login_button.disabled = false

func _auth_request_profile() -> void:
	if _auth_http == null or _auth_token.is_empty():
		return
	_auth_pending_action = "profile"
	if _auth_status_label != null:
		_auth_status_label.text = "Loading profile..."
	var err := _auth_http.request(
		_auth_url("/profile"),
		PackedStringArray(["Authorization: Bearer %s" % _auth_token]),
		HTTPClient.METHOD_GET
	)
	if err != OK:
		_auth_pending_action = ""
		if _auth_status_label != null:
			_auth_status_label.text = "Profile request failed (%s)" % str(err)
		if _auth_login_button != null:
			_auth_login_button.disabled = false

func _auth_sync_wallet() -> void:
	if _auth_http == null or _auth_token.is_empty() or not _auth_logged_in:
		return
	if not _auth_wallet_sync_supported:
		return
	if not _auth_pending_action.is_empty():
		_auth_wallet_sync_queued = true
		_auth_schedule_wallet_retry()
		return
	var owned_skins_payload: Array = []
	for skin_idx in owned_warrior_skins:
		var idx := maxi(0, int(skin_idx))
		if idx <= 0:
			continue
		owned_skins_payload.append({"character_id": "outrage", "skin_index": idx})

	var owned_weapons_payload: Array = []
	for wid in owned_weapons:
		var normalized := str(wid).strip_edges().to_lower()
		if normalized.is_empty() or owned_weapons_payload.has(normalized):
			continue
		owned_weapons_payload.append(normalized)

	var owned_weapon_skins_payload: Dictionary = {}
	for wid in owned_weapon_skins_by_weapon.keys():
		var normalized := str(wid).strip_edges().to_lower()
		if normalized.is_empty():
			continue
		var arr := owned_weapon_skins_by_weapon.get(wid, PackedInt32Array([0])) as PackedInt32Array
		var out_arr: Array = []
		if arr != null:
			for s in arr:
				out_arr.append(maxi(0, int(s)))
		owned_weapon_skins_payload[normalized] = out_arr

	var body := JSON.stringify({
		"coins": wallet_coins,
		"clk": wallet_clk,
		"owned_skins": owned_skins_payload,
		"owned_weapons": owned_weapons_payload,
		"owned_weapon_skins_by_weapon": owned_weapon_skins_payload,
	})
	var endpoint := str(_auth_wallet_sync_endpoint_candidates[_auth_wallet_sync_endpoint_index])
	print("[AUTH][WALLET_SYNC] request user=%s url=%s coins=%d clk=%d" % [player_username, _auth_url(endpoint), wallet_coins, wallet_clk])
	_auth_pending_action = "wallet_sync"
	var err := _auth_http.request(
		_auth_url(endpoint),
		PackedStringArray([
			"Authorization: Bearer %s" % _auth_token,
			"Content-Type: application/json"
		]),
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		print("[AUTH][WALLET_SYNC] request failed err=%s" % str(err))
		_auth_pending_action = ""
		_auth_wallet_sync_queued = true
		_auth_schedule_wallet_retry()

func _copy_weapon_skins_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in src.keys():
		var normalized := str(key).strip_edges().to_lower()
		var arr := src.get(key, PackedInt32Array([0])) as PackedInt32Array
		if arr == null:
			out[normalized] = PackedInt32Array([0])
			continue
		var arr_copy := PackedInt32Array()
		for v in arr:
			arr_copy.append(int(v))
		out[normalized] = arr_copy
	return out

func _auth_capture_wallet_sync_snapshot() -> void:
	if not _auth_logged_in or _auth_token.is_empty():
		return
	_auth_wallet_sync_snapshot = {
		"coins": wallet_coins,
		"clk": wallet_clk,
		"owned_warrior_skins": PackedInt32Array(owned_warrior_skins),
		"owned_weapons": PackedStringArray(owned_weapons),
		"owned_weapon_skins_by_weapon": _copy_weapon_skins_dict(owned_weapon_skins_by_weapon),
		"equipped_weapon_skin_by_weapon": equipped_weapon_skin_by_weapon.duplicate(true),
		"selected_warrior_skin": selected_warrior_skin,
		"selected_weapon_id": selected_weapon_id,
		"selected_weapon_skin": selected_weapon_skin,
	}
	_auth_wallet_sync_snapshot_active = true

func _auth_restore_wallet_sync_snapshot() -> void:
	if not _auth_wallet_sync_snapshot_active:
		return
	wallet_coins = int(_auth_wallet_sync_snapshot.get("coins", wallet_coins))
	wallet_clk = int(_auth_wallet_sync_snapshot.get("clk", wallet_clk))
	owned_warrior_skins = PackedInt32Array(_auth_wallet_sync_snapshot.get("owned_warrior_skins", [0]) as Array)
	owned_weapons = PackedStringArray(_auth_wallet_sync_snapshot.get("owned_weapons", [WEAPON_UZI]) as Array)
	owned_weapon_skins_by_weapon = _copy_weapon_skins_dict(_auth_wallet_sync_snapshot.get("owned_weapon_skins_by_weapon", {}) as Dictionary)
	equipped_weapon_skin_by_weapon = (_auth_wallet_sync_snapshot.get("equipped_weapon_skin_by_weapon", {}) as Dictionary).duplicate(true)
	selected_warrior_skin = maxi(0, int(_auth_wallet_sync_snapshot.get("selected_warrior_skin", selected_warrior_skin)))
	selected_weapon_id = str(_auth_wallet_sync_snapshot.get("selected_weapon_id", selected_weapon_id)).strip_edges().to_lower()
	selected_weapon_skin = maxi(0, int(_auth_wallet_sync_snapshot.get("selected_weapon_skin", selected_weapon_skin)))
	_pending_warrior_skin = selected_warrior_skin
	_pending_weapon_id = selected_weapon_id
	_pending_weapon_skin = selected_weapon_skin
	_apply_warrior_skin_to_player(main_warrior_preview, selected_warrior_skin)
	_apply_warrior_skin_to_player(warrior_shop_preview, _pending_warrior_skin)
	_set_weapon_icon_sprite(main_weapon_icon, selected_weapon_id, 1.0, selected_weapon_skin)
	_apply_weapon_skin_visual(main_weapon_icon, selected_weapon_id, selected_weapon_skin)
	_set_weapon_icon_sprite(weapon_shop_preview, _pending_weapon_id, 1.0, _pending_weapon_skin)
	_apply_weapon_skin_visual(weapon_shop_preview, _pending_weapon_id, _pending_weapon_skin)
	_update_wallet_labels(true)
	_refresh_warrior_grid_texts()
	_refresh_warrior_action()
	_refresh_weapon_grid_texts()
	_refresh_weapon_action()
	_save_state()
	_auth_wallet_sync_snapshot_active = false
	_auth_wallet_sync_snapshot = {}
	print("[AUTH][WALLET_SYNC] rollback applied (server rejected wallet update)")

func _auth_purchase_warrior_skin(skin_index: int) -> void:
	if _auth_http == null or _auth_token.is_empty() or not _auth_logged_in:
		return
	if not _auth_pending_action.is_empty():
		if _auth_status_label != null:
			_auth_status_label.text = "Please wait..."
		return
	var idx := maxi(0, skin_index)
	if idx <= 0:
		_equip_warrior_skin(idx)
		return
	_auth_pending_purchase_skin_index = idx
	var body := JSON.stringify({"character_id": "outrage", "skin_index": idx})
	print("[AUTH][BUY_SKIN] request user=%s skin=%d coins_ui=%d" % [player_username, idx, wallet_coins])
	_auth_pending_action = "purchase_skin"
	var err := _auth_http.request(
		_auth_url("/purchase/skin"),
		PackedStringArray([
			"Authorization: Bearer %s" % _auth_token,
			"Content-Type: application/json"
		]),
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		print("[AUTH][BUY_SKIN] request failed err=%s" % str(err))
		_auth_pending_action = ""
		_auth_pending_purchase_skin_index = -1
		if _auth_status_label != null:
			_auth_status_label.text = "Buy request failed (%s)" % str(err)

func _auth_schedule_wallet_retry() -> void:
	if _auth_wallet_retry_timer == null:
		return
	if _auth_wallet_retry_timer.time_left > 0.0:
		return
	_auth_wallet_retry_timer.start()

func _on_auth_wallet_retry_timeout() -> void:
	_auth_maybe_flush_wallet_sync()

func _auth_maybe_flush_wallet_sync() -> void:
	if not _auth_wallet_sync_queued:
		return
	if not _auth_pending_action.is_empty():
		return
	_auth_wallet_sync_queued = false
	_auth_sync_wallet()

func _auth_apply_profile(profile: Dictionary) -> void:
	wallet_coins = int(profile.get("coins", wallet_coins))
	wallet_clk = int(profile.get("clk", wallet_clk))
	player_username = str(profile.get("username", player_username)).strip_edges()
	if player_username.is_empty():
		player_username = "Player"

	if profile.has("owned_skins"):
		var owned := PackedInt32Array([0])
		for item in profile.get("owned_skins", []) as Array:
			if not (item is Dictionary):
				continue
			var d := item as Dictionary
			if str(d.get("character_id", "")).strip_edges().to_lower() != "outrage":
				continue
			var idx := maxi(0, int(d.get("skin_index", 0)))
			if not owned.has(idx):
				owned.append(idx)
		owned_warrior_skins = owned

	if profile.has("owned_weapons"):
		var allowed := PackedStringArray([WEAPON_UZI, WEAPON_AK47, WEAPON_SHOTGUN, WEAPON_GRENADE])
		var from_api := PackedStringArray()
		for w in profile.get("owned_weapons", []) as Array:
			var wid := str(w).strip_edges().to_lower()
			if allowed.has(wid) and not from_api.has(wid):
				from_api.append(wid)
		if not from_api.has(WEAPON_UZI):
			from_api.append(WEAPON_UZI)
		owned_weapons = from_api

	if profile.has("owned_weapon_skins_by_weapon"):
		var allowed_skins := PackedStringArray([WEAPON_UZI, WEAPON_AK47, WEAPON_SHOTGUN, WEAPON_GRENADE])
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

	_update_wallet_labels(true)
	_refresh_warrior_username_label()
	_refresh_warrior_grid_texts()
	_refresh_warrior_action()
	_refresh_weapon_grid_texts()
	_refresh_weapon_action()
	_save_state()

func _on_auth_http_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := _auth_pending_action
	var text := body.get_string_from_utf8()
	var parsed: Variant = null
	var trimmed := text.strip_edges()
	if not trimmed.is_empty() and (trimmed.begins_with("{") or trimmed.begins_with("[")):
		var json := JSON.new()
		if json.parse(trimmed) == OK:
			parsed = json.data
	if action == "login":
		if (response_code == 404 or response_code == 0) and _auth_login_base_url_index < _auth_login_base_url_candidates.size() - 1:
			_auth_login_base_url_index += 1
			print("[AUTH][LOGIN] code=%d on login endpoint, retry with %s" % [response_code, _auth_login_current_base_url()])
			_auth_pending_action = "login"
			var retry_err := _auth_request_login_with_current_candidate()
			if retry_err == OK:
				return
			_auth_pending_action = ""
			if _auth_status_label != null:
				_auth_status_label.text = "Login request failed (%s)" % str(retry_err)
			if _auth_login_button != null:
				_auth_login_button.disabled = false
			return
		if response_code < 200 or response_code >= 300 or not (parsed is Dictionary):
			if _auth_status_label != null:
				_auth_status_label.text = "Login failed (%d)" % response_code
			if _auth_login_button != null:
				_auth_login_button.disabled = false
			_auth_pending_action = ""
			return
		var data := parsed as Dictionary
		var active_base := _auth_login_current_base_url()
		if _auth_api_base_url != active_base:
			_auth_api_base_url = active_base
			print("[AUTH][LOGIN] using auth base url %s" % _auth_api_base_url)
		_auth_token = str(data.get("token", "")).strip_edges()
		player_username = str(data.get("username", player_username)).strip_edges()
		if _auth_token.is_empty():
			if _auth_status_label != null:
				_auth_status_label.text = "Login failed: missing token"
			if _auth_login_button != null:
				_auth_login_button.disabled = false
			_auth_pending_action = ""
			return
		_auth_pending_action = ""
		_auth_request_profile()
		return

	if action == "profile":
		if response_code < 200 or response_code >= 300 or not (parsed is Dictionary):
			print("[AUTH][PROFILE] failed code=%d body=%s" % [response_code, text])
			if _auth_status_label != null:
				_auth_status_label.text = "Profile load failed (%d)" % response_code
			if _auth_login_button != null:
				_auth_login_button.disabled = false
			_auth_pending_action = ""
			return
		var profile := parsed as Dictionary
		print("[AUTH][PROFILE] ok user=%s coins=%d clk=%d" % [str(profile.get("username", "")), int(profile.get("coins", wallet_coins)), int(profile.get("clk", wallet_clk))])
		_auth_apply_profile(profile)
		var has_wallet_inventory_fields := profile.has("owned_weapons") and profile.has("owned_weapon_skins_by_weapon")
		if not has_wallet_inventory_fields:
			_auth_wallet_sync_supported = false
			print("[AUTH][PROFILE] legacy server detected (missing wallet inventory fields). wallet sync disabled.")
			if _auth_status_label != null:
				_auth_status_label.text = "Server supports only skin purchases"
		else:
			_auth_wallet_sync_supported = true
			_auth_wallet_sync_endpoint_index = 0
		_auth_logged_in = true
		_auth_set_ui_locked(false)
		if _auth_status_label != null:
			_auth_status_label.text = ""
		if _auth_login_button != null:
			_auth_login_button.disabled = false
		_auth_pending_action = ""
		_start_idle_loop()
		_auth_maybe_flush_wallet_sync()
		return

	if action == "wallet_sync":
		if response_code >= 200 and response_code < 300 and (parsed is Dictionary):
			print("[AUTH][WALLET_SYNC] ok user=%s coins=%d clk=%d" % [str((parsed as Dictionary).get("username", player_username)), int((parsed as Dictionary).get("coins", wallet_coins)), int((parsed as Dictionary).get("clk", wallet_clk))])
			_auth_apply_profile(parsed as Dictionary)
			_auth_wallet_sync_endpoint_index = 0
			_auth_wallet_sync_supported = true
			_auth_wallet_sync_snapshot_active = false
			_auth_wallet_sync_snapshot = {}
			_auth_pending_action = ""
			_auth_maybe_flush_wallet_sync()
			return
		print("[AUTH][WALLET_SYNC] failed code=%d body=%s" % [response_code, text])
		if response_code == 404:
			if _auth_wallet_sync_endpoint_index < _auth_wallet_sync_endpoint_candidates.size() - 1:
				_auth_wallet_sync_endpoint_index += 1
				print("[AUTH][WALLET_SYNC] endpoint not found, retry with %s" % str(_auth_wallet_sync_endpoint_candidates[_auth_wallet_sync_endpoint_index]))
				_auth_pending_action = ""
				_auth_wallet_sync_queued = true
				_auth_schedule_wallet_retry()
				return
			_auth_restore_wallet_sync_snapshot()
			_auth_wallet_sync_supported = false
			if _auth_status_label != null:
				_auth_status_label.text = "Server does not support wallet updates"
			_auth_wallet_sync_queued = false
			_auth_pending_action = ""
			return
		_auth_pending_action = ""
		_auth_wallet_sync_queued = true
		_auth_schedule_wallet_retry()
		return

	if action == "purchase_skin":
		if response_code >= 200 and response_code < 300 and (parsed is Dictionary):
			var profile := parsed as Dictionary
			print("[AUTH][BUY_SKIN] ok user=%s skin=%d coins=%d clk=%d" % [str(profile.get("username", player_username)), _auth_pending_purchase_skin_index, int(profile.get("coins", wallet_coins)), int(profile.get("clk", wallet_clk))])
			_auth_apply_profile(profile)
			if _auth_pending_purchase_skin_index >= 0 and _is_warrior_skin_owned(_auth_pending_purchase_skin_index):
				_equip_warrior_skin(_auth_pending_purchase_skin_index)
			_pixel_burst_at(_center_of(wallet_panel), Color(0.25, 1, 0.85, 1))
			_auth_pending_purchase_skin_index = -1
			_auth_pending_action = ""
			_auth_maybe_flush_wallet_sync()
			return
		print("[AUTH][BUY_SKIN] failed code=%d skin=%d body=%s" % [response_code, _auth_pending_purchase_skin_index, text])
		if _auth_status_label != null:
			_auth_status_label.text = "Purchase failed (%d)" % response_code
		_auth_pending_purchase_skin_index = -1
		_auth_pending_action = ""

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
			if _lobby_overlay_ctrl != null and _lobby_overlay_ctrl.is_visible():
				_lobby_overlay_ctrl.hide()
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
	_open_lobby_menu_flow()

func _open_lobby_menu_flow() -> void:
	_stop_idle_loop()
	if _lobby_overlay_ctrl != null:
		_lobby_overlay_ctrl.open(play_button)

func _run_lobby_menu_loading_sequence() -> void:
	if _lobby_overlay_ctrl != null:
		await _lobby_overlay_ctrl.run_loading_sequence()

func _on_lobby_overlay_closed() -> void:
	if _current_screen == screen_main:
		_start_idle_loop()

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
	if _transition_tween != null:
		_transition_tween.kill()
		_transition_tween = null
	_menu_transition_ctrl.open_warriors_menu()

func _open_warriors_menu_stage2() -> void:
	_menu_transition_ctrl.open_warriors_menu_stage2(warriors_menu_preview_scale_mult, _warrior_shop_preview_base_scale)

func _close_warriors_menu() -> void:
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
	_menu_transition_ctrl.open_weapons_menu(_pending_weapon_id, _pending_weapon_skin)

func _open_weapons_menu_stage2() -> void:
	_menu_transition_ctrl.open_weapons_menu_stage2(_pending_weapon_id, _pending_weapon_skin, WEAPON_UZI)

func _close_weapons_menu() -> void:
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
	btn.modulate = Color(1, 1, 1, 1) if selected else Color(0.78, 0.8, 0.86, 0.85)

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
		var wname := _weapon_ui.weapon_display_name(wid)
		if not _weapon_is_owned(wid):
			btn.text = "%s  (LOCKED)" % wname
			continue
		var eq := _equipped_weapon_skin(wid)
		btn.text = "%s - %s  (1 EQUIPPED)" % [wname, _weapon_skin_label(wid, eq)]

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
		{"label": "UZI", "id": WEAPON_UZI},
		{"label": "AK47", "id": WEAPON_AK47},
		{"label": "SHOTGUN", "id": WEAPON_SHOTGUN},
		{"label": "GRENADE", "id": WEAPON_GRENADE},
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
		btn.custom_minimum_size = Vector2(170, 48)
		btn.text = _warrior_skin_button_text(skin_index)
		btn.pressed.connect(Callable(self, "_on_warrior_skin_button_pressed").bind(skin_index))
		warrior_grid.add_child(btn)
		_center_pivot(btn)

func _build_weapon_shop_grid() -> void:
	_clear_children(weapon_grid)
	var weapon_list := [WEAPON_UZI, WEAPON_AK47, WEAPON_SHOTGUN, WEAPON_GRENADE]
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
	# Keep the orange highlight visible all the time (not only on hover).
	sb.add_theme_stylebox_override("grabber", _scroll_grabber_hi)
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
			return "%s\n[EQUIPPED]" % base
		return "%s" % base
	return "%s\nBUY  %d" % [base, _warrior_skin_cost(skin_index)]

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
	if _auth_logged_in and not _auth_token.is_empty():
		_auth_purchase_warrior_skin(idx)
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
	_auth_sync_wallet()
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
			return "%s  [EQUIPPED]" % base
		return base

	return "%s  (%d)  [LOCKED]" % [base, _weapon_skin_cost(weapon_id, skin_index)]

func _select_weapon_skin(weapon_id: String, skin_index: int, silent: bool) -> void:
	_pending_weapon_id = weapon_id.strip_edges().to_lower()
	_pending_weapon_skin = maxi(0, skin_index)

	_set_weapon_icon_sprite(weapon_shop_preview, _pending_weapon_id, 1.0, _pending_weapon_skin)
	_apply_weapon_skin_visual(weapon_shop_preview, _pending_weapon_id, _pending_weapon_skin)

	weapon_name_label.text = "%s - %s" % [_weapon_ui.weapon_display_name(_pending_weapon_id), _weapon_skin_label(_pending_weapon_id, _pending_weapon_skin)]
	_refresh_weapon_grid_texts()
	if not silent:
		_pop(weapon_shop_preview)

func _equip_weapon_item(weapon_id: String, skin_index: int) -> void:
	selected_weapon_id = weapon_id.strip_edges().to_lower()
	selected_weapon_skin = maxi(0, skin_index)
	_pending_weapon_id = selected_weapon_id
	_pending_weapon_skin = selected_weapon_skin
	_set_equipped_weapon_skin(selected_weapon_id, selected_weapon_skin)
	_set_weapon_icon_sprite(main_weapon_icon, _visible_weapon_id, 1.0, _visible_weapon_skin)
	_apply_weapon_skin_visual(main_weapon_icon, _visible_weapon_id, _visible_weapon_skin)
	_set_weapon_icon_sprite(weapon_shop_preview, selected_weapon_id, 1.0, selected_weapon_skin)
	_apply_weapon_skin_visual(weapon_shop_preview, selected_weapon_id, selected_weapon_skin)
	weapon_name_label.text = "%s - %s" % [_weapon_ui.weapon_display_name(selected_weapon_id), _weapon_skin_label(selected_weapon_id, selected_weapon_skin)]
	_weapon_filter_weapon_id = selected_weapon_id
	_refresh_weapon_filter_button_state()
	_save_state()
	_refresh_weapon_grid_texts()
	_pop(main_weapon_icon)
	_pop(weapon_shop_preview)

func _buy_weapon_if_needed(weapon_id: String) -> bool:
	var normalized := weapon_id.strip_edges().to_lower()
	if _weapon_is_owned(normalized):
		return true
	if _auth_logged_in and not _auth_token.is_empty() and not _auth_wallet_sync_supported:
		print("[AUTH][BUY_WEAPON] local-only user=%s reason=wallet_update_missing weapon=%s" % [player_username, normalized])
		if _auth_status_label != null:
			_auth_status_label.text = "Weapon purchase is local only (server won't save it)"
	var cost := int(DATA.WEAPON_BASE_COST_BY_ID.get(normalized, 0))
	if cost <= 0:
		return false
	if wallet_coins < cost:
		if _auth_status_label != null:
			_auth_status_label.text = "Not enough coins"
		_shake(wallet_panel)
		return false
	_auth_capture_wallet_sync_snapshot()
	wallet_coins -= cost
	owned_weapons.append(normalized)
	_update_wallet_labels(false)
	_save_state()
	_auth_sync_wallet()
	return true

func _buy_weapon_skin_if_needed(weapon_id: String, skin_index: int) -> bool:
	var normalized := weapon_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	if _weapon_skin_is_owned(normalized, idx):
		return true
	if _auth_logged_in and not _auth_token.is_empty() and not _auth_wallet_sync_supported:
		print("[AUTH][BUY_WEAPON_SKIN] local-only user=%s reason=wallet_update_missing weapon=%s skin=%d" % [player_username, normalized, idx])
		if _auth_status_label != null:
			_auth_status_label.text = "Weapon-skin purchase is local only (server won't save it)"
	var cost := _weapon_skin_cost(normalized, idx)
	if cost <= 0:
		return false
	if wallet_coins < cost:
		if _auth_status_label != null:
			_auth_status_label.text = "Not enough coins"
		_shake(wallet_panel)
		return false
	_auth_capture_wallet_sync_snapshot()
	wallet_coins -= cost
	var arr := owned_weapon_skins_by_weapon.get(normalized, PackedInt32Array([0])) as PackedInt32Array
	if not arr.has(idx):
		arr.append(idx)
		arr.sort()
	owned_weapon_skins_by_weapon[normalized] = arr
	_update_wallet_labels(false)
	_save_state()
	_auth_sync_wallet()
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
	_set_weapon_icon_sprite(weapon_shop_preview, normalized, 1.0, idx)
	_apply_weapon_skin_visual(weapon_shop_preview, normalized, idx)
	weapon_name_label.text = "%s - %s" % [_weapon_ui.weapon_display_name(normalized), _weapon_skin_label(normalized, idx)]
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
	var fallback_username := OS.get_environment("USERNAME").strip_edges()
	if fallback_username.is_empty():
		fallback_username = "Player"
	var defaults := {
		"coins": 1000000,
		"clk": 50000,
		"username": fallback_username,
		"owned_warrior_skins": [0],
		"selected_warrior_skin": 0,
		"owned_weapons": [WEAPON_UZI],
		"owned_weapon_skins_by_weapon": {WEAPON_UZI: [0], WEAPON_GRENADE: [0], WEAPON_AK47: [0], WEAPON_SHOTGUN: [0]},
		"equipped_weapon_skin_by_weapon": {WEAPON_UZI: 0, WEAPON_GRENADE: 0, WEAPON_AK47: 0, WEAPON_SHOTGUN: 0},
		"selected_weapon_id": WEAPON_UZI,
		"selected_weapon_skin": 0,
	}
	var st := _state_store.load_state_or_defaults(DATA.SHOP_STATE_PATH, defaults, WEAPON_UZI)

	wallet_coins = int(st.get("coins", 0))
	wallet_clk = int(st.get("clk", 0))
	player_username = str(st.get("username", fallback_username)).strip_edges()
	if player_username.is_empty():
		player_username = fallback_username

	owned_warrior_skins = PackedInt32Array(st.get("owned_warrior_skins", [0]) as Array)
	selected_warrior_skin = maxi(0, int(st.get("selected_warrior_skin", 0)))

	owned_weapons = PackedStringArray(st.get("owned_weapons", [WEAPON_UZI]) as Array)
	selected_weapon_id = str(st.get("selected_weapon_id", WEAPON_UZI)).strip_edges().to_lower()
	selected_weapon_skin = maxi(0, int(st.get("selected_weapon_skin", 0)))

	# Sanitize weapon ids (remove weapons that no longer exist in this menu).
	var allowed := PackedStringArray([WEAPON_UZI, WEAPON_AK47, WEAPON_SHOTGUN, WEAPON_GRENADE])
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
	if not _is_warrior_skin_owned(selected_warrior_skin):
		selected_warrior_skin = 0
	if not _weapon_is_owned(selected_weapon_id):
		selected_weapon_id = WEAPON_UZI
	selected_weapon_skin = _equipped_weapon_skin(selected_weapon_id)
	if not _weapon_skin_is_owned(selected_weapon_id, selected_weapon_skin):
		selected_weapon_skin = 0
		_set_equipped_weapon_skin(selected_weapon_id, 0)

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
		"username": player_username,
		"owned_warrior_skins": owned_warrior_list,
		"selected_warrior_skin": selected_warrior_skin,
		"owned_weapons": owned_weapons_list,
		"owned_weapon_skins_by_weapon": owned_weapon_skins_dict,
		"equipped_weapon_skin_by_weapon": equipped_weapon_skin_by_weapon,
		"selected_weapon_id": selected_weapon_id,
		"selected_weapon_skin": selected_weapon_skin,
	}
	_state_store.save_state(DATA.SHOP_STATE_PATH, d)

func _ensure_warrior_username_label() -> void:
	if _warrior_username_label != null and is_instance_valid(_warrior_username_label):
		return
	if warrior_area == null:
		return
	var label := Label.new()
	label.name = "WarriorUsername"
	label.z_index = 20
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.layout_mode = 1
	label.anchors_preset = Control.PRESET_CENTER_TOP
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.0
	label.anchor_bottom = 0.0
	label.offset_left = -74
	label.offset_right = 74
	label.offset_top = -6
	label.offset_bottom = 16
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.98, 0.97, 0.95, 1))
	label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.08, 1))
	label.add_theme_constant_override("outline_size", 0)
	warrior_area.add_child(label)
	_warrior_username_label = label

func _refresh_warrior_username_label() -> void:
	if _warrior_username_label == null:
		return
	_warrior_username_label.text = player_username

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
	_ui_anim.add_hover_pop(btn)

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
