extends RefCounted

class_name LobbyConnectionConfigController

const CONNECT_FALLBACK_PORTS := [8081]
const ALLOW_LOCALHOST_LOBBY_CONNECT := false

var _host: Object

func configure(host: Object) -> void:
	_host = host

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
	var resolved := resolve_server_host_port_from_args(host, port)
	if _host != null and _host.has_method("_log"):
		_host.call("_log", "resolved primary server endpoint=%s:%d config_found=%s" % [
			str(resolved.get("host", "")),
			int(resolved.get("port", 0)),
			str(bool(config.get("found", false)))
		])
	return resolved

func resolve_auth_api_host_port() -> Dictionary:
	var configured := str(ProjectSettings.get_setting("kw/auth_api_base_url", "http://updates.outrage.ink:8081/auth")).strip_edges()
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
	var seen := {}
	var resolved_primary := resolve_server_host_port()
	var from_args := resolve_server_host_port_from_args(
		str(resolved_primary.get("host", "")).strip_edges(),
		int(resolved_primary.get("port", 8080))
	)
	for endpoint in [resolved_primary, from_args]:
		var host := str(endpoint.get("host", "")).strip_edges()
		var port := int(endpoint.get("port", 8080))
		if host.is_empty() or port < 1 or port > 65535:
			continue
		var host_lc := host.to_lower()
		var is_localhost := host_lc == "localhost" or host_lc == "127.0.0.1" or host_lc == "::1"
		if is_localhost and not ALLOW_LOCALHOST_LOBBY_CONNECT:
			continue
		var key := "%s:%d" % [host, port]
		if seen.has(key):
			continue
		seen[key] = true
		out.append({"host": host, "port": port})
		for fallback_port_value in CONNECT_FALLBACK_PORTS:
			var fallback_port := int(fallback_port_value)
			if fallback_port < 1 or fallback_port > 65535 or fallback_port == port:
				continue
			var fallback_key := "%s:%d" % [host, fallback_port]
			if seen.has(fallback_key):
				continue
			seen[fallback_key] = true
			out.append({"host": host, "port": fallback_port})
		var local_hosts := local_connect_fallback_hosts()
		for local_host_value in local_hosts:
			var local_host := str(local_host_value).strip_edges()
			if local_host.is_empty():
				continue
			var local_key := "%s:%d" % [local_host, port]
			if not seen.has(local_key):
				seen[local_key] = true
				out.append({"host": local_host, "port": port})
			for fallback_port_value in CONNECT_FALLBACK_PORTS:
				var local_fallback_port := int(fallback_port_value)
				if local_fallback_port < 1 or local_fallback_port > 65535 or local_fallback_port == port:
					continue
				var local_fallback_key := "%s:%d" % [local_host, local_fallback_port]
				if seen.has(local_fallback_key):
					continue
				seen[local_fallback_key] = true
				out.append({"host": local_host, "port": local_fallback_port})
	if _host != null and _host.has_method("_log"):
		_host.call("_log", "connect candidates=%s" % str(out))
	return out

func local_connect_fallback_hosts() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("127.0.0.1")
	out.append("localhost")
	for address_value in IP.get_local_addresses():
		var address := str(address_value).strip_edges()
		if address.is_empty():
			continue
		if not address.contains("."):
			continue
		if address.begins_with("127."):
			continue
		if address.begins_with("169.254."):
			continue
		if out.has(address):
			continue
		out.append(address)
	return out
