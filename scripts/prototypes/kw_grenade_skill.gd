extends Node3D
## G: arcing, bouncing grenade. Unique radial hit per enemy; solid cover blocks damage.
const COOLDOWN := 6.0
const FUSE := 1.25
const BLAST_RADIUS := 5.5
const MAX_DAMAGE := 110.0
const MIN_DAMAGE := 35.0
const GRAVITY := 16.0
const LAUNCHER_SPEED := 22.0
const LAUNCHER_FUSE := 2.4
const LAUNCHER_BLAST_RADIUS := 4.8
const LAUNCHER_MAX_DAMAGE := 72.0
const LAUNCHER_MIN_DAMAGE := 22.0
var stage: Node3D
var cooldown_left := 0.0
var requested := false
var serial := 0
var active: Array[Dictionary] = []
var projectile_pool: Dictionary={"skill":[],"launcher":[]}
var effects: Array[Dictionary] = []
var explosion_mesh_pool: Array[MeshInstance3D] = []
var explosion_ring_pool: Array[MeshInstance3D] = []
var explosion_light_pool: Array[OmniLight3D] = []
const MAX_ACTIVE_EXPLOSION_LIGHTS := 3
var last_blast: Dictionary = {}
var throws := 0
var detonations := 0
var skill_label: Label
var skill_fill: ColorRect
var rng := RandomNumberGenerator.new()
var throw_guard_query:=PhysicsRayQueryParameters3D.new()
var visibility_query:=PhysicsRayQueryParameters3D.new()
var hud_refresh_clock:=0.0

func setup(owner_stage: Node3D) -> void:
	stage = owner_stage
	name = "GrenadeSkill"
	throw_guard_query.collision_mask=1;throw_guard_query.hit_from_inside=true
	visibility_query.collision_mask=1;visibility_query.hit_from_inside=true
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

func _tick_hud(delta: float) -> bool:
	hud_refresh_clock-=delta
	if hud_refresh_clock>0.0:return false
	hud_refresh_clock=0.10
	_update_hud()
	return true

func throw_grenade() -> bool:
	if stage == null or stage.combat == null or stage.combat.is_game_over() or cooldown_left>0.0: return false
	if stage.combat.director.suspended: return false
	var anchor: Vector3 = stage._weapon_anchor()+Vector3.UP*0.15
	var goal: Vector3 = stage._get_aim_target()
	var direction := (goal-anchor).normalized()
	var origin := anchor+direction*0.65
	throw_guard_query.from=anchor;throw_guard_query.to=origin
	var obstruction := get_world_3d().direct_space_state.intersect_ray(throw_guard_query)
	if not obstruction.is_empty():
		origin = obstruction.position-direction*0.22
	var delta_goal := (goal-origin).limit_length(22.0)
	var flight_time := clampf(delta_goal.length()/17.0,0.40,1.05)
	var velocity := delta_goal/flight_time+Vector3.UP*(GRAVITY*flight_time*0.5)
	velocity = velocity.limit_length(29.0)
	var pooled:=_acquire_projectile("skill")
	var body:=pooled.body as CharacterBody3D
	var visual:=pooled.visual as Node3D
	body.global_position = origin
	active.append({
		"body":body,"visual":visual,"pool_entry":pooled,"velocity":velocity,"age":0.0,"beeped":false,"bounces":0,"bounce_gate":0.0,
		"source":"skill","fuse_duration":FUSE,"gravity":GRAVITY,"blast_radius":BLAST_RADIUS,"max_damage":MAX_DAMAGE,"min_damage":MIN_DAMAGE
	})
	cooldown_left = COOLDOWN
	throws += 1
	if stage.arena_audio != null: stage.arena_audio.play_event("throw",origin,-14.0)
	stage.locomotion.body_angular_velocity.x -= 0.30
	_update_hud()
	return true


