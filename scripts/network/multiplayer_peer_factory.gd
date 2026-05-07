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
		return trimmed

	var scheme := "ws"
	if port == 443:
		scheme = "wss"
	return "%s://%s:%d" % [scheme, trimmed, port]
