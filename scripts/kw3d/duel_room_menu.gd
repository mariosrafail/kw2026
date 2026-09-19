extends Control
## 3D online room browser rendered as a real KW main-menu screen.
const UI_ANIM := preload("res://scripts/ui/main_menu/ui_animator.gd")
const MENU_PALETTE := preload("res://scripts/ui/main_menu/menu_palette.gd")
const MENU_LOADING_OVERLAY := preload("res://scripts/ui/main_menu/loading/menu_loading_overlay.gd")
const MENU_SKIN := preload("res://scripts/ui/main_menu/kw_menu_skin.gd")

var stage: Node3D
var ui_anim := UI_ANIM.new()
var loading_overlay := MENU_LOADING_OVERLAY.new()
var public_room_button: Button
var panel: PanelContainer
var logo: TextureRect
var title: Label
var message: Label
var room_label: Label
var connection_screen: Control
var room_screen: Control
var address: LineEdit
var port: SpinBox
var slot_one: Label
var slot_two: Label
var ready_button: Button
var start_button: Button
var create_button: Button
var join_button: Button
var leave_button: Button
var controls_button: Button
var quit_button: Button
var last_phase := ""
var last_connected := false
var intro_played := false
var panel_rest_position := Vector2.ZERO

func _style_box(bg: Color, border: Color, bottom: int = 5, shadow: int = 5) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_width_left = 3
	box.border_width_top = 3
	box.border_width_right = 3
	box.border_width_bottom = bottom
	box.border_color = border
	box.shadow_color = Color(0.1569, 0.1098, 0.349, 0.28)
	box.shadow_size = shadow
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

func _panel_style(alpha: float = 0.96) -> StyleBoxFlat:
	return _style_box(Color(0.1216,0.1569,0.2549,alpha), Color(0.9294,0.9686,0.7412,0.96), 4, 6)

func _decorate_button(button: Button, compact: bool = false) -> void:
	# Exact shared skin from main_menu.tscn: same normal/hover/pressed/focus shapes,
	# same palette, same bottom-heavy pixel border and same hover-pop motion.
	MENU_SKIN.apply_button(button, 14 if compact else 18, 34.0 if compact else 40.0)
	ui_anim.add_hover_pop(button)

func _make_button(text_value: String, action: Callable, compact: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	_decorate_button(button, compact)
	button.pressed.connect(func() -> void:
		ui_anim.button_press_anim(self, button, 0.055)
		action.call()
	)
	return button

func _make_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", MENU_SKIN.panel_style(0.88))
	return card

func _make_card_body(card: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	card.add_child(margin)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	return box

func _heading(text_value: String, font_size: int = 18) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.98,0.97,0.84))
	return label

func _body_label(text_value: String, font_size: int = 10) -> Label:
	var label := Label.new()
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.86,0.90,0.94))
	return label

func _decorate_edit(edit: LineEdit) -> void:
	edit.custom_minimum_size.y = 34
	edit.add_theme_font_size_override("font_size", 13)
	edit.add_theme_color_override("font_color", Color(0.98,0.97,0.95))
	edit.add_theme_stylebox_override("normal", _style_box(Color(0.08,0.11,0.18,0.96), Color(0.5216,0.7804,0.6039), 3, 2))
	edit.add_theme_stylebox_override("focus", _style_box(Color(0.10,0.14,0.24,0.98), Color(0.9294,0.9686,0.7412), 3, 4))

