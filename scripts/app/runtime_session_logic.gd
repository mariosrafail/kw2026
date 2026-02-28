extends "res://scripts/app/runtime_world_logic.gd"


const PIXEL_FONT := preload("res://assets/fonts/kwfont.ttf")

var _pixel_popup_panel_stylebox: StyleBoxFlat = null
var _pixel_popup_hover_stylebox: StyleBoxFlat = null
var _pixel_popup_separator_stylebox: StyleBoxFlat = null
var _pixel_empty_icon_texture: Texture2D = null

const AUTH_SESSION_PATH := "user://auth_session.json"
const AUTH_API_BASE_URL_SETTING := "kw/auth_api_base_url"
const AUTH_PROFILE_SETTING := "kw/auth_profile"
const AUTH_PROFILE_ARG_PREFIX := "--auth-profile="

var _auth_inflight := false
var _auth_pending_action := ""
var _auth_logout_token := ""
var _auth_profile := "default"
@export var auth_require_login_on_startup := true

@export var dev_auto_login_on_autostart := true
@export var dev_auto_login_password := "test"
@export var dev_auto_login_max_attempts := 3

var _dev_auto_login_active := false
var _dev_auto_login_attempts := 0

var wallet_coins := 0
var wallet_clk := 0
var owned_skins_by_character: Dictionary = {}

var _purchase_pending_character_id := ""
var _purchase_pending_skin_index := 0
var _purchase_pending_skin_name := ""
var _purchase_inflight := false

func _connect_local_signals() -> void:
	start_server_button.pressed.connect(_on_start_server_pressed)
	stop_button.pressed.connect(_on_stop_pressed)
	connect_button.pressed.connect(_on_connect_pressed)
	disconnect_button.pressed.connect(_on_disconnect_pressed)

	if lobby_create_button != null:
		lobby_create_button.pressed.connect(_on_lobby_create_pressed)
	if lobby_join_button != null:
		lobby_join_button.pressed.connect(_on_lobby_join_pressed)
	if lobby_refresh_button != null:
		lobby_refresh_button.pressed.connect(_on_lobby_refresh_pressed)
	if lobby_leave_button != null:
		lobby_leave_button.pressed.connect(_on_lobby_leave_pressed)
	if lobby_logout_button != null:
		lobby_logout_button.pressed.connect(_on_logout_pressed)
	if lobby_list != null:
		lobby_list.item_selected.connect(_on_lobby_list_item_selected)
		lobby_list.empty_clicked.connect(_on_lobby_list_empty_clicked)
	if lobby_weapon_option != null:
		lobby_weapon_option.item_selected.connect(_on_lobby_weapon_selected)
	if lobby_character_option != null:
		lobby_character_option.item_selected.connect(_on_lobby_character_selected)
	if lobby_skin_option != null:
		lobby_skin_option.item_selected.connect(_on_lobby_skin_selected)
	if lobby_map_option != null:
		lobby_map_option.item_selected.connect(_on_lobby_map_selected)

	if auth_login_button != null:
		auth_login_button.pressed.connect(_on_auth_login_pressed)
	if auth_register_button != null:
		auth_register_button.pressed.connect(_on_auth_register_pressed)
	if auth_request != null and not auth_request.request_completed.is_connected(_on_auth_request_completed):
		auth_request.request_completed.connect(_on_auth_request_completed)

	if esc_logout_button != null:
		esc_logout_button.pressed.connect(_on_esc_logout_pressed)
	if esc_exit_button != null:
		esc_exit_button.pressed.connect(_on_esc_exit_pressed)
	if esc_cancel_button != null:
		esc_cancel_button.pressed.connect(_on_esc_cancel_pressed)

	if purchase_buy_button != null:
		purchase_buy_button.pressed.connect(_on_purchase_buy_pressed)
	if purchase_cancel_button != null:
		purchase_cancel_button.pressed.connect(_on_purchase_cancel_pressed)

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _setup_ui_defaults() -> void:
	_setup_auth_flow()
	_setup_weapon_picker()
	_setup_character_picker()
	_setup_skin_picker()
	_setup_map_picker()
	_apply_pixel_dropdown_popups()
	_refresh_lobby_buttons()
	_update_peer_labels()
	_update_ping_label()
	_update_buttons()
	_update_ui_visibility()
	_update_score_labels()

func _setup_auth_flow() -> void:
	if auth_panel == null:
		return
	_configure_auth_ui_for_login_only()
	_resolve_auth_profile()

	var session_path := _auth_session_path()
	_append_log("[AUTH] profile=%s session file: %s (exists=%s)" % [_auth_profile, ProjectSettings.globalize_path(session_path), str(FileAccess.file_exists(session_path))])
	_load_auth_session()
	if auth_username_input != null and auth_username_input.text.strip_edges().is_empty() and not auth_username.strip_edges().is_empty():
		auth_username_input.text = auth_username

	if auth_require_login_on_startup:
		if not auth_token.strip_edges().is_empty():
			_append_log("[AUTH] Startup requires login. Ignoring stored session token.")
		auth_token = ""
		_show_auth_panel(true)
		_set_auth_status("Auth: login required")
		_set_auth_buttons_enabled(true)
		return

	if auth_token.strip_edges().is_empty():
		if _try_dev_auto_login_if_needed():
			return
		_show_auth_panel(true)
		_set_auth_status("Auth: login required")
		_set_auth_buttons_enabled(true)
		return
	_auth_me()

