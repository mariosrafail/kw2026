extends RefCounted
class_name RuntimeAuthFlow

const AUTH_SESSION_PATH := "user://auth_session.json"
const MAIN_MENU_AUTH_SESSION_PATH := "user://main_menu_auth_session.json"
const AUTH_API_BASE_URL_SETTING := "kw/auth_api_base_url"
const AUTH_PROFILE_SETTING := "kw/auth_profile"
const AUTH_PROFILE_ARG_PREFIX := "--auth-profile="
const DEFAULT_AUTH_USERNAME := "mario"
const DEFAULT_AUTH_PASSWORD := "1234"
const ACCOUNT_LOADOUT_PATH_PREFIX := "user://account_loadout"

func setup_auth_flow(host: Node) -> void:
	host.call("_resolve_auth_profile")
	host.call("_ensure_auth_request_node")
	if host.get("auth_panel") != null:
		configure_auth_ui_for_login_only(host)

	var session_path := session_path(host)
	host.call("_append_log", "[AUTH] profile=%s session file: %s (exists=%s)" % [
		str(host.get("_auth_profile")),
		ProjectSettings.globalize_path(session_path),
		str(FileAccess.file_exists(session_path))
	])
	load_auth_session(host)
	var auth_username_input := host.get("auth_username_input") as LineEdit
	if auth_username_input != null:
		auth_username_input.text = DEFAULT_AUTH_USERNAME
	var auth_password_input := host.get("auth_password_input") as LineEdit
	if auth_password_input != null:
		auth_password_input.text = DEFAULT_AUTH_PASSWORD

	if bool(host.get("auth_require_login_on_startup")):
		if not str(host.get("auth_token")).strip_edges().is_empty():
			host.call("_append_log", "[AUTH] Startup requires login. Ignoring stored session token.")
		host.set("auth_token", "")
		show_auth_panel(host, true)
		set_auth_status(host, "Auth: login required")
		set_auth_buttons_enabled(host, true)
		return

	if str(host.get("auth_token")).strip_edges().is_empty():
		if bool(host.call("_try_dev_auto_login_if_needed")):
			return
		show_auth_panel(host, true)
		set_auth_status(host, "Auth: login required")
		set_auth_buttons_enabled(host, true)
		return
	auth_me(host)

func configure_auth_ui_for_login_only(host: Node) -> void:
	var auth_register_button := host.get("auth_register_button") as Button
	if auth_register_button != null:
		auth_register_button.visible = false
		auth_register_button.disabled = true
	var auth_login_button := host.get("auth_login_button") as Button
	if auth_login_button != null:
		auth_login_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func ensure_auth_request_node(host: Node) -> void:
	if host.get("auth_request") != null:
		return
	var auth_request := HTTPRequest.new()
	auth_request.name = "AuthRequestRuntime"
	host.add_child(auth_request)
	host.set("auth_request", auth_request)
	var completed_cb := Callable(host, "_on_auth_request_completed")
	if not auth_request.request_completed.is_connected(completed_cb):
		auth_request.request_completed.connect(completed_cb)

func show_auth_panel(host: Node, visible: bool) -> void:
	var auth_panel := host.get("auth_panel") as Control
	if auth_panel != null:
		auth_panel.visible = visible

func set_auth_status(host: Node, text: String) -> void:
	var auth_status_label := host.get("auth_status_label") as Label
	if auth_status_label != null:
		auth_status_label.text = text

func set_auth_buttons_enabled(host: Node, enabled: bool) -> void:
	var auth_login_button := host.get("auth_login_button") as Button
	if auth_login_button != null:
		auth_login_button.disabled = not enabled
	var auth_register_button := host.get("auth_register_button") as Button
	if auth_register_button != null:
		auth_register_button.disabled = true

func auth_logout_best_effort(host: Node) -> void:
	var auth_request := host.get("auth_request") as HTTPRequest
	if auth_request == null:
		return
	var token := str(host.get("auth_token")).strip_edges()
	if token.is_empty():
		return
	if bool(host.get("_auth_inflight")):
		return
	host.set("_auth_inflight", true)
	host.set("_auth_pending_action", "logout")
	host.set("_auth_logout_token", token)
	var url := "%s/logout" % auth_api_base_url(host)
	var headers := PackedStringArray(["Authorization: Bearer %s" % token])
	var err := auth_request.request(url, headers, HTTPClient.METHOD_POST, "")
	if err != OK:
		host.set("_auth_inflight", false)
		host.set("_auth_pending_action", "")
		host.set("_auth_logout_token", "")