func setup(view: Node3D) -> void:
	stage = view
	name = "DuelRoomMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/kwFont.ttf")
	theme.default_font_size = 13
	self.theme = theme
	loading_overlay.configure(self)

	var background := ColorRect.new()
	background.color = Color(0.5248462,0.7325527,0.7741166,0.985)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var noise := TextureRect.new()
	noise.texture = load("res://assets/textures/bullet.png")
	noise.modulate = Color(1,1,1,0.055)
	noise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	noise.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	noise.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(noise)
	noise.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0.1569,0.1098,0.349,0.055)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	panel = PanelContainer.new()
	# No legacy dark modal shell: the room browser itself is now the menu screen.
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = Vector2(600,334)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 16)
	outer_margin.add_theme_constant_override("margin_right", 16)
	outer_margin.add_theme_constant_override("margin_top", 7)
	outer_margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(outer_margin)

	var root_box := VBoxContainer.new()
	root_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_theme_constant_override("separation", 3)
	outer_margin.add_child(root_box)

	var top := HBoxContainer.new()
	top.custom_minimum_size.y = 40
	top.add_theme_constant_override("separation", 10)
	root_box.add_child(top)

	logo = TextureRect.new()
	logo.texture = load("res://assets/textures/textLogo.png")
	logo.custom_minimum_size = Vector2(150,44)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(logo)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(title_box)
	title = _heading("KW // ONLINE ROOMS", 22)
	title_box.add_child(title)
	var mode := _body_label("FIGHT!  /  PUBLIC 1V1  /  FIRST TO 10", 9)
	mode.add_theme_color_override("font_color", Color(0.5216,0.7804,0.6039))
	title_box.add_child(mode)

	message = _body_label("Choose a public room, or use direct LAN as fallback.", 9)
	message.custom_minimum_size.y = 18
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	root_box.add_child(message)

	var screens := Control.new()
	screens.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	screens.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_box.add_child(screens)

	connection_screen = _build_connection_screen()
	screens.add_child(connection_screen)
	connection_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	room_screen = _build_room_screen()
	screens.add_child(room_screen)
	room_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	stage.session.connection_message.connect(_on_connection_message)
	call_deferred("_finish_setup")

func _build_connection_screen() -> Control:
	var screen := Control.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(row)

	# Left side: same room-browser idea as the original lobby overlay.
	var browser_card := _make_card()
	browser_card.size_flags_stretch_ratio = 1.2
	row.add_child(browser_card)
	var browser_box := _make_card_body(browser_card)
	browser_box.add_child(_heading("ONLINE ROOMS", 17))
	var online_status := _body_label("PUBLIC SERVER  /  CLOUDFLARE  /  ONLINE", 9)
	online_status.add_theme_color_override("font_color", MENU_PALETTE.highlight(1.0))
	browser_box.add_child(online_status)

	var list_panel := PanelContainer.new()
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", MENU_SKIN.dark_panel_style(0.38))
	browser_box.add_child(list_panel)
	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 6)
	list_margin.add_theme_constant_override("margin_top", 6)
	list_margin.add_theme_constant_override("margin_right", 6)
	list_margin.add_theme_constant_override("margin_bottom", 6)
	list_panel.add_child(list_margin)
	var list_box := VBoxContainer.new()
	list_box.add_theme_constant_override("separation", 5)
	list_margin.add_child(list_box)

	public_room_button = _make_button("KW PUBLIC DUEL\n3D ARENA 01   /   1V1   /   FIRST TO 10", func() -> void:
		message.text = "PUBLIC ROOM SELECTED  /  CREATE TO CLAIM HOST OR JOIN TO ENTER"
	, true)
	public_room_button.custom_minimum_size.y = 56
	public_room_button.add_theme_font_size_override("font_size", 13)
	public_room_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	public_room_button.add_theme_stylebox_override("normal", MENU_SKIN.button_style("focus"))
	public_room_button.add_theme_color_override("font_color", Color(0.98,0.97,0.95))
	list_box.add_child(public_room_button)

	var note := _body_label("More 3D rooms/maps will appear here as they are added.", 8)
	note.add_theme_color_override("font_color", MENU_PALETTE.text_primary(0.72))
	browser_box.add_child(note)

	var public_actions := HBoxContainer.new()
	public_actions.add_theme_constant_override("separation", 7)
	browser_box.add_child(public_actions)
	create_button = _make_button("CREATE ROOM", func() -> void:
		show_loading("CREATING ONLINE ROOM...")
		stage.create_room()
	)
	create_button.custom_minimum_size.y = 36
	create_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	public_actions.add_child(create_button)
	join_button = _make_button("JOIN ROOM", func() -> void:
		show_loading("JOINING KW ONLINE...")
		stage.join_public_room()
	)
	join_button.custom_minimum_size.y = 36
	join_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	public_actions.add_child(join_button)

	# Right side: compact room info + direct LAN fallback.
	var detail_card := _make_card()
	detail_card.size_flags_stretch_ratio = 0.8
	row.add_child(detail_card)
	var detail_box := _make_card_body(detail_card)
	detail_box.add_child(_heading("ROOM DETAILS", 17))
	var details := _body_label("OUTRAGE 1V1\nFIRST TO 10 KILLS\n3D ARENA 01\nCONTROLLER + KB/M", 10)
	details.add_theme_color_override("font_color", MENU_PALETTE.text_primary(0.96))
	detail_box.add_child(details)

	var online_hint := _body_label("ONLINE WSS\nNO PORT FORWARDING", 9)
	online_hint.add_theme_color_override("font_color", MENU_PALETTE.highlight(1.0))
	detail_box.add_child(online_hint)

	var separator := HSeparator.new()
	detail_box.add_child(separator)
	detail_box.add_child(_heading("DIRECT LAN", 12))

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 5)
	detail_box.add_child(input_row)
	address = LineEdit.new()
	address.text = stage.lan_address()
	address.placeholder_text = "192.168.1.x"
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decorate_edit(address)
	input_row.add_child(address)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = int(stage.options.get("port","18886"))
	port.custom_minimum_size = Vector2(78,34)
	input_row.add_child(port)

	var lan_join := _make_button("JOIN LAN", func() -> void:
		show_loading("CONNECTING TO LAN ROOM...")
		stage.join_lan_room(address.text, int(port.value))
	, true)
	lan_join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_box.add_child(lan_join)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 6)
	detail_box.add_child(bottom)
	controls_button = _make_button("CONTROLS", func(): stage.open_controls_menu(), true)
	controls_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(controls_button)
	quit_button = _make_button("I HATE THIS GAME", func(): get_tree().quit(), true)
	quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(quit_button)
	return screen

