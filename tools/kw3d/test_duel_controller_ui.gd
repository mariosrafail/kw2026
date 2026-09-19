extends SceneTree
var pressed := false
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	var stage=load("res://scenes/prototypes/kw_3d_lan_duel.tscn").instantiate()
	root.add_child(stage)
	for i in range(5): await process_frame
	var has_a := false
	var has_b := false
	for event in InputMap.action_get_events("ui_accept"):
		if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_A: has_a=true
	for event in InputMap.action_get_events("ui_cancel"):
		if event is InputEventJoypadButton and event.button_index==JOY_BUTTON_B: has_b=true
	var probe := Button.new()
	probe.text="PAD ACCEPT PROBE"
	root.add_child(probe)
	probe.pressed.connect(func(): pressed=true)
	probe.grab_focus()
	var input := InputEventJoypadButton.new()
	input.button_index=JOY_BUTTON_A
	input.pressed=true
	input.device=0
	Input.parse_input_event(input)
	await process_frame
	input.pressed=false
	Input.parse_input_event(input)
	await process_frame
	var focus_ok: bool = stage.client.menu.create_button.focus_mode!=Control.FOCUS_NONE
	print("DUEL_CONTROLLER_UI ",{"ui_accept_a":has_a,"ui_cancel_b":has_b,"button_pressed":pressed,"room_focusable":focus_ok})
	quit(0 if has_a and has_b and pressed and focus_ok else 1)
