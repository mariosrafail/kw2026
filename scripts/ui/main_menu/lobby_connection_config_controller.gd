extends RefCounted

class_name LobbyConnectionConfigController

const CONNECT_FALLBACK_PORTS := [8081]
const ALLOW_LOCALHOST_LOBBY_CONNECT := false

var _host: Object
var _browser_hostname_checked := false
var _browser_hostname_cached := ""

func configure(host: Object) -> void:
	_host = host
	_browser_hostname_checked = false
	_browser_hostname_cached = ""

func resolve_server_host_port_from_args(host: String = "127.0.0.1", port: int = 8080) -> Dictionary:
	var resolved_host := host.strip_edges()
	var resolved_port := clampi(port, 1, 65535)
	if resolved_host.is_empty():
		resolved_host = "127.0.0.1"
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--host="):
			resolved_host = arg.substr("--host=".length()).strip_edges()
		elif arg.begins_with("--port="):
			var parsed := int(arg.substr("--port=".length()))
			if parsed >= 1 and parsed <= 65535:
				resolved_port = parsed
	if resolved_host.is_empty():
		resolved_host = "127.0.0.1"
	return {"host": resolved_host, "port": resolved_port}

func read_launcher_config_defaults() -> Dictionary:
	var candidate_paths := PackedStringArray()
	var executable_config := OS.get_executable_path().get_base_dir().path_join("launcher_config.json")
	candidate_paths.append(executable_config)
	candidate_paths.append("res://build/release/launcher_config.json")
	candidate_paths.append("res://build/launcher/launcher_config.json")
	candidate_paths.append("res://launcher/launcher_config.json")

	for path in candidate_paths:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if not (parsed is Dictionary):
			continue
		var payload := parsed as Dictionary
		return {
			"found": true,
			"host": str(payload.get("default_host", "")).strip_edges(),
			"port": int(payload.get("default_port", 8080))
		}

	return {"found": false}

func resolve_server_host_port() -> Dictionary:
	var host := "127.0.0.1"
	var port := 8080
	var config := read_launcher_config_defaults()
	if bool(config.get("found", false)):
		var config_host := str(config.get("host", "")).strip_edges()
		var config_port := int(config.get("port", 8080))
		if not config_host.is_empty():
			host = config_host
		if config_port >= 1 and config_port <= 65535:
			port = config_port
	var runtime_host := str(ProjectSettings.get_setting("kw/default_server_host", "")).strip_edges()
	if not runtime_host.is_empty():
		host = runtime_host
	var runtime_port := int(ProjectSettings.get_setting("kw/default_server_port", 0))
	if runtime_port >= 1 and runtime_port <= 65535:
		port = runtime_port
	var resolved := resolve_server_host_port_from_args(host, port)
	if _host != null and _host.has_method("_log"):
		_host.call("_log", "resolved primary server endpoint=%s:%d config_found=%s" % [
			str(resolved.get("host", "")),
			int(resolved.get("port", 0)),
			str(bool(config.get("found", false)))
		])
	return resolved

func resolve_auth_api_host_port() -> Dictionary:
	var configured := str(ProjectSettings.get_setting("kw/auth_api_base_url", "https://play.outrage.ink/auth")).strip_edges()
	if configured.is_empty():
		return {"host": "", "port": 8080}
	var scheme_idx := configured.find("://")
	if scheme_idx >= 0:
		configured = configured.substr(scheme_idx + 3)
	var slash_idx := configured.find("/")
	if slash_idx >= 0:
		configured = configured.substr(0, slash_idx)
	var host := configured
	var port := 8080
	var colon_idx := configured.rfind(":")
	if colon_idx > 0:
		host = configured.substr(0, colon_idx)
		var parsed_port := int(configured.substr(colon_idx + 1))
		if parsed_port >= 1 and parsed_port <= 65535:
			port = parsed_port
	return {"host": host.strip_edges(), "port": port}

func build_connect_candidates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var network_mode := _selected_network_mode()
	var lan_usable := _is_lan_usable_from_owner()
	var lan_block_reason := _lan_block_reason_from_owner()
	if network_mode == "online":
		out.append({"host": "wss://play.outrage.ink/ws", "port": 443})
		_log("connect candidates forced ONLINE web=%s" % str(out))
		return out
	if not lan_usable:
		_log("connect candidates forced LAN web=[] (blocked: %s)" % lan_block_reason)
		return out

	var resolved := resolve_server_host_port()
	var lan_host := str(resolved.get("host", "")).strip_edges()
	var lan_skip := _candidate_skip_reason(lan_host, true)
	if lan_host.is_empty() or not lan_skip.is_empty():
		var local_hosts := local_connect_fallback_hosts(true)
		if not local_hosts.is_empty():
			lan_host = str(local_hosts[0]).strip_edges()
	if lan_host.is_empty():
		_log("connect candidates forced LAN web=[] (no usable LAN host)")
		return out
	var lan_port := int(resolved.get("port", 8080))
	if lan_port < 1 or lan_port > 65535:
		lan_port = 8080
	if lan_host.begins_with("ws://") or lan_host.begins_with("wss://"):
		out.append({"host": lan_host, "port": lan_port})
	else:
		out.append({"host": lan_host, "port": 8080})
	_log("connect candidates forced LAN web=%s" % str(out))
	return out

