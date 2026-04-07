extends RefCounted
class_name MainMenuAuthFlow

const DATA := preload("res://scripts/ui/main_menu/data.gd")
const MENU_PALETTE := preload("res://scripts/ui/main_menu/menu_palette.gd")
const AUTH_REQUEST_TIMEOUT_SEC := 15.0
const DEFAULT_AUTH_USERNAME := "BLACKSHADOW"
const DEFAULT_AUTH_PASSWORD := "1234"
const AUTH_SESSION_PATH := "user://main_menu_auth_session.json"
const AUTH_PROFILE_SETTING := "kw/auth_profile"
const AUTH_PROFILE_ARG_PREFIX := "--auth-profile="
const WEAPON_UZI := DATA.WEAPON_UZI
const WEAPON_GRENADE := DATA.WEAPON_GRENADE
const WEAPON_AK47 := DATA.WEAPON_AK47
const WEAPON_KAR := DATA.WEAPON_KAR
const WEAPON_SHOTGUN := DATA.WEAPON_SHOTGUN

static var _runtime_session_token := ""
static var _runtime_session_username := ""
static var _runtime_session_api_base_url := ""

func setup_auth_gate(host: Control, api_base_url_default: String) -> void:
	resolve_auth_profile(host)
	host.set("_auth_api_base_url", _normalize_api_base_url(str(ProjectSettings.get_setting("kw/auth_api_base_url", api_base_url_default)).strip_edges()))
	if str(host.get("_auth_api_base_url")).is_empty():
		host.set("_auth_api_base_url", _normalize_api_base_url(api_base_url_default))
	if str(host.get("_auth_api_base_url")).ends_with("/"):
		var trimmed := str(host.get("_auth_api_base_url"))
		host.set("_auth_api_base_url", trimmed.substr(0, trimmed.length() - 1))
	auth_rebuild_login_base_candidates(host)

	auth_recreate_http_request(host)

	var retry_timer := Timer.new()
	retry_timer.name = "AuthWalletRetryTimer"
	retry_timer.one_shot = true
	retry_timer.wait_time = 1.5
	host.add_child(retry_timer)
	retry_timer.timeout.connect(Callable(host, "_on_auth_wallet_retry_timeout"))
	host.set("_auth_wallet_retry_timer", retry_timer)

	var watchdog_timer := Timer.new()
	watchdog_timer.name = "AuthRequestWatchdogTimer"
	watchdog_timer.one_shot = true
	watchdog_timer.wait_time = AUTH_REQUEST_TIMEOUT_SEC
	host.add_child(watchdog_timer)
	watchdog_timer.timeout.connect(Callable(host, "_on_auth_request_watchdog_timeout"))
	host.set("_auth_request_watchdog_timer", watchdog_timer)

	var overlay := Control.new()
	overlay.name = "AuthOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 2000
	host.add_child(overlay)
	host.set("_auth_overlay", overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = MENU_PALETTE.accent(0.34)
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 240)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220, -120)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = MENU_PALETTE.accent(0.96)
	panel_style.border_width_left = 3
	panel_style.border_width_top = 3
	panel_style.border_width_right = 3
	panel_style.border_width_bottom = 3
	panel_style.border_color = MENU_PALETTE.highlight(0.92)
	panel_style.corner_radius_top_left = 0
	panel_style.corner_radius_top_right = 0
	panel_style.corner_radius_bottom_left = 0
	panel_style.corner_radius_bottom_right = 0
	panel.add_theme_stylebox_override("panel", panel_style)
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
	title.add_theme_color_override("font_color", MENU_PALETTE.highlight(1.0))
	box.add_child(title)

	var field_style := StyleBoxFlat.new()
	field_style.bg_color = MENU_PALETTE.hot(0.82)
	field_style.border_width_left = 2
	field_style.border_width_top = 2
	field_style.border_width_right = 2
	field_style.border_width_bottom = 2
	field_style.border_color = MENU_PALETTE.highlight(0.85)
	field_style.corner_radius_top_left = 0
	field_style.corner_radius_top_right = 0
	field_style.corner_radius_bottom_left = 0
	field_style.corner_radius_bottom_right = 0
	var field_focus_style := field_style.duplicate() as StyleBoxFlat
	field_focus_style.border_color = MENU_PALETTE.highlight(1.0)

	var user_input := LineEdit.new()
	user_input.placeholder_text = "Username or Email"
	user_input.text = DEFAULT_AUTH_USERNAME
	user_input.custom_minimum_size = Vector2(0, 34)
	user_input.add_theme_stylebox_override("normal", field_style)
	user_input.add_theme_stylebox_override("focus", field_focus_style)
	user_input.add_theme_color_override("font_color", MENU_PALETTE.text_primary(1.0))
	user_input.add_theme_color_override("font_placeholder_color", MENU_PALETTE.text_dark(0.78))
	user_input.add_theme_color_override("caret_color", MENU_PALETTE.highlight(1.0))
	box.add_child(user_input)
	host.set("_auth_user_input", user_input)

	var pass_input := LineEdit.new()
	pass_input.placeholder_text = "Password"
	pass_input.secret = true
	pass_input.text = DEFAULT_AUTH_PASSWORD
	pass_input.custom_minimum_size = Vector2(0, 34)
	pass_input.add_theme_stylebox_override("normal", field_style)
	pass_input.add_theme_stylebox_override("focus", field_focus_style)
	pass_input.add_theme_color_override("font_color", MENU_PALETTE.text_primary(1.0))
	pass_input.add_theme_color_override("font_placeholder_color", MENU_PALETTE.text_dark(0.78))
	pass_input.add_theme_color_override("caret_color", MENU_PALETTE.highlight(1.0))
	box.add_child(pass_input)
	host.set("_auth_pass_input", pass_input)

	var login_btn := host.call("_make_shop_button") as Button
	login_btn.text = "LOG IN"
	login_btn.custom_minimum_size = Vector2(0, 34)
	login_btn.pressed.connect(Callable(host, "_auth_submit_login"))
	box.add_child(login_btn)
	host.set("_auth_login_button", login_btn)
	host.call("_add_hover_pop", login_btn)

	var status := Label.new()
	status.text = "Enter your account to continue"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", MENU_PALETTE.highlight(0.95))
	box.add_child(status)
	host.set("_auth_status_label", status)

	auth_set_ui_locked(host, true)
	if auth_restore_persisted_session(host):
		auth_set_ui_locked(host, false)
		var auth_status_label := host.get("_auth_status_label") as Label
		if auth_status_label != null:
			auth_status_label.text = "Restoring session..."
		var auth_login_button := host.get("_auth_login_button") as Button
		if auth_login_button != null:
			auth_login_button.disabled = true
		auth_request_profile(host)

func auth_set_ui_locked(host: Control, locked: bool) -> void:
	var auth_overlay := host.get("_auth_overlay") as Control
	if auth_overlay != null:
		auth_overlay.visible = locked
	for path in ["play_button", "options_button", "warrior_button", "weapon_button"]:
		var button := host.get(path) as Button
		if button != null:
			button.disabled = locked
	var auth_logout_button := host.get("_auth_logout_button") as Button
	if auth_logout_button != null:
		auth_logout_button.visible = not locked and bool(host.get("_auth_logged_in"))
	if host.has_method("_refresh_auth_footer"):
		host.call("_refresh_auth_footer")

