extends "res://scripts/app/runtime_world_logic.gd"


const PIXEL_FONT := preload("res://assets/fonts/kwfont.ttf")
const RUNTIME_AUTH_FLOW_SCRIPT := preload("res://scripts/app/runtime_auth_flow.gd")
const RUNTIME_SESSION_AUTH_UI_CONTROLLER_SCRIPT := preload("res://scripts/app/runtime_session_auth_ui_controller.gd")
const RUNTIME_SESSION_AUTH_RESPONSE_CONTROLLER_SCRIPT := preload("res://scripts/app/runtime_session_auth_response_controller.gd")
const RUNTIME_SESSION_PROFILE_WALLET_CONTROLLER_SCRIPT := preload("res://scripts/app/runtime_session_profile_wallet_controller.gd")
const RUNTIME_SESSION_DROPDOWN_THEME_CONTROLLER_SCRIPT := preload("res://scripts/app/runtime_session_dropdown_theme_controller.gd")
const RUNTIME_SESSION_LOBBY_CONNECTION_CONTROLLER_SCRIPT := preload("res://scripts/app/runtime_session_lobby_connection_controller.gd")
const RUNTIME_SESSION_PURCHASE_FLOW_CONTROLLER_SCRIPT := preload("res://scripts/app/runtime_session_purchase_flow_controller.gd")
const RUNTIME_SESSION_LOBBY_ACTIONS_CONTROLLER_SCRIPT := preload("res://scripts/app/runtime_session_lobby_actions_controller.gd")
const RUNTIME_SESSION_LOBBY_SELECTION_CONTROLLER_SCRIPT := preload("res://scripts/app/runtime_session_lobby_selection_controller.gd")

var _runtime_auth_flow: Object = RUNTIME_AUTH_FLOW_SCRIPT.new()
var _runtime_session_auth_ui_controller: Object = RUNTIME_SESSION_AUTH_UI_CONTROLLER_SCRIPT.new()
var _runtime_session_auth_response_controller: Object = RUNTIME_SESSION_AUTH_RESPONSE_CONTROLLER_SCRIPT.new()
var _runtime_session_profile_wallet_controller: Object = RUNTIME_SESSION_PROFILE_WALLET_CONTROLLER_SCRIPT.new()
var _runtime_session_dropdown_theme_controller: Object = RUNTIME_SESSION_DROPDOWN_THEME_CONTROLLER_SCRIPT.new()
var _runtime_session_lobby_connection_controller: Object = RUNTIME_SESSION_LOBBY_CONNECTION_CONTROLLER_SCRIPT.new()
var _runtime_session_purchase_flow_controller: Object = RUNTIME_SESSION_PURCHASE_FLOW_CONTROLLER_SCRIPT.new()
var _runtime_session_lobby_actions_controller: Object = RUNTIME_SESSION_LOBBY_ACTIONS_CONTROLLER_SCRIPT.new()
var _runtime_session_lobby_selection_controller: Object = RUNTIME_SESSION_LOBBY_SELECTION_CONTROLLER_SCRIPT.new()

var _auth_inflight := false
var _auth_pending_action := ""
var _auth_logout_token := ""
var _auth_profile := "default"
var _auth_selection_sync_queued := false
@export var auth_require_login_on_startup := true

@export var dev_auto_login_on_autostart := false
@export var dev_auto_login_username := "mario"
@export var dev_auto_login_password := "1234"
@export var dev_auto_login_max_attempts := 3
@export var dev_auto_create_lobby_on_autostart := false
@export var dev_auto_create_lobby_name := ""

var _dev_auto_login_active := false
var _dev_auto_login_attempts := 0
var _dev_auto_lobby_create_attempted := false

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
	if lobby_mode_option != null:
		lobby_mode_option.item_selected.connect(_on_lobby_mode_selected)

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
		_install_purchase_button_anim(purchase_buy_button)
	if purchase_cancel_button != null:
		purchase_cancel_button.pressed.connect(_on_purchase_cancel_pressed)
		_install_purchase_button_anim(purchase_cancel_button)

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
	_runtime_auth_flow.setup_auth_flow(self)

func _configure_auth_ui_for_login_only() -> void:
	_runtime_auth_flow.configure_auth_ui_for_login_only(self)

