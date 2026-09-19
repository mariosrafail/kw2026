extends SceneTree
var clicked := false
var failures: Array[String] = []
func check(v: bool, label: String) -> void:
	if not v:
		failures.append(label)
		push_error("CLICK_QA_FAIL "+label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var stage=load("res://scenes/prototypes/kw_3d_lan_duel.tscn").instantiate()
	root.add_child(stage)
	for i in range(18): await process_frame
	var menu=stage.client.menu
	var b: Button=menu.create_button
	b.pressed.connect(func(): clicked=true)
	var logical=b.get_global_rect().get_center()
	var physical=root.get_final_transform()*logical
	var motion:=InputEventMouseMotion.new()
	motion.position=physical; motion.global_position=physical
	Input.parse_input_event(motion)
	await process_frame
	var down:=InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; down.position=physical; down.global_position=physical
	Input.parse_input_event(down)
	await process_frame
	var up:=InputEventMouseButton.new()
	up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false; up.position=physical; up.global_position=physical
	Input.parse_input_event(up)
	await create_timer(3.2).timeout
	check(clicked,"pressed_signal")
	check(stage.session.connected,"create_room_connected")
	print("CREATE_BUTTON_MOUSE_QA_", "PASS" if failures.is_empty() else "FAIL", failures, " message=",menu.message.text)
	if stage.session.connected: stage.client.leave_room()
	quit(0 if failures.is_empty() else 1)