func auth_api_base_url(host: Node) -> String:
	var configured := str(ProjectSettings.get_setting(AUTH_API_BASE_URL_SETTING, "http://updates.outrage.ink:8081/auth")).strip_edges()
	if configured.is_empty():
		configured = "http://updates.outrage.ink:8081/auth"
	return configured.trim_suffix("/")

func load_auth_session(host: Node) -> void:
	var path := session_path(host)
	if not FileAccess.file_exists(path):
		var main_menu_path := _main_menu_session_path(host)
		if FileAccess.file_exists(main_menu_path):
			path = main_menu_path
		else:
			host.set("auth_token", "")
			host.set("auth_username", "")
			return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var payload := parsed as Dictionary
	host.set("auth_token", str(payload.get("token", "")).strip_edges())
	host.set("auth_username", str(payload.get("username", "")).strip_edges())

func save_auth_session(host: Node) -> void:
	var payload := {
		"token": host.get("auth_token"),
		"username": host.get("auth_username"),
	}
	var file := FileAccess.open(session_path(host), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(payload))

func clear_auth_session(host: Node) -> void:
	host.set("auth_token", "")
	host.set("auth_username", "")
	var path := session_path(host)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func save_account_loadout(host: Node) -> void:
	var path := account_loadout_path(host)
	if path.is_empty():
		return
	var selected_weapon_id := str(host.get("selected_weapon_id")).strip_edges().to_lower()
	if selected_weapon_id.is_empty():
		selected_weapon_id = "ak47"
	var selected_character_id := str(host.call("_normalize_character_id", str(host.get("selected_character_id"))))
	var lobby_service: Object = host.get("lobby_service") as Object
	var selected_skin_index := 0
	if lobby_service != null:
		selected_skin_index = int(lobby_service.call("get_local_selected_skin", selected_character_id, 0))
	var payload := {
		"selected_weapon_id": selected_weapon_id,
		"selected_weapon_skin": maxi(0, int(host.get("selected_weapon_skin"))),
		"selected_character_id": selected_character_id,
		"selected_skin_index": maxi(0, selected_skin_index)
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		host.call("_append_log", "[AUTH] Failed to write account loadout: %s" % ProjectSettings.globalize_path(path))
		return
	file.store_string(JSON.stringify(payload))

func load_account_loadout(host: Node) -> void:
	var path := account_loadout_path(host)
	if path.is_empty() or not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Dictionary):
		return
	var payload := parsed as Dictionary
	var selected_weapon_id := str(payload.get("selected_weapon_id", host.get("selected_weapon_id"))).strip_edges().to_lower()
	if selected_weapon_id.is_empty():
		selected_weapon_id = "ak47"
	var selected_character_id := str(host.call("_normalize_character_id", str(payload.get("selected_character_id", host.get("selected_character_id")))))
	var selected_weapon_skin := maxi(0, int(payload.get("selected_weapon_skin", host.get("selected_weapon_skin"))))
	var selected_skin_index := maxi(0, int(payload.get("selected_skin_index", 0)))
	host.set("selected_weapon_id", selected_weapon_id)
	host.set("selected_weapon_skin", selected_weapon_skin)
	host.set("selected_character_id", selected_character_id)
	var lobby_service: Object = host.get("lobby_service") as Object
	if lobby_service != null:
		lobby_service.call("set_local_selected_weapon", selected_weapon_id)
		lobby_service.call("set_local_selected_weapon_skin", selected_weapon_id, selected_weapon_skin)
		lobby_service.call("set_local_selected_character", selected_character_id)
		lobby_service.call("set_local_selected_skin", selected_character_id, selected_skin_index)
	host.call("_setup_weapon_picker")
	host.call("_setup_character_picker")

func resolve_auth_profile(host: Node) -> void:
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

func session_path(host: Node) -> String:
	if str(host.get("_auth_profile")) == "default":
		return AUTH_SESSION_PATH
	return "user://auth_session_%s.json" % str(host.get("_auth_profile"))

