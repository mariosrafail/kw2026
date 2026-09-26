extends "res://scripts/kw3d/online_client.gd"
## Retail/F5 LAN duel client. Connection room stays open until both players ready and host starts.
const DUEL_MENU = preload("res://scripts/kw3d/duel_room_menu.gd")
const DUEL_COMBAT = preload("res://scripts/kw3d/duel_combat_view.gd")
const DUEL_SCENE = "res://scenes/prototypes/kw_3d_lan_duel.tscn"
var room_state: Dictionary = {}
var created_room = false
var live_online_config: Dictionary = {}
var udp_fallback_host := ""
var udp_fallback_port := 0

func _menu_script() -> Script:
	return DUEL_MENU

func _combat_script() -> Script:
	return DUEL_COMBAT

func _open_menu_on_death() -> bool:
	return false

func _aim_assist_is_hostile(state: Dictionary) -> bool:
	return int(state.get("id",0))!=session.actor_id and float(state.get("hp",0.0))>0.0

func _welcome(payload: Dictionary) -> void:
	room_state = payload.get("room",{})
	if menu != null and menu.has_method("hide_loading"):
		menu.hide_loading()
	super._welcome(payload)
	DisplayServer.window_set_title("KW LAN DUEL | PLAYER %d" % payload.slot)
	set_menu(true)
	if menu != null:
		menu.refresh()

func _apply_snapshot(snapshot: Dictionary) -> void:
	if snapshot.has("room"):
		room_state = snapshot.room
	super._apply_snapshot(snapshot)

func _event(e: Dictionary) -> void:
	match str(e.get("type","")):
		"room":
			room_state = e.get("room",room_state)
			if menu != null:
				menu.refresh()
		"match_start":
			room_state = e.get("room",room_state)
			combat.director.hud.reset_run()
			set_menu(false)
		"match_over":
			room_state = e.get("room",room_state)
			input_adapter.suspend()
			if combat != null:
				var winner_name := "PLAYER %d" % int(e.get("winner",0))
				for p in room_state.get("players",[]):
					if int(p.get("id",0)) == int(e.get("winner",0)):
						winner_name = str(p.get("name",winner_name))
						break
				combat.director.hud.announce(winner_name+" WINS","READY UP FOR REMATCH",4.0)
				var players: Array=room_state.get("players",[]) as Array
				var left_score:=int((players[0] as Dictionary).get("rounds",0)) if players.size()>0 else 0
				var right_score:=int((players[1] as Dictionary).get("rounds",0)) if players.size()>1 else 0
				combat.director.hud.show_round_result(winner_name+" WINS THE MATCH","%d  —  %d"%[left_score,right_score],"READY UP FOR REMATCH",4.0,Color("76efbd"))
			set_menu(true)
	super._event(e)

func set_menu(opened: bool) -> void:
	if not opened and session != null and session.connected and str(room_state.get("phase","LOBBY")) != "MATCH":
		opened = true
	super.set_menu(opened)

func _baked_online_config() -> Dictionary:
	var config_path := "res://updates_site/kw/online_config.json"
	if FileAccess.file_exists(config_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(config_path))
		if parsed is Dictionary:return parsed
	return {}

func public_portal_url() -> String:
	return str(ProjectSettings.get_setting("kw3d/public_portal_url","")).strip_edges().trim_suffix("/")

func public_ws_url() -> String:
	var config := live_online_config if not live_online_config.is_empty() else _baked_online_config()
	var value := str(config.get("game_ws_url",ProjectSettings.get_setting("kw3d/public_ws_url",""))).strip_edges()
	return value

func public_udp_host() -> String:
	var config := live_online_config if not live_online_config.is_empty() else _baked_online_config()
	return str(config.get("game_udp_host",ProjectSettings.get_setting("kw3d/public_udp_host",""))).strip_edges()

func public_udp_port() -> int:
	var config := live_online_config if not live_online_config.is_empty() else _baked_online_config()
	return int(config.get("game_udp_port",ProjectSettings.get_setting("kw3d/public_udp_port",18886)))

func public_lan_host() -> String:
	var config := live_online_config if not live_online_config.is_empty() else _baked_online_config()
	return str(config.get("game_lan_host",ProjectSettings.get_setting("kw3d/public_lan_host",""))).strip_edges()

func _same_lan_as(host: String) -> bool:
	var parts := host.split(".")
	if parts.size()!=4:return false
	var prefix := "%s.%s.%s." % [parts[0],parts[1],parts[2]]
	for raw in IP.get_local_addresses():
		var local := str(raw)
		if local.begins_with(prefix):return true
	return false

func preferred_udp_host() -> String:
	var lan := public_lan_host()
	if not lan.is_empty() and _same_lan_as(lan):return lan
	return public_udp_host()

func connect_public_udp() -> void:
	var port := public_udp_port()
	var public_host := public_udp_host()
	var lan := public_lan_host()
	udp_fallback_host = ""
	udp_fallback_port = 0
	if not lan.is_empty() and _same_lan_as(lan) and lan!=public_host:
		udp_fallback_host = public_host
		udp_fallback_port = port
		connect_server(lan,port)
		_arm_udp_fallback(lan)
		return
	connect_server(public_host,port)

func _arm_udp_fallback(initial_host: String) -> void:
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree() or session.connected:return
	if str(session.server_host)!=initial_host or udp_fallback_host.is_empty():return
	var fallback := udp_fallback_host
	var fallback_port := udp_fallback_port
	udp_fallback_host = ""
	udp_fallback_port = 0
	session.close_connection(false)
	if menu != null and menu.has_method("show_loading"):
		menu.show_loading("LAN PATH UNAVAILABLE  /  TRYING PUBLIC UDP...")
	connect_server(fallback,fallback_port)