func _configure_auth_ui_for_login_only() -> void:
	if auth_register_button != null:
		auth_register_button.visible = false
		auth_register_button.disabled = true
	if auth_login_button != null:
		auth_login_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _try_dev_auto_login_if_needed() -> bool:
	if not dev_auto_login_on_autostart:
		return false
	if session_controller == null or not session_controller.is_auto_start_enabled():
		return false
	if auth_request == null or auth_username_input == null or auth_password_input == null:
		return false
	if _auth_inflight:
		return false
	if _dev_auto_login_attempts >= maxi(1, dev_auto_login_max_attempts):
		return false

	var startup_mode := session_controller.get_startup_mode()
	if startup_mode == Role.NONE:
		return false

	_dev_auto_login_active = true
	_dev_auto_login_attempts += 1
	var suffix := "%06d" % int(randi() % 1000000)
	var username := ("auto_%s" % suffix).strip_edges()
	var password := str(dev_auto_login_password)
	if password.length() < 4:
		password = "test"

	auth_username_input.text = username
	auth_password_input.text = password
	_show_auth_panel(true)
	_set_auth_status("Auth: auto-registering %s..." % username)
	_set_auth_buttons_enabled(false)
	call_deferred("_auth_submit", "register")
	return true

func _show_auth_panel(show: bool) -> void:
	if auth_panel != null:
		auth_panel.visible = show
	if lobby_panel != null:
		lobby_panel.visible = not show
	_show_esc_menu(false)
	_show_purchase_menu(false)
	if show:
		_set_loading(false)

func _set_auth_status(text: String) -> void:
	if auth_status_label != null:
		auth_status_label.text = text

func _set_auth_buttons_enabled(enabled: bool) -> void:
	if auth_login_button != null:
		auth_login_button.disabled = not enabled
	if auth_register_button != null:
		auth_register_button.disabled = true

func _on_logout_pressed() -> void:
	_logout_to_login()

func _logout_to_login() -> void:
	if _is_client_connected():
		session_controller.disconnect_client()
	_auth_logout_best_effort()
	_clear_auth_session()
	_set_wallet(0, 0)
	owned_skins_by_character.clear()
	if auth_username_input != null:
		auth_username_input.text = ""
	if auth_password_input != null:
		auth_password_input.text = ""
	if lobby_service != null and multiplayer != null and multiplayer.multiplayer_peer != null:
		var local_peer_id := multiplayer.get_unique_id()
		if local_peer_id > 0 and lobby_service.has_method("set_peer_display_name"):
			lobby_service.call("set_peer_display_name", local_peer_id, "")
	_show_auth_panel(true)
	_set_auth_status("Auth: login required")
	_set_auth_buttons_enabled(true)
	_update_ui_visibility()

func _on_esc_logout_pressed() -> void:
	_show_esc_menu(false)
	_logout_to_login()

func _on_esc_exit_pressed() -> void:
	get_tree().quit()

func _on_esc_cancel_pressed() -> void:
	_show_esc_menu(false)

func _show_esc_menu(show: bool) -> void:
	if esc_overlay != null:
		esc_overlay.visible = show
	if esc_menu != null:
		esc_menu.visible = show
	if show and esc_cancel_button != null:
		esc_cancel_button.grab_focus()

func _show_purchase_menu(show: bool) -> void:
	if purchase_overlay != null:
		purchase_overlay.visible = show
	if purchase_menu != null:
		purchase_menu.visible = show
	if show:
		_show_esc_menu(false)
		if purchase_cancel_button != null:
			purchase_cancel_button.grab_focus()

func _set_loading(show: bool, text: String = "LOADING...") -> void:
	if loading_overlay != null:
		loading_overlay.visible = show
	if loading_panel != null:
		loading_panel.visible = show
	if loading_label != null and not text.strip_edges().is_empty():
		loading_label.text = text
	if show:
		_show_esc_menu(false)
		_show_purchase_menu(false)

func _toggle_escape_menu() -> void:
	# Called from runtime_controller when ESC is pressed in lobby scene flow.
	if auth_panel != null and auth_panel.visible:
		get_tree().quit()
		return
	if purchase_menu != null and purchase_menu.visible:
		_show_purchase_menu(false)
		return
	var showing := esc_menu != null and esc_menu.visible
	_show_esc_menu(not showing)

func _auth_logout_best_effort() -> void:
	if auth_request == null:
		return
	var token := auth_token.strip_edges()
	if token.is_empty():
		return
	if _auth_inflight:
		return
	_auth_inflight = true
	_auth_pending_action = "logout"
	_auth_logout_token = token
	var url := "%s/logout" % _auth_api_base_url()
	var headers := PackedStringArray(["Authorization: Bearer %s" % token])
	var err := auth_request.request(url, headers, HTTPClient.METHOD_POST, "")
	if err != OK:
		_auth_inflight = false
		_auth_pending_action = ""
		_auth_logout_token = ""

