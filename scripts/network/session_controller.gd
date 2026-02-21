extends RefCounted
class_name SessionController

var multiplayer: MultiplayerAPI
var status_label: Label
var host_input: LineEdit
var port_spin: SpinBox
var connect_retry: ConnectRetry

var default_host := ""
var max_clients := 8
var role_none := 0
var role_server := 1
var role_client := 2
var startup_mode := 0
var auto_start_enabled := true
var is_editor := false
var first_private_ipv4 := ""
var lobby_scene_mode_for_boot := false

var arg_mode_prefix := "--mode="
var arg_host_prefix := "--host="
var arg_port_prefix := "--port="
var arg_no_autostart := "--no-autostart"

var get_role_cb: Callable = Callable()
var set_role_cb: Callable = Callable()
var reset_runtime_state_cb: Callable = Callable()
var reset_ping_state_cb: Callable = Callable()
var reset_spawn_request_state_cb: Callable = Callable()
var set_client_lobby_id_cb: Callable = Callable()
var set_lobby_auto_action_inflight_cb: Callable = Callable()
var clear_lobby_list_cb: Callable = Callable()
var set_lobby_status_cb: Callable = Callable()
var update_peer_labels_cb: Callable = Callable()
var update_buttons_cb: Callable = Callable()
var update_ping_label_cb: Callable = Callable()
var update_ui_visibility_cb: Callable = Callable()
var append_log_cb: Callable = Callable()
var request_lobby_list_cb: Callable = Callable()
var retry_callback_generation := 0

func configure(refs: Dictionary, callbacks: Dictionary, config: Dictionary = {}) -> void:
	multiplayer = refs.get("multiplayer", null) as MultiplayerAPI
	status_label = refs.get("status_label", null) as Label
	host_input = refs.get("host_input", null) as LineEdit
	port_spin = refs.get("port_spin", null) as SpinBox
	connect_retry = refs.get("connect_retry", null) as ConnectRetry

	get_role_cb = callbacks.get("get_role", Callable()) as Callable
	set_role_cb = callbacks.get("set_role", Callable()) as Callable
	reset_runtime_state_cb = callbacks.get("reset_runtime_state", Callable()) as Callable
	reset_ping_state_cb = callbacks.get("reset_ping_state", Callable()) as Callable
	reset_spawn_request_state_cb = callbacks.get("reset_spawn_request_state", Callable()) as Callable
	set_client_lobby_id_cb = callbacks.get("set_client_lobby_id", Callable()) as Callable
	set_lobby_auto_action_inflight_cb = callbacks.get("set_lobby_auto_action_inflight", Callable()) as Callable
	clear_lobby_list_cb = callbacks.get("clear_lobby_list", Callable()) as Callable
	set_lobby_status_cb = callbacks.get("set_lobby_status", Callable()) as Callable
	update_peer_labels_cb = callbacks.get("update_peer_labels", Callable()) as Callable
	update_buttons_cb = callbacks.get("update_buttons", Callable()) as Callable
	update_ping_label_cb = callbacks.get("update_ping_label", Callable()) as Callable
	update_ui_visibility_cb = callbacks.get("update_ui_visibility", Callable()) as Callable
	append_log_cb = callbacks.get("append_log", Callable()) as Callable
	request_lobby_list_cb = callbacks.get("request_lobby_list", Callable()) as Callable

	default_host = str(config.get("default_host", default_host))
	max_clients = int(config.get("max_clients", max_clients))
	role_none = int(config.get("role_none", role_none))
	role_server = int(config.get("role_server", role_server))
	role_client = int(config.get("role_client", role_client))
	arg_mode_prefix = str(config.get("arg_mode_prefix", arg_mode_prefix))
	arg_host_prefix = str(config.get("arg_host_prefix", arg_host_prefix))
	arg_port_prefix = str(config.get("arg_port_prefix", arg_port_prefix))
	arg_no_autostart = str(config.get("arg_no_autostart", arg_no_autostart))
	is_editor = bool(config.get("is_editor", is_editor))
	first_private_ipv4 = str(config.get("first_private_ipv4", first_private_ipv4))
	lobby_scene_mode_for_boot = bool(config.get("lobby_scene_mode", lobby_scene_mode_for_boot))

func set_startup(mode: int, auto_start: bool) -> void:
	startup_mode = mode
	auto_start_enabled = auto_start

func set_connection_defaults(host: String) -> void:
	var normalized_host := host.strip_edges()
	if normalized_host.is_empty():
		return
	default_host = normalized_host

func get_startup_mode() -> int:
	return startup_mode

