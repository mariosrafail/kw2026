extends SceneTree
var failures: Array[String]=[]
var output=""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="):output=arg.trim_prefix("--qa-output=")
	run.call_deferred()
func check(value: bool,reason: String) -> void:
	if not value:failures.append(reason);push_error("ONLINE_UI_FAIL "+reason)
func run() -> void:
	var entry =Node3D.new();entry.name="KW3DOnline";root.add_child(entry)
	var session=load("res://scripts/kw3d/online_session.gd").new();entry.add_child(session)
	var client=load("res://scripts/kw3d/online_client.gd").new()
	client.session=session;client.options={"profile":"qa_ui"};entry.add_child(client)
	for i in range(5):await process_frame
	check(client.menu.visible,"connection_menu_visible")
	var before: Control=root.gui_get_focus_owner()
	check(before!=null,"initial_controller_focus")
	var down =InputEventJoypadButton.new();down.device=0;down.button_index=JOY_BUTTON_DPAD_DOWN;down.pressed=true
	Input.parse_input_event(down)
	for i in range(3):await process_frame
	down.pressed=false;Input.parse_input_event(down)
	check(root.gui_get_focus_owner()!=before,"dpad_navigates_native_ui")
	client.input_adapter.rebind_action="grenade"
	var key =InputEventKey.new();key.physical_keycode=KEY_H;key.pressed=true
	client.input_adapter._input(key)
	check(client.input_adapter.rebind_action.is_empty(),"rebind_finishes")
	var found =false
	for event in InputMap.action_get_events("kw3d_grenade"):
		if event is InputEventKey and event.physical_keycode==KEY_H:found=true
	check(found,"keyboard_rebinding")
	var pad_found =false
	for event in InputMap.action_get_events("kw3d_grenade"):
		if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_RIGHT_SHOULDER:pad_found=true
	check(pad_found,"rebind_preserves_other_device")
	client.input_adapter.reset_defaults()
	client.input_adapter.register_actions()
	var count =InputMap.action_get_events("kw3d_fire").size()
	client.input_adapter.register_actions()
	check(InputMap.action_get_events("kw3d_fire").size()==count,"no_duplicate_action_events")
	client.input_adapter.enabled=true;client.input_adapter.pad_id=0
	client.input_adapter._joy_connection(0,false)
	check(not client.input_adapter.enabled and client.menu.visible,"unplug_neutralizes_and_opens_menu")
	client.combat.director.health=0;client.combat.director.dead=true
	client.local_state={"hp":0.0,"respawn_left":1.5}
	client.menu.refresh()
	check(client.menu.respawn_button.disabled,"respawn_button_obeys_server_timer")
	check(root.get_visible_rect().size.x>0,"ui_laid_out")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("online_controller_menu.png"))
	entry.queue_free()
	for i in range(4):await process_frame
	print("ONLINE_CONTROLLER_UI_","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
