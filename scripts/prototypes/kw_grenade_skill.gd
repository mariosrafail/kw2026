extends Node3D
## G: arcing, bouncing grenade. Unique radial hit per enemy; solid cover blocks damage.
const COOLDOWN := 6.0
const FUSE := 1.25
const BLAST_RADIUS := 5.5
const MAX_DAMAGE := 110.0
const MIN_DAMAGE := 35.0
const GRAVITY := 16.0
var stage: Node3D
var cooldown_left := 0.0
var requested := false
var serial := 0
var active: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var last_blast: Dictionary = {}
var throws := 0
var detonations := 0
var skill_label: Label
var skill_fill: ColorRect
var rng := RandomNumberGenerator.new()

func setup(owner_stage: Node3D) -> void:
	stage = owner_stage
	name = "GrenadeSkill"
	rng.randomize()
	var panel := Control.new()
	panel.name = "GrenadeCooldown"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.get_node("HUD").add_child(panel)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	panel.offset_left = -158
	panel.offset_right = -12
	panel.offset_top = -59
	panel.offset_bottom = -12
	var background := ColorRect.new()
	background.color = Color("111827")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skill_label = Label.new()
	skill_label.position = Vector2(9,5)
	skill_label.add_theme_font_size_override("font_size",12)
	skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(skill_label)
	skill_fill = ColorRect.new()
	skill_fill.position = Vector2(9,31)
	skill_fill.size = Vector2(128,6)
	skill_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(skill_fill)
	_update_hud()

func _update_hud() -> void:
	if skill_label == null: return
	var ready := cooldown_left<=0.0
	skill_label.text = "G  GRENADE  READY" if ready else "G  GRENADE  %.1fs" % cooldown_left
	skill_label.modulate = Color("9bf8c9") if ready else Color("c5cdda")
	skill_fill.color = Color("78eab3") if ready else Color("ffb461")
	skill_fill.size.x = 128.0*(1.0-clampf(cooldown_left/COOLDOWN,0.0,1.0))

func throw_grenade() -> bool:
	if stage == null or stage.combat == null or stage.combat.is_game_over() or cooldown_left>0.0: return false
	if stage.combat.director.suspended: return false
	var anchor: Vector3 = stage._weapon_anchor()+Vector3.UP*0.15
	var goal: Vector3 = stage._get_aim_target()
	var direction := (goal-anchor).normalized()
	var origin := anchor+direction*0.65
	var guard := PhysicsRayQueryParameters3D.create(anchor,origin,1)
	guard.hit_from_inside = true
	var obstruction := get_world_3d().direct_space_state.intersect_ray(guard)
	if not obstruction.is_empty():
		origin = obstruction.position-direction*0.22
	var delta_goal := (goal-origin).limit_length(22.0)
	var flight_time := clampf(delta_goal.length()/17.0,0.40,1.05)
	var velocity := delta_goal/flight_time+Vector3.UP*(GRAVITY*flight_time*0.5)
	velocity = velocity.limit_length(29.0)
	var body := CharacterBody3D.new()
	body.name = "ThrownGrenade"
	body.collision_layer = 0
	body.collision_mask = 5
	body.safe_margin = 0.004
	add_child(body)
	body.global_position = origin
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.16
	shape.shape = sphere
	body.add_child(shape)
	var visual := Node3D.new()
	visual.name = "GrenadeVisual"
	body.add_child(visual)
	var shell := _box(visual,Vector3.ZERO,Vector3(0.28,0.32,0.28),Color("537668"))
	stage._add_scene_outline(shell,1.6)
	var fuse := _box(visual,Vector3(0,0.20,0),Vector3(0.15,0.10,0.13),Color("ffb251"))
	stage._add_scene_outline(fuse,1.0)
	fuse.material_override = stage._material(Color("ffb251"),true,0.4)
	active.append({"body":body,"visual":visual,"velocity":velocity,"age":0.0,"beeped":false,"bounces":0,"bounce_gate":0.0})
	cooldown_left = COOLDOWN
	throws += 1
	if stage.arena_audio != null: stage.arena_audio.play_event("throw",origin,-14.0)
	stage.locomotion.body_angular_velocity.x -= 0.30
	_update_hud()
	return true