func show_loading(text_value: String) -> void:
	if message != null:
		message.text = text_value
	loading_overlay.show(text_value)

func hide_loading() -> void:
	loading_overlay.hide()

func _on_connection_message(text_value: String) -> void:
	if message != null:
		message.text = text_value
	if text_value.begins_with("Connecting"):
		loading_overlay.show("CONNECTING TO KW ONLINE...")
	elif not stage.session.connected:
		loading_overlay.hide()

func _player_card(text_value: String) -> Dictionary:
	var card := _make_card()
	card.custom_minimum_size.y = 70
	var body := _make_card_body(card)
	var label := _heading(text_value, 14)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(label)
	return {"panel":card,"label":label}

func _build_room_screen() -> Control:
	var screen := Control.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(box)

	room_label = _body_label("", 10)
	room_label.add_theme_color_override("font_color", MENU_PALETTE.highlight(1.0))
	box.add_child(room_label)

	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 12)
	player_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(player_row)
	var p1 := _player_card("PLAYER 1  -  EMPTY")
	player_row.add_child(p1.panel)
	slot_one = p1.label
	var p2 := _player_card("PLAYER 2  -  EMPTY")
	player_row.add_child(p2.panel)
	slot_two = p2.label

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	box.add_child(action_row)
	ready_button = _make_button("READY", func(): stage.toggle_ready())
	ready_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(ready_button)
	start_button = _make_button("START MATCH", func(): stage.request_match_start())
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_row.add_child(start_button)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	box.add_child(footer)
	leave_button = _make_button("LEAVE", func(): stage.leave_room(), true)
	leave_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(leave_button)
	controls_button = _make_button("CONTROLS", func(): stage.open_controls_menu(), true)
	controls_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(controls_button)
	quit_button = _make_button("I HATE THIS GAME", func(): get_tree().quit(), true)
	quit_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(quit_button)
	return screen

func _layout_panel() -> void:
	if panel == null:
		return
	var target_size := Vector2(minf(600.0, maxf(320.0, size.x - 24.0)), minf(342.0, maxf(250.0, size.y - 10.0)))
	panel.size = target_size
	panel.position = (size - target_size) * 0.5

func _finish_setup() -> void:
	_layout_panel()
	panel_rest_position = panel.position
	if not resized.is_connected(_on_menu_resized):
		resized.connect(_on_menu_resized)
	open()

func _on_menu_resized() -> void:
	_layout_panel()
	panel_rest_position = panel.position

func _my_ready(room: Dictionary) -> bool:
	for player in room.get("players",[]):
		if int(player.get("id",0)) == stage.session.actor_id:
			return bool(player.get("ready",false))
	return false

func _player_text(index: int, room: Dictionary) -> String:
	var players: Array = room.get("players",[])
	if index >= players.size():
		return "PLAYER %d\nEMPTY" % (index + 1)
	var p: Dictionary = players[index]
	var status := "READY" if p.get("ready",false) else "NOT READY"
	var host := "  HOST" if int(p.get("id",0)) == int(room.get("host",0)) else ""
	return "PLAYER %d  /  OUTRAGE%s