func _try_dev_auto_login_if_needed() -> bool:
	return _runtime_session_auth_ui_controller.try_dev_auto_login_if_needed(self)

func _ensure_auth_request_node() -> void:
	_runtime_auth_flow.ensure_auth_request_node(self)

func _show_auth_panel(show: bool) -> void:
	_runtime_session_auth_ui_controller.show_auth_panel(self, show)

func _set_auth_status(text: String) -> void:
	_runtime_auth_flow.set_auth_status(self, text)

func _set_auth_buttons_enabled(enabled: bool) -> void:
	_runtime_auth_flow.set_auth_buttons_enabled(self, enabled)

func _on_logout_pressed() -> void:
	_logout_to_login()

func _logout_to_login() -> void:
	_runtime_session_auth_ui_controller.logout_to_login(self)

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
		if purchase_buy_button != null:
			_animate_purchase_button_state(purchase_buy_button, "idle")
		if purchase_cancel_button != null:
			_animate_purchase_button_state(purchase_cancel_button, "idle")
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
	_runtime_auth_flow.auth_logout_best_effort(self)

func _auth_api_base_url() -> String:
	return _runtime_auth_flow.auth_api_base_url(self)

func _load_auth_session() -> void:
	_runtime_auth_flow.load_auth_session(self)

func _save_auth_session() -> void:
	_runtime_auth_flow.save_auth_session(self)

func _clear_auth_session() -> void:
	_runtime_auth_flow.clear_auth_session(self)

func _save_account_loadout() -> void:
	_runtime_auth_flow.save_account_loadout(self)

func _load_account_loadout() -> void:
	_runtime_auth_flow.load_account_loadout(self)

func _resolve_auth_profile() -> void:
	_runtime_auth_flow.resolve_auth_profile(self)

func _auth_session_path() -> String:
	return _runtime_auth_flow.session_path(self)

func _kill_purchase_button_tween(btn: Button, meta_key: String) -> void:
	if btn == null or not btn.has_meta(meta_key):
		return
	var tween_variant: Variant = btn.get_meta(meta_key)
	if tween_variant is Tween:
		var tween := tween_variant as Tween
		if tween != null:
			tween.kill()
	btn.remove_meta(meta_key)

func _start_purchase_button_idle_anim(btn: Button) -> void:
	if btn == null:
		return
	_kill_purchase_button_tween(btn, "_purchase_idle_tween")
	_kill_purchase_button_tween(btn, "_purchase_fx_tween")
	btn.scale = Vector2.ONE
	btn.rotation = 0.0

func _animate_purchase_button_state(btn: Button, state: String) -> void:
	if btn == null:
		return
	_kill_purchase_button_tween(btn, "_purchase_fx_tween")
	if state != "idle":
		_kill_purchase_button_tween(btn, "_purchase_idle_tween")

	var target_scale := Vector2.ONE
	var target_rot := 0.0
	var dur := 0.12
	if state == "hover":
		target_scale = Vector2.ONE * 1.04
	elif state == "press":
		target_scale = btn.scale * 0.94
		dur = 0.06

	var tw := btn.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(btn, "scale", target_scale, dur)
	tw.parallel().tween_property(btn, "rotation", target_rot, dur)
	btn.set_meta("_purchase_fx_tween", tw)
	if state == "idle":
		_start_purchase_button_idle_anim(btn)

func _install_purchase_button_anim(btn: Button) -> void:
	if btn == null or btn.has_meta("_purchase_anim_installed"):
		return
	btn.set_meta("_purchase_anim_installed", true)
	btn.set_meta("kw_hovered", false)
	_start_purchase_button_idle_anim(btn)

	btn.mouse_entered.connect(func() -> void:
		btn.set_meta("kw_hovered", true)
		_animate_purchase_button_state(btn, "hover")
	)
	btn.focus_entered.connect(func() -> void:
		btn.set_meta("kw_hovered", true)
		_animate_purchase_button_state(btn, "hover")
	)
	btn.mouse_exited.connect(func() -> void:
		btn.set_meta("kw_hovered", false)
		_animate_purchase_button_state(btn, "idle")
	)
	btn.focus_exited.connect(func() -> void:
		btn.set_meta("kw_hovered", false)
		_animate_purchase_button_state(btn, "idle")
	)
	btn.button_down.connect(func() -> void:
		_animate_purchase_button_state(btn, "press")
	)
	btn.button_up.connect(func() -> void:
		var hovered := false
		if btn.has_meta("kw_hovered"):
			hovered = bool(btn.get_meta("kw_hovered"))
		if hovered:
			_animate_purchase_button_state(btn, "hover")
		else:
			_animate_purchase_button_state(btn, "idle")
	)