func _auth_api_base_url() -> String:
	var configured := str(ProjectSettings.get_setting(AUTH_API_BASE_URL_SETTING, "http://127.0.0.1:8090")).strip_edges()
	if configured.is_empty():
		return "http://127.0.0.1:8090"
	return configured.trim_suffix("/")

func _load_auth_session() -> void:
	var session_path := _auth_session_path()
	if not FileAccess.file_exists(session_path):
		auth_token = ""
		auth_username = ""
		return
	var f := FileAccess.open(session_path, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not (parsed is Dictionary):
		return
	var payload := parsed as Dictionary
	auth_token = str(payload.get("token", "")).strip_edges()
	auth_username = str(payload.get("username", "")).strip_edges()

func _save_auth_session() -> void:
	var payload := {
		"token": auth_token,
		"username": auth_username
	}
	var f := FileAccess.open(_auth_session_path(), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(payload))

func _clear_auth_session() -> void:
	auth_token = ""
	auth_username = ""
	var session_path := _auth_session_path()
	if FileAccess.file_exists(session_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(session_path))

func _resolve_auth_profile() -> void:
	var configured := str(ProjectSettings.get_setting(AUTH_PROFILE_SETTING, "default")).strip_edges()
	if not configured.is_empty():
		_auth_profile = configured
	for raw_arg in OS.get_cmdline_args():
		var arg := str(raw_arg)
		if arg.begins_with(AUTH_PROFILE_ARG_PREFIX):
			var value := arg.substr(AUTH_PROFILE_ARG_PREFIX.length()).strip_edges()
			if not value.is_empty():
				_auth_profile = value
				break
	_auth_profile = _auth_profile.strip_edges()
	if _auth_profile.is_empty():
		_auth_profile = "default"

func _auth_session_path() -> String:
	if _auth_profile == "default":
		return AUTH_SESSION_PATH
	return "user://auth_session_%s.json" % _auth_profile


func _auth_me() -> void:
	if _auth_inflight:
		return
	if auth_request == null:
		_show_auth_panel(true)
		_set_auth_status("Auth error: missing HTTPRequest")
		return
	_auth_inflight = true
	_auth_pending_action = "me"
	_set_auth_status("Auth: checking session...")
	_set_loading(true, "LOADING...")
	var url := "%s/me" % _auth_api_base_url()
	var headers := PackedStringArray()
	if not auth_token.strip_edges().is_empty():
		headers.append("Authorization: Bearer %s" % auth_token)
	var err := auth_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_auth_inflight = false
		_auth_pending_action = ""
		_show_auth_panel(true)
		_set_auth_status("Auth error: request failed (%s)" % error_string(err))
		_set_loading(false)

func _on_auth_login_pressed() -> void:
	_auth_submit("login")

func _on_auth_register_pressed() -> void:
	_set_auth_status("Auth: register disabled")

func _auth_submit(action: String) -> void:
	if _auth_inflight:
		return
	if auth_request == null:
		_set_auth_status("Auth error: missing HTTPRequest")
		return
	if auth_username_input == null or auth_password_input == null:
		_set_auth_status("Auth error: missing UI")
		return

	var username := auth_username_input.text.strip_edges()
	var password := auth_password_input.text
	if username.is_empty() or password.is_empty():
		_set_auth_status("Auth: enter username + password")
		return

	_auth_inflight = true
	_auth_pending_action = action
	_set_auth_status("Auth: %s..." % action)
	_set_loading(true, "LOADING...")

	var url := "%s/%s" % [_auth_api_base_url(), action]
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"username": username, "password": password})
	var err := auth_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_auth_inflight = false
		_auth_pending_action = ""
		_set_auth_status("Auth error: request failed (%s)" % error_string(err))
		_set_loading(false)