func _box(parent: Node3D, position_value: Vector3, size_value: Vector3, color: Color) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = size_value
	part.mesh = cube
	part.material_override = stage._material(color,false,0)
	part.position = position_value
	parent.add_child(part)
	return part

func clear_active(reset_cooldown: bool = false) -> void:
	for entry in active:
		if is_instance_valid(entry.body): entry.body.queue_free()
	active.clear()
	for entry in effects:
		if is_instance_valid(entry.node): entry.node.queue_free()
	effects.clear()
	requested = false
	if reset_cooldown: cooldown_left = 0.0
	_update_hud()

func _physics_process(delta: float) -> void:
	if stage == null or stage.combat == null: return
	if stage.combat.is_game_over():
		if not active.is_empty(): clear_active(false)
		return
	if stage.combat.director.suspended: return
	if not OS.get_cmdline_user_args().has("--kw-qa") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		requested = false
		return
	var dt := clampf(delta,0.0,0.1)
	cooldown_left = maxf(0.0,cooldown_left-dt)
	if requested:
		requested = false
		throw_grenade()
	for i in range(active.size()-1,-1,-1):
		var grenade: Dictionary = active[i]
		var body: CharacterBody3D = grenade.body
		if not is_instance_valid(body):
			active.remove_at(i)
			continue
		grenade.age += dt
		grenade.bounce_gate = maxf(0.0,float(grenade.bounce_gate)-dt)
		var direct_hit := false
		var steps := maxi(1,int(ceil(dt*120.0)))
		var h := dt/float(steps)
		for unused in range(steps):
			grenade.velocity.y -= GRAVITY*h
			var collision := body.move_and_collide((grenade.velocity as Vector3)*h)
			if collision != null:
				var object: Object = collision.get_collider()
				if object != null and object.has_method("receive_hit"):
					direct_hit = true
					break
				var normal := collision.get_normal()
				grenade.velocity = (grenade.velocity as Vector3).bounce(normal)*0.46
				if normal.y>0.7: grenade.velocity *= Vector3(0.78,1.0,0.78)
				if float(grenade.bounce_gate)<=0.0 and (grenade.velocity as Vector3).length()>0.6:
					grenade.bounces += 1
					grenade.bounce_gate = 0.14
					if stage.arena_audio != null: stage.arena_audio.play_event("bounce",body.global_position,-19.0)
		grenade.visual.rotation += Vector3(5.1,3.0,2.0)*dt
		if float(grenade.age)>0.8: grenade.visual.scale = Vector3.ONE*(1.0+0.08*sin(float(grenade.age)*50.0))
		if direct_hit or float(grenade.age)>=FUSE or body.global_position.y < -5.0:
			var point := body.global_position
			active.remove_at(i)
			body.queue_free()
			detonate(point)
	_tick_effects(dt)
	_update_hud()

