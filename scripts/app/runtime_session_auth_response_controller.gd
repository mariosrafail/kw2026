extends RefCounted


func on_auth_request_completed(host: Node, result: int, response_code: int, body: PackedByteArray) -> void:
	var action: String = str(host.get("_auth_pending_action"))
	var wallet_before_coins: int = int(host.get("wallet_coins"))
	var wallet_before_clk: int = int(host.get("wallet_clk"))
	host.set("_auth_inflight", false)
	host.set("_auth_pending_action", "")
	host.call("_set_loading", false)

	var text: String = body.get_string_from_utf8()
	var trimmed_text: String = text.strip_edges()
	var payload: Dictionary = {}
	if trimmed_text.begins_with("{") or trimmed_text.begins_with("["):
		var parsed: Variant = JSON.parse_string(trimmed_text)
		if parsed is Dictionary:
			payload = parsed as Dictionary

	var detail: String = str(payload.get("detail", "")).strip_edges()
	if detail.is_empty() and response_code == 0:
		detail = "no response (result=%d; auth API offline/unreachable?)" % result
	if detail.is_empty() and not trimmed_text.is_empty() and trimmed_text.length() <= 200:
		detail = trimmed_text
	if detail.is_empty():
		detail = "HTTP %d" % response_code
	if action == "profile" or action == "purchase_skin":
		host.call("_append_log", "[AUTH][%s] response code=%d user=%s detail=%s" % [action, response_code, str(host.get("auth_username")), detail])

	if action == "logout":
		host.set("_auth_logout_token", "")
		return

	if response_code < 200 or response_code >= 300:
		if bool(host.get("_dev_auto_login_active")) and action == "login" and (response_code == 401 or response_code == 404):
			var login_username: String = str(host.call("_auth_input_username"))
			host.call("_append_log", "[AUTH] Auto-login failed, trying auto-register for %s" % login_username)
			host.call("_auth_submit_credentials", "register", login_username, str(host.get("dev_auto_login_password")))
			return
		if bool(host.get("_dev_auto_login_active")) and action == "register" and response_code == 409 and not str(host.get("dev_auto_login_username")).strip_edges().is_empty():
			var fixed_username: String = str(host.call("_auth_input_username"))
			host.call("_append_log", "[AUTH] Auto-register conflict, retrying login for %s" % fixed_username)
			host.call("_auth_submit_credentials", "login", fixed_username, str(host.get("dev_auto_login_password")))
			return
		if bool(host.get("_dev_auto_login_active")) and action == "register" and response_code == 409 and int(host.get("_dev_auto_login_attempts")) < maxi(1, int(host.get("dev_auto_login_max_attempts"))):
			host.call("_append_log", "[AUTH] Auto-register conflict, retrying with a different username.")
			host.set("_dev_auto_login_active", false)
			host.call("_try_dev_auto_login_if_needed")
			return
		if bool(host.get("_dev_auto_login_active")):
			host.set("_dev_auto_login_active", false)
		if action == "profile":
			# Don't block login if the server is on an older version without /profile yet.
			host.call("_set_wallet", 9999, 9999)
			var owned_skins_by_character: Dictionary = host.get("owned_skins_by_character") as Dictionary
			owned_skins_by_character.clear()
			var starter: PackedInt32Array = PackedInt32Array([1])
			owned_skins_by_character["outrage"] = starter
			host.set("owned_skins_by_character", owned_skins_by_character)
			host.call("_update_wallet_label")
			host.call("_setup_skin_picker")
			host.call("_set_lobby_status", "Shop unavailable: %s (restart auth API)" % detail)
			return
		if action == "purchase_skin":
			host.set("_purchase_inflight", false)
			host.call("_set_loading", false)
			var purchase_text: Label = host.get("purchase_text") as Label
			if purchase_text != null:
				purchase_text.text = "%s\n\nFailed: %s" % [str(host.get("_purchase_pending_skin_name")), detail]
			var purchase_buy_button: Button = host.get("purchase_buy_button") as Button
			if purchase_buy_button != null:
				purchase_buy_button.disabled = false
			return
		host.call("_show_auth_panel", true)
		host.call("_set_auth_status", "Auth failed: %s" % detail)
		host.call("_set_auth_buttons_enabled", true)
		return

	if action == "profile":
		host.call("_apply_profile_payload", payload)
		host.call("_append_log", "[AUTH][profile] wallet %d/%d -> %d/%d" % [
			wallet_before_coins,
			wallet_before_clk,
			int(host.get("wallet_coins")),
			int(host.get("wallet_clk"))
		])
		return

	if action == "purchase_skin":
		host.set("_purchase_inflight", false)
		var pending_character_id: String = str(host.get("_purchase_pending_character_id"))
		var pending_skin_index: int = int(host.get("_purchase_pending_skin_index"))
		if not pending_character_id.is_empty() and pending_skin_index > 0:
			host.call("_persist_local_skin_selection", pending_character_id, pending_skin_index)
		host.call("_apply_profile_payload", payload)
		host.call("_append_log", "[AUTH][purchase_skin] user=%s char=%s skin=%d wallet %d/%d -> %d/%d" % [
			str(host.get("auth_username")),
			pending_character_id,
			pending_skin_index,
			wallet_before_coins,
			wallet_before_clk,
			int(host.get("wallet_coins")),
			int(host.get("wallet_clk"))
		])
		host.call("_api_profile")
		host.call("_show_purchase_menu", false)
		host.call("_set_lobby_status", "Purchased: %s" % str(host.get("_purchase_pending_skin_name")))
		if pending_character_id == "outrage" and pending_skin_index > 0 and bool(host.call("_is_client_connected")):
			host.rpc_id(1, "_rpc_lobby_set_skin", pending_skin_index)
		host.set("_purchase_pending_character_id", "")
		host.set("_purchase_pending_skin_index", 0)
		host.set("_purchase_pending_skin_name", "")
		return

	if action == "me":
		var username: String = str(payload.get("username", "")).strip_edges()
		if username.is_empty():
			host.call("_show_auth_panel", true)
			host.call("_set_auth_status", "Auth failed: invalid session")
			host.call("_clear_auth_session")
			host.call("_set_auth_buttons_enabled", true)
			return
		host.set("auth_username", username)
		host.call("_load_account_loadout")
		host.call("_show_auth_panel", false)
		host.call("_set_auth_status", "")
		host.call("_set_auth_buttons_enabled", true)
		host.call("_after_auth_success")
		return

	var token: String = str(payload.get("token", "")).strip_edges()
	var username2: String = str(payload.get("username", "")).strip_edges()
	if token.is_empty() or username2.is_empty():
		host.call("_show_auth_panel", true)
		host.call("_set_auth_status", "Auth failed: invalid response")
		return

	host.set("auth_token", token)
	host.set("auth_username", username2)
	host.call("_save_auth_session")
	host.call("_load_account_loadout")
	host.call("_show_auth_panel", false)
	host.call("_set_auth_status", "")
	host.call("_set_auth_buttons_enabled", true)
	host.set("_dev_auto_login_active", false)
	host.call("_after_auth_success")