func _on_auth_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := _auth_pending_action
	_auth_inflight = false
	_auth_pending_action = ""
	_set_loading(false)

	var text := body.get_string_from_utf8()
	var trimmed_text := text.strip_edges()
	var payload: Dictionary = {}
	if trimmed_text.begins_with("{") or trimmed_text.begins_with("["):
		var parsed: Variant = JSON.parse_string(trimmed_text)
		if parsed is Dictionary:
			payload = parsed as Dictionary

	var detail := str(payload.get("detail", "")).strip_edges()
	if detail.is_empty() and response_code == 0:
		detail = "no response (auth API offline?)"
	if detail.is_empty() and not trimmed_text.is_empty() and trimmed_text.length() <= 200:
		detail = trimmed_text
	if detail.is_empty():
		detail = "HTTP %d" % response_code

	if action == "logout":
		_auth_logout_token = ""
		return

	if response_code < 200 or response_code >= 300:
		if _dev_auto_login_active and action == "register" and response_code == 409 and _dev_auto_login_attempts < maxi(1, dev_auto_login_max_attempts):
			_append_log("[AUTH] Auto-register conflict, retrying with a different username.")
			_dev_auto_login_active = false
			_try_dev_auto_login_if_needed()
			return
		if _dev_auto_login_active:
			_dev_auto_login_active = false
		if action == "profile":
			# Don't block login if the server is on an older version without /profile yet.
			_set_wallet(9999, 9999)
			owned_skins_by_character.clear()
			var starter := PackedInt32Array([1])
			owned_skins_by_character["outrage"] = starter
			_update_wallet_label()
			_setup_skin_picker()
			_set_lobby_status("Shop unavailable: %s (restart auth API)" % detail)
			return
		if action == "purchase_skin":
			_purchase_inflight = false
			_set_loading(false)
			if purchase_text != null:
				purchase_text.text = "%s\n\nFailed: %s" % [_purchase_pending_skin_name, detail]
			if purchase_buy_button != null:
				purchase_buy_button.disabled = false
			return
		_show_auth_panel(true)
		_set_auth_status("Auth failed: %s" % detail)
		_set_auth_buttons_enabled(true)
		return

	if action == "profile":
		_apply_profile_payload(payload)
		return

	if action == "purchase_skin":
		_purchase_inflight = false
		if not _purchase_pending_character_id.is_empty() and _purchase_pending_skin_index > 0:
			_persist_local_skin_selection(_purchase_pending_character_id, _purchase_pending_skin_index)
		_apply_profile_payload(payload)
		_show_purchase_menu(false)
		_set_lobby_status("Purchased: %s" % _purchase_pending_skin_name)
		if _purchase_pending_character_id == CHARACTER_ID_OUTRAGE and _purchase_pending_skin_index > 0 and _is_client_connected():
			_rpc_lobby_set_skin.rpc_id(1, _purchase_pending_skin_index)
		_purchase_pending_character_id = ""
		_purchase_pending_skin_index = 0
		_purchase_pending_skin_name = ""
		return

	if action == "me":
		var username := str(payload.get("username", "")).strip_edges()
		if username.is_empty():
			_show_auth_panel(true)
			_set_auth_status("Auth failed: invalid session")
			_clear_auth_session()
			_set_auth_buttons_enabled(true)
			return
		auth_username = username
		_show_auth_panel(false)
		_set_auth_status("")
		_set_auth_buttons_enabled(true)
		_after_auth_success()
		return

	var token := str(payload.get("token", "")).strip_edges()
	var username2 := str(payload.get("username", "")).strip_edges()
	if token.is_empty() or username2.is_empty():
		_show_auth_panel(true)
		_set_auth_status("Auth failed: invalid response")
		return

	auth_token = token
	auth_username = username2
	_save_auth_session()
	_show_auth_panel(false)
	_set_auth_status("")
	_set_auth_buttons_enabled(true)
	_dev_auto_login_active = false
	_after_auth_success()

func _after_auth_success() -> void:
	_refresh_lobby_buttons()
	_update_ui_visibility()
	_update_peer_labels()
	_api_profile()

func _api_profile() -> void:
	if _auth_inflight:
		return
	if auth_request == null:
		return
	var token := auth_token.strip_edges()
	if token.is_empty():
		return
	_auth_inflight = true
	_auth_pending_action = "profile"
	_set_loading(true, "LOADING...")
	var url := "%s/profile" % _auth_api_base_url()
	var headers := PackedStringArray(["Authorization: Bearer %s" % token])
	var err := auth_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_auth_inflight = false
		_auth_pending_action = ""
		_set_loading(false)

func _apply_profile_payload(payload: Dictionary) -> void:
	var coins := int(payload.get("coins", 0))
	var clk := int(payload.get("clk", 0))
	_set_wallet(coins, clk)

	owned_skins_by_character.clear()
	var owned_raw := payload.get("owned_skins", []) as Array
	for item in owned_raw:
		if not (item is Dictionary):
			continue
		var entry := item as Dictionary
		var character_id := _normalize_character_id(str(entry.get("character_id", "")))
		var skin_index := int(entry.get("skin_index", 0))
		if character_id.is_empty() or skin_index <= 0:
			continue
		var arr := owned_skins_by_character.get(character_id, PackedInt32Array()) as PackedInt32Array
		if not arr.has(skin_index):
			arr.append(skin_index)
		owned_skins_by_character[character_id] = arr

	_update_wallet_label()
	_setup_skin_picker()

func _set_wallet(coins: int, clk: int) -> void:
	wallet_coins = maxi(0, coins)
	wallet_clk = maxi(0, clk)
	_update_wallet_label()

func _update_wallet_label() -> void:
	if wallet_label == null:
		return
	wallet_label.text = "Coins: %d | CLK: %d" % [wallet_coins, wallet_clk]

func _normalize_character_id(raw: String) -> String:
	var normalized := raw.strip_edges().to_lower()
	if normalized != "erebus" and normalized != "tasko":
		normalized = "outrage"
	return normalized

func _is_skin_owned(character_id: String, skin_index: int) -> bool:
	if skin_index <= 1:
		return true
	var normalized := _normalize_character_id(character_id)
	var arr := owned_skins_by_character.get(normalized, PackedInt32Array()) as PackedInt32Array
	return arr.has(skin_index)