func auth_submit_login(host: Control) -> void:
	var auth_http := host.get("_auth_http") as HTTPRequest
	if auth_http == null:
		return
	var user_raw := ""
	var password := ""
	var auth_user_input := host.get("_auth_user_input") as LineEdit
	var auth_pass_input := host.get("_auth_pass_input") as LineEdit
	if auth_user_input != null:
		user_raw = auth_user_input.text.strip_edges()
	if auth_pass_input != null:
		password = auth_pass_input.text
	if user_raw.is_empty() or password.is_empty():
		var auth_status_label := host.get("_auth_status_label") as Label
		if auth_status_label != null:
			auth_status_label.text = "Fill username/email and password"
		return

	var payload: Dictionary = {"password": password, "force": false}
	if user_raw.contains("@"):
		payload["email"] = user_raw
	else:
		payload["username"] = user_raw
	host.set("_auth_login_payload", JSON.stringify(payload))
	host.set("_auth_login_base_url_index", 0)
	host.set("_auth_timeout_retry_attempts", 0)
	host.set("_auth_pending_action", "login")
	var auth_status_label := host.get("_auth_status_label") as Label
	if auth_status_label != null:
		auth_status_label.text = "Logging in..."
	var auth_login_button := host.get("_auth_login_button") as Button
	if auth_login_button != null:
		auth_login_button.disabled = true
	var err := auth_request_login_with_current_candidate(host)
	if err != OK:
		host.set("_auth_pending_action", "")
		auth_stop_request_watchdog(host)
		if auth_status_label != null:
			auth_status_label.text = "Login request failed (%s)" % str(err)
		if auth_login_button != null:
			auth_login_button.disabled = false

