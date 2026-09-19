extends Node3D
const SESSION:=preload("res://scripts/kw3d/online_session.gd")
var session: Node
var world: Node3D
var client: Node3D
var options: Dictionary={}
var age =0.0
var idle_time=0.0
func _ready() -> void:
	name="KW3DOnline"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--kw-"):
			var parts =argument.trim_prefix("--kw-").split("=",true,1)
			options[parts[0]]=parts[1] if parts.size()>1 else "true"
	session=SESSION.new();session.name="Session";add_child(session)
	if options.has("server"):
		world=load("res://scripts/kw3d/authority_world.gd").new();world.name="AuthorityWorld";add_child(world)
		if options.has("qa-fixture"):world.attacks_enabled=false;world.qa_fixture=true
		var error =session.start_server(world,int(options.get("port","18886")),str(options.get("bind","127.0.0.1")))
		if error!=OK:get_tree().quit(2)
	else:
		client=load("res://tools/kw3d/qa_online_client.gd" if options.has("qa-client") else "res://scripts/kw3d/online_client.gd").new();client.name="ClientView"
		client.session=session;client.options=options;add_child(client)
		print("KW_GAMEPADS ",Input.get_connected_joypads())

func _physics_process(delta: float) -> void:
	age+=delta
	if options.has("server"):
		idle_time=idle_time+delta if session.peer_slots.is_empty() else 0.0
		if options.has("idle-exit") and idle_time>float(options["idle-exit"]):get_tree().quit()
	if options.has("server") and options.has("duration") and age>float(options.duration):
		if options.has("report"):
			var file =FileAccess.open(options.report,FileAccess.WRITE)
			var state: Dictionary=world.snapshot()
			state["metrics"]=world.metrics
			state["damage_events"]=world.damage_count;state["kill_events"]=world.kill_count
			state["grenade_events"]=world.grenade_count;state["heals"]=world.heal_count
			state["rejected_inputs"]=session.rejected_inputs
			state["has_camera"]=get_viewport().get_camera_3d()!=null
			file.store_string(JSON.stringify(state,"\t"));file.close()
		get_tree().quit()