func _main_menu_session_path(host: Node) -> String:
	if str(host.get("_auth_profile")) == "default":
		return MAIN_MENU_AUTH_SESSION_PATH
	return "user://main_menu_auth_session_%s.json" % str(host.get("_auth_profile"))

func account_loadout_path(host: Node) -> String:
	var username := str(host.get("auth_username")).strip_edges().to_lower()
	if username.is_empty():
		return ""
	var profile := str(host.get("_auth_profile")).strip_edges().to_lower()
	if profile.is_empty():
		profile = "default"
	return "%s_%s_%s.json" % [
		ACCOUNT_LOADOUT_PATH_PREFIX,
		_sanitize_path_fragment(profile),
		_sanitize_path_fragment(username)
	]

func _sanitize_path_fragment(value: String) -> String:
	var trimmed := value.strip_edges().to_lower()
	if trimmed.is_empty():
		return "default"
	var result := ""
	for i in range(trimmed.length()):
		var ch := trimmed.unicode_at(i)
		var is_digit := ch >= 48 and ch <= 57
		var is_lower := ch >= 97 and ch <= 122
		if is_digit or is_lower:
			result += char(ch)
		else:
			result += "_"
	return result

func auth_me(host: Node) -> void:
	if bool(host.get("_auth_inflight")):
		return
	var auth_request := host.get("auth_request") as HTTPRequest
	if auth_request == null:
		show_auth_panel(host, true)
		set_auth_status(host, "Auth error: missing HTTPRequest")
		return
	host.set("_auth_inflight", true)
	host.set("_auth_pending_action", "me")
	set_auth_status(host, "Auth: checking session...")
	host.call("_set_loading", true, "LOADING...")
	var url := "%s/me" % auth_api_base_url(host)
	var headers := PackedStringArray()
	if not str(host.get("auth_token")).strip_edges().is_empty():
		headers.append("Authorization: Bearer %s" % str(host.get("auth_token")))
	var err := auth_request.request(url, headers, HTTPClient.METHOD_GET)
	if err != OK:
		host.set("_auth_inflight", false)
		host.set("_auth_pending_action", "")
		show_auth_panel(host, true)
		set_auth_status(host, "Auth error: request failed (%s)" % error_string(err))
		host.call("_set_loading", false)

func auth_submit(host: Node, action: String) -> void:
	if bool(host.get("_auth_inflight")):
		return
	if host.get("auth_request") == null:
		set_auth_status(host, "Auth error: missing HTTPRequest")
		return
	var auth_username_input := host.get("auth_username_input") as LineEdit
	var auth_password_input := host.get("auth_password_input") as LineEdit
	if auth_username_input == null or auth_password_input == null:
		set_auth_status(host, "Auth error: missing UI")
		return
	var username := auth_username_input.text.strip_edges()
	var password := auth_password_input.text
	if username.is_empty() or password.is_empty():
		set_auth_status(host, "Auth: enter username + password")
		return
	auth_submit_credentials(host, action, username, password)

func auth_submit_credentials(host: Node, action: String, username: String, password: String) -> void:
	if bool(host.get("_auth_inflight")):
		return
	var auth_request := host.get("auth_request") as HTTPRequest
	if auth_request == null:
		set_auth_status(host, "Auth error: missing HTTPRequest")
		return
	if username.strip_edges().is_empty() or password.is_empty():
		set_auth_status(host, "Auth: enter username + password")
		return
	host.set("_auth_inflight", true)
	host.set("_auth_pending_action", action)
	set_auth_status(host, "Auth: %s..." % action)
	host.call("_set_loading", true, "LOADING...")
	var url := "%s/%s" % [auth_api_base_url(host), action]
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := JSON.stringify({"username": username.strip_edges(), "password": password})
	var err := auth_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		host.set("_auth_inflight", false)
		host.set("_auth_pending_action", "")
		set_auth_status(host, "Auth error: request failed (%s)" % error_string(err))
		host.call("_set_loading", false)

func auth_input_username(host: Node) -> String:
	var auth_username_input := host.get("auth_username_input") as LineEdit
	if auth_username_input != null:
		return auth_username_input.text.strip_edges()
	if not str(host.get("auth_username")).strip_edges().is_empty():
		return str(host.get("auth_username")).strip_edges()
	return str(host.get("dev_auto_login_username")).strip_edges()