func auth_sync_wallet(host: Control) -> void:
	var auth_http := host.get("_auth_http") as HTTPRequest
	var auth_token := str(host.get("_auth_token")).strip_edges()
	if auth_http == null or auth_token.is_empty() or not bool(host.get("_auth_logged_in")):
		return
	if not bool(host.get("_auth_wallet_sync_supported")):
		return
	if not str(host.get("_auth_pending_action")).is_empty():
		host.set("_auth_wallet_sync_queued", true)
		auth_schedule_wallet_retry(host)
		return
	var owned_skins_payload: Array = []
	var owned_warriors_payload: Array = []
	for warrior_id in host.get("owned_warriors") as PackedStringArray:
		var normalized_warrior := str(warrior_id).strip_edges().to_lower()
		if normalized_warrior.is_empty() or owned_warriors_payload.has(normalized_warrior):
			continue
		owned_warriors_payload.append(normalized_warrior)
	var owned_warrior_skins_by_warrior := host.get("owned_warrior_skins_by_warrior") as Dictionary
	for warrior_id in owned_warrior_skins_by_warrior.keys():
		var normalized_character := str(warrior_id).strip_edges().to_lower()
		var skin_arr := owned_warrior_skins_by_warrior.get(warrior_id, PackedInt32Array([0])) as PackedInt32Array
		if skin_arr == null:
			continue
		for skin_idx in skin_arr:
			var idx := maxi(0, int(skin_idx))
			if idx <= 0:
				continue
			owned_skins_payload.append({"character_id": normalized_character, "skin_index": idx})

	var owned_weapons_payload: Array = []
	for wid in host.get("owned_weapons") as PackedStringArray:
		var normalized := str(wid).strip_edges().to_lower()
		if normalized.is_empty() or owned_weapons_payload.has(normalized):
			continue
		owned_weapons_payload.append(normalized)

	var owned_weapon_skins_payload: Dictionary = {}
	var owned_weapon_skins_by_weapon := host.get("owned_weapon_skins_by_weapon") as Dictionary
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
		"coins": int(host.get("wallet_coins")),
		"clk": int(host.get("wallet_clk")),
		"owned_warriors": owned_warriors_payload,
		"owned_skins": owned_skins_payload,
		"owned_warrior_skins_by_warrior": copy_warrior_skins_dict(owned_warrior_skins_by_warrior),
		"equipped_warrior_skin_by_warrior": (host.get("equipped_warrior_skin_by_warrior") as Dictionary).duplicate(true),
		"selected_warrior_id": str(host.get("selected_warrior_id")),
		"selected_warrior_skin": int(host.get("selected_warrior_skin")),
		"owned_weapons": owned_weapons_payload,
		"owned_weapon_skins_by_weapon": owned_weapon_skins_payload,
		"equipped_weapon_skin_by_weapon": (host.get("equipped_weapon_skin_by_weapon") as Dictionary).duplicate(true),
		"selected_weapon_id": str(host.get("selected_weapon_id")),
		"selected_weapon_skin": int(host.get("selected_weapon_skin")),
	})
	var endpoint_candidates := host.get("_auth_wallet_sync_endpoint_candidates") as Array
	var endpoint_index := int(host.get("_auth_wallet_sync_endpoint_index"))
	var endpoint := str(endpoint_candidates[endpoint_index])
	print("[AUTH][WALLET_SYNC] request user=%s url=%s coins=%d clk=%d" % [str(host.get("player_username")), auth_url(host, endpoint), int(host.get("wallet_coins")), int(host.get("wallet_clk"))])
	host.set("_auth_pending_action", "wallet_sync")
	if host.has_method("_show_menu_loading_overlay"):
		host.call("_show_menu_loading_overlay", "SYNCING...")
	var err := auth_http.request(
		auth_url(host, endpoint),
		PackedStringArray([
			"Authorization: Bearer %s" % auth_token,
			"Content-Type: application/json"
		]),
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		print("[AUTH][WALLET_SYNC] request failed err=%s" % str(err))
		host.set("_auth_pending_action", "")
		auth_stop_request_watchdog(host)
		host.set("_auth_wallet_sync_queued", true)
		auth_schedule_wallet_retry(host)
		if host.has_method("_hide_menu_loading_overlay"):
			host.call("_hide_menu_loading_overlay")
		return
	auth_start_request_watchdog(host)

func auth_purchase_warrior_skin(host: Control, skin_index: int) -> void:
	var auth_http := host.get("_auth_http") as HTTPRequest
	var auth_token := str(host.get("_auth_token")).strip_edges()
	if auth_http == null or auth_token.is_empty() or not bool(host.get("_auth_logged_in")):
		return
	if not str(host.get("_auth_pending_action")).is_empty():
		var auth_status_label := host.get("_auth_status_label") as Label
		if auth_status_label != null:
			auth_status_label.text = "Please wait..."
		return
	var idx := maxi(0, skin_index)
	if idx <= 0:
		host.call("_equip_warrior_item", str(host.get("selected_warrior_id")), idx)
		return
	host.set("_auth_pending_purchase_skin_index", idx)
	var body := JSON.stringify({"character_id": str(host.get("selected_warrior_id")), "skin_index": idx})
	print("[AUTH][BUY_SKIN] request user=%s skin=%d coins_ui=%d" % [str(host.get("player_username")), idx, int(host.get("wallet_coins"))])
	host.set("_auth_pending_action", "purchase_skin")
	if host.has_method("_show_menu_loading_overlay"):
		host.call("_show_menu_loading_overlay", "PURCHASING...")
	var err := auth_http.request(
		auth_url(host, "/purchase/skin"),
		PackedStringArray([
			"Authorization: Bearer %s" % auth_token,
			"Content-Type: application/json"
		]),
		HTTPClient.METHOD_POST,
		body
	)
	if err != OK:
		print("[AUTH][BUY_SKIN] request failed err=%s" % str(err))
		host.set("_auth_pending_action", "")
		auth_stop_request_watchdog(host)
		host.set("_auth_pending_purchase_skin_index", -1)
		var auth_status_label := host.get("_auth_status_label") as Label
		if auth_status_label != null:
			auth_status_label.text = "Buy request failed (%s)" % str(err)
		if host.has_method("_hide_menu_loading_overlay"):
			host.call("_hide_menu_loading_overlay")
		return
	auth_start_request_watchdog(host)

func auth_schedule_wallet_retry(host: Control) -> void:
	var auth_wallet_retry_timer := host.get("_auth_wallet_retry_timer") as Timer
	if auth_wallet_retry_timer == null:
		return
	if auth_wallet_retry_timer.time_left > 0.0:
		return
	auth_wallet_retry_timer.start()

func auth_maybe_flush_wallet_sync(host: Control) -> void:
	if not bool(host.get("_auth_wallet_sync_queued")):
		return
	if not str(host.get("_auth_pending_action")).is_empty():
		return
	host.set("_auth_wallet_sync_queued", false)
	auth_sync_wallet(host)

func default_warrior_id(host: Control) -> String:
	var warrior_ui: Variant = host.get("_warrior_ui")
	if warrior_ui != null and warrior_ui.has_method("default_warrior_id"):
		return str(warrior_ui.call("default_warrior_id"))
	return "outrage"

func default_owned_warriors(host: Control) -> PackedStringArray:
	var warrior_ui: Variant = host.get("_warrior_ui")
	if warrior_ui != null and warrior_ui.has_method("default_owned_warriors"):
		var value: Variant = warrior_ui.call("default_owned_warriors")
		if value is PackedStringArray:
			return value
	return PackedStringArray(["outrage"])

func default_owned_warrior_skins_by_warrior(host: Control) -> Dictionary:
	var warrior_ui: Variant = host.get("_warrior_ui")
	if warrior_ui != null and warrior_ui.has_method("default_owned_warrior_skins_by_warrior"):
		var value: Variant = warrior_ui.call("default_owned_warrior_skins_by_warrior")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {"outrage": PackedInt32Array([0])}

func default_equipped_warrior_skin_by_warrior(host: Control) -> Dictionary:
	var warrior_ui: Variant = host.get("_warrior_ui")
	if warrior_ui != null and warrior_ui.has_method("default_equipped_warrior_skin_by_warrior"):
		var value: Variant = warrior_ui.call("default_equipped_warrior_skin_by_warrior")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return {"outrage": 0}

func normalize_owned_warrior_skins_dict(host: Control, src: Dictionary) -> Dictionary:
	var out := default_owned_warrior_skins_by_warrior(host)
	var warrior_ids: PackedStringArray = host.call("_warrior_ui_warrior_ids")
	for wid in warrior_ids:
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

func normalize_equipped_warrior_skins_dict(host: Control, src: Dictionary) -> Dictionary:
	var out := default_equipped_warrior_skin_by_warrior(host)
	var warrior_ids: PackedStringArray = host.call("_warrior_ui_warrior_ids")
	for wid in warrior_ids:
		var normalized := str(wid).strip_edges().to_lower()
		out[normalized] = maxi(0, int(src.get(normalized, src.get(wid, 0))))
	return out

func auth_handle_http_completed(host: Control, response_code: int, body: PackedByteArray) -> void:
	var action := str(host.get("_auth_pending_action"))
	auth_stop_request_watchdog(host)
	if not action.is_empty() and host.has_method("_hide_menu_loading_overlay"):
		host.call("_hide_menu_loading_overlay")
	var text := body.get_string_from_utf8()
	var parsed: Variant = null
	var trimmed := text.strip_edges()
	if not trimmed.is_empty() and (trimmed.begins_with("{") or trimmed.begins_with("[")):
		var json := JSON.new()
		if json.parse(trimmed) == OK:
			parsed = json.data
	var auth_status_label := host.get("_auth_status_label") as Label
	var auth_login_button := host.get("_auth_login_button") as Button

	if action == "login":
		var login_base_candidates := host.get("_auth_login_base_url_candidates") as PackedStringArray
		var login_base_index := int(host.get("_auth_login_base_url_index"))
		if (response_code == 404 or response_code == 0) and login_base_index < login_base_candidates.size() - 1:
			host.set("_auth_login_base_url_index", login_base_index + 1)
			print("[AUTH][LOGIN] code=%d on login endpoint, retry with %s" % [response_code, auth_login_current_base_url(host)])
			host.set("_auth_pending_action", "login")
			var retry_err := auth_request_login_with_current_candidate(host)
			if retry_err == OK:
				return
			host.set("_auth_pending_action", "")
			if auth_status_label != null:
				auth_status_label.text = "Login request failed (%s)" % str(retry_err)
			if auth_login_button != null:
				auth_login_button.disabled = false
			return
		if response_code < 200 or response_code >= 300 or not (parsed is Dictionary):
			if auth_status_label != null:
				auth_status_label.text = "Login failed (%d)" % response_code
			if auth_login_button != null:
				auth_login_button.disabled = false
			host.set("_auth_timeout_retry_attempts", 0)
			host.set("_auth_pending_action", "")
			return
		var data := parsed as Dictionary
		var active_base := auth_login_current_base_url(host)
		if str(host.get("_auth_api_base_url")) != active_base:
			host.set("_auth_api_base_url", active_base)
			print("[AUTH][LOGIN] using auth base url %s" % str(host.get("_auth_api_base_url")))
		host.set("_auth_token", str(data.get("token", "")).strip_edges())
		host.set("player_username", str(data.get("username", host.get("player_username"))).strip_edges())
		if str(host.get("_auth_token")).is_empty():
			if auth_status_label != null:
				auth_status_label.text = "Login failed: missing token"
			if auth_login_button != null:
				auth_login_button.disabled = false
			host.set("_auth_timeout_retry_attempts", 0)
			host.set("_auth_pending_action", "")
			return
		host.set("_auth_timeout_retry_attempts", 0)
		host.set("_auth_pending_action", "")
		auth_recreate_http_request(host)
		host.call_deferred("_auth_request_profile")
		return

	if action == "profile":
		if response_code < 200 or response_code >= 300 or not (parsed is Dictionary):
			print("[AUTH][PROFILE] failed code=%d body=%s" % [response_code, text])
			var had_runtime_session := bool(host.get("_auth_logged_in")) and not str(host.get("_auth_token")).is_empty()
			if response_code == 401 or response_code == 403:
				auth_clear_persisted_session(host)
				auth_set_ui_locked(host, true)
				if auth_status_label != null:
					auth_status_label.text = "Session expired. Log in again."
				if auth_login_button != null:
					auth_login_button.disabled = false
				host.set("_auth_pending_action", "")
				return
			var fallback_reason := "Logged in without remote profile. Shop sync unavailable."
			if response_code == 404:
				fallback_reason = "Server has no /profile endpoint yet. Shop sync unavailable."
			if had_runtime_session:
				host.set("_auth_pending_action", "")
				host.call("_auth_finalize_without_remote_profile", fallback_reason)
				return
			host.set("_auth_pending_action", "")
			host.call("_auth_finalize_without_remote_profile", fallback_reason)
			return
		var profile := parsed as Dictionary
		print("[AUTH][PROFILE] ok user=%s coins=%d clk=%d" % [str(profile.get("username", "")), int(profile.get("coins", host.get("wallet_coins"))), int(profile.get("clk", host.get("wallet_clk")))])
		host.call("_auth_apply_profile", profile)
		var has_wallet_inventory_fields := profile.has("owned_weapons") and profile.has("owned_weapon_skins_by_weapon")
		if not has_wallet_inventory_fields:
			host.set("_auth_wallet_sync_supported", false)
			print("[AUTH][PROFILE] legacy server detected (missing wallet inventory fields). wallet sync disabled.")
			if auth_status_label != null:
				auth_status_label.text = "Server supports only skin purchases"
		else:
			host.set("_auth_wallet_sync_supported", true)
			host.set("_auth_wallet_sync_endpoint_index", 0)
		host.set("_auth_logged_in", true)
		auth_save_runtime_session(host)
		auth_save_persisted_session(host)
		auth_set_ui_locked(host, false)
		if auth_status_label != null:
			auth_status_label.text = ""
		if auth_login_button != null:
			auth_login_button.disabled = false
		host.set("_auth_pending_action", "")
		host.call("_start_idle_loop")
		auth_maybe_flush_wallet_sync(host)
		return

	if action == "wallet_sync":
		if response_code >= 200 and response_code < 300 and (parsed is Dictionary):
			var wallet_profile := parsed as Dictionary
			print("[AUTH][WALLET_SYNC] ok user=%s coins=%d clk=%d" % [str(wallet_profile.get("username", host.get("player_username"))), int(wallet_profile.get("coins", host.get("wallet_coins"))), int(wallet_profile.get("clk", host.get("wallet_clk")))])
			host.call("_auth_apply_profile", wallet_profile)
			host.set("_auth_wallet_sync_endpoint_index", 0)
			host.set("_auth_wallet_sync_supported", true)
			host.set("_auth_wallet_sync_snapshot_active", false)
			host.set("_auth_wallet_sync_snapshot", {})
			host.set("_auth_pending_action", "")
			auth_maybe_flush_wallet_sync(host)
			return
		print("[AUTH][WALLET_SYNC] failed code=%d body=%s" % [response_code, text])
		if response_code == 404:
			var endpoint_candidates := host.get("_auth_wallet_sync_endpoint_candidates") as Array
			var endpoint_index := int(host.get("_auth_wallet_sync_endpoint_index"))
			if endpoint_index < endpoint_candidates.size() - 1:
				host.set("_auth_wallet_sync_endpoint_index", endpoint_index + 1)
				print("[AUTH][WALLET_SYNC] endpoint not found, retry with %s" % str(endpoint_candidates[int(host.get("_auth_wallet_sync_endpoint_index"))]))
				host.set("_auth_pending_action", "")
				host.set("_auth_wallet_sync_queued", true)
				auth_schedule_wallet_retry(host)
				return
			auth_restore_wallet_sync_snapshot(host)
			host.set("_auth_wallet_sync_supported", false)
			if auth_status_label != null:
				auth_status_label.text = "Server does not support wallet updates"
			host.set("_auth_wallet_sync_queued", false)
			host.set("_auth_pending_action", "")
			return
		host.set("_auth_pending_action", "")
		host.set("_auth_wallet_sync_queued", true)
		auth_schedule_wallet_retry(host)
		return

	if action == "purchase_skin":
		if response_code >= 200 and response_code < 300 and (parsed is Dictionary):
			var purchase_profile := parsed as Dictionary
			print("[AUTH][BUY_SKIN] ok user=%s skin=%d coins=%d clk=%d" % [str(purchase_profile.get("username", host.get("player_username"))), int(host.get("_auth_pending_purchase_skin_index")), int(purchase_profile.get("coins", host.get("wallet_coins"))), int(purchase_profile.get("clk", host.get("wallet_clk")))])
			host.call("_auth_apply_profile", purchase_profile)
			var purchased_skin_idx := int(host.get("_auth_pending_purchase_skin_index"))
			if purchased_skin_idx >= 0 and bool(host.call("_is_warrior_skin_owned", purchased_skin_idx)):
				host.call("_equip_warrior_item", str(host.get("selected_warrior_id")), purchased_skin_idx)
			host.call("_pixel_burst_at", host.call("_center_of", host.get("wallet_panel")), Color(0.25, 1, 0.85, 1))
			host.set("_auth_pending_purchase_skin_index", -1)
			host.set("_auth_pending_action", "")
			auth_maybe_flush_wallet_sync(host)
			return
		print("[AUTH][BUY_SKIN] failed code=%d skin=%d body=%s" % [response_code, int(host.get("_auth_pending_purchase_skin_index")), text])
		if auth_status_label != null:
			auth_status_label.text = "Purchase failed (%d)" % response_code
		host.set("_auth_pending_purchase_skin_index", -1)
		host.set("_auth_pending_action", "")

func auth_on_logout_pressed(host: Control) -> void:
	var auth_logout_button := host.get("_auth_logout_button") as Button
	if auth_logout_button != null:
		host.call("_button_press_anim", auth_logout_button)
	var auth_http := host.get("_auth_http") as HTTPRequest
	if auth_http != null:
		auth_http.cancel_request()
	auth_stop_request_watchdog(host)
	auth_clear_persisted_session(host)
	host.set("_auth_pending_action", "")
	host.set("_auth_pending_purchase_skin_index", -1)
	host.set("_auth_wallet_sync_queued", false)
	host.set("_auth_wallet_sync_snapshot_active", false)
	host.set("_auth_wallet_sync_snapshot", {})
	host.set("_auth_logged_in", false)
	var auth_status_label := host.get("_auth_status_label") as Label
	if auth_status_label != null:
		auth_status_label.text = "Logged out"
	var auth_login_button := host.get("_auth_login_button") as Button
	if auth_login_button != null:
		auth_login_button.disabled = false
	var auth_pass_input := host.get("_auth_pass_input") as LineEdit
	if auth_pass_input != null:
		auth_pass_input.text = DEFAULT_AUTH_PASSWORD
	var auth_user_input := host.get("_auth_user_input") as LineEdit
	if auth_user_input != null:
		auth_user_input.text = DEFAULT_AUTH_USERNAME
	var auth_overlay := host.get("_auth_overlay") as Control
	if auth_overlay != null:
		auth_overlay.visible = true
	auth_set_ui_locked(host, true)
	if host.has_method("_hide_menu_loading_overlay"):
		host.call("_hide_menu_loading_overlay")

func auth_url(host: Control, path: String) -> String:
	return "%s%s" % [str(host.get("_auth_api_base_url")), path]

func auth_login_current_base_url(host: Control) -> String:
	var candidates := host.get("_auth_login_base_url_candidates") as PackedStringArray
	var index := int(host.get("_auth_login_base_url_index"))
	if candidates.is_empty():
		return str(host.get("_auth_api_base_url"))
	return str(candidates[index])

func auth_build_base_url_with_port(base_url: String, port: int) -> String:
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

func auth_trim_suffix(url: String, suffix: String) -> String:
	var trimmed := url.strip_edges()
	if trimmed.ends_with(suffix):
		return trimmed.substr(0, trimmed.length() - suffix.length())
	return trimmed

func auth_rebuild_login_base_candidates(host: Control) -> void:
	var result := PackedStringArray()
	var normalized := str(host.get("_auth_api_base_url")).strip_edges()
	if not normalized.is_empty():
		_append_login_base_candidate(result, normalized)
		var parts := _split_base_url(normalized)
		var scheme := str(parts.get("scheme", "http"))
		var hostname := str(parts.get("hostname", ""))
		var suffix := str(parts.get("suffix", ""))
		var has_explicit_port := bool(parts.get("has_explicit_port", false))
		var port := int(parts.get("port", -1))
		if not hostname.is_empty():
			if suffix == "/auth":
				_append_login_base_candidate(result, _compose_base_url(scheme, hostname, -1, suffix, false))
				_append_login_base_candidate(result, _compose_base_url("http", hostname, 8090, "", true))
				if has_explicit_port and port == 8081:
					_append_login_base_candidate(result, _compose_base_url(scheme, hostname, 8080, suffix, true))
			elif suffix.is_empty():
				_append_login_base_candidate(result, _compose_base_url(scheme, hostname, port, "/auth", has_explicit_port))
				_append_login_base_candidate(result, _compose_base_url("http", hostname, 8090, "", true))
	host.set("_auth_login_base_url_candidates", result)
	host.set("_auth_login_base_url_index", 0)

func auth_request_login_with_current_candidate(host: Control) -> int:
	var auth_http := host.get("_auth_http") as HTTPRequest
	if auth_http == null:
		return ERR_UNCONFIGURED
	if host.has_method("_show_menu_loading_overlay"):
		host.call("_show_menu_loading_overlay", "LOGGING IN...")
	var auth_user_input := host.get("_auth_user_input") as LineEdit
	var url := "%s/login" % auth_login_current_base_url(host)
	print("[AUTH][LOGIN] request url=%s user=%s" % [url, (auth_user_input.text.strip_edges() if auth_user_input != null else "")])
	var err := auth_http.request(
		url,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		str(host.get("_auth_login_payload"))
	)
	if err == OK:
		auth_start_request_watchdog(host)
	else:
		if host.has_method("_hide_menu_loading_overlay"):
			host.call("_hide_menu_loading_overlay")
	return err

func auth_request_profile(host: Control) -> void:
	var auth_http := host.get("_auth_http") as HTTPRequest
	var auth_token := str(host.get("_auth_token")).strip_edges()
	if auth_http == null or auth_token.is_empty():
		return
	if host.has_method("_show_menu_loading_overlay"):
		host.call("_show_menu_loading_overlay", "LOADING PROFILE...")
	host.set("_auth_pending_action", "profile")
	var auth_status_label := host.get("_auth_status_label") as Label
	if auth_status_label != null:
		auth_status_label.text = "Loading profile..."
	var err := auth_http.request(
		auth_url(host, "/profile"),
		PackedStringArray(["Authorization: Bearer %s" % auth_token]),
		HTTPClient.METHOD_GET
	)
	if err != OK:
		host.set("_auth_pending_action", "")
		auth_stop_request_watchdog(host)
		if auth_status_label != null:
			auth_status_label.text = "Profile request failed (%s)" % str(err)
		var auth_login_button := host.get("_auth_login_button") as Button
		if auth_login_button != null:
			auth_login_button.disabled = false
		if host.has_method("_hide_menu_loading_overlay"):
			host.call("_hide_menu_loading_overlay")
		return
	auth_start_request_watchdog(host)

func auth_recreate_http_request(host: Control) -> void:
	var old_http := host.get("_auth_http") as HTTPRequest
	if old_http != null:
		old_http.cancel_request()
		old_http.queue_free()
	var auth_http := HTTPRequest.new()
	auth_http.name = "AuthHttp"
	host.add_child(auth_http)
	auth_http.request_completed.connect(Callable(host, "_on_auth_http_completed"))
	host.set("_auth_http", auth_http)

func auth_start_request_watchdog(host: Control) -> void:
	var watchdog_timer := host.get("_auth_request_watchdog_timer") as Timer
	if watchdog_timer == null:
		return
	watchdog_timer.stop()
	watchdog_timer.wait_time = AUTH_REQUEST_TIMEOUT_SEC
	watchdog_timer.start()

func auth_stop_request_watchdog(host: Control) -> void:
	var watchdog_timer := host.get("_auth_request_watchdog_timer") as Timer
	if watchdog_timer == null:
		return
	watchdog_timer.stop()

func auth_on_request_watchdog_timeout(host: Control) -> void:
	var action := str(host.get("_auth_pending_action")).strip_edges()
	if action.is_empty():
		return
	if host.has_method("_hide_menu_loading_overlay"):
		host.call("_hide_menu_loading_overlay")
	var auth_token := str(host.get("_auth_token")).strip_edges()
	var auth_http := host.get("_auth_http") as HTTPRequest
	if auth_http != null:
		auth_http.cancel_request()
	var auth_login_button := host.get("_auth_login_button") as Button
	var auth_status_label := host.get("_auth_status_label") as Label
	if action == "login":
		var login_base_candidates := host.get("_auth_login_base_url_candidates") as PackedStringArray
		var login_base_index := int(host.get("_auth_login_base_url_index"))
		if login_base_index < login_base_candidates.size() - 1:
			var failed_base := auth_login_current_base_url(host)
			host.set("_auth_login_base_url_index", login_base_index + 1)
			host.set("_auth_timeout_retry_attempts", 0)
			host.set("_auth_pending_action", "login")
			if auth_status_label != null:
				auth_status_label.text = "Login timeout on %s, trying %s..." % [failed_base, auth_login_current_base_url(host)]
			print("[AUTH][LOGIN] timeout on %s, retry with fallback %s" % [failed_base, auth_login_current_base_url(host)])
			var fallback_err := auth_request_login_with_current_candidate(host)
			if fallback_err == OK:
				return
			if auth_status_label != null:
				auth_status_label.text = "Login fallback failed (%s)" % str(fallback_err)
			if auth_login_button != null:
				auth_login_button.disabled = false
			host.set("_auth_pending_action", "")
			return
		var retries := int(host.get("_auth_timeout_retry_attempts"))
		var retry_limit := maxi(0, int(host.get("_auth_timeout_retry_limit")))
		if retries < retry_limit:
			host.set("_auth_timeout_retry_attempts", retries + 1)
			host.set("_auth_pending_action", "login")
			if auth_status_label != null:
				auth_status_label.text = "Login timeout, retrying (%d/%d)..." % [retries + 1, retry_limit]
			var retry_err := auth_request_login_with_current_candidate(host)
			if retry_err == OK:
				return
			if auth_status_label != null:
				auth_status_label.text = "Login retry failed (%s)" % str(retry_err)
			if auth_login_button != null:
				auth_login_button.disabled = false
			host.set("_auth_timeout_retry_attempts", 0)
			host.set("_auth_pending_action", "")
			return
	host.set("_auth_pending_action", "")
	host.set("_auth_pending_purchase_skin_index", -1)
	if auth_login_button != null:
		auth_login_button.disabled = false
	if auth_status_label != null:
		auth_status_label.text = "%s timeout (%s). Check server/IP and try again." % [action.capitalize(), auth_login_current_base_url(host)]
	host.set("_auth_timeout_retry_attempts", 0)
	if action == "profile" and not auth_token.is_empty():
		host.call("_auth_finalize_without_remote_profile", "Profile timeout. Logged in with local profile only.")
		return
	if action == "wallet_sync":
		host.set("_auth_wallet_sync_queued", true)
		auth_schedule_wallet_retry(host)
	print("[AUTH][TIMEOUT] action=%s base_url=%s" % [action, str(host.get("_auth_api_base_url"))])

func auth_apply_profile(host: Control, profile: Dictionary) -> void:
	host.set("wallet_coins", int(profile.get("coins", host.get("wallet_coins"))))
	host.set("wallet_clk", int(profile.get("clk", host.get("wallet_clk"))))
	host.set("player_username", str(profile.get("username", host.get("player_username"))).strip_edges())
	if str(host.get("player_username")).is_empty():
		host.set("player_username", "Player")

	if profile.has("owned_warriors"):
		var incoming_owned_warriors := PackedStringArray()
		for item in profile.get("owned_warriors", []) as Array:
			var wid := str(item).strip_edges().to_lower()
			if not wid.is_empty() and not incoming_owned_warriors.has(wid):
				incoming_owned_warriors.append(wid)
		var default_warrior := str(host.call("_default_warrior_id"))
		if not incoming_owned_warriors.has(default_warrior):
			incoming_owned_warriors.append(default_warrior)
		host.set("owned_warriors", incoming_owned_warriors)

	var incoming_warrior_skins := host.call("_default_owned_warrior_skins_by_warrior") as Dictionary
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
			var owned_warriors := host.get("owned_warriors") as PackedStringArray
			if not owned_warriors.has(wid):
				owned_warriors.append(wid)
				host.set("owned_warriors", owned_warriors)
	host.set("owned_warrior_skins_by_warrior", incoming_warrior_skins)
	host.set("owned_warrior_skins", incoming_warrior_skins.get(str(host.call("_default_warrior_id")), PackedInt32Array([0])) as PackedInt32Array)
	if profile.has("equipped_warrior_skin_by_warrior"):
		host.set("equipped_warrior_skin_by_warrior", host.call("_normalize_equipped_warrior_skins_dict", (profile.get("equipped_warrior_skin_by_warrior", {}) as Dictionary).duplicate(true)))
	var next_selected_warrior_id := str(host.get("selected_warrior_id"))
	if profile.has("selected_warrior_id"):
		next_selected_warrior_id = str(profile.get("selected_warrior_id", host.get("selected_warrior_id"))).strip_edges().to_lower()
	host.set("selected_warrior_id", next_selected_warrior_id)
	var owned_warriors_after := host.get("owned_warriors") as PackedStringArray
	if not owned_warriors_after.has(str(host.get("selected_warrior_id"))):
		host.set("selected_warrior_id", str(host.call("_default_warrior_id")))
	var next_selected_warrior_skin := int(host.get("selected_warrior_skin"))
	if profile.has("selected_warrior_skin"):
		next_selected_warrior_skin = maxi(0, int(profile.get("selected_warrior_skin", host.get("selected_warrior_skin"))))
	elif profile.has("equipped_warrior_skin_by_warrior"):
		next_selected_warrior_skin = int(host.call("_equipped_warrior_skin", str(host.get("selected_warrior_id"))))
	if not bool(host.call("_warrior_skin_is_owned", str(host.get("selected_warrior_id")), next_selected_warrior_skin)):
		next_selected_warrior_skin = 0
	host.set("selected_warrior_skin", next_selected_warrior_skin)
	host.call("_set_equipped_warrior_skin", str(host.get("selected_warrior_id")), int(host.get("selected_warrior_skin")))

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
		host.set("owned_weapons", from_api)

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
			if not bool(host.call("_weapon_is_owned", wid)):
				arr_out = PackedInt32Array([0])
			out[wid] = arr_out
		host.set("owned_weapon_skins_by_weapon", out)
	if profile.has("equipped_weapon_skin_by_weapon"):
		var incoming_equipped_weapon := profile.get("equipped_weapon_skin_by_weapon", {}) as Dictionary
		for wid in PackedStringArray([host.get("WEAPON_UZI"), host.get("WEAPON_AK47"), host.get("WEAPON_KAR"), host.get("WEAPON_SHOTGUN"), host.get("WEAPON_GRENADE")]):
			var equipped_weapon_skin_by_weapon := host.get("equipped_weapon_skin_by_weapon") as Dictionary
			equipped_weapon_skin_by_weapon[wid] = maxi(0, int(incoming_equipped_weapon.get(wid, equipped_weapon_skin_by_weapon.get(wid, 0))))
			host.set("equipped_weapon_skin_by_weapon", equipped_weapon_skin_by_weapon)
	var next_selected_weapon_id := str(host.get("selected_weapon_id"))
	if profile.has("selected_weapon_id"):
		next_selected_weapon_id = str(profile.get("selected_weapon_id", host.get("selected_weapon_id"))).strip_edges().to_lower()
	host.set("selected_weapon_id", next_selected_weapon_id)
	if not bool(host.call("_weapon_is_owned", str(host.get("selected_weapon_id")))):
		host.set("selected_weapon_id", WEAPON_UZI)
	var next_selected_weapon_skin := int(host.get("selected_weapon_skin"))
	if profile.has("selected_weapon_skin"):
		next_selected_weapon_skin = maxi(0, int(profile.get("selected_weapon_skin", host.get("selected_weapon_skin"))))
	elif profile.has("equipped_weapon_skin_by_weapon"):
		next_selected_weapon_skin = int(host.call("_equipped_weapon_skin", str(host.get("selected_weapon_id"))))
	if not bool(host.call("_weapon_skin_is_owned", str(host.get("selected_weapon_id")), next_selected_weapon_skin)):
		next_selected_weapon_skin = 0
	host.set("selected_weapon_skin", next_selected_weapon_skin)
	host.call("_set_equipped_weapon_skin", str(host.get("selected_weapon_id")), int(host.get("selected_weapon_skin")))
	auth_dev_unlock_all_for_mario(host)
	host.set("_pending_warrior_id", str(host.get("selected_warrior_id")))
	host.set("_pending_warrior_skin", int(host.get("selected_warrior_skin")))
	host.set("_pending_weapon_id", str(host.get("selected_weapon_id")))
	host.set("_pending_weapon_skin", int(host.get("selected_weapon_skin")))
	host.set("_weapon_filter_weapon_id", str(host.get("selected_weapon_id")))
	host.call("_apply_warrior_skin_to_player", host.get("main_warrior_preview"), str(host.get("selected_warrior_id")), int(host.get("selected_warrior_skin")))
	host.call("_apply_warrior_skin_to_player", host.get("warrior_shop_preview"), str(host.get("_pending_warrior_id")), int(host.get("_pending_warrior_skin")))
	host.call("_set_weapon_icon_sprite", host.get("main_weapon_icon"), str(host.get("selected_weapon_id")), 1.0, int(host.get("selected_weapon_skin")))
	host.call("_apply_weapon_skin_visual", host.get("main_weapon_icon"), str(host.get("selected_weapon_id")), int(host.get("selected_weapon_skin")))
	host.call("_set_weapon_icon_sprite", host.get("weapon_shop_preview"), str(host.get("_pending_weapon_id")), 1.0, int(host.get("_pending_weapon_skin")))
	host.call("_apply_weapon_skin_visual", host.get("weapon_shop_preview"), str(host.get("_pending_weapon_id")), int(host.get("_pending_weapon_skin")))
	var warrior_name_label := host.get("warrior_name_label") as Label
	if warrior_name_label != null:
		warrior_name_label.text = "%s - %s" % [
			str(host.call("_warrior_ui_warrior_display_name", str(host.get("_pending_warrior_id")))),
			str(host.call("_warrior_ui_warrior_skin_label", str(host.get("_pending_warrior_id")), int(host.get("_pending_warrior_skin"))))
		]
	var weapon_name_label := host.get("weapon_name_label") as Label
	if weapon_name_label != null:
		weapon_name_label.text = "%s - %s" % [
			str(host.call("_weapon_ui_weapon_display_name", str(host.get("_pending_weapon_id")))),
			host.call("_weapon_skin_label", str(host.get("_pending_weapon_id")), int(host.get("_pending_weapon_skin")))
		]

	host.call("_update_wallet_labels", true)
	host.call("_refresh_warrior_username_label")
	host.call("_refresh_auth_footer")
	host.call("_refresh_warrior_grid_texts")
	host.call("_refresh_warrior_action")
	host.call("_refresh_weapon_grid_texts")
	host.call("_refresh_weapon_action")
	host.call("_save_state")

func auth_finalize_without_remote_profile(host: Control, reason: String = "") -> void:
	if str(host.get("player_username")).is_empty():
		host.set("player_username", "Player")
	host.set("_auth_logged_in", true)
	host.set("_auth_wallet_sync_supported", false)
	auth_dev_unlock_all_for_mario(host)
	host.call("_update_wallet_labels", true)
	host.call("_refresh_warrior_username_label")
	host.call("_refresh_warrior_grid_texts")
	host.call("_refresh_warrior_action")
	host.call("_refresh_weapon_grid_texts")
	host.call("_refresh_weapon_action")
	auth_save_runtime_session(host)
	auth_save_persisted_session(host)
	auth_set_ui_locked(host, false)
	host.call("_refresh_auth_footer")
	var auth_status_label := host.get("_auth_status_label") as Label
	if auth_status_label != null:
		auth_status_label.text = reason
	var auth_login_button := host.get("_auth_login_button") as Button
	if auth_login_button != null:
		auth_login_button.disabled = false
	host.call("_start_idle_loop")
	host.call("_save_state")

func auth_dev_unlock_all_for_mario(host: Control) -> void:
	var dev_user := str(host.get("player_username")).strip_edges().to_lower()
	if dev_user != "mario" and dev_user != "blackshadow":
		return

	var warrior_ids: PackedStringArray = PackedStringArray(host.call("_warrior_ui_warrior_ids"))
	var all_owned_warriors: PackedStringArray = PackedStringArray()
	for wid in warrior_ids:
		var normalized: String = str(wid).strip_edges().to_lower()
		if normalized.is_empty() or all_owned_warriors.has(normalized):
			continue
		all_owned_warriors.append(normalized)
	host.set("owned_warriors", all_owned_warriors)

	var all_warrior_skins: Dictionary = {}
	for wid in all_owned_warriors:
		all_warrior_skins[wid] = host.call("_warrior_ui_available_skin_indices_for", wid)
	host.set("owned_warrior_skins_by_warrior", all_warrior_skins)

	var all_weapons := PackedStringArray([WEAPON_UZI, WEAPON_AK47, WEAPON_KAR, WEAPON_SHOTGUN, WEAPON_GRENADE])
	host.set("owned_weapons", all_weapons)

	var all_weapon_skins: Dictionary = {}
	for wid in all_weapons:
		var arr := PackedInt32Array([0])
		for skin in host.call("_weapon_skins_for", wid):
			var idx := maxi(0, int((skin as Dictionary).get("skin", 0)))
			if not arr.has(idx):
				arr.append(idx)
		arr.sort()
		all_weapon_skins[wid] = arr
	host.set("owned_weapon_skins_by_weapon", all_weapon_skins)

	var equipped_warrior_skin_by_warrior := host.get("equipped_warrior_skin_by_warrior") as Dictionary
	var owned_warrior_skins_by_warrior := host.get("owned_warrior_skins_by_warrior") as Dictionary
	for wid in warrior_ids:
		var normalized := str(wid).strip_edges().to_lower()
		var owned_arr := owned_warrior_skins_by_warrior.get(normalized, PackedInt32Array([0])) as PackedInt32Array
		var equipped := maxi(0, int(equipped_warrior_skin_by_warrior.get(normalized, 0)))
		if not owned_arr.has(equipped):
			equipped_warrior_skin_by_warrior[normalized] = 0
	host.set("equipped_warrior_skin_by_warrior", equipped_warrior_skin_by_warrior)

	var equipped_weapon_skin_by_weapon := host.get("equipped_weapon_skin_by_weapon") as Dictionary
	var owned_weapon_skins_by_weapon := host.get("owned_weapon_skins_by_weapon") as Dictionary
	for wid in all_weapons:
		var owned_arr := owned_weapon_skins_by_weapon.get(wid, PackedInt32Array([0])) as PackedInt32Array
		var equipped := maxi(0, int(equipped_weapon_skin_by_weapon.get(wid, 0)))
		if not owned_arr.has(equipped):
			equipped_weapon_skin_by_weapon[wid] = 0
	host.set("equipped_weapon_skin_by_weapon", equipped_weapon_skin_by_weapon)

	if not (host.get("owned_warriors") as PackedStringArray).has(str(host.get("selected_warrior_id"))):
		host.set("selected_warrior_id", str(host.call("_default_warrior_id")))
	if not bool(host.call("_warrior_skin_is_owned", str(host.get("selected_warrior_id")), int(host.get("selected_warrior_skin")))):
		host.set("selected_warrior_skin", int(host.call("_equipped_warrior_skin", str(host.get("selected_warrior_id")))))
	if not bool(host.call("_warrior_skin_is_owned", str(host.get("selected_warrior_id")), int(host.get("selected_warrior_skin")))):
		host.set("selected_warrior_skin", 0)
	host.call("_set_equipped_warrior_skin", str(host.get("selected_warrior_id")), int(host.get("selected_warrior_skin")))
	host.set("owned_warrior_skins", (host.get("owned_warrior_skins_by_warrior") as Dictionary).get(str(host.get("selected_warrior_id")), PackedInt32Array([0])) as PackedInt32Array)

	if not (host.get("owned_weapons") as PackedStringArray).has(str(host.get("selected_weapon_id"))):
		host.set("selected_weapon_id", WEAPON_UZI)
	if not bool(host.call("_weapon_skin_is_owned", str(host.get("selected_weapon_id")), int(host.get("selected_weapon_skin")))):
		host.set("selected_weapon_skin", int(host.call("_equipped_weapon_skin", str(host.get("selected_weapon_id")))))
	if not bool(host.call("_weapon_skin_is_owned", str(host.get("selected_weapon_id")), int(host.get("selected_weapon_skin")))):
		host.set("selected_weapon_skin", 0)
	host.call("_set_equipped_weapon_skin", str(host.get("selected_weapon_id")), int(host.get("selected_weapon_skin")))

func auth_restore_runtime_session(host: Control) -> bool:
	var token := str(_runtime_session_token).strip_edges()
	if token.is_empty():
		return false
	host.set("_auth_token", token)
	host.set("_auth_logged_in", true)
	var username := str(_runtime_session_username).strip_edges()
	if not username.is_empty():
		host.set("player_username", username)
		var auth_user_input := host.get("_auth_user_input") as LineEdit
		if auth_user_input != null and auth_user_input.text.strip_edges().is_empty():
			auth_user_input.text = username
	var api_base := str(_runtime_session_api_base_url).strip_edges()
	if not api_base.is_empty():
		host.set("_auth_api_base_url", _normalize_api_base_url(api_base))
		auth_rebuild_login_base_candidates(host)
	return true

func auth_save_runtime_session(host: Control) -> void:
	_runtime_session_token = str(host.get("_auth_token")).strip_edges()
	_runtime_session_username = str(host.get("player_username")).strip_edges()
	_runtime_session_api_base_url = str(host.get("_auth_api_base_url")).strip_edges()

func resolve_auth_profile(host: Control) -> void:
	var configured := str(ProjectSettings.get_setting(AUTH_PROFILE_SETTING, "default")).strip_edges()
	if not configured.is_empty():
		host.set("_auth_profile", configured)
	for raw_arg in OS.get_cmdline_args():
		var arg := str(raw_arg)
		if arg.begins_with(AUTH_PROFILE_ARG_PREFIX):
			var value := arg.substr(AUTH_PROFILE_ARG_PREFIX.length()).strip_edges()
			if not value.is_empty():
				host.set("_auth_profile", value)
				break
	var profile := str(host.get("_auth_profile")).strip_edges()
	if profile.is_empty():
		profile = "default"
	host.set("_auth_profile", profile)

func session_path(host: Control) -> String:
	if str(host.get("_auth_profile")).strip_edges() == "default":
		return AUTH_SESSION_PATH
	return "user://main_menu_auth_session_%s.json" % str(host.get("_auth_profile")).strip_edges()

func auth_restore_persisted_session(host: Control) -> bool:
	if auth_restore_runtime_session(host):
		return true
	var path := session_path(host)
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return false
	var payload := parsed as Dictionary
	var token := str(payload.get("token", "")).strip_edges()
	if token.is_empty():
		return false
	_runtime_session_token = token
	_runtime_session_username = str(payload.get("username", "")).strip_edges()
	_runtime_session_api_base_url = _normalize_api_base_url(str(payload.get("api_base_url", "")).strip_edges())
	return auth_restore_runtime_session(host)

func auth_save_persisted_session(host: Control) -> void:
	auth_save_runtime_session(host)
	var token := str(host.get("_auth_token")).strip_edges()
	if token.is_empty():
		auth_clear_persisted_session(host)
		return
	var payload := {
		"token": token,
		"username": str(host.get("player_username")).strip_edges(),
		"api_base_url": str(host.get("_auth_api_base_url")).strip_edges(),
	}
	var file := FileAccess.open(session_path(host), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))

