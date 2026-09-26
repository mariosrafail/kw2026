extends Node
## Device adapters -> portable actions -> one command stream. Runtime registration leaves project.godot alone.
signal action_requested(action: String)
signal device_lost
signal binding_changed
const PREFIX:="kw3d_"
const AK_RECOIL:=preload("res://scripts/kw3d/ak_recoil.gd")
var recoil_model =AK_RECOIL.new()
var enabled =false
var focused =true
var last_device ="keyboard"
var pad_id =-1
var yaw =0.0
var pitch =-0.174533
var side =1.0
var weapon_slot =0
var inspect_requested=false
var jump_serial =0
var grenade_serial =0
var sequence =0
var sprint_latched =false
var aim_latched =false
var rebind_action =""
var config_path ="user://kw3d_controls.cfg"
var settings: Dictionary={"look_x":2.6,"look_y":2.1,"deadzone":0.16,"look_curve":1.5,"ads":0.78,"invert_y":false,"aim_toggle":false,"sprint_toggle":true,"vibration":0.4}
var overrides: Dictionary={}
var fov =74.0
const KEYS: Dictionary={"left":KEY_A,"right":KEY_D,"forward":KEY_W,"back":KEY_S,"jump":KEY_SPACE,"sprint":KEY_SHIFT,"grenade":KEY_G,"skill":KEY_E,"reload":KEY_R,"inspect":KEY_H,"shoulder":KEY_Q,"pause":KEY_ESCAPE,"help":KEY_TAB,"music":KEY_M,"comic":KEY_O,"pixels":KEY_P,"borderlands":KEY_Y}
const BUTTONS: Dictionary={"jump":JOY_BUTTON_A,"sprint":JOY_BUTTON_LEFT_STICK,"grenade":JOY_BUTTON_RIGHT_SHOULDER,"skill":JOY_BUTTON_LEFT_SHOULDER,"reload":JOY_BUTTON_X,"inspect":JOY_BUTTON_Y,"weapon_next":JOY_BUTTON_DPAD_RIGHT,"weapon_prev":JOY_BUTTON_DPAD_LEFT,"shoulder":JOY_BUTTON_RIGHT_STICK,"pause":JOY_BUTTON_START,"help":JOY_BUTTON_BACK}
func _ready() -> void:
	name="PortableInput"
	load_settings()
	register_actions()
	Input.joy_connection_changed.connect(_joy_connection)
	var devices =Input.get_connected_joypads()
	if not devices.is_empty():pad_id=devices[0]
	Input.ignore_joypad_on_unfocused_application=true

func add_event(action: String,event: InputEvent) -> void:
	event.device=-1
	if not InputMap.has_action(PREFIX+action):InputMap.add_action(PREFIX+action,0.18)
	InputMap.action_add_event(PREFIX+action,event)
