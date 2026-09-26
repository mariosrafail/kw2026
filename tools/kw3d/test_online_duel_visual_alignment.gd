extends SceneTree

const LEVEL := preload("res://scripts/kw3d/online_level.gd")
const WEAPON_RULES := preload("res://scripts/kw3d/weapon_rules.gd")
const SKILL_RULES := preload("res://scripts/kw3d/warrior_skill_rules.gd")
const RIG_NAMES := ["HeadRig", "TorsoRig", "LeftLegRig", "RightLegRig"]

var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if value:
		return
	failures.append(label)
	push_error("ONLINE_DUEL_VISUAL_FAIL " + label)

func _profile_pose(profile_id: String) -> PackedFloat32Array:
	var data: Dictionary = LEVEL.read()
	var profile: Dictionary = (data.get("profiles", {}) as Dictionary).get(profile_id, {}) as Dictionary
	var result := PackedFloat32Array()
	for title in RIG_NAMES:
		var rig: Dictionary = profile[title] as Dictionary
		var p := LEVEL.vec(rig.p)
		var rot := LEVEL.vec(rig.r)
		result.append_array([p.x,p.y,p.z,rot.x,rot.y,rot.z,1.0,1.0,1.0])
	return result

func _visual_min_y(root_node: Node3D) -> float:
	var minimum:=INF
	for child in root_node.find_children("*","MeshInstance3D",true,false):
		var mesh:=child as MeshInstance3D
		if mesh.mesh==null:continue
		var box:=mesh.mesh.get_aabb()
		for index in range(8):
			minimum=minf(minimum,(mesh.global_transform*box.get_endpoint(index)).y)
	return minimum

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var old_warrior := str(ProjectSettings.get_setting("kw3d/selected_warrior_id", "outrage"))
	ProjectSettings.set_setting("kw3d/selected_warrior_id", "outrage")
	var session: Node = load("res://scripts/kw3d/online_session.gd").new()
	root.add_child(session)
	var client: Node = load("res://scripts/kw3d/overdrive_duel_client.gd").new()
	client.session = session
	client.options = {}
	root.add_child(client)
	for i in range(12):
		await process_frame

	var remote_state := {
		"id":77,"bot":false,"skin":"erebus","hero":"erebus","name":"KW BOT",
		"p":Vector3(0,1.715,-6),"v":Vector3.ZERO,"yaw":0.0,"ay":0.0,"ap":0.0,
		"hp":100.0,"kills":0,"gcd":0.0,"fcd":0.0,"weapon":0,"ammo":25,"reload":0.0,
		"pose":_profile_pose("erebus"),"steps":0,"ground":true,"phase":0.0,"connected":true
	}
	client._make_replica(remote_state)
	var record: Dictionary = client.replicas[77]
	client._apply_replica(record, 1.0)
	var style := record.style as Node3D
	var torso := record.rigs.TorsoRig as Node3D
	var gun := record.gun as Node3D
	check(str(style.get_meta("warrior_id", "")) == "erebus", "remote_uses_real_erebus_model")
	check(absf(_visual_min_y(style))<0.10, "remote_erebus_feet_touch_floor")
	check(gun.global_position.distance_to(torso.global_position) < 2.0, "remote_weapon_stays_with_torso")
	check(gun.global_position.x > torso.global_position.x, "remote_weapon_on_aiming_side")
	var ak := record.ak_body as Node3D
	var right_hand := record.right_hand as Node3D
	var left_hand := record.left_hand as Node3D
	check(right_hand.global_position.distance_to(ak.to_global(Vector3(-0.04,-0.12,-0.12))) < 0.002, "right_hand_on_grip")
	check(left_hand.global_position.distance_to(ak.to_global(Vector3(0.50,-0.05,0.09))) < 0.002, "left_hand_on_grip")
	var visible_muzzle: Vector3 = client._visible_muzzle_for_actor(77,Vector3(99,99,99))
	var expected_muzzle := ak.to_global(Vector3(float(WEAPON_RULES.by_slot(0).muzzle_x),0.02,0.0))
	check(visible_muzzle.distance_to(expected_muzzle) < 0.002, "remote_fx_use_visible_muzzle")

	client._ensure_local_network_warrior({"hero":"erebus","skin":"erebus"})
	check(client.player_warrior_id == "erebus", "local_role_switches_to_erebus")
	check(str(client.head_style.get_meta("warrior_id", "")) == "erebus", "local_uses_real_erebus_model")
	check(client.left_hand_rig != null and client.right_hand_rig != null, "local_erebus_hands_rebound")
	var hud: Node = client.combat.director.hud
	hud.set_player_name("erebus")
	hud.set_health(88.0,100.0,true)
	check(str(hud.hp_text.text).begins_with("EREBUS"), "hud_tracks_assigned_hero")
	client._update_warrior_skill_hud(0.0,0.0)
	var fill_style:=client.warrior_skill_bar.get_theme_stylebox("fill") as StyleBoxFlat
	check(fill_style!=null and fill_style.bg_color.is_equal_approx(SKILL_RULES.color("erebus")), "skill_bar_tracks_assigned_hero")

	# Death camera writes a world-space look_at() directly on the Camera3D.  A
	# round reset must restore the normal parent-driven local camera transform or
	# the next centre ray can point back through the player model.
	client.camera.rotation = Vector3(0.42,1.1,-0.18)
	client.camera.global_position = Vector3(9.0,5.0,-8.0)
	client.death_camera_active = true
	client._stop_death_camera(false)
	check(client.camera.rotation.length() < 0.0001, "round_reset_clears_death_camera_rotation")
	check(not client.input_adapter.enabled, "countdown_camera_reset_keeps_input_frozen")
	client._sync_local_round_view({"ay":PI,"ap":deg_to_rad(-10.0),"yaw":PI,"ack":0,"js":0,"gs":0})
	check(absf(wrapf(client.input_adapter.yaw-PI,-PI,PI))<0.0001, "round_reset_syncs_authority_yaw")
	check(absf(client.input_adapter.pitch-deg_to_rad(-10.0))<0.0001, "round_reset_syncs_authority_pitch")
	check(client.camera.rotation.length() < 0.0001, "round_reset_camera_stays_parent_aligned")

	client.queue_free()
	session.queue_free()
	for i in range(4):await process_frame
	ProjectSettings.set_setting("kw3d/selected_warrior_id", old_warrior)
	print("ONLINE_DUEL_VISUAL_QA_", "PASS" if failures.is_empty() else "FAIL", failures)
	quit(0 if failures.is_empty() else 1)
