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
var edges: Array[ColorRect] = []
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

func notify_heal(amount: float) -> void:
	if amount <= 0.0: return
	heal_time = 0.85
	heal_text.text = "+%d HP   ON KILL" % int(amount)
	heal_text.add_theme_color_override("font_color",Color("86ffbc"))

func announce(title: String, detail: String, duration: float = 2.0) -> void:
	banner.text = title
	banner_detail.text = detail
	banner_time = duration

func show_death(wave: int, kills: int) -> void:
	death_stats.text = "WAVE %02d    //    %d KILLS" % [wave,kills]
	game_over_panel.show()

func reset_run() -> void:
	game_over_panel.hide()
	hurt_time = 0.0
	heal_time = 0.0
	for data in damage_labels:
		if is_instance_valid(data.node): data.node.queue_free()
	damage_labels.clear()
	set_health(100,100,true)

func damage_number(point: Vector3, amount: float, lethal: bool) -> void:
	while damage_labels.size() >= 24:
		var old: Dictionary = damage_labels.pop_front()
		if is_instance_valid(old.node): old.node.queue_free()
	var label := _label(self,str(int(amount)),34 if lethal else 27,Color("ff4058"))
	label.name = "RedDamage"
	label.add_theme_constant_override("outline_size",5)
	label.add_theme_color_override("font_shadow_color",Color("220713"))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(96,50)
	label.pivot_offset = Vector2(48,25)
	number_index += 1
	var side := -1.0 if number_index % 2 == 0 else 1.0
	# Alternating side kick: numbers stay clear of the exact aim point.
	damage_labels.append({"node":label,"point":point,"age":0.0,
		"duration":0.92 if lethal else 0.76,"side":side,"lethal":lethal})

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
	banner_time = maxf(0,banner_time-delta)
	var banner_y := 116.0 if stage.instructions_visible else 21.0
	banner.position=Vector2((size.x-340)*0.5,banner_y)
	banner_detail.position=banner.position+Vector2(0,30)
	banner.modulate.a=minf(1,banner_time*3)
	banner_detail.modulate.a=banner.modulate.a
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null: cam = stage.camera
	for i in range(damage_labels.size()-1,-1,-1):
		var d: Dictionary = damage_labels[i]
		var l: Label = d.node
		d.age += delta
		var age := float(d.age)
		var duration := float(d.duration)
		if age >= duration or not is_instance_valid(l):
			if is_instance_valid(l): l.queue_free()
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