func _ensure_ui_button(action: String, button_index: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for old in InputMap.action_get_events(action):
		if old is InputEventJoypadButton and old.button_index == button_index:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	event.device = -1
	InputMap.action_add_event(action,event)

func register_actions() -> void:
	# Godot's built-in navigation already has d-pad/stick, but this project did
	# not have controller accept/cancel. Add them at runtime so retail menus are
	# fully usable without touching project.godot or requiring a mouse.
	_ensure_ui_button("ui_accept",JOY_BUTTON_A)
	_ensure_ui_button("ui_cancel",JOY_BUTTON_B)
	for action in InputMap.get_actions():
		if str(action).begins_with(PREFIX):InputMap.action_erase_events(action)
	for key in KEYS:
		if InputMap.has_action(PREFIX+key):InputMap.action_erase_events(PREFIX+key)
		var e =InputEventKey.new();e.physical_keycode=KEYS[key];add_event(key,e)
	for key in BUTTONS:
		var e =InputEventJoypadButton.new();e.button_index=BUTTONS[key];add_event(key,e)
	for row in [["left",JOY_AXIS_LEFT_X,-1.0],["right",JOY_AXIS_LEFT_X,1.0],["forward",JOY_AXIS_LEFT_Y,-1.0],["back",JOY_AXIS_LEFT_Y,1.0],["look_left",JOY_AXIS_RIGHT_X,-1.0],["look_right",JOY_AXIS_RIGHT_X,1.0],["look_up",JOY_AXIS_RIGHT_Y,-1.0],["look_down",JOY_AXIS_RIGHT_Y,1.0],["fire",JOY_AXIS_TRIGGER_RIGHT,1.0],["aim",JOY_AXIS_TRIGGER_LEFT,1.0]]:
		var e =InputEventJoypadMotion.new();e.axis=row[1];e.axis_value=row[2];add_event(row[0],e)
	for row in [["fire",MOUSE_BUTTON_LEFT],["aim",MOUSE_BUTTON_RIGHT]]:
		var e =InputEventMouseButton.new();e.button_index=row[1];add_event(row[0],e)
	for key in overrides:
		if typeof(key)!=TYPE_STRING or not overrides[key] is Dictionary:continue
		var action_name: String=str(key).get_slice("/",0)
		if action_name not in KEYS and action_name not in ["fire","aim"]:continue
		if action_name in ["pause","help"]:continue
		var entry: Dictionary=overrides[key]
		var event: InputEvent=decode_binding(entry)
		if event!=null:_replace_binding(str(key).get_slice("/",0),event)

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value)>0.25:
			last_device="pad";pad_id=event.device
	elif event is InputEventMouseMotion or event is InputEventKey or event is InputEventMouseButton:last_device="keyboard"
	if not rebind_action.is_empty():
		if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:rebind_action="";binding_changed.emit();get_viewport().set_input_as_handled();return
		if event.is_pressed() and not event.is_echo() and (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton):
			_replace_binding(rebind_action,event)
			var family: String="pad" if event is InputEventJoypadButton else "keyboard"
			overrides[rebind_action+"/"+family]=encode_binding(event)
			rebind_action="";save_settings();binding_changed.emit();get_viewport().set_input_as_handled()
		return
	if event.is_echo():return
	if event.is_action_pressed(PREFIX+"pause"):
		action_requested.emit("pause");get_viewport().set_input_as_handled();return
	if not enabled or not focused:return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		weapon_slot=posmod(weapon_slot+(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1),4)
		action_requested.emit("weapon")
		get_viewport().set_input_as_handled();return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		var ratio =tan(deg_to_rad(fov)*0.5)/tan(deg_to_rad(74.0)*0.5)
		var delta_yaw: float =-event.screen_relative.x*0.0016*ratio
		var delta_pitch: float =-event.screen_relative.y*0.0013*ratio*(-1.0 if settings.invert_y else 1.0)
		yaw+=delta_yaw;pitch+=delta_pitch
		recoil_model.note_manual_look(delta_yaw,delta_pitch)
	for action in ["jump","grenade","skill","inspect","weapon_next","weapon_prev","shoulder","sprint","aim","help","music","comic","pixels","borderlands"]:
		if event.is_action_pressed(PREFIX+action):
			match action:
				"jump":jump_serial+=1
				"grenade":grenade_serial+=1
				"inspect":action_requested.emit("inspect")
				"weapon_next":weapon_slot=posmod(weapon_slot+1,4);action_requested.emit("weapon")
				"weapon_prev":weapon_slot=posmod(weapon_slot-1,4);action_requested.emit("weapon")
				"shoulder":side=1.0
				"sprint":sprint_latched=not sprint_latched
				"aim":aim_latched=not aim_latched
				_:action_requested.emit(action)
	pitch=clampf(pitch,-0.837758,0.523599);yaw=wrapf(yaw,-PI,PI)

func sample(dt: float) -> Dictionary:
	var move =Vector2.ZERO
	var aiming =false
	var firing =false
	var reloading =false
	var sprint =false
	if enabled and focused:
		move=Input.get_vector(PREFIX+"left",PREFIX+"right",PREFIX+"back",PREFIX+"forward",float(settings.deadzone))
		var look =Input.get_vector(PREFIX+"look_left",PREFIX+"look_right",PREFIX+"look_up",PREFIX+"look_down",float(settings.deadzone))
		var magnitude =look.length()
		if magnitude>0:look=look.normalized()*pow(magnitude,float(settings.look_curve))
		aiming=aim_latched if settings.aim_toggle else Input.is_action_pressed(PREFIX+"aim")
		firing=Input.is_action_pressed(PREFIX+"fire")
		reloading=Input.is_action_pressed(PREFIX+"reload")
		var multiplier: float=settings.ads if aiming else 1.0
		var delta_yaw: float =-look.x*float(settings.look_x)*dt*multiplier
		var delta_pitch: float =-look.y*float(settings.look_y)*dt*multiplier*(-1.0 if settings.invert_y else 1.0)
		yaw+=delta_yaw;pitch+=delta_pitch
		recoil_model.note_manual_look(delta_yaw,delta_pitch)
		var recovery: Vector2=recoil_model.step(dt,firing)
		yaw+=recovery.x;pitch+=recovery.y
		sprint=sprint_latched if settings.sprint_toggle and last_device=="pad" else Input.is_action_pressed(PREFIX+"sprint")
		if move.length()<0.05:sprint_latched=false;sprint=false
	yaw=wrapf(yaw,-PI,PI);pitch=clampf(pitch,-0.837758,0.523599)
	side=1.0
	sequence+=1
	return {"seq":sequence,"ct":sequence,"js":jump_serial,"gs":grenade_serial,"move":move,"yaw":yaw,"pitch":pitch,"side":side,"fire":firing,"aim":aiming,"sprint":sprint,"reload":reloading,"weapon":weapon_slot}

