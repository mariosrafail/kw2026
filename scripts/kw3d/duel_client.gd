extends "res://scripts/kw3d/online_client.gd"
## Retail/F5 LAN duel client. Connection room stays open until both players ready and host starts.
const DUEL_MENU = preload("res://scripts/kw3d/duel_room_menu.gd")
const DUEL_COMBAT = preload("res://scripts/kw3d/duel_combat_view.gd")
const DUEL_SCENE = "res://scenes/prototypes/kw_3d_lan_duel.tscn"
var room_state: Dictionary = {}
var created_room = false

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
	if menu != null and menu.visible:
		menu.refresh()

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
				combat.director.hud.announce("OUTRAGE %d WINS" % int(e.get("winner",0)),"READY UP FOR REMATCH",4.0)
			set_menu(true)
	super._event(e)

func set_menu(opened: bool) -> void:
	if not opened and session != null and session.connected and str(room_state.get("phase","LOBBY")) != "MATCH":
		opened = true
	super.set_menu(opened)

func public_ws_url() -> String:
	return str(ProjectSettings.get_setting("kw3d/public_ws_url", "")).strip_edges()

func public_online_enabled() -> bool:
	return bool(ProjectSettings.get_setting("kw3d/public_online_enabled", true)) and not public_ws_url().is_empty()

func join_public_room() -> void:
	if session.connected:
		return
	created_room = false
	var endpoint := public_ws_url()
	if endpoint.is_empty():
		if menu != null: menu.message.text = "Public server endpoint is unavailable."
		return
	if menu != null and menu.has_method("show_loading"):
		menu.show_loading("JOINING KW ONLINE...")
	connect_server(endpoint, 443)

func join_lan_room(host: String, port_value: int) -> void:
	if session.connected:
		return
	created_room = false
	if menu != null and menu.has_method("show_loading"):
		menu.show_loading("CONNECTING TO LAN ROOM...")
	connect_server(host, port_value)

func create_room() -> void:
	if session.connected:
		return
	# Online-first: the first player on the persistent public authority becomes room host.
	# LAN server spawning remains as fallback when no public endpoint is configured.
	if public_online_enabled():
		created_room = true
		if menu != null and menu.has_method("show_loading"):
			menu.show_loading("CREATING ONLINE ROOM...")
		connect_server(public_ws_url(),443)
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
	if normalized != "127.0.0.1" and normalized != lan_address() and normalized != public_ws_url():
		created_room = false
	super.connect_server(host,port_value)

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
	if session.connected:
		session.request_match_start()

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