func fire_launcher(origin: Vector3, direction: Vector3, profile: Dictionary = {}) -> bool:
	if stage == null or stage.combat == null or stage.combat.is_game_over():
		return false
	var launch_direction := direction.normalized()
	if launch_direction.length_squared() < 0.001:
		return false
	var pooled:=_acquire_projectile("launcher")
	var body:=pooled.body as CharacterBody3D
	var visual:=pooled.visual as Node3D
	body.global_position = origin + launch_direction * 0.28
	var speed := float(profile.get("projectile_speed", LAUNCHER_SPEED))
	active.append({
		"body":body,
		"visual":visual,
		"pool_entry":pooled,
		"velocity":launch_direction * speed,
		"age":0.0,
		"beeped":false,
		"bounces":0,
		"bounce_gate":0.0,
		"source":"launcher",
		"fuse_duration":float(profile.get("fuse", LAUNCHER_FUSE)),
		"gravity":float(profile.get("gravity", GRAVITY)),
		"blast_radius":float(profile.get("blast_radius", LAUNCHER_BLAST_RADIUS)),
		"max_damage":float(profile.get("max_damage", LAUNCHER_MAX_DAMAGE)),
		"min_damage":float(profile.get("min_damage", LAUNCHER_MIN_DAMAGE))
	})
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

func _create_projectile(kind: String) -> Dictionary:
	var body:=CharacterBody3D.new()
	body.name="ThrownGrenade" if kind=="skill" else "LauncherGrenade"
	body.collision_layer=0
	body.collision_mask=0
	body.safe_margin=0.004
	body.visible=false
	add_child(body)
	var shape:=CollisionShape3D.new()
	var sphere:=SphereShape3D.new();sphere.radius=0.16 if kind=="skill" else 0.14
	shape.shape=sphere;shape.disabled=true;body.add_child(shape)
	var visual:=Node3D.new();visual.name="GrenadeVisual" if kind=="skill" else "LauncherGrenadeVisual";body.add_child(visual)
	if kind=="skill":
		var shell:=_box(visual,Vector3.ZERO,Vector3(0.28,0.32,0.28),Color("537668"));stage._add_scene_outline(shell,1.6)
		var fuse:=_box(visual,Vector3(0,0.20,0),Vector3(0.15,0.10,0.13),Color("ffb251"));stage._add_scene_outline(fuse,1.0)
		fuse.material_override=stage._material(Color("ffb251"),true,0.4)
	else:
		var shell:=MeshInstance3D.new();var ball:=SphereMesh.new();ball.radius=0.14;ball.height=0.28;shell.mesh=ball
		shell.material_override=stage._material(Color("d7b04c"),false,0.0);visual.add_child(shell);stage._add_scene_outline(shell,1.35)
		var band:=_box(visual,Vector3.ZERO,Vector3(0.29,0.06,0.10),Color("34383f"));stage._add_scene_outline(band,0.85)
	var entry:={"body":body,"visual":visual,"shape":shape,"kind":kind,"active":false}
	(projectile_pool[kind] as Array).append(entry)
	return entry

func _acquire_projectile(kind: String) -> Dictionary:
	var pool:=projectile_pool.get(kind,[]) as Array
	for entry in pool:
		if not bool(entry.get("active",false)):
			_activate_projectile(entry)
			return entry
	var entry:=_create_projectile(kind)
	_activate_projectile(entry)
	return entry

func _activate_projectile(entry: Dictionary) -> void:
	entry.active=true
	var body:=entry.body as CharacterBody3D
	var shape:=entry.shape as CollisionShape3D
	body.visible=true;body.collision_mask=5;body.velocity=Vector3.ZERO;body.rotation=Vector3.ZERO;body.scale=Vector3.ONE
	shape.disabled=false
	var visual:=entry.visual as Node3D
	visual.rotation=Vector3.ZERO;visual.scale=Vector3.ONE

func _release_projectile(entry: Dictionary) -> void:
	if entry.is_empty():return
	entry.active=false
	var body:=entry.body as CharacterBody3D
	var shape:=entry.shape as CollisionShape3D
	if body!=null:
		body.collision_mask=0;body.velocity=Vector3.ZERO;body.visible=false;body.rotation=Vector3.ZERO;body.scale=Vector3.ONE
	if shape!=null:shape.disabled=true
	var visual:=entry.visual as Node3D
	if visual!=null:visual.rotation=Vector3.ZERO;visual.scale=Vector3.ONE

