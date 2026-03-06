extends RefCounted
class_name TestMenuAuthFlow

const AUTH_SESSION_PATH := "user://test_menu_auth_session.json"

static var _runtime_session_token := ""
static var _runtime_session_username := ""
static var _runtime_session_api_base_url := ""

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
	var base_variants := PackedStringArray([str(host.get("_auth_api_base_url"))])
	var without_auth := auth_trim_suffix(str(host.get("_auth_api_base_url")), "/auth")
	if without_auth != str(host.get("_auth_api_base_url")):
		base_variants.append(without_auth)

	var candidates := PackedStringArray()
	for base in base_variants:
		candidates.append(base)
		candidates.append(auth_build_base_url_with_port(base, 8080))
		candidates.append(auth_build_base_url_with_port(base, 8081))
		candidates.append(auth_build_base_url_with_port(base, 8090))

	for candidate in candidates:
		var normalized := str(candidate).strip_edges()
		if normalized.is_empty() or result.has(normalized):
			continue
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
