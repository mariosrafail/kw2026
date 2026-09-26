extends SceneTree

var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("ONLINE_AEVILOK_VISUAL_FAIL " + label)


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var old := str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "outrage"))
	ProjectSettings.set_setting("kw3d/selected_warrior_id", "aevilok")
	var session: Node = load("res://scripts/kw3d/online_session.gd").new()
	root.add_child(session)
	var client: Node = load("res://scripts/kw3d/online_client.gd").new()
	client.session = session
	client.options = {"qa-client": "1"}
	root.add_child(client)
	for i in range(12):
		await process_frame
	check(client.player_warrior_id == "aevilok", "local_selected_aevilok")
	check(client.head_style != null and str(client.head_style.get_meta("warrior_id", "")) == "aevilok", "local_aevilok_model")
	check(client.head_style.get_node_or_null("TorsoRig/AevilokWingRoot") is Node3D, "local_wings")
	var local_wings := client.head_style.get_node_or_null("TorsoRig/AevilokWingRoot") as Node3D
	check(local_wings != null and local_wings.find_children("*", "CollisionShape3D", true, false).is_empty(), "local_wings_visual_only")
	var remote_state := {
		"id": 78, "bot": false, "skin": "aevilok", "p": Vector3.ZERO, "v": Vector3.ZERO,
		"yaw": 0.0, "ay": 0.0, "ap": 0.0, "hp": 100.0, "kills": 0,
		"gcd": 0.0, "fcd": 0.0, "weapon": 0, "ammo": 25, "reload": 0.0,
		"pose": PackedFloat32Array([
			0,1.015,0, 0,0,0, 1,1,1,
			0,-0.245,0, 0,0,0, 1,1,1,
			-0.35,-1.365,0, 0,0,0, 1,1,1,
			0.35,-1.365,0, 0,0,0, 1,1,1
		]), "steps": 0
	}
	client._make_replica(remote_state)
	var record: Dictionary = client.replicas.get(78, {})
	var remote_style := record.get("style") as Node3D
	check(remote_style != null and str(remote_style.get_meta("warrior_id", "")) == "aevilok", "remote_aevilok_model")
	check(remote_style != null and remote_style.get_node_or_null("TorsoRig/AevilokWingRoot") is Node3D, "remote_wings")
	client.queue_free()
	session.queue_free()
	for i in range(4):
		await process_frame
	ProjectSettings.set_setting("kw3d/selected_warrior_id", old)
	print("ONLINE_AEVILOK_VISUAL_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
