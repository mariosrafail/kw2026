extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	run.call_deferred()
func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		push_error("CREATE_DOCKER_FAIL "+label)
func run() -> void:
	var stage = load("res://scenes/prototypes/kw_3d_lan_duel.tscn").instantiate()
	root.add_child(stage)
	for i in range(8): await process_frame
	stage.client.create_room()
	await create_timer(2.2).timeout
	check(stage.session.connected, "not_connected")
	check(stage.session.actor_id > 0, "no_actor")
	check(stage.client.room_state.get("players",[]).size() == 1, "room_missing_host")
	check(int(stage.client.room_state.get("host",0)) == stage.session.actor_id, "not_host")
	stage.client.leave_room()
	print("CREATE_ROOM_DOCKER_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