func _skin_cost_coins(character_id: String, skin_index: int) -> int:
	# Must match auth API pricing (tools/auth_api/app.py::_skin_cost_coins).
	var normalized := _normalize_character_id(character_id)
	if skin_index <= 1:
		return 0
	if normalized == "outrage":
		return 10
	return 10

func _prompt_purchase_skin(character_id: String, skin_index: int, skin_label: String) -> void:
	if auth_token.strip_edges().is_empty():
		_show_auth_panel(true)
		_set_auth_status("Auth: login first")
		return
	_purchase_pending_character_id = _normalize_character_id(character_id)
	_purchase_pending_skin_index = maxi(0, skin_index)
	var cleaned := skin_label.replace(" [LOCKED]", "")
	var paren := cleaned.find(" (")
	if paren >= 0:
		cleaned = cleaned.substr(0, paren)
	cleaned = cleaned.strip_edges()
	_purchase_pending_skin_name = cleaned
	if purchase_text != null:
		var cost := _skin_cost_coins(character_id, skin_index)
		purchase_text.text = "Skin: %s\nCost: %d Coins" % [_purchase_pending_skin_name, cost]
	if purchase_buy_button != null:
		purchase_buy_button.disabled = false
	_show_purchase_menu(true)

func _on_purchase_buy_pressed() -> void:
	if _purchase_inflight:
		return
	if _purchase_pending_character_id.is_empty() or _purchase_pending_skin_index <= 0:
		return
	_api_purchase_skin(_purchase_pending_character_id, _purchase_pending_skin_index)

func _on_purchase_cancel_pressed() -> void:
	_purchase_pending_character_id = ""
	_purchase_pending_skin_index = 0
	_purchase_pending_skin_name = ""
	_show_purchase_menu(false)

func _api_purchase_skin(character_id: String, skin_index: int) -> void:
	if _auth_inflight:
		return
	if auth_request == null:
		return
	var token := auth_token.strip_edges()
	if token.is_empty():
		return

	_purchase_inflight = true
	if purchase_buy_button != null:
		purchase_buy_button.disabled = true
	_set_loading(true, "PROCESSING...")

	_auth_inflight = true
	_auth_pending_action = "purchase_skin"
	var url := "%s/purchase/skin" % _auth_api_base_url()
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % token,
		"Content-Type: application/json"
	])
	var body := JSON.stringify({"character_id": character_id, "skin_index": skin_index})
	var err := auth_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		_purchase_inflight = false
		_auth_inflight = false
		_auth_pending_action = ""
		_set_loading(false)
		if purchase_buy_button != null:
			purchase_buy_button.disabled = false

func _setup_weapon_picker() -> void:
	if lobby_weapon_option == null:
		return
	lobby_weapon_option.clear()
	lobby_weapon_option.add_item("AK47")
	lobby_weapon_option.set_item_metadata(0, WEAPON_ID_AK47)
	lobby_weapon_option.add_item("Uzi")
	lobby_weapon_option.set_item_metadata(1, WEAPON_ID_UZI)
	var target_weapon := _normalize_weapon_id(selected_weapon_id)
	for index in range(lobby_weapon_option.item_count):
		if _normalize_weapon_id(str(lobby_weapon_option.get_item_metadata(index))) == target_weapon:
			lobby_weapon_option.select(index)
			break
	_apply_pixel_dropdown_popup(lobby_weapon_option)

func _setup_map_picker() -> void:
	if lobby_map_option == null:
		return
	map_flow_service.setup_lobby_map_picker(lobby_map_option, map_catalog, selected_map_id)
	_apply_pixel_dropdown_popup(lobby_map_option)

func _setup_character_picker() -> void:
	if lobby_character_option == null:
		return
	lobby_character_option.clear()
	lobby_character_option.add_item("Outrage")
	lobby_character_option.set_item_metadata(0, CHARACTER_ID_OUTRAGE)
	lobby_character_option.add_item("Erebus")
	lobby_character_option.set_item_metadata(1, CHARACTER_ID_EREBUS)
	lobby_character_option.add_item("Tasko")
	lobby_character_option.set_item_metadata(2, CHARACTER_ID_TASKO)
	print("[DBG SETUP] Character picker: added Outrage (meta: %s), Erebus (meta: %s), Tasko (meta: %s)" % [CHARACTER_ID_OUTRAGE, CHARACTER_ID_EREBUS, CHARACTER_ID_TASKO])
	var target_character := _normalize_character_id(selected_character_id)
	print("[DBG SETUP] Character picker: looking for target character: %s" % target_character)
	var found_index := -1
	for index in range(lobby_character_option.item_count):
		var item_metadata = lobby_character_option.get_item_metadata(index)
		var normalized_meta = _normalize_character_id(str(item_metadata))
		print("[DBG SETUP] Index %d: metadata=%s, normalized=%s" % [index, item_metadata, normalized_meta])
		if normalized_meta == target_character:
			found_index = index
			break
	if found_index >= 0:
		print("[DBG SETUP] Selecting character at index %d" % found_index)
		lobby_character_option.select(found_index)
	else:
		print("[DBG SETUP] No matching character found for %s, selecting index 0" % target_character)
		lobby_character_option.select(0)
	_apply_pixel_dropdown_popup(lobby_character_option)
	_setup_skin_picker()