func refresh_live_online_config() -> void:
	var portal := public_portal_url()
	if portal.is_empty():return
	var request := HTTPRequest.new()
	add_child(request)
	var headers := PackedStringArray(["ngrok-skip-browser-warning: true","User-Agent: KWGame/"+str(ProjectSettings.get_setting("application/config/version","dev"))])
	var err := request.request(portal+"/kw/online_config.json?ts="+str(Time.get_ticks_msec()),headers)
	if err!=OK:
		request.queue_free()
		return
	var completed: Array=await request.request_completed
	request.queue_free()
	if completed.size()<4 or int(completed[0])!=HTTPRequest.RESULT_SUCCESS or int(completed[1])!=200:return
	var body: PackedByteArray=completed[3]
	var parsed: Variant=JSON.parse_string(body.get_string_from_utf8())
	if parsed is Dictionary:live_online_config=parsed

func public_online_enabled() -> bool:
	return bool(ProjectSettings.get_setting("kw3d/public_online_enabled", true)) and not public_udp_host().is_empty()

func join_public_room() -> void:
	if session.connected:return
	created_room = false
	if menu != null and menu.has_method("show_loading"):
		menu.show_loading("JOINING KW ONLINE VIA UDP...")
	await refresh_live_online_config()
	if public_udp_host().is_empty():
		if menu != null:
			menu.hide_loading()
			menu.message.text = "Public UDP server endpoint is unavailable."
		return
	connect_public_udp()

func join_lan_room(host: String, port_value: int) -> void:
	if session.connected:
		return
	created_room = false
	if menu != null and menu.has_method("show_loading"):
		menu.show_loading("CONNECTING TO LAN ROOM...")
	connect_server(host, port_value)

func create_room() -> void:
	if session.connected:return
	# Online-first: connect to the persistent ENet/UDP authority on the host PC.
	# The stable ngrok endpoint is used only to fetch updater/config files, never gameplay.
	if public_online_enabled():
		created_room = true
		if menu != null and menu.has_method("show_loading"):
			menu.show_loading("CREATING ONLINE ROOM VIA UDP...")
		await refresh_live_online_config()
		if public_udp_host().is_empty():
			if menu != null:
				menu.hide_loading()
				menu.message.text = "Public UDP server endpoint is unavailable."
			return
		connect_public_udp()
		return
	created_room = true
	var port_value = int(menu.port.value)
	if owned_server_pid < 0 or not OS.is_process_running(owned_server_pid):
		var args = PackedStringArray()
		args.append("--headless")
		if OS.has_feature("editor"):
			args.append_array(["--path",ProjectSettings.globalize_path("res://"),DUEL_SCENE])
		args.append_array(["--","--kw-server","--kw-port="+str(port_value),"--kw-bind=0.0.0.0","--kw-idle-exit=120"])
		owned_server_pid = OS.create_process(OS.get_executable_path(),args,false)
		if owned_server_pid < 0:
			menu.message.text = "Could not start LAN room server."
			return
	var host_address := lan_address()
	menu.message.text = "Creating LAN room on "+host_address+":"+str(port_value)+" ..."
	await get_tree().create_timer(0.75).timeout
	if is_inside_tree():
		connect_server(host_address,port_value)

func connect_server(host: String,port_value: int) -> void:
	var normalized := host.strip_edges()
	if normalized != "127.0.0.1" and normalized != lan_address() and normalized != public_lan_host() and normalized != public_udp_host():
		created_room = false
	super.connect_server(host,port_value)

func _connection_message(text: String) -> void:
	super._connection_message(text)
	if menu == null:return
	if text.begins_with("Connecting"):
		if menu.has_method("show_loading"):menu.show_loading("CONNECTING TO KW UDP SERVER...")
	else:
		if menu.has_method("hide_loading"):menu.hide_loading()
		if not session.connected:
			menu.message.text = "ONLINE CONNECTION FAILED  /  "+text

func toggle_ready() -> void:
	if not session.connected:
		return
	var mine = false
	for p in room_state.get("players",[]):
		if int(p.get("id",0)) == session.actor_id:
			mine = bool(p.get("ready",false))
			break
	session.set_ready(not mine)

func request_match_start() -> void:
	if not session.connected:return
	if str(room_state.get("phase","LOBBY")) not in ["LOBBY","RESULT"]:return
	if int(room_state.get("host",0)) != int(session.actor_id):return
	if not bool(room_state.get("can_start",false)):return
	session.request_match_start()

func set_bot_fallback(value: bool) -> void:
	if not session.connected:return
	if int(room_state.get("host",0)) != int(session.actor_id):return
	session.set_duel_bot_fallback(value)

func leave_room() -> void:
	if session != null:
		session.close_connection(true)
	clear_session_view()
	room_state = {}
	input_adapter.suspend()
	if created_room and owned_server_pid > 0 and OS.is_process_running(owned_server_pid):
		OS.kill(owned_server_pid)
	owned_server_pid = -1
	created_room = false
	if menu != null:
		menu.message.text = "Left room."
		menu.open()

func open_controls_menu() -> void:
	if menu == null:
		return
	var pad: String = input_adapter.prompt()
	menu.message.text = "CONTROLS: "+pad+"\nA/Cross jump • L3 sprint • AK/Shotgun keep aim assist; KAR scope has no magnet and near-zero movement • Esc/Start room menu."

func lan_address() -> String:
	var candidates: Array[String] = []
	for raw in IP.get_local_addresses():
		var value := str(raw)
		if ":" in value or value.begins_with("127.") or value.begins_with("169.254."):
			continue
		candidates.append(value)
	for prefix in ["192.168.","10.","172."]:
		for value in candidates:
			if value.begins_with(prefix):
				return value
	return candidates[0] if not candidates.is_empty() else "127.0.0.1"