func apply_weapon_recoil(aiming: bool) -> Vector2:
	var kick: Vector2=recoil_model.kick(aiming)
	yaw=wrapf(yaw+kick.x,-PI,PI);pitch=clampf(pitch+kick.y,-0.837758,0.523599)
	return kick

func reset_weapon_recoil() -> void:
	recoil_model.reset()

func suspend() -> void:
	enabled=false;sprint_latched=false;aim_latched=false;recoil_model.reset()
	for key in InputMap.get_actions():
		if str(key).begins_with(PREFIX):Input.action_release(key)
	if pad_id>=0:Input.stop_joy_vibration(pad_id)

func _joy_connection(id: int,present: bool) -> void:
	if present and pad_id<0:
		pad_id=id
		# Do not force-enable here: online menus intentionally control enabled state.
		# Offline adapters that were already enabled remain enabled across reconnects.
	elif not present and id==pad_id:
		pad_id=-1
		sprint_latched=false;aim_latched=false;recoil_model.reset()
		device_lost.emit()

func rumble(strength: float,duration: float=0.08) -> void:
	if last_device=="pad" and pad_id>=0 and enabled and focused and not OS.get_cmdline_user_args().has("--kw-qa"):
		Input.start_joy_vibration(pad_id,strength*float(settings.vibration),strength*float(settings.vibration)*0.55,duration)

func prompt() -> String:
	if last_device!="pad":return "WASD move  |  LMB fire  |  RMB aim  |  E skill  |  G grenade  |  wheel weapon  |  Esc menu"
	var sony =pad_id>=0 and ("Dual" in Input.get_joy_name(pad_id) or "PS" in Input.get_joy_name(pad_id))
	return "Sticks move/look  |  R2/L2 fire/aim  |  L1 skill  |  R1 grenade  |  D-pad weapons  |  Options" if sony else "Sticks move/look  |  RT/LT fire/aim  |  LB skill  |  RB grenade  |  D-pad weapons  |  Menu"

func _replace_binding(action: String,event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.button_index in [JOY_BUTTON_START,JOY_BUTTON_BACK]:return
	if event is InputEventKey and event.physical_keycode in [KEY_ESCAPE,KEY_TAB]:return
	var pad =event is InputEventJoypadButton or event is InputEventJoypadMotion
	for old in InputMap.action_get_events(PREFIX+action):
		if (old is InputEventJoypadButton or old is InputEventJoypadMotion)==pad:InputMap.action_erase_event(PREFIX+action,old)
	add_event(action,event.duplicate())
func encode_binding(e: InputEvent) -> Dictionary:
	if e is InputEventKey:return {"kind":"key","code":e.physical_keycode}
	if e is InputEventMouseButton:return {"kind":"mouse","code":e.button_index}
	if e is InputEventJoypadButton:return {"kind":"button","code":e.button_index}
	return {}
func decode_binding(d: Dictionary) -> InputEvent:
	var code: int=int(d.get("code",-1))
	if code<0:return null
	match d.get("kind",""):
		"key":
			var e =InputEventKey.new();e.physical_keycode=code;return e
		"mouse":
			if code>9:return null
			var e =InputEventMouseButton.new();e.button_index=code;return e
		"button":
			if code>=JOY_BUTTON_MAX:return null
			var e =InputEventJoypadButton.new();e.button_index=code;return e
	return null
func load_settings() -> void:
	var c =ConfigFile.new()
	if c.load(config_path)!=OK:return
	for key in settings:
		var v: Variant=c.get_value("controls",key,settings[key])
		if typeof(v)==typeof(settings[key]):settings[key]=v
	settings.deadzone=clampf(settings.deadzone,0.05,0.40)
	settings.look_x=clampf(settings.look_x,0.5,6);settings.look_y=clampf(settings.look_y,0.5,6)
	settings.ads=clampf(settings.ads,0.25,1.5);settings.look_curve=clampf(settings.look_curve,1,3)
	settings.vibration=clampf(settings.vibration,0,1)
	var saved: Variant=c.get_value("bindings","overrides",{})
	if saved is Dictionary:overrides=saved
func save_settings() -> void:
	var c =ConfigFile.new()
	for key in settings:c.set_value("controls",key,settings[key])
	c.set_value("bindings","overrides",overrides)
	var error =c.save(config_path)
	if error!=OK:push_warning("Controls could not be saved: "+str(error))

func reset_defaults() -> void:
	overrides.clear()
	settings={"look_x":2.6,"look_y":2.1,"deadzone":0.16,"look_curve":1.5,"ads":0.78,"invert_y":false,"aim_toggle":false,"sprint_toggle":true,"vibration":0.4}
	register_actions();save_settings();binding_changed.emit()