func _setup_skin_picker() -> void:
	if lobby_skin_option == null:
		return
	var skin_row := lobby_skin_option.get_parent() as CanvasItem
	if skin_row != null:
		skin_row.visible = selected_character_id == CHARACTER_ID_OUTRAGE
	if lobby_skin_label != null:
		lobby_skin_label.visible = selected_character_id == CHARACTER_ID_OUTRAGE
	lobby_skin_option.visible = selected_character_id == CHARACTER_ID_OUTRAGE
	lobby_skin_option.clear()

	if selected_character_id != CHARACTER_ID_OUTRAGE:
		return

	# Outrage skins (metadata = spritesheet 1-based frame index)
	# Keep "Classic" first so it is always index 0 in the picker.
	var indices := PackedInt32Array([1, 12, 13, 20, 21, 22, 23, 24, 25])
	for i in range(indices.size()):
		var idx := int(indices[i])
		if i == 0:
			lobby_skin_option.add_item("Classic")
		else:
			var base := "Skin %d" % i
			if _is_skin_owned(CHARACTER_ID_OUTRAGE, idx):
				lobby_skin_option.add_item(base)
			else:
				var cost := _skin_cost_coins(CHARACTER_ID_OUTRAGE, idx)
				lobby_skin_option.add_item("%s (%d Coins) [LOCKED]" % [base, cost])
		lobby_skin_option.set_item_metadata(i, idx)

	var target := 1
	if lobby_service != null:
		target = int(lobby_service.get_local_selected_skin(CHARACTER_ID_OUTRAGE, 1))
	if not _is_skin_owned(CHARACTER_ID_OUTRAGE, target):
		target = 1
	for i in range(lobby_skin_option.item_count):
		if int(lobby_skin_option.get_item_metadata(i)) == target:
			lobby_skin_option.select(i)
			return
	if lobby_skin_option.item_count > 0:
		lobby_skin_option.select(0)
	_apply_pixel_dropdown_popup(lobby_skin_option)

func _on_start_server_pressed() -> void:
	session_controller.start_server(int(port_spin.value))
	if role == Role.SERVER and not _uses_lobby_scene_flow() and multiplayer.is_server() and _should_spawn_local_server_player():
		_server_spawn_peer_if_needed(multiplayer.get_unique_id(), 1)

func _on_connect_pressed() -> void:
	session_controller.start_client(host_input.text.strip_edges(), int(port_spin.value), true, _uses_lobby_scene_flow())

func _on_stop_pressed() -> void:
	session_controller.stop_server()

func _on_disconnect_pressed() -> void:
	session_controller.disconnect_client()

func _on_connected_to_server() -> void:
	session_controller.on_connected_to_server()
	if _uses_lobby_scene_flow() and not auth_username.strip_edges().is_empty():
		_rpc_lobby_set_display_name.rpc_id(1, auth_username)
	if not _uses_lobby_scene_flow():
		_request_spawn_from_server()

func _on_connection_failed() -> void:
	session_controller.on_connection_failed(get_tree(), _uses_lobby_scene_flow())

func _on_server_disconnected() -> void:
	session_controller.on_server_disconnected()

func _on_peer_connected(peer_id: int) -> void:
	_append_log("Peer connected: %d" % peer_id)
	if multiplayer.is_server():
		var peer_lobby_id := _peer_lobby(peer_id)
		if peer_lobby_id > 0:
			_server_spawn_peer_if_needed(peer_id, peer_lobby_id)
		elif not _uses_lobby_scene_flow() and (lobby_service == null or not lobby_service.has_active_lobbies()):
			_server_spawn_peer_if_needed(peer_id, 1)
		if _uses_lobby_scene_flow() or (lobby_service != null and lobby_service.has_active_lobbies()):
			_server_send_lobby_list_to_peer(peer_id)
	_update_peer_labels()

func _on_peer_disconnected(peer_id: int) -> void:
	_append_log("Peer disconnected: %d" % peer_id)
	if multiplayer.is_server():
		if _peer_lobby(peer_id) > 0:
			lobby_flow_controller.server_leave_lobby(peer_id, true, true)
		else:
			_server_remove_player(peer_id, [])
		if not _uses_lobby_scene_flow():
			_server_return_to_lobby_scene_if_idle()
	_update_peer_labels()
	_update_score_labels()

func _on_lobby_create_pressed() -> void:
	if not _is_client_connected() or lobby_auto_action_inflight:
		return
	_persist_local_weapon_selection()
	_persist_local_character_selection()
	_persist_local_outage_skin_if_needed()
	if not auth_username.strip_edges().is_empty():
		_rpc_lobby_set_display_name.rpc_id(1, auth_username)
	lobby_auto_action_inflight = true
	_refresh_lobby_buttons()
	_set_lobby_status("Creating lobby...")
	var payload := map_flow_service.encode_create_lobby_payload(
		map_catalog,
		Callable(self, "_normalize_weapon_id"),
		selected_weapon_id,
		selected_map_id,
		selected_character_id
	)
	_rpc_lobby_create.rpc_id(1, _lobby_name_value(), payload)