func local_connect_fallback_hosts(web_lan_mode: bool = false) -> PackedStringArray:
	var out := PackedStringArray()
	if web_lan_mode:
		var browser_host := _browser_hostname_candidate()
		if not browser_host.is_empty() and not out.has(browser_host):
			out.append(browser_host)
	else:
		out.append("127.0.0.1")
		out.append("localhost")
	for address_value in IP.get_local_addresses():
		var address := str(address_value).strip_edges()
		if address.is_empty():
			continue
		if not address.contains("."):
			continue
		var skip_reason := _candidate_skip_reason(address, web_lan_mode)
		if not skip_reason.is_empty():
			_log("skipped fallback host %s (%s)" % [address, skip_reason])
			continue
		if out.has(address):
			continue
		out.append(address)
	if web_lan_mode:
		var ranked := Array(out)
		ranked.sort_custom(Callable(self, "_compare_host_priority"))
		var has_preferred_lan := false
		for host_value in ranked:
			var host := str(host_value).strip_edges().to_lower()
			if host.begins_with("192.168.") or host.begins_with("10."):
				has_preferred_lan = true
				break
		var sorted_out := PackedStringArray()
		for host_value in ranked:
			var host := str(host_value).strip_edges()
			if has_preferred_lan and _is_private_172_host(host.to_lower()):
				_log("skipped fallback host %s (private 172 deprioritized by preferred LAN IP)" % host)
				continue
			sorted_out.append(host)
		out = sorted_out
	return out

func _selected_network_mode() -> String:
	var network_mode := ""
	if _host == null:
		return network_mode
	var owner := _host.get("_host") as Control
	if owner != null and owner.has_meta("kw_network_mode"):
		network_mode = str(owner.get_meta("kw_network_mode")).strip_edges().to_lower()
	return network_mode

func _is_lan_usable_from_owner() -> bool:
	if _host == null:
		return true
	var owner := _host.get("_host") as Control
	if owner == null:
		return true
	return bool(owner.get_meta("kw_lan_usable", true))

func _lan_block_reason_from_owner() -> String:
	if _host == null:
		return ""
	var owner := _host.get("_host") as Control
	if owner == null:
		return ""
	return str(owner.get_meta("kw_lan_blocked_reason", "")).strip_edges()

func _candidate_skip_reason(host: String, web_lan_mode: bool) -> String:
	var normalized := host.strip_edges().to_lower()
	if normalized.is_empty():
		return "empty"
	if normalized == "localhost":
		if web_lan_mode:
			return "localhost disabled in web LAN mode"
		if ALLOW_LOCALHOST_LOBBY_CONNECT:
			return ""
		return "localhost not allowed"
	if not normalized.contains("."):
		return ""
	if normalized.begins_with("127."):
		if ALLOW_LOCALHOST_LOBBY_CONNECT and not web_lan_mode:
			return ""
		return "loopback not allowed"
	if normalized.begins_with("169.254."):
		return "link-local"
	return ""

func _browser_hostname_candidate() -> String:
	if _browser_hostname_checked:
		return _browser_hostname_cached
	_browser_hostname_checked = true
	if not OS.has_feature("web"):
		return ""
	var hostname := str(JavaScriptBridge.eval("window.location.hostname")).strip_edges().to_lower()
	var skip_reason := _candidate_skip_reason(hostname, true)
	if not skip_reason.is_empty():
		_log("skipped browser hostname %s (%s)" % [hostname, skip_reason])
		return ""
	_browser_hostname_cached = hostname
	return _browser_hostname_cached

func _compare_host_priority(a: String, b: String) -> bool:
	return _host_priority(a) < _host_priority(b)

func _compare_endpoint_priority(a: Dictionary, b: Dictionary) -> bool:
	var host_a := str(a.get("host", ""))
	var host_b := str(b.get("host", ""))
	var port_a := int(a.get("port", 0))
	var port_b := int(b.get("port", 0))
	var pri_a := _host_priority(host_a)
	var pri_b := _host_priority(host_b)
	if pri_a == pri_b:
		return port_a < port_b
	return pri_a < pri_b

func _host_priority(host: String) -> int:
	var normalized := host.strip_edges().to_lower()
	if normalized.begins_with("192.168."):
		return 0
	if normalized.begins_with("10."):
		return 1
	if _is_private_172_host(normalized):
		return 2
	return 3

func _is_private_172_host(host: String) -> bool:
	var parts := host.split(".")
	if parts.size() != 4:
		return false
	if parts[0] != "172":
		return false
	var second := int(parts[1])
	return second >= 16 and second <= 31

func _log(message: String) -> void:
	if _host != null and _host.has_method("_log"):
		_host.call("_log", message)