func _auth_me() -> void:
	_runtime_auth_flow.auth_me(self)

func _on_auth_login_pressed() -> void:
	_runtime_auth_flow.auth_submit(self, "login")

func _on_auth_register_pressed() -> void:
	_set_auth_status("Auth: register disabled")

func _auth_submit(action: String) -> void:
	_runtime_auth_flow.auth_submit(self, action)

func _auth_submit_credentials(action: String, username: String, password: String) -> void:
	_runtime_auth_flow.auth_submit_credentials(self, action, username, password)

func _auth_input_username() -> String:
	return _runtime_auth_flow.auth_input_username(self)

func _sync_selected_loadout_to_server() -> void:
	_runtime_auth_flow.sync_selected_loadout_to_server(self)

func _flush_queued_selected_loadout_sync() -> void:
	if not _auth_selection_sync_queued:
		return
	if _auth_inflight:
		return
	_sync_selected_loadout_to_server()

func _on_auth_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_runtime_session_auth_response_controller.on_auth_request_completed(self, result, response_code, body)

func _after_auth_success() -> void:
	_runtime_session_lobby_connection_controller.after_auth_success(self, role == Role.CLIENT)

func _ensure_lobby_connection_after_auth() -> void:
	_runtime_session_lobby_connection_controller.ensure_lobby_connection_after_auth(self, role == Role.CLIENT)

func _has_active_runtime_peer() -> bool:
	return _runtime_session_lobby_connection_controller.has_active_runtime_peer(self)

func _should_dev_auto_create_lobby_on_autostart() -> bool:
	return _runtime_session_lobby_connection_controller.should_dev_auto_create_lobby_on_autostart(self)

func _maybe_dev_auto_create_lobby() -> void:
	_runtime_session_lobby_connection_controller.maybe_dev_auto_create_lobby(self)

func _dev_auto_create_lobby_if_ready() -> void:
	_runtime_session_lobby_connection_controller.dev_auto_create_lobby_if_ready(
		self,
		MAP_ID_CLASSIC,
		GAME_MODE_DEATHMATCH
	)

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
	_append_log("[AUTH][profile] request user=%s url=%s" % [auth_username, url])
	var headers := PackedStringArray(["Authorization: Bearer %s" % token])
	var err := auth_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		_auth_inflight = false
		_auth_pending_action = ""
		_set_loading(false)

func _apply_profile_payload(payload: Dictionary) -> void:
	_runtime_session_profile_wallet_controller.apply_profile_payload(self, payload)

func _set_wallet(coins: int, clk: int) -> void:
	_runtime_session_profile_wallet_controller.set_wallet(self, coins, clk)

func _update_wallet_label() -> void:
	_runtime_session_profile_wallet_controller.update_wallet_label(self)

func _normalize_character_id(raw: String) -> String:
	return _runtime_session_profile_wallet_controller.normalize_character_id(raw)

func _is_skin_owned(character_id: String, skin_index: int) -> bool:
	return _runtime_session_profile_wallet_controller.is_skin_owned(self, character_id, skin_index)

func _skin_cost_coins(character_id: String, skin_index: int) -> int:
	return _runtime_session_profile_wallet_controller.skin_cost_coins(character_id, skin_index)

func _prompt_purchase_skin(character_id: String, skin_index: int, skin_label: String) -> void:
	_runtime_session_purchase_flow_controller.prompt_purchase_skin(self, character_id, skin_index, skin_label)

func _on_purchase_buy_pressed() -> void:
	_runtime_session_purchase_flow_controller.on_purchase_buy_pressed(self)

func _on_purchase_cancel_pressed() -> void:
	_runtime_session_purchase_flow_controller.on_purchase_cancel_pressed(self)

func _api_purchase_skin(character_id: String, skin_index: int) -> void:
	_runtime_session_purchase_flow_controller.api_purchase_skin(self, character_id, skin_index)