func _on_lobby_join_pressed() -> void:
	if not _is_client_connected() or lobby_auto_action_inflight:
		return
	_persist_local_weapon_selection()
	_persist_local_character_selection()
	_persist_local_outage_skin_if_needed()
	if not auth_username.strip_edges().is_empty():
		_rpc_lobby_set_display_name.rpc_id(1, auth_username)
	var lobby_id := ui_controller.selected_lobby_id()
	if lobby_id <= 0:
		_set_lobby_status("Select a lobby first.")
		return
	lobby_auto_action_inflight = true
	_refresh_lobby_buttons()
	_set_lobby_status("Joining lobby...")
	print("[DBG CHAR] JOIN pressed -> lobby_id=%d weapon=%s character=%s" % [lobby_id, selected_weapon_id, selected_character_id])
	_rpc_lobby_join.rpc_id(1, lobby_id, selected_weapon_id, selected_character_id)

func _on_lobby_refresh_pressed() -> void:
	if not _is_client_connected():
		return
	_request_lobby_list()

func _on_lobby_leave_pressed() -> void:
	if not _is_client_connected() or lobby_auto_action_inflight:
		return
	lobby_auto_action_inflight = true
	_refresh_lobby_buttons()
	_set_lobby_status("Leaving lobby...")
	_rpc_lobby_leave.rpc_id(1)

func _on_lobby_list_item_selected(_index: int) -> void:
	_refresh_lobby_buttons()

func _on_lobby_list_empty_clicked(_position: Vector2, _button_index: int) -> void:
	_refresh_lobby_buttons()

func _on_lobby_weapon_selected(index: int) -> void:
	if lobby_weapon_option == null:
		return
	selected_weapon_id = _normalize_weapon_id(str(lobby_weapon_option.get_item_metadata(index)))
	_persist_local_weapon_selection()
	if _is_client_connected() and client_lobby_id > 0:
		_rpc_lobby_set_weapon.rpc_id(1, selected_weapon_id)

func _on_lobby_character_selected(index: int) -> void:
	if lobby_character_option == null:
		return
	if index < 0 or index >= lobby_character_option.item_count:
		print("[DBG CHAR] Invalid character index: %d (item_count: %d)" % [index, lobby_character_option.item_count])
		return
	var metadata = lobby_character_option.get_item_metadata(index)
	if metadata == null:
		print("[DBG CHAR] Character metadata at index %d is null!" % index)
		return
	selected_character_id = _normalize_character_id(str(metadata))
	print("[DBG CHAR] ===>>> SELECTED CHARACTER: %s (index: %d, metadata: %s, client_lobby_id: %d)" % [selected_character_id, index, metadata, client_lobby_id])
	_persist_local_character_selection()
	_setup_skin_picker()
	if _is_client_connected() and client_lobby_id > 0:
		print("[DBG CHAR] Sending RPC to server for character: %s" % selected_character_id)
		_rpc_lobby_set_character.rpc_id(1, selected_character_id)
	else:
		print("[DBG CHAR] Not sending RPC yet (connected=%s, lobby_id=%d)" % [_is_client_connected(), client_lobby_id])

func _on_lobby_skin_selected(index: int) -> void:
	if lobby_skin_option == null:
		return
	if selected_character_id != CHARACTER_ID_OUTRAGE:
		return
	if index < 0 or index >= lobby_skin_option.item_count:
		return
	var meta: Variant = lobby_skin_option.get_item_metadata(index)
	if meta == null:
		return
	var skin_index: int = int(meta)
	if not _is_skin_owned(selected_character_id, skin_index):
		var previous := 1
		if lobby_service != null:
			previous = int(lobby_service.get_local_selected_skin(selected_character_id, 1))
		if not _is_skin_owned(selected_character_id, previous):
			previous = 1
		for i in range(lobby_skin_option.item_count):
			if int(lobby_skin_option.get_item_metadata(i)) == previous:
				lobby_skin_option.select(i)
				break
		_prompt_purchase_skin(selected_character_id, skin_index, lobby_skin_option.get_item_text(index))
		return
	_persist_local_skin_selection(selected_character_id, skin_index)
	if _is_client_connected():
		_rpc_lobby_set_skin.rpc_id(1, skin_index)

func _on_lobby_map_selected(index: int) -> void:
	if lobby_map_option == null:
		return
	selected_map_id = map_flow_service.normalize_map_id(map_catalog, str(lobby_map_option.get_item_metadata(index)))
	if client_lobby_id <= 0:
		client_target_map_id = selected_map_id

func _persist_local_weapon_selection() -> void:
	if lobby_service == null:
		return
	lobby_service.set_local_selected_weapon(selected_weapon_id)
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return
	lobby_service.set_peer_weapon(local_peer_id, selected_weapon_id)

func _persist_local_character_selection() -> void:
	if lobby_service == null:
		return
	lobby_service.set_local_selected_character(selected_character_id)
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return
	lobby_service.set_peer_character(local_peer_id, selected_character_id)