func is_auto_start_enabled() -> bool:
	return auto_start_enabled

func apply_startup_overrides() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with(arg_mode_prefix):
			var mode_value := arg.substr(arg_mode_prefix.length()).to_lower()
			match mode_value:
				"server":
					startup_mode = role_server
				"client":
					startup_mode = role_client
				"manual":
					startup_mode = role_none
					auto_start_enabled = false
		elif arg.begins_with(arg_host_prefix):
			var host_value := arg.substr(arg_host_prefix.length()).strip_edges()
			if host_input != null and not host_value.is_empty():
				host_input.text = host_value
		elif arg.begins_with(arg_port_prefix):
			var port_value := int(arg.substr(arg_port_prefix.length()))
			if port_spin != null and port_value >= 1 and port_value <= 65535:
				port_spin.value = port_value
		elif arg == arg_no_autostart:
			auto_start_enabled = false

func apply_editor_localhost_override() -> void:
	if not is_editor:
		return
	if host_input == null:
		return
	if startup_mode == role_server:
		return
	if host_input.text != default_host:
		return
	host_input.text = "127.0.0.1"
	_append_log("Editor run detected: using localhost server (127.0.0.1).")

func configure_retry_hosts() -> void:
	if connect_retry == null or host_input == null:
		return
	# In editor, allow automatic fallback to localhost/private IP if the chosen host hangs (common when using a public IP on the same LAN).
	var include_editor_fallback := is_editor
	connect_retry.configure(host_input.text, include_editor_fallback, first_private_ipv4, default_host)

func start_server(port: int) -> void:
	close_peer()
	if multiplayer == null:
		return

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_clients)
	if err != OK:
		_append_log("Server error: %s" % error_string(err))
		_append_log("Tip: port %d may already be in use (for example by Docker server)." % port)
		return

	multiplayer.multiplayer_peer = peer
	_set_role(role_server)
	_reset_runtime_state()
	if status_label != null:
		status_label.text = "Status: Server running on port %d" % port
	_append_log("Server started on port %d." % port)
	_refresh_ui()

func start_client(host: String, port: int, reset_attempt_chain: bool = true, lobby_scene_mode: bool = false) -> void:
	close_peer()
	if multiplayer == null:
		return
	if host.is_empty():
		host = default_host
	if connect_retry != null:
		var include_editor_fallback := is_editor and not lobby_scene_mode
		if reset_attempt_chain:
			connect_retry.configure(host, include_editor_fallback, first_private_ipv4, default_host)
		else:
			connect_retry.set_current_host(host)
		connect_retry.reset_timer()

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(host, port)
	if err != OK:
		_append_log("Client error: %s" % error_string(err))
		return

	multiplayer.multiplayer_peer = peer
	_set_role(role_client)
	_reset_runtime_state()
	if lobby_scene_mode:
		_set_lobby_status("Connecting to server...")
	if status_label != null:
		status_label.text = "Status: Connecting to %s:%d..." % [host, port]
	_append_log("Connecting to %s:%d ..." % [host, port])
	_refresh_ui()

func stop_server() -> void:
	close_peer()
	set_idle_state()
	_append_log("Server stopped.")

func disconnect_client() -> void:
	close_peer()
	set_idle_state()
	_append_log("Disconnected.")

func on_connected_to_server() -> void:
	if status_label != null:
		status_label.text = "Status: Connected to server."
	_append_log("Connected to server. Requesting lobbies.")
	_reset_ping_state()
	_reset_spawn_request_state()
	_update_ping_label()
	_set_client_lobby_id(0)
	_set_lobby_auto_action_inflight(false)
	_clear_lobby_list()
	_set_lobby_status("Connected. Choose or create lobby.")
	if request_lobby_list_cb.is_valid():
		request_lobby_list_cb.call()
	_refresh_ui()

func on_connection_failed(tree: SceneTree, lobby_scene_mode: bool) -> void:
	close_peer()
	set_idle_state()
	_append_log("Connection failed.")
	if not lobby_scene_mode:
		return

	var retry_host := ""
	if connect_retry != null:
		retry_host = connect_retry.advance_to_next_host()
	if retry_host.is_empty():
		retry_host = host_input.text.strip_edges() if host_input != null else default_host
		_set_lobby_status("Connection failed. Retrying...")
	else:
		if host_input != null:
			host_input.text = retry_host
		_set_lobby_status("Connection failed. Trying %s..." % retry_host)
		_append_log("Connection retry target: %s" % retry_host)

	if tree == null:
		return
	retry_callback_generation += 1
	var callback_generation := retry_callback_generation
	var retry_timer := tree.create_timer(0.9)
	retry_timer.timeout.connect(Callable(self, "_on_retry_timer_timeout").bind(callback_generation, retry_host, lobby_scene_mode))

