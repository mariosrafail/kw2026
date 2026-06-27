extends RefCounted
class_name NetworkProfiles

const DEFAULT_PROFILE := "local_dev"
const SETTING_PATH := "application/config/network_profile"

const PROFILES := {
	"local_dev": {
		"server_snapshot_rate": 24.0,
		"client_input_send_rate": 45.0,
		"client_idle_input_send_rate": 8.0,
		"max_input_packets_per_sec": 60,
		"player_history_ms": 350,
		"ping_interval": 1.0,
		"trail_max_points": 6,
		"trail_sample_interval": 0.04,
		"trail_wall_clip": false
	},
	"lan_high_quality": {
		"server_snapshot_rate": 30.0,
		"client_input_send_rate": 60.0,
		"client_idle_input_send_rate": 10.0,
		"max_input_packets_per_sec": 90,
		"player_history_ms": 250,
		"ping_interval": 1.0,
		"trail_max_points": 8,
		"trail_sample_interval": 0.03,
		"trail_wall_clip": false
	},
	"remote_light": {
		"server_snapshot_rate": 15.0,
		"client_input_send_rate": 24.0,
		"client_idle_input_send_rate": 5.0,
		"max_input_packets_per_sec": 40,
		"player_history_ms": 400,
		"ping_interval": 1.0,
		"trail_max_points": 4,
		"trail_sample_interval": 0.06,
		"trail_wall_clip": false
	},
	"production_balanced": {
		"server_snapshot_rate": 20.0,
		"client_input_send_rate": 30.0,
		"client_idle_input_send_rate": 5.0,
		"max_input_packets_per_sec": 50,
		"player_history_ms": 350,
		"ping_interval": 1.0,
		"trail_max_points": 5,
		"trail_sample_interval": 0.05,
		"trail_wall_clip": false
	}
}

static func selected_profile_name() -> String:
	var configured := str(ProjectSettings.get_setting(SETTING_PATH, DEFAULT_PROFILE)).strip_edges().to_lower()
	if PROFILES.has(configured):
		return configured
	return DEFAULT_PROFILE

static func selected_profile() -> Dictionary:
	return profile(selected_profile_name())

static func profile(name: String) -> Dictionary:
	var normalized := name.strip_edges().to_lower()
	if not PROFILES.has(normalized):
		normalized = DEFAULT_PROFILE
	return (PROFILES[normalized] as Dictionary).duplicate(true)
