extends Control
## Controller-navigable connection/settings menu. Opening it never pauses the authority.
var stage: Node3D
var list: VBoxContainer
var address: LineEdit
var port: SpinBox
var message: Label
var resume_button: Button
var respawn_button: Button
var pad_notice: Label
func setup(view: Node3D) -> void:
	stage=view;name="OnlineMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade =ColorRect.new();shade.color=Color(0.02,0.025,0.05,0.93)
	add_child(shade);shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel =PanelContainer.new();add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left=70;panel.offset_right=-70;panel.offset_top=12;panel.offset_bottom=-12
	var scroll =ScrollContainer.new();scroll.follow_focus=true;panel.add_child(scroll)
	list=VBoxContainer.new();list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",5);scroll.add_child(list)
	var title =Label.new();title.text="KW / 3D CO-OP - NETWORK PROOF";title.add_theme_font_size_override("font_size",18);list.add_child(title)
	message=Label.new();message.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;message.custom_minimum_size.x=360
	message.text="Start a local session, or join the same server as your friend.\nEsc / Start returns here. The online match keeps running.";list.add_child(message)
	resume_button=button("Resume game",func():stage.set_menu(false))
	button("Start local session (this PC)",func():stage.start_local_session())
	var row =HBoxContainer.new();list.add_child(row)
	address=LineEdit.new();address.text=str(stage.options.get("host","127.0.0.1"));address.placeholder_text="Server IP";address.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(address)
	port=SpinBox.new();port.min_value=1024;port.max_value=65535;port.value=int(stage.options.get("port","18886"));row.add_child(port)
	button("Join server",func():stage.connect_server(address.text,int(port.value)))
	button("Reconnect / keep my actor",func():stage.session.reconnect())
	respawn_button=button("Respawn (3 seconds after defeat)",func():stage.session.request_respawn();stage.set_menu(false))
	button("Disconnect",func():stage.session.close_connection(false);stage.clear_session_view();message.text="Disconnected. Rejoin within 30 seconds to recover this actor.")
	pad_notice=Label.new();pad_notice.text="Mouse + keyboard and gamepad supported";list.add_child(pad_notice)
	var heading =Label.new();heading.text="CONTROLS / ACCESSIBILITY";list.add_child(heading)
	setting_slider("Horizontal sensitivity","look_x",0.5,6.0,0.1)
	setting_slider("Vertical sensitivity","look_y",0.5,6.0,0.1)
	setting_slider("ADS sensitivity","ads",0.25,1.5,0.05)
	setting_slider("Stick deadzone","deadzone",0.05,0.4,0.01)
	setting_slider("Vibration strength","vibration",0,1,0.1)
	setting_check("Invert vertical look","invert_y")
	setting_check("Toggle aim instead of hold","aim_toggle")
	setting_check("Toggle sprint on gamepad","sprint_toggle")
	for item in [["left","Rebind Move Left"],["right","Rebind Move Right"],["forward","Rebind Move Forward"],["back","Rebind Move Back"],["jump","Rebind Jump"],["grenade","Rebind Grenade"],["fire","Rebind Fire"],["aim","Rebind Aim"],["shoulder","Rebind Shoulder"],["sprint","Rebind Sprint"]]:
		button(item[1],_begin_rebind.bind(item[0]))
	button("Reset control defaults",func():stage.input_adapter.reset_defaults();message.text="Defaults restored. Settings apply immediately.")
	button("Music ON / OFF",func():stage.arena_audio.toggle_music())
	button("Comic shader ON / OFF",func():stage._set_comic_enabled(not stage.comic_enabled))
	button("Pixel look ON / OFF",func():stage._set_pixel_enabled(not stage.pixel_enabled))
	button("Show / hide instructions",func():stage._toggle_instructions())
	button("Quit this client",func():get_tree().quit())
	stage.input_adapter.binding_changed.connect(func():message.text="Binding saved. Use Esc / Start to return to play.")
	stage.session.connection_message.connect(func(text):message.text=text)

func button(text: String,action: Callable) -> Button:
	var b =Button.new();b.text=text;b.custom_minimum_size.y=25
	b.add_theme_font_size_override("font_size",13);b.pressed.connect(action);list.add_child(b);return b
func setting_slider(title: String,key: String,minimum: float,maximum: float,step: float) -> void:
	var label =Label.new();label.text=title;list.add_child(label)
	var s =HSlider.new();s.min_value=minimum;s.max_value=maximum;s.step=step;s.value=float(stage.input_adapter.settings[key]);s.custom_minimum_size.y=20;list.add_child(s)
	s.value_changed.connect(func(value):stage.input_adapter.settings[key]=value;stage.input_adapter.save_settings())
func setting_check(title: String,key: String) -> void:
	var c =CheckButton.new();c.text=title;c.button_pressed=stage.input_adapter.settings[key];list.add_child(c)
	c.toggled.connect(func(value):stage.input_adapter.settings[key]=value;stage.input_adapter.save_settings())
func _begin_rebind(action: String) -> void:
	stage.input_adapter.rebind_action=action
	message.text="Press a key, mouse button or controller button for "+action+". Esc cancels."
func open() -> void:
	show();resume_button.disabled=not stage.session.connected
	message.text=stage.session.connection_state+"\nOnline enemies do not pause while this menu is open."
	pad_notice.text=stage.input_adapter.prompt()
	if not resume_button.disabled:resume_button.grab_focus()
	else:
		for child in list.get_children():
			if child is Button and not child.disabled:child.grab_focus();break

func refresh() -> void:
	if respawn_button==null:return
	var dead: bool=stage.local_state.get("hp",100.0)<=0
	var remaining: float=stage.local_state.get("respawn_left",0.0)
	respawn_button.disabled=not stage.session.connected or not dead or remaining>0
	respawn_button.text="Respawn in %.1fs"%remaining if dead and remaining>0 else "Respawn now" if dead else "Respawn (only after defeat)"
