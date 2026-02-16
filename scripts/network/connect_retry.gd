extends RefCounted
class_name ConnectRetry

var timeout_seconds := 3.5
var hosts: PackedStringArray = PackedStringArray()
var index := 0
var elapsed := 0.0

func configure(primary_host: String, include_editor_fallback: bool, private_ipv4: String, default_host: String) -> void:
	var ordered_hosts: Array[String] = []
	var trimmed_primary := primary_host.strip_edges()
	if not trimmed_primary.is_empty():
		ordered_hosts.append(trimmed_primary)

	if include_editor_fallback:
		ordered_hosts.append("127.0.0.1")
		if not private_ipv4.is_empty():
			ordered_hosts.append(private_ipv4)
		ordered_hosts.append(default_host)

	var unique_hosts := PackedStringArray()
	for host in ordered_hosts:
		if host.is_empty():
			continue
		if unique_hosts.has(host):
			continue
		unique_hosts.append(host)

	hosts = unique_hosts
	var configured_index := _index_of(trimmed_primary)
	index = configured_index if configured_index >= 0 else 0
	elapsed = 0.0

func set_current_host(host: String) -> void:
	var idx := _index_of(host.strip_edges())
	if idx >= 0:
		index = idx
	elapsed = 0.0

func current_host() -> String:
	if hosts.is_empty() or index < 0 or index >= hosts.size():
		return ""
	return hosts[index]

func reset_timer() -> void:
	elapsed = 0.0

func tick(delta: float) -> bool:
	elapsed += delta
	if elapsed < timeout_seconds:
		return false
	elapsed = 0.0
	return true

func advance_to_next_host() -> String:
	if hosts.is_empty():
		return ""
	if index >= hosts.size() - 1:
		return ""
	index += 1
	elapsed = 0.0
	return hosts[index]

func _index_of(host: String) -> int:
	for i in range(hosts.size()):
		if hosts[i] == host:
			return i
	return -1
