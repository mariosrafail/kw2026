extends "res://scripts/kw3d/overdrive_duel_client.gd"
var qa_index := 0
var qa_age := 0.0
var qa_ready_sent := false
var qa_start_requested := false
var qa_started := false
var qa_started_at := -1.0
var qa_player_peak := 0
var qa_rtt_min := 99999.0
var qa_rtt_max := 0.0
var qa_rtt_sum := 0.0
var qa_rtt_samples := 0
var qa_snapshot_start := 0
var qa_move_started := false
var qa_pending_peak := 0

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
	if str(room_state.get("phase","")) == "MATCH" and str(room_state.get("round_phase","")) in ["COUNTDOWN","FIGHT","OVERLOAD"]:
		if not qa_started:
			qa_started_at = qa_age
			qa_snapshot_start = session.snapshot_count
		qa_started = true

func _physics_process(delta: float) -> void:
	# Same deterministic strafe on both A/B tests so prediction/correction numbers are comparable.
	var fighting := str(room_state.get("phase","")) == "MATCH" and str(room_state.get("round_phase","")) in ["FIGHT","OVERLOAD"]
	if fighting and qa_started_at >= 0.0 and qa_age-qa_started_at < 7.0:
		qa_move_started = true
		if qa_index == 1:
			Input.action_press("kw3d_right",0.72)
			Input.action_release("kw3d_left")
		else:
			Input.action_press("kw3d_left",0.72)
			Input.action_release("kw3d_right")
	else:
		Input.action_release("kw3d_left")
		Input.action_release("kw3d_right")
	super._physics_process(delta)
	qa_age += delta
	qa_pending_peak = maxi(qa_pending_peak,pending.size())
	if session.connected and session.rtt_ms > 0.0:
		qa_rtt_min = minf(qa_rtt_min,session.rtt_ms)
		qa_rtt_max = maxf(qa_rtt_max,session.rtt_ms)
		qa_rtt_sum += session.rtt_ms
		qa_rtt_samples += 1
	if qa_started and qa_started_at >= 0.0 and qa_age-qa_started_at > 9.0:
		_finish_qa()
	elif qa_age > 40.0:
		_finish_qa()

func _finish_qa() -> void:
	var out := {
		"index": qa_index,
		"connected": session.connected,
		"actor": session.actor_id,
		"phase": room_state.get("phase",""),
		"round_phase": room_state.get("round_phase",""),
		"heroes": room_state.get("players",[]).map(func(p):return p.get("hero","")),
		"players": qa_player_peak,
		"started": qa_started,
		"host": room_state.get("host",0),
		"rtt": session.rtt_ms,
		"rtt_min": 0.0 if qa_rtt_samples==0 else qa_rtt_min,
		"rtt_max": qa_rtt_max,
		"rtt_avg": 0.0 if qa_rtt_samples==0 else qa_rtt_sum/float(qa_rtt_samples),
		"snapshots_during_match": session.snapshot_count-qa_snapshot_start,
		"snapshot_rate_hz": 0.0 if qa_started_at<0.0 else float(session.snapshot_count-qa_snapshot_start)/maxf(0.001,qa_age-qa_started_at),
		"pending_peak": qa_pending_peak,
		"max_correction": max_correction,
		"steady_max_correction": steady_max_correction,
		"large_corrections": corrections_over_half_meter,
		"move_injected": qa_move_started
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
