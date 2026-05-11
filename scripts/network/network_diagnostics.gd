extends RefCounted
class_name NetworkDiagnostics

const INTERVAL_SEC := 1.0

var last_ping_ms := -1
var smoothed_ping_ms := -1.0
var min_ping_ms := -1
var max_ping_ms := -1
var avg_ping_ms := -1.0
var ping_jitter_ms := 0.0
var ping_sample_count := 0

var _last_ping_sample_ms := -1
var _accumulator := 0.0
var _physics_delta_sum := 0.0
var _physics_delta_max := 0.0
var _physics_delta_samples := 0

func reset() -> void:
	last_ping_ms = -1
	smoothed_ping_ms = -1.0
	min_ping_ms = -1
	max_ping_ms = -1
	avg_ping_ms = -1.0
	ping_jitter_ms = 0.0
	ping_sample_count = 0
	_last_ping_sample_ms = -1
	_accumulator = 0.0
	physics_reset()

func physics_reset() -> void:
	_physics_delta_sum = 0.0
	_physics_delta_max = 0.0
	_physics_delta_samples = 0

func record_ping_sample(sample_ms: int) -> int:
	last_ping_ms = maxi(0, sample_ms)
	ping_sample_count += 1
	if min_ping_ms < 0 or last_ping_ms < min_ping_ms:
		min_ping_ms = last_ping_ms
	if max_ping_ms < 0 or last_ping_ms > max_ping_ms:
		max_ping_ms = last_ping_ms
	if avg_ping_ms < 0.0:
		avg_ping_ms = float(last_ping_ms)
	else:
		avg_ping_ms = lerpf(avg_ping_ms, float(last_ping_ms), 0.12)
	if smoothed_ping_ms < 0.0:
		smoothed_ping_ms = float(last_ping_ms)
	else:
		smoothed_ping_ms = lerpf(smoothed_ping_ms, float(last_ping_ms), 0.18)
	if _last_ping_sample_ms >= 0:
		var delta_ms := absf(float(last_ping_ms - _last_ping_sample_ms))
		ping_jitter_ms = delta_ms if ping_jitter_ms <= 0.0 else lerpf(ping_jitter_ms, delta_ms, 0.2)
	_last_ping_sample_ms = last_ping_ms
	return last_ping_ms

func debug_text(role_is_server: bool, role_is_client: bool) -> String:
	if role_is_server:
		return "Server"
	if not role_is_client:
		return "Not connected"
	if last_ping_ms < 0:
		return "..."
	return "rtt=%dms smooth=%dms jit=%dms min/avg/max=%d/%d/%d" % [
		last_ping_ms,
		int(round(smoothed_ping_ms)),
		int(round(ping_jitter_ms)),
		min_ping_ms,
		int(round(avg_ping_ms)),
		max_ping_ms
	]

func print_summary(reason: String, runtime_label: String, transport: String, auth_endpoint: String, game_endpoint: String, project_transport: String, env_transport: String, browser_protocol: String, peer_status: int) -> void:
	print("[NET DIAG]")
	print("reason = %s" % reason)
	print("runtime = %s" % runtime_label)
	print("transport = %s" % transport)
	print("auth = %s" % auth_endpoint)
	print("game endpoint = %s" % game_endpoint)
	print("project setting transport = %s" % project_transport)
	print("env transport = %s" % env_transport)
	print("browser protocol = %s" % browser_protocol)
	print("server peer status = %d" % peer_status)

func tick(delta: float, multiplayer: MultiplayerAPI, client_input_controller: RefCounted, player_replication: RefCounted) -> void:
	_physics_delta_sum += delta
	_physics_delta_max = maxf(_physics_delta_max, delta)
	_physics_delta_samples += 1
	_accumulator += delta
	if _accumulator < INTERVAL_SEC:
		return
	var elapsed := _accumulator
	_accumulator = 0.0
	var avg_delta := _physics_delta_sum / maxf(1.0, float(_physics_delta_samples))
	var peer_status := -1
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		peer_status = multiplayer.multiplayer_peer.get_connection_status()
	var input_stats := _consume_dict(client_input_controller, "consume_debug_counters")
	var server_input_stats := _consume_dict(player_replication, "consume_server_input_stats")
	var snapshot_send_stats := _consume_dict(player_replication, "consume_snapshot_send_stats")
	var snapshot_recv_stats := _consume_dict(player_replication, "consume_client_snapshot_stats")
	print("[PING] rtt=%d min=%d avg=%d max=%d jitter=%d smooth=%d" % [
		last_ping_ms,
		min_ping_ms,
		int(round(avg_ping_ms)),
		max_ping_ms,
		int(round(ping_jitter_ms)),
		int(round(smoothed_ping_ms))
	])
	print("[INPUT] send_rate=%.1f/s throttled=%d accepted=%.1f/s dropped=%.1f/s" % [
		float(input_stats.get("sent", 0)) / maxf(0.001, elapsed),
		int(input_stats.get("throttled", 0)),
		float(server_input_stats.get("accepted", 0)) / maxf(0.001, elapsed),
		float(server_input_stats.get("dropped", 0)) / maxf(0.001, elapsed)
	])
	print("[SNAPSHOT] send_rate=%.1f/s recv_rate=%.1f/s bytes_est=%d recipients=%d" % [
		float(snapshot_send_stats.get("sent", 0)) / maxf(0.001, elapsed),
		float(snapshot_recv_stats.get("received", 0)) / maxf(0.001, elapsed),
		int(snapshot_send_stats.get("bytes", 0)),
		int(snapshot_send_stats.get("recipients", 0))
	])
	print("[NET] peer connection status = %d fps=%d physics_fps=%.1f physics_delta_avg=%.4f max=%.4f peers=%d" % [
		peer_status,
		Engine.get_frames_per_second(),
		1.0 / avg_delta if avg_delta > 0.0 else 0.0,
		avg_delta,
		_physics_delta_max,
		multiplayer.get_peers().size() if multiplayer != null and multiplayer.multiplayer_peer != null else 0
	])
	physics_reset()

func _consume_dict(target: RefCounted, method_name: String) -> Dictionary:
	if target == null or not target.has_method(method_name):
		return {}
	var value: Variant = target.call(method_name)
	if value is Dictionary:
		return value as Dictionary
	return {}
