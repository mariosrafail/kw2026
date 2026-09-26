extends SceneTree
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	if not v:
		failures.append(label);push_error("OFFLINE_CONTROLLER_FAIL "+label)
func _initialize()->void:run.call_deferred()

func _has_axis(action: String,axis: int)->bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadMotion and event.axis==axis:return true
	return false
func _has_button(action: String,button: int)->bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and event.button_index==button:return true
	return false

func run()->void:
	ProjectSettings.set_setting("kw3d/offline_test_mode","sandbox")
	var stage=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(12):await physics_frame
	stage.combat.set_training_mode(true);stage.combat.set_roaming_enabled(false)
	stage.set_physics_process(false)
	var adapter=stage.offline_input_adapter
	check(adapter!=null and adapter.enabled,"offline_adapter_enabled")
	var ids:=Input.get_connected_joypads()
	print("OFFLINE_CONTROLLER_REAL_IDS ",ids)
	if "--require-pad" in OS.get_cmdline_user_args():
		check(not ids.is_empty(),"real_controller_detected")
	if not ids.is_empty():
		check("XInput" in Input.get_joy_name(ids[0]) or "Xbox" in str(Input.get_joy_info(ids[0]).get("raw_name","")),"real_xinput_controller")

	check(_has_axis("kw3d_left",JOY_AXIS_LEFT_X) and _has_axis("kw3d_forward",JOY_AXIS_LEFT_Y),"left_stick_mapped")
	check(_has_axis("kw3d_look_left",JOY_AXIS_RIGHT_X) and _has_axis("kw3d_look_up",JOY_AXIS_RIGHT_Y),"right_stick_mapped")
	check(_has_axis("kw3d_fire",JOY_AXIS_TRIGGER_RIGHT) and _has_axis("kw3d_aim",JOY_AXIS_TRIGGER_LEFT),"triggers_mapped")
	check(_has_button("kw3d_jump",JOY_BUTTON_A),"jump_a_mapped")
	check(_has_button("kw3d_reload",JOY_BUTTON_X),"reload_x_mapped")
	check(_has_button("kw3d_inspect",JOY_BUTTON_Y),"inspect_y_mapped")
	check(_has_button("kw3d_grenade",JOY_BUTTON_RIGHT_SHOULDER),"grenade_rb_mapped")
	check(_has_button("kw3d_weapon_next",JOY_BUTTON_DPAD_RIGHT) and _has_button("kw3d_weapon_prev",JOY_BUTTON_DPAD_LEFT),"dpad_weapon_mapped")

	var device:=ids[0] if not ids.is_empty() else 0
	adapter.pad_id=device;adapter.last_device="pad";adapter.enabled=true
	Input.action_press("kw3d_right",1.0)
	stage._physics_process(1.0/60.0)
	check(stage.player.velocity.x>0.05,"pad_move_reaches_offline_motor")
	Input.action_release("kw3d_right")

	var aim_before: float=stage.yaw
	Input.action_press("kw3d_look_right",0.8)
	Input.action_press("kw3d_aim",1.0)
	stage._physics_process(1.0/60.0)
	check(stage.aiming,"pad_left_trigger_aims")
	check(absf(stage.yaw-aim_before)>0.0001,"pad_right_stick_looks")
	Input.action_release("kw3d_look_right");Input.action_release("kw3d_aim")

	var ammo_before: int=stage.ammo_in_mag
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	Input.action_press("kw3d_fire",1.0)
	stage.shot_cooldown=0.0
	stage._physics_process(1.0/60.0)
	Input.action_release("kw3d_fire")
	stage._physics_process(1.0/60.0)
	check(stage.ammo_in_mag==ammo_before-1,"pad_right_trigger_fires")

	var next:=InputEventJoypadButton.new();next.device=device;next.button_index=JOY_BUTTON_DPAD_RIGHT;next.pressed=true
	adapter._input(next)
	check(stage.weapon_slot==1,"dpad_next_selects_shotgun")
	adapter._input(next)
	check(stage.weapon_slot==2,"dpad_next_selects_kar")
	adapter._input(next)
	check(stage.weapon_slot==3,"dpad_next_selects_launcher")
	var prev:=InputEventJoypadButton.new();prev.device=device;prev.button_index=JOY_BUTTON_DPAD_LEFT;prev.pressed=true
	adapter._input(prev)
	check(stage.weapon_slot==2,"dpad_prev_selects_kar")

	var inspect:=InputEventJoypadButton.new();inspect.device=device;inspect.button_index=JOY_BUTTON_Y;inspect.pressed=true
	adapter._input(inspect)
	check(stage.inspect_time>0.0,"pad_y_starts_inspect")

	var was_enabled: bool=adapter.enabled
	adapter._joy_connection(device,false)
	check(adapter.enabled==was_enabled,"disconnect_does_not_disable_adapter")
	adapter._joy_connection(device,true)
	check(adapter.enabled==was_enabled and adapter.pad_id==device,"reconnect_preserves_enabled_state")

	print("OFFLINE_CONTROLLER_","PASS" if failures.is_empty() else "FAIL",failures,
		" real_pad=",not ids.is_empty()," name=",Input.get_joy_name(device) if not ids.is_empty() else "synthetic")
	stage.queue_free();quit(0 if failures.is_empty() else 1)
