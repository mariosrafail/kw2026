extends RefCounted
class_name MultiplayerPeerFactory

const TRANSPORT_SETTING := "kw/network_transport"
const TRANSPORT_ENET := "enet"
const TRANSPORT_WEBSOCKET := "websocket"

static func transport() -> String:
	var env_transport := OS.get_environment("KW_NETWORK_TRANSPORT").strip_edges().to_lower()
	if env_transport == "websocket" or env_transport == "ws" or env_transport == "wss":
		return TRANSPORT_WEBSOCKET
	if env_transport == "enet" or env_transport == "udp":
		return TRANSPORT_ENET

	var configured := str(ProjectSettings.get_setting(TRANSPORT_SETTING, "")).strip_edges().to_lower()
	if configured == "websocket" or configured == "ws" or configured == "wss":
		return TRANSPORT_WEBSOCKET
	if configured == "enet" or configured == "udp":
		return TRANSPORT_ENET

	if OS.has_feature("web"):
		return TRANSPORT_WEBSOCKET
	return TRANSPORT_ENET

static func uses_websocket() -> bool:
	return transport() == TRANSPORT_WEBSOCKET

static func create_client_peer(host: String, port: int) -> Dictionary:
	if uses_websocket():
		var ws_peer := WebSocketMultiplayerPeer.new()
		var url := websocket_url(host, port)
		print("[NET] transport = websocket")
		print("[NET] websocket url = %s" % url)
		return {
			"peer": ws_peer,
			"error": ws_peer.create_client(url),
			"endpoint": url,
			"transport": TRANSPORT_WEBSOCKET
		}

	var enet_peer := ENetMultiplayerPeer.new()
	return {
		"peer": enet_peer,
		"error": enet_peer.create_client(host, port),
		"endpoint": "%s:%d" % [host, port],
		"transport": TRANSPORT_ENET
	}

static func create_server_peer(port: int, max_clients: int = 8) -> Dictionary:
	if uses_websocket():
		var ws_peer := WebSocketMultiplayerPeer.new()
		print("[NET] transport = websocket")
		print("[NET] websocket url = ws://0.0.0.0:%d" % port)
		return {
			"peer": ws_peer,
			"error": ws_peer.create_server(port, "*"),
			"endpoint": "ws://0.0.0.0:%d" % port,
			"transport": TRANSPORT_WEBSOCKET
		}

	var enet_peer := ENetMultiplayerPeer.new()
	return {
		"peer": enet_peer,
		"error": enet_peer.create_server(port, max_clients),
		"endpoint": "udp://0.0.0.0:%d" % port,
		"transport": TRANSPORT_ENET
	}

static func websocket_url(host: String, port: int) -> String:
	var trimmed := host.strip_edges()
	if trimmed.begins_with("ws://") or trimmed.begins_with("wss://"):
		print("[NET] final websocket url = %s" % trimmed)
		return trimmed

	var scheme := "ws"
	var scheme_override := str(ProjectSettings.get_setting("kw/network_ws_scheme", "")).strip_edges().to_lower()
	if scheme_override == "ws" or scheme_override == "wss":
		scheme = scheme_override
	elif OS.has_feature("web"):
		var href := str(JavaScriptBridge.eval("window.location.href")).strip_edges()
		var origin := str(JavaScriptBridge.eval("window.location.origin")).strip_edges()
		var protocol := str(JavaScriptBridge.eval("window.location.protocol")).strip_edges().to_lower()
		print("[BROWSER] href = %s" % href)
		print("[BROWSER] origin = %s" % origin)
		print("[BROWSER] protocol = %s" % protocol)
		if protocol == "https:":
			scheme = "wss"
	if port == 443:
		scheme = "wss"
	var final_url := "%s://%s:%d" % [scheme, trimmed, port]
	print("[NET] final websocket url = %s" % final_url)
	return final_url