func auth_clear_runtime_session(host: Control) -> void:
	_runtime_session_token = ""
	_runtime_session_username = ""
	_runtime_session_api_base_url = ""
	host.set("_auth_token", "")
	host.set("_auth_logged_in", false)

func auth_clear_persisted_session(host: Control) -> void:
	auth_clear_runtime_session(host)
	var path := session_path(host)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _normalize_api_base_url(raw: String) -> String:
	var api_base := raw.strip_edges().trim_suffix("/")
	if api_base.is_empty():
		return api_base
	if api_base == "http://85.75.243.92:8081/auth" or api_base == "http://85.75.243.92:8081":
		return "http://updates.outrage.ink:8081/auth"
	if api_base == "http://127.0.0.1:8081/auth" or api_base == "http://127.0.0.1:8081":
		return "http://updates.outrage.ink:8081/auth"
	if api_base == "http://localhost:8081/auth" or api_base == "http://localhost:8081":
		return "http://updates.outrage.ink:8081/auth"
	return api_base

func _append_login_base_candidate(candidates: PackedStringArray, candidate: String) -> void:
	var normalized := candidate.strip_edges().trim_suffix("/")
	if normalized.is_empty():
		return
	for existing in candidates:
		if str(existing) == normalized:
			return
	candidates.append(normalized)