%s" % [index + 1, host, status]

func _apply_slot_visual(label: Label, ready: bool) -> void:
	if label == null or label.get_parent() == null or label.get_parent().get_parent() == null:
		return
	var card := label.get_parent().get_parent() as PanelContainer
	if card == null:
		return
	card.add_theme_stylebox_override("panel", MENU_SKIN.button_style("hover") if ready else MENU_SKIN.panel_style(0.86))
	label.add_theme_color_override("font_color", Color(0.06,0.05,0.08) if ready else Color(0.98,0.97,0.95))

func refresh() -> void:
	if stage == null or stage.session == null:
		return
	var connected: bool = bool(stage.session.connected)
	var room: Dictionary = stage.room_state
	var room_phase := str(room.get("phase","LOBBY"))
	var players: Array = room.get("players",[])
	var me_ready: bool = _my_ready(room)
	var is_host: bool = connected and int(room.get("host",0)) == int(stage.session.actor_id)
	var both_ready: bool = players.size() == 2
	for player in players:
		both_ready = both_ready and bool(player.get("ready",false))

	connection_screen.visible = not connected
	room_screen.visible = connected
	if connected:
		loading_overlay.hide()
		slot_one.text = _player_text(0,room)
		slot_two.text = _player_text(1,room)
		_apply_slot_visual(slot_one, players.size() > 0 and bool(players[0].get("ready",false)))
		_apply_slot_visual(slot_two, players.size() > 1 and bool(players[1].get("ready",false)))
		ready_button.visible = room_phase != "MATCH"
		start_button.visible = room_phase != "MATCH" and is_host
		ready_button.text = "UNREADY" if me_ready else "READY"
		start_button.disabled = not both_ready
		var host_text := "YOU ARE HOST" if is_host else "CONNECTED TO HOST"
		var endpoint_text := "CLOUDFLARE WSS" if str(stage.session.server_host).begins_with("wss://") else ("%s:%d" % [stage.lan_address() if is_host else stage.session.server_host, int(port.value)])
		room_label.text = "%s  /  %s" % [host_text,endpoint_text]
		if room_phase == "RESULT":
			message.text = "MATCH OVER  -  OUTRAGE %d WINS. READY UP FOR REMATCH." % int(room.get("winner",0))
		elif players.size() < 2:
			message.text = "ROOM OPEN  /  WAITING FOR PLAYER 2"
		elif not both_ready:
			message.text = "BOTH PLAYERS MUST READY"
		else:
			message.text = "BOTH READY  /  HOST CAN START"
	else:
		message.text = "Choose a public room, or use direct LAN as fallback."

	if connected != last_connected:
		last_connected = connected
		_animate_screen_swap(connection_screen if not connected else room_screen)
	if room_phase != last_phase:
		last_phase = room_phase
		if visible:
			_focus_best()

func _animate_screen_swap(target: Control) -> void:
	if target == null:
		return
	target.modulate = Color(1,1,1,0)
	target.position = Vector2(18,0)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(target,"position",Vector2.ZERO,0.24)
	tween.parallel().tween_property(target,"modulate:a",1.0,0.15)

func _focus_best() -> void:
	if not stage.session.connected:
		create_button.grab_focus()
	elif ready_button.visible and not ready_button.disabled:
		ready_button.grab_focus()
	elif start_button.visible and not start_button.disabled:
		start_button.grab_focus()
	elif leave_button.visible:
		leave_button.grab_focus()

func _animate_intro() -> void:
	if panel == null:
		return
	panel.pivot_offset = panel.size * 0.5
	panel.modulate = Color(1,1,1,0)
	panel.scale = Vector2(0.94,0.94)
	panel.position = panel_rest_position + Vector2(0,14)
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel,"position",panel_rest_position,0.32)
	tween.parallel().tween_property(panel,"scale",Vector2.ONE,0.32)
	tween.parallel().tween_property(panel,"modulate:a",1.0,0.16)
	if logo != null:
		logo.pivot_offset = logo.size * 0.5
		logo.scale = Vector2(0.92,0.92)
		var logo_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		logo_tween.tween_property(logo,"scale",Vector2(1.04,1.04),0.20)
		logo_tween.tween_property(logo,"scale",Vector2.ONE,0.16)

func open() -> void:
	show()
	refresh()
	_focus_best()
	if not intro_played:
		intro_played = true
		call_deferred("_animate_intro")