func clear_active(reset_cooldown: bool = false) -> void:
	for entry in active:
		_release_projectile(entry.get("pool_entry",{}) as Dictionary)
	active.clear()
	for entry in effects:
		_release_explosion_effect(entry)
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
			grenade.velocity.y -= float(grenade.get("gravity", GRAVITY))*h
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
		if direct_hit or float(grenade.age)>=float(grenade.get("fuse_duration", FUSE)) or body.global_position.y < -5.0:
			var point := body.global_position
			active.remove_at(i)
			_release_projectile(grenade.get("pool_entry",{}) as Dictionary)
			_detonate_profile(
				point,
				float(grenade.get("blast_radius", BLAST_RADIUS)),
				float(grenade.get("max_damage", MAX_DAMAGE)),
				float(grenade.get("min_damage", MIN_DAMAGE))
			)
	_tick_effects(dt)
	_tick_hud(dt)

func _visible_to(point: Vector3, target: Vector3) -> bool:
	visibility_query.from=point;visibility_query.to=target
	return get_world_3d().direct_space_state.intersect_ray(visibility_query).is_empty()

func detonate(point: Vector3) -> Dictionary:
	return _detonate_profile(point, BLAST_RADIUS, MAX_DAMAGE, MIN_DAMAGE)


func _detonate_profile(point: Vector3, blast_radius: float, max_damage: float, min_damage: float) -> Dictionary:
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
		if distance>blast_radius: continue
		var head: Vector3 = bot.visuals.get_node("HeadRig").global_position
		if not _visible_to(origin,center) and not _visible_to(origin,head): continue
		var direction := (center-origin).normalized()
		if direction.length_squared()<0.01: direction = Vector3.UP
		var fraction := clampf((distance-1.2)/maxf(0.1,blast_radius-1.2),0.0,1.0)
		var damage := roundf(lerpf(max_damage,min_damage,fraction)*float(stage.skill_damage_multiplier() if stage.has_method("skill_damage_multiplier") else 1.0))
		if bot.receive_hit(damage,direction,blast_id):
			hit_names.append(str(bot.name))
			values.append(damage)
			stage.combat._spawn_damage_feedback(center,direction,damage,bot.dead)
			if not bot.dead and bot.brain != null: bot.brain.impulse(direction,4.8)
	last_blast = {"id":blast_id,"origin":origin,"radius":blast_radius,"targets":hit_names,"damage":values}
	_spawn_explosion(origin)
	if stage.arena_audio != null: stage.arena_audio.play_event("explosion",origin,-9.0)
	return last_blast

func _acquire_explosion_mesh() -> MeshInstance3D:
	for mesh in explosion_mesh_pool:
		if is_instance_valid(mesh) and not mesh.visible:
			mesh.visible=true
			mesh.rotation=Vector3.ZERO
			mesh.scale=Vector3.ONE
			return mesh
	var mesh:=MeshInstance3D.new()
	mesh.name="PooledExplosionChunk"
	var box:=BoxMesh.new();box.size=Vector3.ONE;mesh.mesh=box
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	stage._add_scene_outline(mesh,1.2)
	explosion_mesh_pool.append(mesh)
	return mesh

func _acquire_explosion_ring() -> MeshInstance3D:
	for ring in explosion_ring_pool:
		if is_instance_valid(ring) and not ring.visible:
			ring.visible=true
			ring.rotation=Vector3.ZERO
			ring.scale=Vector3.ONE
			return ring
	var ring:=MeshInstance3D.new()
	ring.name="PooledExplosionRing"
	var torus:=TorusMesh.new();torus.inner_radius=0.88;torus.outer_radius=1.0;torus.rings=24;torus.ring_segments=6
	ring.mesh=torus
	ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	stage._add_scene_outline(ring,1.3)
	explosion_ring_pool.append(ring)
	return ring