func _split_base_url(base_url: String) -> Dictionary:
	var trimmed := base_url.strip_edges().trim_suffix("/")
	var scheme_idx := trimmed.find("://")
	if scheme_idx < 0:
		return {
			"scheme": "http",
			"hostname": "",
			"port": -1,
			"suffix": "",
			"has_explicit_port": false,
		}
	var scheme := trimmed.substr(0, scheme_idx)
	var rest := trimmed.substr(scheme_idx + 3)
	var slash_idx := rest.find("/")
	var host_port := rest
	var suffix := ""
	if slash_idx >= 0:
		host_port = rest.substr(0, slash_idx)
		suffix = rest.substr(slash_idx)
	var hostname := host_port
	var port := -1
	var has_explicit_port := false
	if host_port.begins_with("["):
		var bracket_idx := host_port.find("]")
		if bracket_idx >= 0:
			hostname = host_port.substr(0, bracket_idx + 1)
			if host_port.length() > bracket_idx + 1 and host_port.substr(bracket_idx + 1, 1) == ":":
				port = int(host_port.substr(bracket_idx + 2))
				has_explicit_port = true
	else:
		var colon_idx := host_port.rfind(":")
		if colon_idx >= 0:
			hostname = host_port.substr(0, colon_idx)
			port = int(host_port.substr(colon_idx + 1))
			has_explicit_port = true
	return {
		"scheme": scheme,
		"hostname": hostname,
		"port": port,
		"suffix": suffix,
		"has_explicit_port": has_explicit_port,
	}