func _persist_local_skin_selection(character_id: String, skin_index: int) -> void:
	if lobby_service == null:
		return
	lobby_service.set_local_selected_skin(character_id, skin_index)
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		return
	var local_peer_id := multiplayer.get_unique_id()
	if local_peer_id <= 0:
		return
	lobby_service.set_peer_skin(local_peer_id, skin_index)

func _persist_local_outage_skin_if_needed() -> void:
	if selected_character_id != CHARACTER_ID_OUTRAGE:
		return
	var skin_index: int = 1
	if lobby_skin_option != null and lobby_skin_option.item_count > 0:
		var selected_index := int(lobby_skin_option.selected)
		if selected_index >= 0 and selected_index < lobby_skin_option.item_count:
			var meta: Variant = lobby_skin_option.get_item_metadata(selected_index)
			if meta != null:
				skin_index = int(meta)
	_persist_local_skin_selection(selected_character_id, skin_index)
	if _is_client_connected():
		_rpc_lobby_set_skin.rpc_id(1, skin_index)

func _apply_pixel_dropdown_popups() -> void:
	_apply_pixel_dropdown_popup(lobby_weapon_option)
	_apply_pixel_dropdown_popup(lobby_character_option)
	_apply_pixel_dropdown_popup(lobby_skin_option)
	_apply_pixel_dropdown_popup(lobby_map_option)

func _apply_pixel_dropdown_popup(option: OptionButton) -> void:
	if option == null:
		return
	var popup := option.get_popup()
	if popup == null:
		return

	popup.add_theme_stylebox_override("panel", _pixel_popup_panel())
	popup.add_theme_stylebox_override("hover", _pixel_popup_hover())
	popup.add_theme_stylebox_override("hover_pressed", _pixel_popup_hover())
	popup.add_theme_stylebox_override("selected", _pixel_popup_hover())
	popup.add_theme_stylebox_override("focus", _pixel_popup_hover())
	popup.add_theme_stylebox_override("item_hover", _pixel_popup_hover())
	popup.add_theme_stylebox_override("separator", _pixel_popup_separator())

	# Hide the default radio/check icons (the "dots" on the left).
	var empty_icon := _pixel_empty_icon()
	popup.add_theme_icon_override("checked", empty_icon)
	popup.add_theme_icon_override("unchecked", empty_icon)
	popup.add_theme_icon_override("radio_checked", empty_icon)
	popup.add_theme_icon_override("radio_unchecked", empty_icon)
	popup.add_theme_constant_override("check_margin", 0)
	_disable_popup_checkmarks(popup)

	popup.add_theme_font_override("font", PIXEL_FONT)
	popup.add_theme_font_size_override("font_size", 16)

	popup.add_theme_color_override("font_color", Color(0.98, 0.97, 0.95, 1))
	popup.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	popup.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	popup.add_theme_color_override("font_disabled_color", Color(0.62, 0.65, 0.7, 0.9))
	popup.add_theme_constant_override("outline_size", 0)
	popup.add_theme_constant_override("v_separation", 2)
	popup.add_theme_constant_override("h_separation", 10)
	popup.add_theme_constant_override("item_start_padding", 10)
	popup.add_theme_constant_override("item_end_padding", 10)

func _disable_popup_checkmarks(popup: PopupMenu) -> void:
	if popup == null:
		return
	var count := int(popup.item_count)
	for i in range(count):
		if popup.has_method("set_item_as_radio_checkable"):
			popup.call("set_item_as_radio_checkable", i, false)
		if popup.has_method("set_item_as_checkable"):
			popup.call("set_item_as_checkable", i, false)
		if popup.has_method("set_item_checked"):
			popup.call("set_item_checked", i, false)

func _pixel_popup_panel() -> StyleBoxFlat:
	if _pixel_popup_panel_stylebox != null:
		return _pixel_popup_panel_stylebox
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.11, 0.16, 0.98)
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4
	sb.border_color = Color(0.06, 0.05, 0.08, 1)
	sb.content_margin_left = 6.0
	sb.content_margin_top = 6.0
	sb.content_margin_right = 6.0
	sb.content_margin_bottom = 6.0
	sb.shadow_size = 6
	sb.shadow_color = Color(0, 0, 0, 0.45)
	_pixel_popup_panel_stylebox = sb
	return sb

func _pixel_popup_hover() -> StyleBoxFlat:
	if _pixel_popup_hover_stylebox != null:
		return _pixel_popup_hover_stylebox
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.6, 0.85, 0.45)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.9, 0.74, 0.27, 0.9)
	_pixel_popup_hover_stylebox = sb
	return sb

func _pixel_popup_separator() -> StyleBoxFlat:
	if _pixel_popup_separator_stylebox != null:
		return _pixel_popup_separator_stylebox
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.08, 1)
	_pixel_popup_separator_stylebox = sb
	return sb

func _pixel_empty_icon() -> Texture2D:
	if _pixel_empty_icon_texture != null:
		return _pixel_empty_icon_texture
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_pixel_empty_icon_texture = ImageTexture.create_from_image(img)
	return _pixel_empty_icon_texture
