extends Control
## Crisp combat feedback above the pixel pass; never changes aim or damage.
var stage: Node3D
var hp_fill: ColorRect
var hp_trail: ColorRect
var hp_text: Label
var heal_text: Label
var banner: Label
var banner_detail: Label
var game_over_panel: Control
var death_stats: Label
var damage_labels: Array[Dictionary] = []
var damage_label_pool: Array[Label] = []
var edges: Array[ColorRect] = []
var damage_direction_arrow: Polygon2D
var damage_direction_time := 0.0
var damage_direction_ui := Vector2.UP
var damage_direction_strength := 1.0
var kill_feed_root: Control
var kill_feed: Array[Dictionary] = []
var kill_feed_pool: Array[Label] = []
var round_card: PanelContainer
var round_card_title: Label
var round_card_score: Label
var round_card_detail: Label
var round_card_time := 0.0
var round_card_duration := 0.0
var countdown_label: Label
var countdown_time := 0.0
var countdown_duration := 0.0
var health := 100.0
var max_health := 100.0
var trail_health := 100.0
var trail_delay := 0.0
var hurt_time := 0.0
var heal_time := 0.0
var banner_time := 0.0
var number_index := 0

func setup(owner_stage: Node3D) -> void:
	stage = owner_stage
	name = "ArenaFeedback"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := Control.new()
	panel.name = "PlayerHealth"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 12
	panel.offset_right = 234
	panel.offset_top = -59
	panel.offset_bottom = -12
	_rect(panel,Rect2(0,0,222,47),Color("111827"))
	_rect(panel,Rect2(0,0,3,47),Color("63e8bf"))
	hp_text = _label(panel,"OUTRAGE   100 / 100",13,Color.WHITE)
	hp_text.position = Vector2(11,5)
	_rect(panel,Rect2(10,29,202,10),Color("3b2434"))
	hp_trail = _rect(panel,Rect2(10,29,202,10),Color("ffc583"))
	hp_fill = _rect(panel,Rect2(10,29,202,10),Color("63e8bf"))
	for i in range(1,10): _rect(panel,Rect2(10+i*20.2,29,1,10),Color(0.03,0.06,0.08,0.55))
	heal_text = _label(panel,"",14,Color("86ffbc"))
	heal_text.position = Vector2(9,-23)
	heal_text.size = Vector2(210,23)
	banner = _label(self,"",21,Color("fff0b8"))
	banner.name = "WaveBanner"
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(340,32)
	banner_detail = _label(self,"",11,Color("acced6"))
	banner_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_detail.size = Vector2(340,20)
	for i in range(4):
		var edge := _rect(self,Rect2(),Color("ff334f"))
		edge.modulate.a = 0.0
		edges.append(edge)
	damage_direction_arrow = Polygon2D.new()
	damage_direction_arrow.name = "DamageDirection"
	damage_direction_arrow.polygon = PackedVector2Array([Vector2(-13,8),Vector2(13,8),Vector2(0,-18)])
	damage_direction_arrow.color = Color("ff4664")
	damage_direction_arrow.visible = false
	damage_direction_arrow.z_index = 40
	add_child(damage_direction_arrow)
	kill_feed_root = Control.new()
	kill_feed_root.name = "KillFeed"
	kill_feed_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_feed_root.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	kill_feed_root.offset_left = -430
	kill_feed_root.offset_right = -16
	kill_feed_root.offset_top = 18
	kill_feed_root.offset_bottom = 220
	add_child(kill_feed_root)
	round_card = PanelContainer.new()
	round_card.name = "RoundResultCard"
	round_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	round_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	round_card.offset_left = -245
	round_card.offset_right = 245
	round_card.offset_top = 78
	round_card.offset_bottom = 196
	var round_style:=StyleBoxFlat.new()
	round_style.bg_color=Color(0.055,0.075,0.13,0.94)
	round_style.border_width_left=3;round_style.border_width_top=3;round_style.border_width_right=3;round_style.border_width_bottom=5
	round_style.border_color=Color("63e8bf")
	round_style.corner_radius_top_left=8;round_style.corner_radius_top_right=8;round_style.corner_radius_bottom_left=8;round_style.corner_radius_bottom_right=8
	round_style.shadow_color=Color(0,0,0,0.45);round_style.shadow_size=10
	round_card.add_theme_stylebox_override("panel",round_style)
	add_child(round_card)
	var round_box:=VBoxContainer.new()
	round_box.alignment=BoxContainer.ALIGNMENT_CENTER
	round_box.add_theme_constant_override("separation",1)
	round_card.add_child(round_box)
	round_card_title=_label(round_box,"ROUND OVER",24,Color("fff0b8"))
	round_card_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	round_card_score=_label(round_box,"0  —  0",18,Color("ffffff"))
	round_card_score.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	round_card_detail=_label(round_box,"",10,Color("acced6"))
	round_card_detail.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	round_card.visible=false
	countdown_label=_label(self,"",74,Color("fff0b8"))
	countdown_label.name="DuelCountdown"
	countdown_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	countdown_label.set_anchors_preset(Control.PRESET_CENTER)
	countdown_label.offset_left=-140
	countdown_label.offset_right=140
	countdown_label.offset_top=-100
	countdown_label.offset_bottom=100
	countdown_label.add_theme_constant_override("outline_size",8)
	countdown_label.add_theme_color_override("font_outline_color",Color("120b18"))
	countdown_label.visible=false
	game_over_panel = Control.new()
	game_over_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_over_panel.name = "GameOver"
	add_child(game_over_panel)
	game_over_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := _rect(game_over_panel,Rect2(),Color(0.03,0.025,0.06,0.78))
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	game_over_panel.add_child(box)
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -150
	box.offset_right = 150
	box.offset_top = -64
	box.offset_bottom = 64
	for info in [["OUTRAGE DOWN",26,"ff5369"],["",16,"ffffff"],["ENTER  /  B    TRY AGAIN",13,"9df8d2"]]:
		var line := _label(box,info[0],info[1],Color(info[2]))
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if info[0] == "": death_stats = line
	game_over_panel.hide()

