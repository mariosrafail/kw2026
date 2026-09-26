extends Node3D
const SESSION = preload("res://scripts/kw3d/online_session.gd")
const DUEL_WORLD = preload("res://scripts/kw3d/duel_authority_world.gd")
const DUEL_CLIENT = preload("res://scripts/kw3d/overdrive_duel_client.gd")
const VIRTUAL_PROFILE = preload("res://scripts/kw3d/virtual_profile.gd")
var session: Node
var world: Node3D
var client: Node3D
var options: Dictionary = {}
var age = 0.0
var idle_time = 0.0

func _ready() -> void:
	name = "KW3DLANDuel"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--kw-"):
			var parts = argument.trim_prefix("--kw-").split("=",true,1)
			options[parts[0]] = parts[1] if parts.size() > 1 else "true"
	if not options.has("name"):
		options["name"] = VIRTUAL_PROFILE.local_username()
	session = SESSION.new()
	session.name = "Session"
	add_child(session)
	if options.has("server"):
		world = DUEL_WORLD.new()
		world.name = "DuelAuthorityWorld"
		add_child(world)
		var error: Error = session.start_server(world,int(options.get("port","18886")),str(options.get("bind","0.0.0.0")),str(options.get("transport","enet")))
		if error != OK:
			get_tree().quit(2)
	else:
		client = load("res://tools/kw3d/qa_duel_client.gd").new() if options.has("qa-duel") else DUEL_CLIENT.new()
		client.name = "DuelClientView"
		client.session = session
		client.options = options
		add_child(client)
		print("KW_DUEL_GAMEPADS ",Input.get_connected_joypads())

func _physics_process(delta: float) -> void:
	age += delta
	if options.has("server"):
		idle_time = idle_time + delta if session.peer_slots.is_empty() else 0.0
		if options.has("idle-exit") and idle_time > float(options["idle-exit"]):
			get_tree().quit()