func _setup_weapon_picker() -> void:
	if lobby_weapon_option == null:
		return
	lobby_weapon_option.clear()
	lobby_weapon_option.add_item("AK47")
	lobby_weapon_option.set_item_metadata(0, WEAPON_ID_AK47)
	lobby_weapon_option.add_item("Grenade")
	lobby_weapon_option.set_item_metadata(1, WEAPON_ID_GRENADE)
	lobby_weapon_option.add_item("Shotgun")
	lobby_weapon_option.set_item_metadata(2, WEAPON_ID_SHOTGUN)
	lobby_weapon_option.add_item("Uzi")
	lobby_weapon_option.set_item_metadata(3, WEAPON_ID_UZI)
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
	_setup_mode_picker()

func _setup_mode_picker() -> void:
	if lobby_mode_option == null:
		return
	selected_game_mode = map_flow_service.select_mode_for_map(map_catalog, selected_map_id, selected_game_mode)
	map_flow_service.setup_lobby_mode_picker(lobby_mode_option, map_catalog, selected_map_id, selected_game_mode)
	if lobby_mode_label != null:
		lobby_mode_label.visible = true
	lobby_mode_option.visible = true
	_apply_pixel_dropdown_popup(lobby_mode_option)

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
	lobby_character_option.add_item("Juice")
	lobby_character_option.set_item_metadata(3, CHARACTER_ID_JUICE)
	lobby_character_option.add_item("Madam")
	lobby_character_option.set_item_metadata(4, CHARACTER_ID_MADAM)
	lobby_character_option.add_item("C3ll3r")
	lobby_character_option.set_item_metadata(5, CHARACTER_ID_CELLER)
	lobby_character_option.add_item("Kotro")
	lobby_character_option.set_item_metadata(6, CHARACTER_ID_KOTRO)
	lobby_character_option.add_item("Nova")
	lobby_character_option.set_item_metadata(7, CHARACTER_ID_NOVA)
	lobby_character_option.add_item("Hindi")
	lobby_character_option.set_item_metadata(8, CHARACTER_ID_HINDI)
	lobby_character_option.add_item("Loker")
	lobby_character_option.set_item_metadata(9, CHARACTER_ID_LOKER)
	lobby_character_option.add_item("Gan")
	lobby_character_option.set_item_metadata(10, CHARACTER_ID_GAN)
	lobby_character_option.add_item("Veila")
	lobby_character_option.set_item_metadata(11, CHARACTER_ID_VEILA)
	lobby_character_option.add_item("Krog")
	lobby_character_option.set_item_metadata(12, CHARACTER_ID_KROG)
	lobby_character_option.add_item("Aevilok")
	lobby_character_option.set_item_metadata(13, CHARACTER_ID_AEVILOK)
	lobby_character_option.add_item("Franky")
	lobby_character_option.set_item_metadata(14, CHARACTER_ID_FRANKY)
	lobby_character_option.add_item("Varn")
	lobby_character_option.set_item_metadata(15, CHARACTER_ID_VARN)
	lobby_character_option.add_item("Lalou")
	lobby_character_option.set_item_metadata(16, CHARACTER_ID_LALOU)
	lobby_character_option.add_item("M4")
	lobby_character_option.set_item_metadata(17, CHARACTER_ID_M4)
	lobby_character_option.add_item("Raining Pleasure")
	lobby_character_option.set_item_metadata(18, CHARACTER_ID_RP)
	print("[DBG SETUP] Character picker: added Outrage (meta: %s), Erebus (meta: %s), Tasko (meta: %s), Juice (meta: %s), Madam (meta: %s), C3ll3r (meta: %s), Kotro (meta: %s), Nova (meta: %s), Hindi (meta: %s), Loker (meta: %s), Gan (meta: %s), Veila (meta: %s), Krog (meta: %s), Aevilok (meta: %s), Franky (meta: %s), Varn (meta: %s), Lalou (meta: %s), M4 (meta: %s), Raining Pleasure (meta: %s)" % [CHARACTER_ID_OUTRAGE, CHARACTER_ID_EREBUS, CHARACTER_ID_TASKO, CHARACTER_ID_JUICE, CHARACTER_ID_MADAM, CHARACTER_ID_CELLER, CHARACTER_ID_KOTRO, CHARACTER_ID_NOVA, CHARACTER_ID_HINDI, CHARACTER_ID_LOKER, CHARACTER_ID_GAN, CHARACTER_ID_VEILA, CHARACTER_ID_KROG, CHARACTER_ID_AEVILOK, CHARACTER_ID_FRANKY, CHARACTER_ID_VARN, CHARACTER_ID_LALOU, CHARACTER_ID_M4, CHARACTER_ID_RP])
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
		if _should_dev_auto_create_lobby_on_autostart():
			_maybe_dev_auto_create_lobby()
		else:
			_request_spawn_from_server()
	_maybe_dev_auto_create_lobby()

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

