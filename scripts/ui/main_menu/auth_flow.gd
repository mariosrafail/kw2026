extends RefCounted
class_name MainMenuAuthFlow

const AUTH_SESSION_PATH := "user://main_menu_auth_session.json"

static var _runtime_session_token := ""
static var _runtime_session_username := ""
static var _runtime_session_api_base_url := ""

func setup_auth_gate(host: Control, api_base_url_default: String) -> void:
	host.set("_auth_api_base_url", str(ProjectSettings.get_setting("kw/auth_api_base_url", api_base_url_default)).strip_edges())
	if str(host.get("_auth_api_base_url")).is_empty():
		host.set("_auth_api_base_url", api_base_url_default)
	if str(host.get("_auth_api_base_url")).ends_with("/"):
		var trimmed := str(host.get("_auth_api_base_url"))
		host.set("_auth_api_base_url", trimmed.substr(0, trimmed.length() - 1))
	auth_rebuild_login_base_candidates(host)

	var auth_http := HTTPRequest.new()
	auth_http.name = "AuthHttp"
	host.add_child(auth_http)
	auth_http.request_completed.connect(Callable(host, "_on_auth_http_completed"))
	host.set("_auth_http", auth_http)

	var retry_timer := Timer.new()
	retry_timer.name = "AuthWalletRetryTimer"
	retry_timer.one_shot = true
	retry_timer.wait_time = 1.5
	host.add_child(retry_timer)
	retry_timer.timeout.connect(Callable(host, "_on_auth_wallet_retry_timeout"))
	host.set("_auth_wallet_retry_timer", retry_timer)

	var overlay := Control.new()
	overlay.name = "AuthOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 2000
	host.add_child(overlay)
	host.set("_auth_overlay", overlay)

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
	user_input.text = str(host.get("player_username"))
	box.add_child(user_input)
	host.set("_auth_user_input", user_input)

	var pass_input := LineEdit.new()
	pass_input.placeholder_text = "Password"
	pass_input.secret = true
	pass_input.text = "1234"
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
		host.set("_auth_wallet_sync_queued", true)
		auth_schedule_wallet_retry(host)

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
		host.set("_auth_pending_purchase_skin_index", -1)
		var auth_status_label := host.get("_auth_status_label") as Label
		if auth_status_label != null:
			auth_status_label.text = "Buy request failed (%s)" % str(err)

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

func auth_handle_http_completed(host: Control, response_code: int, body: PackedByteArray) -> void:
	var action := str(host.get("_auth_pending_action"))
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
			host.set("_auth_pending_action", "")
			return
		host.set("_auth_pending_action", "")
		auth_request_profile(host)
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
			if had_runtime_session:
				if auth_status_label != null:
					auth_status_label.text = ""
				if auth_login_button != null:
					auth_login_button.disabled = false
				host.set("_auth_pending_action", "")
				return
			if auth_status_label != null:
				auth_status_label.text = "Profile load failed (%d)" % response_code
			if auth_login_button != null:
				auth_login_button.disabled = false
			host.set("_auth_pending_action", "")
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
		auth_pass_input.text = ""
	var auth_overlay := host.get("_auth_overlay") as Control
	if auth_overlay != null:
		auth_overlay.visible = true
	auth_set_ui_locked(host, true)

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
		result.append(normalized)
	host.set("_auth_login_base_url_candidates", result)
	host.set("_auth_login_base_url_index", 0)

func auth_request_login_with_current_candidate(host: Control) -> int:
	var auth_http := host.get("_auth_http") as HTTPRequest
	if auth_http == null:
		return ERR_UNCONFIGURED
	var auth_user_input := host.get("_auth_user_input") as LineEdit
	var url := "%s/login" % auth_login_current_base_url(host)
	print("[AUTH][LOGIN] request url=%s user=%s" % [url, (auth_user_input.text.strip_edges() if auth_user_input != null else "")])
	return auth_http.request(
		url,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		str(host.get("_auth_login_payload"))
	)

func auth_request_profile(host: Control) -> void:
	var auth_http := host.get("_auth_http") as HTTPRequest
	var auth_token := str(host.get("_auth_token")).strip_edges()
	if auth_http == null or auth_token.is_empty():
		return
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
		if auth_status_label != null:
			auth_status_label.text = "Profile request failed (%s)" % str(err)
		var auth_login_button := host.get("_auth_login_button") as Button
		if auth_login_button != null:
			auth_login_button.disabled = false

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
		host.set("_auth_api_base_url", api_base)
		auth_rebuild_login_base_candidates(host)
	return true

func auth_save_runtime_session(host: Control) -> void:
	_runtime_session_token = str(host.get("_auth_token")).strip_edges()
	_runtime_session_username = str(host.get("player_username")).strip_edges()
	_runtime_session_api_base_url = str(host.get("_auth_api_base_url")).strip_edges()

func auth_restore_persisted_session(host: Control) -> bool:
	if auth_restore_runtime_session(host):
		return true
	if not FileAccess.file_exists(AUTH_SESSION_PATH):
		return false
	var file := FileAccess.open(AUTH_SESSION_PATH, FileAccess.READ)
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
	_runtime_session_api_base_url = str(payload.get("api_base_url", "")).strip_edges()
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
	var file := FileAccess.open(AUTH_SESSION_PATH, FileAccess.WRITE)
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
	if FileAccess.file_exists(AUTH_SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(AUTH_SESSION_PATH))

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
