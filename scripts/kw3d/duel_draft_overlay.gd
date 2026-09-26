extends Control
const RULES := preload("res://scripts/kw3d/duel_rules.gd")

var stage: Node3D
var shade: ColorRect
var root_box: VBoxContainer
var title: Label
var status: Label
var cards: GridContainer
var hint: Label
var last_key := ""

func setup(view: Node3D) -> void:
	stage = view
	name = "OverdriveDraft"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/kwFont.ttf")
	theme.default_font_size = 12
	self.theme = theme

	shade = ColorRect.new()
	shade.color = Color(0.025,0.03,0.065,0.93)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	root_box = VBoxContainer.new()
	root_box.add_theme_constant_override("separation",8)
	add_child(root_box)

	title = Label.new()
	title.text = "OVERDRIVE DRAFT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(title)

	status = Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_box.add_child(status)

	cards = GridContainer.new()
	cards.columns = 2
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation",8)
	cards.add_theme_constant_override("v_separation",8)
	root_box.add_child(cards)

	hint = Label.new()
	hint.text = "LOSER PICKS FIRST  //  BUILDS STACK"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.modulate = Color(0.78,0.82,0.92)
	root_box.add_child(hint)

	resized.connect(_layout_overlay)
	call_deferred("_layout_overlay")
	hide()

func _layout_overlay() -> void:
	if root_box == null:return
	var safe_margin := 18.0
	var target := Vector2(
		minf(610.0,maxf(280.0,size.x-safe_margin*2.0)),
		minf(320.0,maxf(200.0,size.y-safe_margin*2.0))
	)
	root_box.size = target
	root_box.position = (size-target)*0.5
	root_box.position.x = clampf(root_box.position.x,safe_margin,maxf(safe_margin,size.x-target.x-safe_margin))
	root_box.position.y = clampf(root_box.position.y,safe_margin,maxf(safe_margin,size.y-target.y-safe_margin))
	var compact := size.x < 620.0 or size.y < 420.0
	var card_count:=maxi(1,cards.get_child_count())
	cards.columns=1 if target.x<430.0 else 2
	var rows:=int(ceil(float(card_count)/float(cards.columns)))
	var overhead:=86.0 if compact else 96.0
	var available_cards:=maxf(92.0,target.y-overhead)
	var card_height:=clampf((available_cards-float(maxi(0,rows-1))*6.0)/float(rows),44.0,82.0 if compact else 92.0)
	title.add_theme_font_size_override("font_size",22 if compact else 26)
	status.add_theme_font_size_override("font_size",12 if compact else 14)
	hint.add_theme_font_size_override("font_size",9 if compact else 10)
	cards.add_theme_constant_override("v_separation",6 if compact else 8)
	for child in cards.get_children():
		if child is Button:
			child.custom_minimum_size = Vector2(0,card_height)
			child.add_theme_font_size_override("font_size",9 if compact else 10)
			child.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _local_hero(room: Dictionary) -> String:
	for p in room.get("players",[]):
		if int(p.get("id",0)) == int(stage.session.actor_id):
			return str(p.get("hero",RULES.OUTRAGE))
	return RULES.OUTRAGE

func _card_style(bg: Color,border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(2)
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 6
	box.corner_radius_bottom_left = 6
	box.corner_radius_bottom_right = 6
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 7
	box.content_margin_bottom = 7
	return box

func _rebuild(room: Dictionary) -> void:
	for child in cards.get_children():child.queue_free()
	var hero := _local_hero(room)
	var mine: bool = int(room.get("draft_chooser",0)) == int(stage.session.actor_id)
	for card_id in room.get("draft_pool",[]):
		var data := RULES.card(str(card_id),hero)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0,94)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.size_flags_vertical = Control.SIZE_EXPAND_FILL
		button.text = str(data.label)+"\n"+str(data.desc)
		button.clip_text = true
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = not mine
		button.focus_mode = Control.FOCUS_ALL if mine else Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size",10)
		button.add_theme_stylebox_override("normal",_card_style(Color(0.10,0.12,0.22,0.98),Color(0.38,0.42,0.68)))
		button.add_theme_stylebox_override("disabled",_card_style(Color(0.08,0.09,0.16,0.96),Color(0.28,0.31,0.48)))
		button.add_theme_stylebox_override("hover",_card_style(Color(0.16,0.13,0.29,1.0),Color(0.93,0.83,0.38)))
		button.add_theme_stylebox_override("focus",_card_style(Color(0.16,0.13,0.29,1.0),Color(0.93,0.83,0.38)))
		button.add_theme_stylebox_override("pressed",_card_style(Color(0.24,0.14,0.30,1.0),Color(1.0,0.42,0.46)))
		var chosen := str(card_id)
		button.pressed.connect(func():stage.choose_augment(chosen))
		cards.add_child(button)
	_layout_overlay()
	if mine:
		for child in cards.get_children():
			if child is Button and not child.disabled:
				child.grab_focus()
				break

func refresh(room: Dictionary) -> void:
	var draft := str(room.get("round_phase","")) == "DRAFT"
	visible = draft
	if not draft:
		last_key = ""
		return
	var chooser := int(room.get("draft_chooser",0))
	var pool: Array = room.get("draft_pool",[])
	var key := str(chooser)+":"+str(pool)+":"+_local_hero(room)
	if key != last_key:
		last_key = key
		_rebuild(room)
	if chooser == int(stage.session.actor_id):
		status.text = "YOUR PICK  //  CHOOSE ONE AUGMENT"
		status.modulate = Color("ffe783")
	else:
		status.text = "RIVAL PICKING  //  GET READY"
		status.modulate = Color("a8b8d8")