func _visible_to(point: Vector3, target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(point,target,1)
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func detonate(point: Vector3) -> Dictionary:
	if stage.combat.is_game_over(): return {}
	serial += 1
	detonations += 1
	var blast_id := -serial # Rifle IDs are positive; every blast is independently idempotent.
	var hit_names: Array[String] = []
	var values: Array[float] = []
	var origin := point+Vector3.UP*0.12
	# Iterate actors, not their many per-part hitboxes: at most one hit/heal per enemy.
	for bot in stage.combat.targets.duplicate():
		if not is_instance_valid(bot) or bot.dead: continue
		var center: Vector3 = bot.visuals.get_node("TorsoRig/Torso_Upper").global_position
		var distance := origin.distance_to(center)
		if distance>BLAST_RADIUS: continue
		var head: Vector3 = bot.visuals.get_node("HeadRig").global_position
		if not _visible_to(origin,center) and not _visible_to(origin,head): continue
		var direction := (center-origin).normalized()
		if direction.length_squared()<0.01: direction = Vector3.UP
		var fraction := clampf((distance-1.4)/(BLAST_RADIUS-1.4),0.0,1.0)
		var damage := roundf(lerpf(MAX_DAMAGE,MIN_DAMAGE,fraction))
		if bot.receive_hit(damage,direction,blast_id):
			hit_names.append(str(bot.name))
			values.append(damage)
			stage.combat._spawn_damage_feedback(center,direction,damage,bot.dead)
			if not bot.dead and bot.brain != null: bot.brain.impulse(direction,4.8)
	last_blast = {"id":blast_id,"origin":origin,"radius":BLAST_RADIUS,"targets":hit_names,"damage":values}
	_spawn_explosion(origin)
	if stage.arena_audio != null: stage.arena_audio.play_event("explosion",origin,-9.0)
	return last_blast

func _spawn_explosion(point: Vector3) -> void:
	# Faceted hot core, expanding shock ring and chunky smoke. No camera/aim shake.
	while effects.size()>70:
		var old: Dictionary = effects.pop_front()
		if is_instance_valid(old.node): old.node.queue_free()
	var light := OmniLight3D.new()
	light.light_color = Color("ff934e")
	light.light_energy = 4.0
	light.omni_range = 8.0
	add_child(light)
	light.global_position = point
	effects.append({"node":light,"age":0.0,"duration":0.18,"kind":"light","velocity":Vector3.ZERO})
	for i in range(14):
		var smoke := i>=8
		var cube_size := rng.randf_range(0.32,0.64) if smoke else rng.randf_range(0.14,0.32)
		var color := Color("3d3341") if smoke else Color("ffbc65") if i%2==0 else Color("ff622f")
		var chip := _box(self,Vector3.ZERO,Vector3.ONE*cube_size,color)
		chip.global_position = point+Vector3(rng.randf_range(-0.2,0.2),0,rng.randf_range(-0.2,0.2))
		stage._add_scene_outline(chip,1.4)
		var angle := TAU*float(i)/14.0
		var velocity := Vector3(cos(angle),rng.randf_range(0.3,1.0),sin(angle))*rng.randf_range(2.0,5.5)
		effects.append({"node":chip,"age":0.0,"duration":0.95 if smoke else 0.52,"kind":"smoke" if smoke else "chip","velocity":velocity})
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius=0.88
	torus.outer_radius=1.0
	torus.rings=24
	torus.ring_segments=6
	ring.mesh=torus
	ring.material_override=stage._material(Color("ffb16a"),true,0.7)
	add_child(ring)
	ring.global_position=point
	stage._add_scene_outline(ring,1.3)
	effects.append({"node":ring,"age":0.0,"duration":0.42,"kind":"ring","velocity":Vector3.ZERO})
	var core := _box(self,Vector3.ZERO,Vector3.ONE*0.8,Color("fff1bf"))
	core.global_position=point
	core.material_override=stage._material(Color("fff1bf"),true,1.0)
	effects.append({"node":core,"age":0.0,"duration":0.19,"kind":"core","velocity":Vector3.ZERO})

func _tick_effects(dt: float) -> void:
	for i in range(effects.size()-1,-1,-1):
		var effect: Dictionary=effects[i]
		if not is_instance_valid(effect.node):
			effects.remove_at(i)
			continue
		effect.age+=dt
		var p := clampf(float(effect.age)/float(effect.duration),0.0,1.0)
		var node: Node3D=effect.node
		match str(effect.kind):
			"light": (node as OmniLight3D).light_energy=4.0*(1.0-p)
			"ring": node.scale=Vector3(0.2+p*(BLAST_RADIUS-0.2),0.12*(1.0-p)+0.02,0.2+p*(BLAST_RADIUS-0.2))
			"core":
				node.scale=Vector3.ONE*maxf(0.02,sin(p*PI)*2.8)
				node.rotation+=Vector3(2,1,3)*dt
			_:
				node.global_position+=(effect.velocity as Vector3)*dt
				effect.velocity.y+= (1.2 if effect.kind=="smoke" else -7.0)*dt
				node.rotation+=Vector3(2.2,1.3,0.7)*dt
				node.scale=Vector3.ONE*maxf(0.01,(1.0-p)*(1.0+p*2.0 if effect.kind=="smoke" else 1.0))
		if p>=1.0:
			node.queue_free()
			effects.remove_at(i)