func _compose_base_url(scheme: String, hostname: String, port: int, suffix: String, force_port: bool) -> String:
	var normalized_scheme := scheme.strip_edges().to_lower()
	if normalized_scheme.is_empty():
		normalized_scheme = "http"
	var normalized_host := hostname.strip_edges()
	if normalized_host.is_empty():
		return ""
	var normalized_suffix := suffix.strip_edges()
	if not normalized_suffix.is_empty() and not normalized_suffix.begins_with("/"):
		normalized_suffix = "/" + normalized_suffix
	var use_port := force_port or port > 0
	if not force_port:
		if (normalized_scheme == "http" and port == 80) or (normalized_scheme == "https" and port == 443):
			use_port = false
	var port_part := ""
	if use_port and port > 0:
		port_part = ":%d" % port
	return "%s://%s%s%s" % [normalized_scheme, normalized_host, port_part, normalized_suffix]

func copy_weapon_skins_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in src.keys():
		var normalized := str(key).strip_edges().to_lower()
		var arr := src.get(key, PackedInt32Array([0])) as PackedInt32Array
		if arr == null:
			out[normalized] = PackedInt32Array([0])
			continue
		var arr_copy := PackedInt32Array()
		for value in arr:
			arr_copy.append(int(value))
		out[normalized] = arr_copy
	return out

