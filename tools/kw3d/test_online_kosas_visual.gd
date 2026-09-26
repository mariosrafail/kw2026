extends SceneTree

var failures: Array[String] = []

func check(value: bool,label: String) -> void:
	if value:return
	failures.append(label)
	push_error("ONLINE_KOSAS_VISUAL_FAIL "+label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var old := str(ProjectSettings.get_setting("kw3d/selected_warrior_id","outrage"))
	ProjectSettings.set_setting("kw3d/selected_warrior_id","kosas")
	var session: Node = load("res://scripts/kw3d/online_session.gd").new()
	root.add_child(session)
	var client: Node = load("res://scripts/kw3d/online_client.gd").new()
	client.session = session
	client.options = {"qa-client":"1"}
	root.add_child(client)
	for i in range(12):
		await process_frame
	check(client.player_warrior_id=="kosas","local_selected_kosas")
	check(client.head_style!=null and str(client.head_style.get_meta("warrior_id",""))=="kosas","local_kosas_model")
	check(client.head_style.get_node_or_null("TorsoRig/KosasBodyBox") is MeshInstance3D,"local_rect_body")
	var body := client.head_style.get_node_or_null("TorsoRig/KosasBodyBox") as MeshInstance3D
	if body!=null:
		var s:=body.mesh.get_aabb().size
		check(absf(s.x-0.50)<0.001 and absf(s.y-0.82)<0.001 and absf(s.z-0.32)<0.001,"local_rect_dimensions")
	var remote_state := {
		"id": 77, "bot": false, "skin": "kosas", "p": Vector3.ZERO, "v": Vector3.ZERO,
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
	var record: Dictionary=client.replicas.get(77,{})
	var remote_style:=record.get("style") as Node3D
	check(remote_style!=null and str(remote_style.get_meta("warrior_id",""))=="kosas","remote_kosas_model")
	check(remote_style!=null and remote_style.get_node_or_null("TorsoRig/KosasBodyBox") is MeshInstance3D,"remote_rect_body")
	client.queue_free()
	session.queue_free()
	for i in range(4):await process_frame
	ProjectSettings.set_setting("kw3d/selected_warrior_id",old)
	print("ONLINE_KOSAS_VISUAL_QA_","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