func on_server_disconnected() -> void:
	close_peer()
	set_idle_state()
	_append_log("Server disconnected.")

func set_idle_state() -> void:
	_set_role(role_none)
	if status_label != null:
		status_label.text = "Status: Idle"
	_set_client_lobby_id(0)
	_set_lobby_auto_action_inflight(false)
	_reset_ping_state()
	_reset_spawn_request_state()
	_clear_lobby_list()
	_set_lobby_status("Connect to server.")
	_refresh_ui()

func close_peer() -> void:
	retry_callback_generation += 1
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_reset_runtime_state()

func _on_retry_timer_timeout(callback_generation: int, retry_host: String, lobby_scene_mode: bool) -> void:
	if callback_generation != retry_callback_generation:
		return
	if _role() != role_none:
		return
	var target_port := int(port_spin.value) if port_spin != null else 0
	start_client(retry_host, target_port, false, lobby_scene_mode)

func auto_boot_from_environment() -> void:
	if not auto_start_enabled:
		_append_log("Autostart disabled. Use Start/Connect manually.")
		return
	if startup_mode == role_server:
		_append_log("Autostart: server mode.")
		start_server(_port_value())
	elif startup_mode == role_client:
		_append_log("Autostart: client mode.")
		start_client(_host_value(), _port_value(), true, lobby_scene_mode_for_boot)
	else:
		_append_log("Manual startup mode.")

func client_connect_watchdog_tick(delta: float) -> void:
	if _role() != role_client:
		_reset_retry_timer()
		return
	if multiplayer == null or multiplayer.multiplayer_peer == null:
		_reset_retry_timer()
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTING:
		_reset_retry_timer()
		return
	if connect_retry == null:
		return
	if not connect_retry.tick(delta):
		return

	var current_host := connect_retry.current_host()
	if current_host.is_empty():
		current_host = _host_value()
	var next_host := connect_retry.advance_to_next_host()
	if next_host.is_empty():
		return

	_append_log("Connect timeout on %s:%d, trying %s..." % [current_host, _port_value(), next_host])
	if host_input != null:
		host_input.text = next_host
	start_client(next_host, _port_value(), false, lobby_scene_mode_for_boot)

func _refresh_ui() -> void:
	_update_peer_labels()
	_update_buttons()
	_update_ping_label()
	_update_ui_visibility()

func _role() -> int:
	if get_role_cb.is_valid():
		return int(get_role_cb.call())
	return role_none

func _set_role(value: int) -> void:
	if set_role_cb.is_valid():
		set_role_cb.call(value)

func _set_client_lobby_id(value: int) -> void:
	if set_client_lobby_id_cb.is_valid():
		set_client_lobby_id_cb.call(value)

func _set_lobby_auto_action_inflight(value: bool) -> void:
	if set_lobby_auto_action_inflight_cb.is_valid():
		set_lobby_auto_action_inflight_cb.call(value)

func _reset_runtime_state() -> void:
	if reset_runtime_state_cb.is_valid():
		reset_runtime_state_cb.call()

func _reset_ping_state() -> void:
	if reset_ping_state_cb.is_valid():
		reset_ping_state_cb.call()

func _reset_spawn_request_state() -> void:
	if reset_spawn_request_state_cb.is_valid():
		reset_spawn_request_state_cb.call()

func _clear_lobby_list() -> void:
	if clear_lobby_list_cb.is_valid():
		clear_lobby_list_cb.call()

func _set_lobby_status(text: String) -> void:
	if set_lobby_status_cb.is_valid():
		set_lobby_status_cb.call(text)

func _update_peer_labels() -> void:
	if update_peer_labels_cb.is_valid():
		update_peer_labels_cb.call()

func _update_buttons() -> void:
	if update_buttons_cb.is_valid():
		update_buttons_cb.call()

func _update_ping_label() -> void:
	if update_ping_label_cb.is_valid():
		update_ping_label_cb.call()

func _update_ui_visibility() -> void:
	if update_ui_visibility_cb.is_valid():
		update_ui_visibility_cb.call()

func _append_log(message: String) -> void:
	if append_log_cb.is_valid():
		append_log_cb.call(message)

func _host_value() -> String:
	if host_input == null:
		return default_host
	return host_input.text.strip_edges()

func _port_value() -> int:
	if port_spin == null:
		return 0
	return int(port_spin.value)

func _reset_retry_timer() -> void:
	if connect_retry != null:
		connect_retry.reset_timer()