func copy_warrior_skins_dict(src: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key in src.keys():
		var normalized := str(key).strip_edges().to_lower()
		var arr := src.get(key, PackedInt32Array([0])) as PackedInt32Array
		if arr == null:
			out[normalized] = PackedInt32Array([0])
			continue
		var arr_copy := PackedInt32Array()
		for value in arr:
			arr_copy.append(int(value))
		if not arr_copy.has(0):
			arr_copy.append(0)
		arr_copy.sort()
		out[normalized] = arr_copy
	return out

func auth_capture_wallet_sync_snapshot(host: Control) -> void:
	if not bool(host.get("_auth_logged_in")) or str(host.get("_auth_token")).is_empty():
		return
	host.set("_auth_wallet_sync_snapshot", {
		"coins": int(host.get("wallet_coins")),
		"clk": int(host.get("wallet_clk")),
		"owned_warriors": PackedStringArray(host.get("owned_warriors")),
		"owned_warrior_skins": PackedInt32Array(host.get("owned_warrior_skins")),
		"owned_warrior_skins_by_warrior": copy_warrior_skins_dict(host.get("owned_warrior_skins_by_warrior") as Dictionary),
		"equipped_warrior_skin_by_warrior": (host.get("equipped_warrior_skin_by_warrior") as Dictionary).duplicate(true),
		"selected_warrior_id": str(host.get("selected_warrior_id")),
		"owned_weapons": PackedStringArray(host.get("owned_weapons")),
		"owned_weapon_skins_by_weapon": copy_weapon_skins_dict(host.get("owned_weapon_skins_by_weapon") as Dictionary),
		"equipped_weapon_skin_by_weapon": (host.get("equipped_weapon_skin_by_weapon") as Dictionary).duplicate(true),
		"selected_warrior_skin": int(host.get("selected_warrior_skin")),
		"selected_weapon_id": str(host.get("selected_weapon_id")),
		"selected_weapon_skin": int(host.get("selected_weapon_skin")),
	})
	host.set("_auth_wallet_sync_snapshot_active", true)

func auth_restore_wallet_sync_snapshot(host: Control) -> void:
	if not bool(host.get("_auth_wallet_sync_snapshot_active")):
		return
	var snapshot := host.get("_auth_wallet_sync_snapshot") as Dictionary
	host.set("wallet_coins", int(snapshot.get("coins", host.get("wallet_coins"))))
	host.set("wallet_clk", int(snapshot.get("clk", host.get("wallet_clk"))))
	host.set("owned_warriors", PackedStringArray(snapshot.get("owned_warriors", ["outrage"]) as Array))
	host.set("owned_warrior_skins", PackedInt32Array(snapshot.get("owned_warrior_skins", [0]) as Array))
	host.set("owned_warrior_skins_by_warrior", copy_warrior_skins_dict(snapshot.get("owned_warrior_skins_by_warrior", {}) as Dictionary))
	host.set("equipped_warrior_skin_by_warrior", (snapshot.get("equipped_warrior_skin_by_warrior", {}) as Dictionary).duplicate(true))
	host.set("selected_warrior_id", str(snapshot.get("selected_warrior_id", host.get("selected_warrior_id"))).strip_edges().to_lower())
	host.set("owned_weapons", PackedStringArray(snapshot.get("owned_weapons", ["uzi"]) as Array))
	host.set("owned_weapon_skins_by_weapon", copy_weapon_skins_dict(snapshot.get("owned_weapon_skins_by_weapon", {}) as Dictionary))
	host.set("equipped_weapon_skin_by_weapon", (snapshot.get("equipped_weapon_skin_by_weapon", {}) as Dictionary).duplicate(true))
	host.set("selected_warrior_skin", maxi(0, int(snapshot.get("selected_warrior_skin", host.get("selected_warrior_skin")))))
	host.set("selected_weapon_id", str(snapshot.get("selected_weapon_id", host.get("selected_weapon_id"))).strip_edges().to_lower())
	host.set("selected_weapon_skin", maxi(0, int(snapshot.get("selected_weapon_skin", host.get("selected_weapon_skin")))))
	host.set("_pending_warrior_id", str(host.get("selected_warrior_id")))
	host.set("_pending_warrior_skin", int(host.get("selected_warrior_skin")))
	host.set("_pending_weapon_id", str(host.get("selected_weapon_id")))
	host.set("_pending_weapon_skin", int(host.get("selected_weapon_skin")))
	host.call("_apply_warrior_skin_to_player", host.get("main_warrior_preview"), str(host.get("selected_warrior_id")), int(host.get("selected_warrior_skin")))
	host.call("_apply_warrior_skin_to_player", host.get("warrior_shop_preview"), str(host.get("_pending_warrior_id")), int(host.get("_pending_warrior_skin")))
	host.call("_set_weapon_icon_sprite", host.get("main_weapon_icon"), str(host.get("selected_weapon_id")), 1.0, int(host.get("selected_weapon_skin")))
	host.call("_apply_weapon_skin_visual", host.get("main_weapon_icon"), str(host.get("selected_weapon_id")), int(host.get("selected_weapon_skin")))
	host.call("_set_weapon_icon_sprite", host.get("weapon_shop_preview"), str(host.get("_pending_weapon_id")), 1.0, int(host.get("_pending_weapon_skin")))
	host.call("_apply_weapon_skin_visual", host.get("weapon_shop_preview"), str(host.get("_pending_weapon_id")), int(host.get("_pending_weapon_skin")))
	host.call("_update_wallet_labels", true)
	host.call("_refresh_warrior_grid_texts")
	host.call("_refresh_warrior_action")
	host.call("_refresh_weapon_grid_texts")
	host.call("_refresh_weapon_action")
	host.call("_save_state")
	host.set("_auth_wallet_sync_snapshot_active", false)
	host.set("_auth_wallet_sync_snapshot", {})
	print("[AUTH][WALLET_SYNC] rollback applied (server rejected wallet update)")
