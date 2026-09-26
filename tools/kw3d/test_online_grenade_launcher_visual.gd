extends SceneTree

var failures: Array[String] = []


func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("ONLINE_GRENADE_LAUNCHER_FAIL " + label)


func _initialize() -> void:
	run.call_deferred()


func _remote_pose() -> PackedFloat32Array:
	return PackedFloat32Array([
		0,1.015,0, 0,0,0, 1,1,1,
		0,-0.245,0, 0,0,0, 1,1,1,
		-0.35,-1.365,0, 0,0,0, 1,1,1,
		0.35,-1.365,0, 0,0,0, 1,1,1
	])


func run() -> void:
	var session: Node = load("res://scripts/kw3d/online_session.gd").new()
	root.add_child(session)
	var client: Node = load("res://scripts/kw3d/online_client.gd").new()
	client.session = session
	client.options = {"qa-client":"1"}
	root.add_child(client)
	for i in range(12):
		await process_frame

	client._set_weapon_slot(3, false)
	check(client.weapon_slot == 3, "local_launcher_slot")
	check(client.grenade_launcher_visual_root != null and client.grenade_launcher_visual_root.visible, "local_launcher_visual")

	var remote_state := {
		"id": 81, "bot": false, "skin": "outrage", "p": Vector3(2,2.2,0), "v": Vector3.ZERO,
		"yaw": 0.0, "ay": 0.0, "ap": -0.12, "hp": 100.0, "kills": 0,
		"gcd": 0.0, "fcd": 0.0, "weapon": 3, "ammo": 1, "reload": 0.0,
		"ak_ammo":25,"sg_ammo":2,"kar_ammo":1,"gl_ammo":1,
		"ak_reload":0.0,"sg_reload":0.0,"kar_reload":0.0,"gl_reload":0.0,
		"pose": _remote_pose(), "steps": 0, "ground": true, "phase": 0.0
	}
	client._make_replica(remote_state)
	var record: Dictionary = client.replicas.get(81, {})
	check(not record.is_empty(), "remote_record_created")
	var launcher_body := record.get("launcher_body") as Node3D
	check(launcher_body != null and launcher_body.visible, "remote_launcher_visible")
	check(record.get("ak_body") == null, "remote_ak_lazy")
	check(record.get("shotgun_body") == null, "remote_shotgun_lazy")
	check(record.get("kar_body") == null, "remote_kar_lazy")
	var bodies: Array = record.get("weapon_bodies",[]) as Array
	var built_count := 0
	for body in bodies:
		if body != null:built_count += 1
	check(built_count == 1, "remote_only_active_weapon_built")
	client._ensure_remote_weapon_body(record,2)
	check(record.get("kar_body") != null and (record.kar_body as Node3D).visible, "remote_kar_lazy_build")
	check(launcher_body != null and not launcher_body.visible, "remote_launcher_hidden_after_switch")
	client._ensure_remote_weapon_body(record,3)
	client._apply_replica(record, 1.0)
	var left_hand := record.get("left_hand") as Node3D
	var right_hand := record.get("right_hand") as Node3D
	check(left_hand != null and right_hand != null, "remote_two_hands")
	if left_hand != null and right_hand != null and launcher_body != null:
		var right_local: Vector3 = launcher_body.to_local(right_hand.global_position)
		var left_local: Vector3 = launcher_body.to_local(left_hand.global_position)
		check(left_local.x > right_local.x + 0.35, "remote_launcher_two_hand_spacing")

	client._sync_projectiles({
		"grenades":[{
			"id":345,"owner":81,"p":Vector3(1,3,-2),"v":Vector3(0,2,-20),
			"fuse":1.7,"kind":"launcher","gravity":16.0,"radius":4.8,"max_damage":72.0,"min_damage":22.0
		}],
		"bolts":[]
	})
	check(client.flying.has("g345"), "launcher_projectile_replicated")
	if client.flying.has("g345"):
		var projectile := (client.flying["g345"] as Dictionary).node as MeshInstance3D
		check(projectile != null and projectile.mesh is SphereMesh, "launcher_projectile_is_sphere")

	client._event({
		"type":"launcher_shot","event":1,"tick":1,"match":"qa","actor":81,"input":7,
		"weapon":3,"from":Vector3(2,3,0),"v":Vector3(0,3,-21),"ammo":0,"id":345
	})
	check(int(client.qa_events.get("launcher_shot",0)) == 1, "launcher_shot_event_received")

	client.queue_free()
	session.queue_free()
	for i in range(5):
		await process_frame
	print("ONLINE_GRENADE_LAUNCHER_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