func _can_issue_lobby_actions() -> bool:
	return _runtime_session_lobby_actions_controller.can_issue_lobby_actions(self)

func _on_lobby_create_pressed() -> void:
	_runtime_session_lobby_actions_controller.on_lobby_create_pressed(self)

func _on_lobby_join_pressed() -> void:
	_runtime_session_lobby_actions_controller.on_lobby_join_pressed(self)

func _on_lobby_refresh_pressed() -> void:
	_runtime_session_lobby_actions_controller.on_lobby_refresh_pressed(self)

func _on_lobby_leave_pressed() -> void:
	_runtime_session_lobby_actions_controller.on_lobby_leave_pressed(self)

func _on_lobby_list_item_selected(_index: int) -> void:
	_runtime_session_lobby_actions_controller.on_lobby_list_item_selected(self, _index)

func _on_lobby_list_empty_clicked(_position: Vector2, _button_index: int) -> void:
	_runtime_session_lobby_actions_controller.on_lobby_list_empty_clicked(self, _position, _button_index)

func _on_lobby_weapon_selected(index: int) -> void:
	_runtime_session_lobby_selection_controller.on_lobby_weapon_selected(self, index)

func _on_lobby_character_selected(index: int) -> void:
	_runtime_session_lobby_selection_controller.on_lobby_character_selected(self, index)

func _on_lobby_skin_selected(index: int) -> void:
	_runtime_session_lobby_selection_controller.on_lobby_skin_selected(self, index, CHARACTER_ID_OUTRAGE)

func _on_lobby_map_selected(index: int) -> void:
	_runtime_session_lobby_selection_controller.on_lobby_map_selected(self, index)

func _on_lobby_mode_selected(index: int) -> void:
	_runtime_session_lobby_selection_controller.on_lobby_mode_selected(self, index)

func _persist_local_weapon_selection() -> void:
	_runtime_session_lobby_selection_controller.persist_local_weapon_selection(self)

func _persist_local_character_selection() -> void:
	_runtime_session_lobby_selection_controller.persist_local_character_selection(self)

func _persist_local_skin_selection(character_id: String, skin_index: int) -> void:
	_runtime_session_lobby_selection_controller.persist_local_skin_selection(self, character_id, skin_index)

func _persist_local_outage_skin_if_needed() -> void:
	_runtime_session_lobby_selection_controller.persist_local_outage_skin_if_needed(self, CHARACTER_ID_OUTRAGE)

func _apply_pixel_dropdown_popups() -> void:
	_runtime_session_dropdown_theme_controller.apply_pixel_dropdown_popups(
		lobby_weapon_option,
		lobby_character_option,
		lobby_skin_option,
		lobby_map_option,
		lobby_mode_option,
		PIXEL_FONT
	)

func _apply_pixel_dropdown_popup(option: OptionButton) -> void:
	_runtime_session_dropdown_theme_controller.apply_pixel_dropdown_popup(option, PIXEL_FONT)

func _disable_popup_checkmarks(popup: PopupMenu) -> void:
	_runtime_session_dropdown_theme_controller.disable_popup_checkmarks(popup)

func _pixel_popup_panel() -> StyleBoxFlat:
	return _runtime_session_dropdown_theme_controller.pixel_popup_panel()

func _pixel_popup_hover() -> StyleBoxFlat:
	return _runtime_session_dropdown_theme_controller.pixel_popup_hover()

func _pixel_popup_separator() -> StyleBoxFlat:
	return _runtime_session_dropdown_theme_controller.pixel_popup_separator()

func _pixel_empty_icon() -> Texture2D:
	return _runtime_session_dropdown_theme_controller.pixel_empty_icon()