func _rect(parent: Node, box: Rect2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.color = color
	parent.add_child(r)
	r.position = box.position
	r.size = box.size
	return r

func _label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.text = text
	l.add_theme_font_size_override("font_size",font_size)
	l.add_theme_color_override("font_color",color)
	l.add_theme_color_override("font_outline_color",Color("170b18"))
	l.add_theme_constant_override("outline_size",3)
	parent.add_child(l)
	return l

func set_health(value: float, maximum: float, immediate: bool = false) -> void:
	if not immediate and is_equal_approx(value,health) and is_equal_approx(maximum,max_health):return
	if value < health: trail_delay = 0.25
	health = value
	max_health = maximum
	if immediate: trail_health = value
	hp_text.text = "OUTRAGE   %d / %d" % [int(ceil(value)),int(maximum)]
	hp_fill.size.x = 202.0 * clampf(value / maximum,0,1)
	hp_fill.color = Color("ff5369") if value <= 30 else Color("63e8bf")

func notify_hurt(amount: float) -> void:
	hurt_time = 0.34
	heal_time = 0.0
	heal_text.text = "-%d HP" % int(amount)
	heal_text.add_theme_color_override("font_color",Color("ff5369"))

func notify_directional_damage(local_shot_direction: Vector3, amount: float, headshot: bool = false) -> void:
	if damage_direction_arrow == null or local_shot_direction.length_squared() < 0.0001:return
	# Damage direction points from attacker -> victim. Negating it points back to source.
	var source_local := -local_shot_direction.normalized()
	var ui := Vector2(source_local.x,source_local.z)
	if ui.length_squared() < 0.0001:return
	damage_direction_ui = ui.normalized()
	damage_direction_time = 0.82 if headshot else 0.62
	damage_direction_strength = clampf(amount/42.0,0.72,1.45)+(0.16 if headshot else 0.0)
	damage_direction_arrow.color = Color("fff0a8") if headshot else Color("ff4664")
	damage_direction_arrow.visible = true

func add_kill_feed(killer_name: String,victim_name: String,weapon: String,headshot: bool,is_local_killer: bool,is_local_victim: bool) -> void:
	while kill_feed.size()>=6:
		var old: Dictionary=kill_feed.pop_front()
		_release_kill_feed_label(old.label as Label)
	var label:=_acquire_kill_feed_label()
	var weapon_label:=_weapon_feed_label(weapon)
	label.text="%s  ◆ %s%s ◆  %s"%[
		killer_name.to_upper(),
		"HS / " if headshot else "",
		weapon_label,
		victim_name.to_upper()
	]
	label.add_theme_color_override("font_color",Color("82f3c6") if is_local_killer else Color("ff6c84") if is_local_victim else Color("f5f1df"))
	label.visible=true
	label.modulate=Color.WHITE
	label.scale=Vector2.ONE
	kill_feed.append({"label":label,"age":0.0,"duration":4.2})

func _weapon_feed_label(weapon: String) -> String:
	match weapon.strip_edges().to_lower():
		"ak":return "AK47"
		"shotgun":return "SHOTGUN"
		"kar":return "KAR"
		"grenade_launcher":return "GL"
		"grenade":return "GRENADE"
		"nose_rush":return "NOSE RUSH"
		"flamethrower":return "HELLFIRE"
		"overload":return "OVERLOAD"
		_:return weapon.to_upper() if not weapon.is_empty() else "HIT"

func _acquire_kill_feed_label() -> Label:
	for label in kill_feed_pool:
		if is_instance_valid(label) and not bool(label.get_meta("kw_kill_feed_active",false)):
			label.set_meta("kw_kill_feed_active",true)
			return label
	var label:=_label(kill_feed_root,"",13,Color("f5f1df"))
	label.name="KillFeedLine"
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	label.size=Vector2(410,26)
	label.add_theme_constant_override("outline_size",4)
	label.add_theme_color_override("font_shadow_color",Color("100813"))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	label.set_meta("kw_kill_feed_active",true)
	kill_feed_pool.append(label)
	return label

func _release_kill_feed_label(label: Label) -> void:
	if label==null:return
	label.visible=false
	label.text=""
	label.modulate=Color.WHITE
	label.scale=Vector2.ONE
	label.set_meta("kw_kill_feed_active",false)

func notify_heal(amount: float) -> void:
	if amount <= 0.0: return
	heal_time = 0.85
	heal_text.text = "+%d HP   ON KILL" % int(amount)
	heal_text.add_theme_color_override("font_color",Color("86ffbc"))

func announce(title: String, detail: String, duration: float = 2.0) -> void:
	banner.text = title
	banner_detail.text = detail
	banner_time = duration

func show_round_result(title: String,scoreline: String,detail: String,duration: float=2.2,accent: Color=Color("63e8bf")) -> void:
	if round_card==null:return
	round_card_title.text=title
	round_card_score.text=scoreline
	round_card_detail.text=detail
	var style:=round_card.get_theme_stylebox("panel") as StyleBoxFlat
	if style!=null:
		style=style.duplicate() as StyleBoxFlat
		style.border_color=accent
		round_card.add_theme_stylebox_override("panel",style)
	round_card_duration=maxf(0.2,duration)
	round_card_time=round_card_duration
	round_card.visible=true
	round_card.modulate=Color.WHITE
	round_card.scale=Vector2(0.88,0.88)
	round_card.pivot_offset=round_card.size*0.5

func hide_round_result() -> void:
	if round_card==null:return
	round_card_time=0.0
	round_card.visible=false
	round_card.modulate=Color.WHITE
	round_card.scale=Vector2.ONE

func show_countdown(value: String,duration: float=0.72,accent: Color=Color("fff0b8")) -> void:
	if countdown_label==null:return
	countdown_label.text=value
	countdown_label.add_theme_color_override("font_color",accent)
	countdown_duration=maxf(0.15,duration)
	countdown_time=countdown_duration
	countdown_label.visible=true
	countdown_label.modulate=Color.WHITE
	countdown_label.scale=Vector2(0.62,0.62)
	countdown_label.pivot_offset=countdown_label.size*0.5

func hide_countdown() -> void:
	if countdown_label==null:return
	countdown_time=0.0
	countdown_label.visible=false
	countdown_label.scale=Vector2.ONE
	countdown_label.modulate=Color.WHITE

func show_death(wave: int, kills: int) -> void:
	death_stats.text = "WAVE %02d    //    %d KILLS" % [wave,kills]
	game_over_panel.show()

func reset_run() -> void:
	game_over_panel.hide()
	hurt_time = 0.0
	heal_time = 0.0
	for data in damage_labels:
		if is_instance_valid(data.node): _release_damage_label(data.node as Label)
	damage_labels.clear()
	for data in kill_feed:
		if is_instance_valid(data.label):_release_kill_feed_label(data.label as Label)
	kill_feed.clear()
	damage_direction_time=0.0
	if damage_direction_arrow!=null:damage_direction_arrow.visible=false
	hide_round_result()
	hide_countdown()
	set_health(100,100,true)

func damage_number(point: Vector3, amount: float, lethal: bool) -> void:
	while damage_labels.size() >= 24:
		var old: Dictionary = damage_labels.pop_front()
		_release_damage_label(old.node as Label)
	var label := _acquire_damage_label()
	label.text=str(int(amount))
	label.add_theme_font_size_override("font_size",34 if lethal else 27)
	label.visible=true
	label.scale=Vector2.ONE
	label.rotation=0.0
	label.modulate=Color.WHITE
	number_index += 1
	var side := -1.0 if number_index % 2 == 0 else 1.0
	# Alternating side kick: numbers stay clear of the exact aim point.
	damage_labels.append({"node":label,"point":point,"age":0.0,
		"duration":0.92 if lethal else 0.76,"side":side,"lethal":lethal})

func _acquire_damage_label() -> Label:
	for label in damage_label_pool:
		if is_instance_valid(label) and not bool(label.get_meta("kw_damage_number_active",false)):
			label.set_meta("kw_damage_number_active",true)
			return label
	var label:=_label(self,"",27,Color("ff4058"))
	label.name="RedDamage"
	label.add_theme_constant_override("outline_size",5)
	label.add_theme_color_override("font_shadow_color",Color("220713"))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",3)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.size=Vector2(96,50)
	label.pivot_offset=Vector2(48,25)
	label.set_meta("kw_damage_number_active",true)
	damage_label_pool.append(label)
	return label

func _release_damage_label(label: Label) -> void:
	if label==null:return
	label.visible=false
	label.text=""
	label.scale=Vector2.ONE
	label.rotation=0.0
	label.modulate=Color.WHITE
	label.set_meta("kw_damage_number_active",false)

func _process(delta: float) -> void:
	if stage == null: return
	trail_delay = maxf(0,trail_delay-delta)
	if health >= trail_health: trail_health = health
	elif trail_delay <= 0: trail_health = move_toward(trail_health,health,delta*95)
	hp_trail.size.x = 202 * clampf(trail_health/max_health,0,1)
	hurt_time = maxf(0,hurt_time-delta)
	heal_time = maxf(0,heal_time-delta)
	var notice := maxf(hurt_time*2.4,heal_time)
	heal_text.visible = notice > 0
	heal_text.modulate.a = minf(1.0,notice*4)
	heal_text.position.y = -23 - (1.0-clampf(notice,0,1))*7
	for edge in edges: edge.modulate.a = hurt_time*1.25
	edges[0].position=Vector2.ZERO; edges[0].size=Vector2(size.x,4)
	edges[1].position=Vector2(0,size.y-4); edges[1].size=Vector2(size.x,4)
	edges[2].position=Vector2.ZERO; edges[2].size=Vector2(4,size.y)
	edges[3].position=Vector2(size.x-4,0); edges[3].size=Vector2(4,size.y)
	damage_direction_time=maxf(0.0,damage_direction_time-delta)
	if damage_direction_arrow!=null:
		damage_direction_arrow.visible=damage_direction_time>0.0
		if damage_direction_arrow.visible:
			var center:=size*0.5
			var radius:=minf(size.x,size.y)*0.145
			damage_direction_arrow.position=center+damage_direction_ui*radius
			damage_direction_arrow.rotation=atan2(damage_direction_ui.y,damage_direction_ui.x)+PI*0.5
			damage_direction_arrow.scale=Vector2.ONE*damage_direction_strength
			damage_direction_arrow.modulate.a=minf(1.0,damage_direction_time*3.4)
	for i in range(kill_feed.size()-1,-1,-1):
		var feed: Dictionary=kill_feed[i]
		var line:=feed.label as Label
		feed.age=float(feed.age)+delta
		if not is_instance_valid(line) or float(feed.age)>=float(feed.duration):
			if is_instance_valid(line):_release_kill_feed_label(line)
			kill_feed.remove_at(i)
	for i in range(kill_feed.size()):
		var feed: Dictionary=kill_feed[i]
		var line:=feed.label as Label
		var age:=float(feed.age)
		var duration:=float(feed.duration)
		line.position=Vector2(0,float(i)*29.0)
		line.modulate.a=1.0-smoothstep(duration-0.65,duration,age)
		line.scale=Vector2.ONE*(1.0+(0.08*(1.0-clampf(age/0.15,0.0,1.0))))
	banner_time = maxf(0,banner_time-delta)
	var banner_y := 116.0 if stage.instructions_visible else 21.0
	banner.position=Vector2((size.x-340)*0.5,banner_y)
	banner_detail.position=banner.position+Vector2(0,30)
	banner.modulate.a=minf(1,banner_time*3)
	banner_detail.modulate.a=banner.modulate.a
	if round_card!=null and round_card.visible:
		round_card_time=maxf(0.0,round_card_time-delta)
		var age:=round_card_duration-round_card_time
		var intro:=clampf(age/0.16,0.0,1.0)
		var outro:=clampf(round_card_time/0.32,0.0,1.0)
		var visible_alpha:=minf(intro,outro)
		round_card.modulate.a=visible_alpha
		var pop:=1.0+sin(intro*PI)*0.08
		round_card.scale=Vector2.ONE*lerpf(0.88,pop,intro)
		if round_card_time<=0.0:hide_round_result()
	if countdown_label!=null and countdown_label.visible:
		countdown_time=maxf(0.0,countdown_time-delta)
		var age:=countdown_duration-countdown_time
		var intro:=clampf(age/0.11,0.0,1.0)
		var outro:=clampf(countdown_time/0.18,0.0,1.0)
		countdown_label.modulate.a=minf(intro,outro)
		var overshoot:=1.0+sin(intro*PI)*0.18
		countdown_label.scale=Vector2.ONE*lerpf(0.62,overshoot,intro)
		if countdown_time<=0.0:hide_countdown()
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null: cam = stage.camera
	for i in range(damage_labels.size()-1,-1,-1):
		var d: Dictionary = damage_labels[i]
		var l: Label = d.node
		d.age += delta
		var age := float(d.age)
		var duration := float(d.duration)
		if age >= duration or not is_instance_valid(l):
			if is_instance_valid(l):_release_damage_label(l)
			damage_labels.remove_at(i)
			continue
		var point: Vector3 = d.point
		l.visible = not cam.is_position_behind(point)
		if not l.visible: continue
		var projected := get_global_transform_with_canvas().affine_inverse() * cam.unproject_position(point)
		var shift := Vector2(float(d.side)*(22+28*age),-19-62*age+27*age*age)
		l.position=projected+shift-l.pivot_offset
		var pop := 1.0
		if age < 0.075: pop=lerpf(0.45,1.40,sin(age/0.075*PI*0.5))
		elif age < 0.22: pop=lerpf(1.40,1.0,smoothstep(0.075,0.22,age))
		l.scale=Vector2.ONE*pop
		l.rotation=float(d.side)*(-0.13+0.20*age)
		l.modulate.a=1.0-smoothstep(duration-0.22,duration,age)
