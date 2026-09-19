extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,title: String) -> void:
	if not value:failures.append(title);push_error("ONLINE_UNIT_FAIL "+title)
func run() -> void:
	var session_script=load("res://scripts/kw3d/online_session.gd")
	var codec=load("res://scripts/kw3d/input_codec.gd")
	var frame: Dictionary={"seq":1,"ct":0,"js":0,"gs":0,"move":Vector2(0.4,0.2),"yaw":0.2,"pitch":-0.1,"side":-1.0,"fire":true,"aim":true,"sprint":false,"reload":false,"weapon":0}
	check(session_script.valid_frame(frame),"valid_command")
	var encoded: PackedByteArray=codec.encode([frame,frame,frame,frame])
	check(encoded.size()==144,"four_commands_below_mtu")
	var decoded: Array=codec.decode(encoded)
	check(decoded.size()==4 and decoded[0].move.distance_to(frame.move)<0.00001 and not decoded[0].reload and decoded[0].weapon==0,"codec_round_trip")
	var weapon_frame: Dictionary=frame.duplicate();weapon_frame.weapon=1
	var weapon_decoded: Array=codec.decode(codec.encode([weapon_frame]))
	check(weapon_decoded.size()==1 and weapon_decoded[0].weapon==1,"weapon_slot_round_trip")
	var reload_frame: Dictionary=frame.duplicate();reload_frame.reload=true
	var reload_decoded: Array=codec.decode(codec.encode([reload_frame]))
	check(reload_decoded.size()==1 and reload_decoded[0].reload,"reload_flag_round_trip")
	for bad in [Vector2(NAN,0),Vector2(2,0)]:
		var copy: Dictionary=frame.duplicate();copy.move=bad
		check(not session_script.valid_frame(copy),"reject_bad_movement")
	var false_damage =frame.duplicate();false_damage.damage=900
	check(not session_script.valid_frame(false_damage),"reject_client_damage_field")
	check(codec.decode(PackedByteArray([1])).is_empty(),"malformed_binary_rejected")
	var input=load("res://scripts/kw3d/portable_input.gd").new()
	input.config_path="user://kw3d_unit_test_controls.cfg";root.add_child(input)
	input.enabled=true;input.focused=true
	Input.action_press("kw3d_right",0.6)
	var analog: Dictionary=input.sample(1.0/60.0)
	check(analog.move.x>0.1 and analog.move.x<0.8,"analog_not_full_speed")
	Input.action_release("kw3d_right")
	Input.action_press("kw3d_right",0.05)
	check(input.sample(1.0/60.0).move.length()<0.001,"deadzone_no_drift")
	Input.action_release("kw3d_right")
	var key =InputEventJoypadButton.new();key.button_index=JOY_BUTTON_RIGHT_SHOULDER;key.pressed=true
	input._input(key)
	check(input.grenade_serial==1,"gamepad_grenade_binding")
	var reload_key_found:=false
	var reload_pad_found:=false
	for event in InputMap.action_get_events("kw3d_reload"):
		if event is InputEventKey and event.physical_keycode==KEY_R:reload_key_found=true
		if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_X:reload_pad_found=true
	check(reload_key_found and reload_pad_found,"reload_keyboard_gamepad_binding")
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
	input._input(wheel)
	check(input.weapon_slot==1,"mouse_wheel_weapon_switch")
	Input.action_press("kw3d_fire")
	input.suspend()
	check(not input.sample(1.0/60.0).fire,"pause_releases_fire")
	input.settings.look_x=3.4;input.save_settings();input.settings.look_x=1.0;input.load_settings()
	check(is_equal_approx(input.settings.look_x,3.4),"settings_roundtrip")
	input.queue_free()
	var world: Node3D=load("res://scripts/kw3d/authority_world.gd").new();root.add_child(world)
	world.attacks_enabled=false
	world.add_player(1);world.add_player(2)
	for i in range(120):
		world.step();await physics_frame
	check(root.get_camera_3d()==null,"headless_no_camera")
	check(not _has_render_nodes(world),"authority_no_render_or_audio_nodes")
	check(world.alive_bots()==3,"same_arena_bots")
	for actor in world.actors.values():
		check(actor.transform.is_finite(),"finite_actor")
		for foot in actor.locomotion.feet:check(foot.node.global_position.distance_to(actor.global_position)<3.1,"bounded_server_walk")
	world.actors[1].health=50
	world.damage(1000,100,Vector3.FORWARD,1,Vector3.ZERO)
	check(world.actors[1].health==58 and world.actors[1].kills==1,"authoritative_kill_heal")
	world.damage(1000,100,Vector3.FORWARD,1,Vector3.ZERO)
	check(world.actors[1].kills==1,"no_double_kill")
	world.detach_player(2)
	check(not world.actors[2].command.fire,"disconnect_neutral")
	# Server-owned blast: one damage event per actor, occlusion, kill ownership, cooldown.
	var alive_ids: Array=[]
	for id in world.actors:
		if world.actors[id].is_bot and world.actors[id].health>0:alive_ids.append(id)
	var victim: Node3D=world.actors[alive_ids[0]]
	var protected: Node3D=world.actors[alive_ids[1]]
	victim.global_position=Vector3(0,1.735,65)
	protected.global_position=Vector3(4,1.735,65)
	victim.locomotion.reset();protected.locomotion.reset();victim.update_shapes();protected.update_shapes()
	var wall =StaticBody3D.new();world.add_child(wall);wall.position=Vector3(2,2,65)
	var shape =CollisionShape3D.new();var box =BoxShape3D.new();box.size=Vector3(0.25,6,5);shape.shape=box;wall.add_child(shape)
	for i in range(2):await physics_frame
	var before: float=protected.health
	world.explode(Vector3(0,1.45,65),1,90001)
	check(victim.health==0,"server_blast_center_lethal")
	check(protected.health==before,"server_blast_cover")
	var kills_before: int=world.actors[1].kills
	world.explode(Vector3(0,1.45,65),1,90001)
	check(world.actors[1].kills==kills_before,"duplicate_blast_ignored")
	var shooter: Node3D=world.actors[1]
	shooter.position=Vector3(0,2,6);shooter.command={"yaw":0.0,"pitch":0.0,"aim":false,"side":-1.0}
	shooter.build_aim(world.get_world_3d().direct_space_state,1.0/60.0)
	world._throw(shooter)
	check(world.grenades.size()==1 and shooter.grenade_clock==6.0,"server_throw_and_cooldown")
	check(world.grenade_bodies.values()[0].get_child(0).shape is SphereShape3D,"swept_grenade_sphere")
	for i in range(80):world._tick_grenades();await physics_frame
	check(world.grenades.is_empty() and world.grenade_bodies.is_empty(),"fuse_cleanup")
	shooter.hurt(100,Vector3.FORWARD)
	check(not world.respawn(1),"respawn_grace")
	shooter.death_clock=3.1
	check(world.respawn(1) and shooter.health==100 and shooter.kills==kills_before,"per_actor_respawn_keeps_score")
	check(not _has_render_nodes(world),"grenade_authority_render_free")
	print("ONLINE_FOUNDATION_UNIT_","PASS" if failures.is_empty() else "FAIL",failures)
	world.free()
	quit(0 if failures.is_empty() else 1)
func _has_render_nodes(node: Node) -> bool:
	if node is VisualInstance3D or node is Camera3D or node is CanvasLayer or node is AudioStreamPlayer or node is AudioStreamPlayer3D:return true
	for c in node.get_children():
		if _has_render_nodes(c):return true
	return false