func _acquire_explosion_light() -> OmniLight3D:
	for light in explosion_light_pool:
		if is_instance_valid(light) and not light.visible:
			light.visible=true
			return light
	var light:=OmniLight3D.new()
	light.name="PooledExplosionLight"
	light.shadow_enabled=false
	add_child(light)
	explosion_light_pool.append(light)
	return light

func _active_explosion_light_count() -> int:
	var count:=0
	for light in explosion_light_pool:
		if is_instance_valid(light) and light.visible:count+=1
	return count

func _release_explosion_effect(effect: Dictionary) -> void:
	var node:=effect.get("node") as Node3D
	if node==null:return
	node.visible=false
	node.scale=Vector3.ONE
	node.rotation=Vector3.ZERO
	if node is OmniLight3D:(node as OmniLight3D).light_energy=0.0

func _spawn_explosion(point: Vector3) -> void:
	# Faceted hot core, expanding shock ring and chunky smoke. No camera/aim shake.
	var detail:=2
	if stage!=null and stage.combat!=null and stage.combat.has_method("_fx_detail"):
		detail=int(stage.combat._fx_detail(point))
	while effects.size()>70:
		var old: Dictionary = effects.pop_front()
		_release_explosion_effect(old)
	if detail>=1 and _active_explosion_light_count()<MAX_ACTIVE_EXPLOSION_LIGHTS:
		var light := _acquire_explosion_light()
		light.light_color = Color("ff934e")
		light.light_energy = 4.0 if detail>=2 else 2.2
		light.omni_range = 8.0 if detail>=2 else 5.5
		light.global_position = point
		effects.append({"node":light,"age":0.0,"duration":0.18,"kind":"light","velocity":Vector3.ZERO})
	var chunk_count:=14 if detail>=2 else (8 if detail==1 else 4)
	var smoke_start:=8 if detail>=2 else (5 if detail==1 else 3)
	for i in range(chunk_count):
		var smoke := i>=smoke_start
		var cube_size := rng.randf_range(0.32,0.64) if smoke else rng.randf_range(0.14,0.32)
		var color := Color("3d3341") if smoke else Color("ffbc65") if i%2==0 else Color("ff622f")
		var chip := _acquire_explosion_mesh()
		chip.material_override=stage._material(color,false,0.0)
		chip.scale=Vector3.ONE*cube_size
		chip.global_position = point+Vector3(rng.randf_range(-0.2,0.2),0,rng.randf_range(-0.2,0.2))
		var angle := TAU*float(i)/float(maxi(1,chunk_count))
		var velocity := Vector3(cos(angle),rng.randf_range(0.3,1.0),sin(angle))*rng.randf_range(2.0,5.5)
		effects.append({"node":chip,"age":0.0,"duration":0.95 if smoke else 0.52,"kind":"smoke" if smoke else "chip","velocity":velocity,"base_scale":Vector3.ONE*cube_size})
	var ring := _acquire_explosion_ring()
	ring.material_override=stage._material(Color("ffb16a"),true,0.7)
	ring.global_position=point
	effects.append({"node":ring,"age":0.0,"duration":0.42,"kind":"ring","velocity":Vector3.ZERO})
	var core := _acquire_explosion_mesh()
	core.global_position=point
	core.material_override=stage._material(Color("fff1bf"),true,1.0)
	core.scale=Vector3.ONE*0.8
	effects.append({"node":core,"age":0.0,"duration":0.19,"kind":"core","velocity":Vector3.ZERO,"base_scale":Vector3.ONE*0.8})

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
				node.scale=(effect.get("base_scale",Vector3.ONE) as Vector3)*maxf(0.02,sin(p*PI)*2.8)
				node.rotation+=Vector3(2,1,3)*dt
			_:
				node.global_position+=(effect.velocity as Vector3)*dt
				effect.velocity.y+= (1.2 if effect.kind=="smoke" else -7.0)*dt
				node.rotation+=Vector3(2.2,1.3,0.7)*dt
				node.scale=(effect.get("base_scale",Vector3.ONE) as Vector3)*maxf(0.01,(1.0-p)*(1.0+p*2.0 if effect.kind=="smoke" else 1.0))
		if p>=1.0:
			_release_explosion_effect(effect)
			effects.remove_at(i)
