extends RefCounted

const DEFAULT_AUTH_USERNAME := "mario"
const DEFAULT_AUTH_PASSWORD := "1234"

func try_dev_auto_login_if_needed(host: Node) -> bool:
	if not bool(host.get("dev_auto_login_on_autostart")):
		return false
	var auth_request: HTTPRequest = host.get("auth_request") as HTTPRequest
	if auth_request == null:
		return false
	if bool(host.get("_auth_inflight")):
		return false

	var max_attempts: int = maxi(1, int(host.get("dev_auto_login_max_attempts")))
	var attempts: int = int(host.get("_dev_auto_login_attempts"))
	if attempts >= max_attempts:
		return false

	host.set("_dev_auto_login_active", true)
	host.set("_dev_auto_login_attempts", attempts + 1)

	var username: String = str(host.get("dev_auto_login_username")).strip_edges()
	if username.is_empty():
		var suffix: String = "%06d" % int(randi() % 1000000)
		username = ("auto_%s" % suffix).strip_edges()

	var password: String = str(host.get("dev_auto_login_password"))
	if password.length() < 4:
		password = "test"

	var auth_username_input: LineEdit = host.get("auth_username_input") as LineEdit
	if auth_username_input != null:
		auth_username_input.text = username
	var auth_password_input: LineEdit = host.get("auth_password_input") as LineEdit
	if auth_password_input != null:
		auth_password_input.text = password

	show_auth_panel(host, true)
	host.call("_set_auth_status", "Auth: auto-login %s..." % username)
	host.call("_set_auth_buttons_enabled", false)
	host.call_deferred("_auth_submit_credentials", "login", username, password)
	return true

func show_auth_panel(host: Node, show: bool) -> void:
	var runtime_auth_flow: Object = host.get("_runtime_auth_flow") as Object
	if runtime_auth_flow != null:
		runtime_auth_flow.call("show_auth_panel", host, show)
	var lobby_panel: Control = host.get("lobby_panel") as Control
	if lobby_panel != null:
		lobby_panel.visible = not show
	host.call("_show_esc_menu", false)
	host.call("_show_purchase_menu", false)
	if show:
		host.call("_set_loading", false)

func logout_to_login(host: Node) -> void:
	if bool(host.call("_is_client_connected")):
		var session_controller: Object = host.get("session_controller") as Object
		if session_controller != null:
			session_controller.call("disconnect_client")
	host.call("_auth_logout_best_effort")
	host.call("_clear_auth_session")
	host.call("_set_wallet", 0, 0)

	var owned: Dictionary = host.get("owned_skins_by_character") as Dictionary
	owned.clear()
	host.set("owned_skins_by_character", owned)

	var auth_username_input: LineEdit = host.get("auth_username_input") as LineEdit
	if auth_username_input != null:
		auth_username_input.text = DEFAULT_AUTH_USERNAME
	var auth_password_input: LineEdit = host.get("auth_password_input") as LineEdit
	if auth_password_input != null:
		auth_password_input.text = DEFAULT_AUTH_PASSWORD

	var lobby_service: Object = host.get("lobby_service") as Object
	var multiplayer_api: MultiplayerAPI = host.get("multiplayer") as MultiplayerAPI
	if lobby_service != null and multiplayer_api != null and multiplayer_api.multiplayer_peer != null:
		var local_peer_id: int = multiplayer_api.get_unique_id()
		if local_peer_id > 0 and lobby_service.has_method("set_peer_display_name"):
			lobby_service.call("set_peer_display_name", local_peer_id, "")

	show_auth_panel(host, true)
	host.call("_set_auth_status", "Auth: login required")
	host.call("_set_auth_buttons_enabled", true)
	host.call("_update_ui_visibility")
