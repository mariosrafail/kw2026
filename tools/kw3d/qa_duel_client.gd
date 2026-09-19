extends "res://scripts/kw3d/duel_client.gd"
var qa_index := 0
var qa_age := 0.0
var qa_ready_sent := false
var qa_start_requested := false
var qa_started := false
var qa_player_peak := 0

func _ready() -> void:
	qa_index = int(options.get("qa-duel","0"))
	super._ready()

func _welcome(payload: Dictionary) -> void:
	super._welcome(payload)
	if not qa_ready_sent:
		qa_ready_sent = true
		session.set_ready(true)

func _apply_snapshot(snapshot: Dictionary) -> void:
	super._apply_snapshot(snapshot)
	var players: Array = room_state.get("players",[])
	qa_player_peak = maxi(qa_player_peak,players.size())
	var all_ready := players.size() == 2
	for p in players:
		all_ready = all_ready and bool(p.get("ready",false))
	if str(room_state.get("phase","")) == "LOBBY" and all_ready and int(room_state.get("host",0)) == session.actor_id and not qa_start_requested:
		qa_start_requested = true
		session.request_match_start()
	if str(room_state.get("phase","")) == "MATCH":
		qa_started = true

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	qa_age += delta
	if qa_started and qa_age > 5.0:
		_finish_qa()
	elif qa_age > 12.0:
		_finish_qa()

func _finish_qa() -> void:
	var out := {
		"index": qa_index,
		"connected": session.connected,
		"actor": session.actor_id,
		"phase": room_state.get("phase",""),
		"players": qa_player_peak,
		"started": qa_started,
		"host": room_state.get("host",0),
		"rtt": session.rtt_ms
	}
	var folder := str(options.get("output",""))
	if not folder.is_empty():
		DirAccess.make_dir_recursive_absolute(folder)
		var f := FileAccess.open(folder.path_join("duel_client_%d.json"%qa_index),FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(out,"\t"))
			f.close()
	print("DUEL_QA_",qa_index," ",JSON.stringify(out))
	get_tree().quit(0 if session.connected and qa_started and qa_player_peak==2 else 1)
	set_physics_process(false)
