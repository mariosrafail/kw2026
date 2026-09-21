extends Node3D
## Local-only practice range. All gameplay damage is one muzzle ray per rifle shot.
const DUMMY := preload("res://scripts/prototypes/kw_training_dummy.gd")
const WAVE_DIRECTOR := preload("res://scripts/prototypes/kw_wave_director.gd")
const WEAPON_RULES := preload("res://scripts/kw3d/weapon_rules.gd")
const HIT_REGIONS := preload("res://scripts/kw3d/hit_regions.gd")
const FLAME_PARTICLES := preload("res://scripts/prototypes/kw_flame_particles.gd")
var director: RefCounted
var wave_label: Label
const DAMAGE := 5.0
const RANGE := 120.0
const SHOT_MASK := 5 # environment (1) + targets (4); cosmetic effects have no bodies.
const VICTIM_MAIN_COLORS := {
	"outrage": Color("fa0512"), "tasko": Color("bf3fff"), "gan": Color("7ab1b7"),
	"celler": Color("eaeaea"), "nova": Color("334756"), "m4": Color("c59370"),
	"crashout": Color("a11b1b"), "juice": Color("f2ff8f"), "kotro": Color("78ead8")
}
var stage: Node3D
var targets: Array[Node3D] = []
var shots_fired := 0
var kills := 0
var total_kills := 0
var credited_kills: Dictionary = {}
var roaming_enabled := true
var kill_label: Label
var alive_label: Label
var kill_notice: Label
var score_pulse := 0.0
var hit_effects: Array[Dictionary] = []
var fx_rng := RandomNumberGenerator.new()
var last_shot: Dictionary = {}
var hit_timer := 0.0
var lethal_hit := false
var counter: Label
var hit_marker: Label
var tracer_material: Material
var tracer_halo_material: Material
var tracer_hot_materials: Array[Material] = []
var projectile_material_cache: Dictionary = {}
var surface_material_cache: Dictionary = {}
var impact_material: Material
var impact_hot_material: Material
var hit_material: Material
var tracer_serial := 0
var reticle: Control
var camera_hit: Dictionary = {}
var aim_solution: Dictionary = {}
var active_tracers: Array[Dictionary] = []
var trail_echoes: Array[Dictionary] = []
var impacts: Array[Node3D] = []
var confirm_audio: AudioStreamPlayer
var confirm_hit: AudioStreamWAV
var confirm_kill: AudioStreamWAV

static func blood_color_for_skin(skin: String) -> Color:
	return VICTIM_MAIN_COLORS.get(skin.to_lower(),Color("fa0512"))

func setup(owner_stage: Node3D) -> void:
	stage = owner_stage
	name = "PracticeRange"
	fx_rng.randomize()
	_setup_shooting_fx_materials()
	_build_hud()
	_build_confirm_audio()
	director = WAVE_DIRECTOR.new()
	director.setup(self)

func _fx_material(color: Color, emission_energy: float = 2.5, alpha: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r,color.g,color.b,alpha)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission_energy
	if alpha < 0.999:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test = false
	return material

func _setup_shooting_fx_materials() -> void:
	tracer_material = _fx_material(Color("fff1a8"), 6.8)
	tracer_halo_material = _fx_material(Color("ff7b4b"), 5.6, 0.52)
	tracer_hot_materials = [
		_fx_material(Color("84edff"), 5.4),
		_fx_material(Color("ff5f9a"), 5.2),
		_fx_material(Color("fff0a2"), 5.8)
	]
	impact_material = _fx_material(Color("fff5c2"), 7.2)
	impact_hot_material = _fx_material(Color("ff8b55"), 6.1)
	hit_material = _fx_material(Color("ff4058"), 4.8)

func _projectile_material(color: Color, emission_energy: float, alpha: float = 1.0) -> Material:
	var key := "%s|%.2f|%.2f" % [color.to_html(false), emission_energy, alpha]
	if projectile_material_cache.has(key):
		return projectile_material_cache[key] as Material
	var material := _fx_material(color, emission_energy, alpha)
	projectile_material_cache[key] = material
	return material

func _projectile_style(weapon_id: String) -> Dictionary:
	if stage != null and stage.has_method("projectile_style_for_weapon"):
		var style: Variant = stage.call("projectile_style_for_weapon", weapon_id)
		if style is Dictionary:
			return style as Dictionary
	return {"color": Color("fff1a8"), "inferno": false}

func _surface_material(color: Color, lightness: float = 0.0) -> StandardMaterial3D:
	var resolved := color.lightened(lightness) if lightness >= 0.0 else color.darkened(-lightness)
	var key := "%s|%.2f" % [resolved.to_html(false), lightness]
	if surface_material_cache.has(key):
		return surface_material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = resolved
	material.metallic = 0.04
	material.roughness = 0.84
	surface_material_cache[key] = material
	return material

func _surface_color_from_collider(collider: Object, fallback: Color = Color("8b98a8")) -> Color:
	if collider == null:
		return fallback
	if collider.has_meta("surface_color"):
		var stored: Variant = collider.get_meta("surface_color")
		if stored is Color:
			return stored as Color
	if collider is Node:
		var node := collider as Node
		for candidate in node.find_children("*", "MeshInstance3D", true, false):
			var mesh := candidate as MeshInstance3D
			var material := mesh.material_override
			if material is StandardMaterial3D:
				return (material as StandardMaterial3D).albedo_color
			if material is ShaderMaterial:
				var base: Variant = (material as ShaderMaterial).get_shader_parameter("base_color")
				if base is Color:
					return base as Color
	return fallback

func _surface_color_at(point: Vector3, normal: Vector3, collider: Object = null) -> Color:
	if collider != null:
		return _surface_color_from_collider(collider)
	var safe_normal := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var query := PhysicsRayQueryParameters3D.create(
		point + safe_normal * 0.08,
		point - safe_normal * 0.12,
		SHOT_MASK,
		[stage.player.get_rid()] if stage != null and stage.player != null else []
	)
	query.hit_from_inside = true
	var sampled := get_world_3d().direct_space_state.intersect_ray(query)
	return _surface_color_from_collider(sampled.get("collider"))

func _build_hud() -> void:
	counter = Label.new()
	counter.name = "RangeCounter"
	counter.position = Vector2(12,92)
	counter.add_theme_font_size_override("font_size",11)
	stage.get_node("HUD/HelpPanel").add_child(counter)
	_build_score_hud()
	reticle = stage.get_node("HUD/Crosshair") as Control

func reset_targets() -> void:
	if director != null: director.retry_wave()

func sync_style() -> void:
	for target in targets:
		if is_instance_valid(target): target.set_style(stage.head_style.enabled,stage.pixel_enabled)

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to,SHOT_MASK,[stage.player.get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query)

func camera_target() -> Vector3:
	# Use the same viewport centre as the HUD, also at non-default window sizes.
	var cam: Camera3D = stage.camera
	var centre := cam.get_viewport().get_visible_rect().size * 0.5
	var origin := cam.project_ray_origin(centre)
	var direction := cam.project_ray_normal(centre).normalized()
	var end := origin + direction * RANGE
	camera_hit = _ray(origin, end)
	return camera_hit["position"] if not camera_hit.is_empty() else end

func predict_shot(muzzle: Vector3, target: Vector3, chest: Vector3) -> Dictionary:
	# This exact solver serves both pre-shot feedback and damage. No aim magnet.
	var guard_hit := _ray(chest, muzzle)
	var start := chest if not guard_hit.is_empty() else muzzle
	var direction := (target - muzzle).normalized()
	var hit := guard_hit if not guard_hit.is_empty() else _ray(muzzle, target + direction * 0.035)
	var endpoint: Vector3 = hit.get("position", target)
	var object: Object = hit.get("collider")
	var expected: Object = camera_hit.get("collider")
	var receiver := object != null and object.has_method("receive_hit")
	var same_target := receiver and object == expected
	var occluded := not guard_hit.is_empty()
	if not hit.is_empty() and not same_target:
		occluded = occluded or (muzzle.distance_to(endpoint) + 0.08 < muzzle.distance_to(target) and endpoint.distance_to(target) > 0.12)
	return {"start": start, "end": endpoint, "hit": hit, "occluded": occluded,
		"guard_blocked": not guard_hit.is_empty(), "target_ready": same_target and not occluded,
		"normal": hit.get("normal", Vector3.UP), "target": target}

func update_aim_feedback(muzzle: Vector3, target: Vector3, chest: Vector3) -> void:
	aim_solution = predict_shot(muzzle, target, chest)
	if reticle != null: reticle.set_feedback(aim_solution, stage.camera, stage.aiming)

func fire(muzzle: Vector3,target: Vector3,chest: Vector3,profile: Dictionary=WEAPON_RULES.AK,weapon_id: String="ak") -> Dictionary:
	shots_fired+=1
	var guard_hit:=_ray(chest,muzzle)
	var start: Vector3=chest if not guard_hit.is_empty() else muzzle
	var base_direction: Vector3=(target-muzzle).normalized()
	var direction:=WEAPON_RULES.spread_direction(base_direction,profile,bool(stage.aiming),int(shots_fired*7919+stage.get_instance_id()%100000+stage.weapon_slot*977))
	var hit: Dictionary=guard_hit if not guard_hit.is_empty() else _ray(muzzle,muzzle+direction*float(profile.range))
	var endpoint: Vector3=hit.get("position",muzzle+direction*float(profile.range))
	var applied:=false
	var target_name:=""
	var headshot:=HIT_REGIONS.is_headshot(hit) if not hit.is_empty() else false
	var shot_damage:=WEAPON_RULES.damage(profile,headshot)
	if not hit.is_empty():
		var object: Object=hit.get("collider")
		var environment_hit := object == null or not object.has_method("receive_hit")
		if object!=null and object.has_method("receive_hit"):
			applied=object.receive_hit(shot_damage,direction,shots_fired,endpoint);target_name=str(object.name)
		elif object is RigidBody3D:object.apply_impulse(direction*1.6,endpoint-object.global_position)
		_spawn_impact(
			endpoint,
			hit.get("normal",Vector3.UP),
			_surface_color_at(endpoint, hit.get("normal",Vector3.UP), object),
			environment_hit
		)
		if applied:
			var victim_skin:=str(object.get("warrior_id")) if object!=null else "outrage"
			_spawn_damage_feedback(endpoint,direction,shot_damage,object.dead,blood_color_for_skin(victim_skin),true)
	if guard_hit.is_empty():_spawn_tracer(muzzle,endpoint,weapon_id)
	if reticle!=null:reticle.notify_shot()
	last_shot={"id":shots_fired,"damage_applied":applied,"target":target_name,"start":start,"end":endpoint,
		"blocked":not hit.is_empty(),"headshot":headshot,"damage":shot_damage if applied else 0.0,
		"occluded":not guard_hit.is_empty(),"guard_blocked":not guard_hit.is_empty(),"weapon":weapon_id,
		"spread_deg":WEAPON_RULES.spread_for(profile,bool(stage.aiming))}
	return last_shot

func fire_shotgun(muzzle: Vector3,target: Vector3,chest: Vector3) -> Dictionary:
	shots_fired += 1
	var profile: Dictionary=WEAPON_RULES.SHOTGUN
	var guard_hit:=_ray(chest,muzzle)
	var centre_dir: Vector3=(target-muzzle).normalized()
	var pellet_results: Array=[]
	var applied_damage:=0.0
	var headshots:=0
	for pellet in range(int(profile.pellets)):
		var direction: Vector3=WEAPON_RULES.spread_direction(centre_dir,profile,bool(stage.aiming),int(shots_fired*7919+stage.get_instance_id()%100000+pellet*131))
		var hit: Dictionary=guard_hit if not guard_hit.is_empty() else _ray(muzzle,muzzle+direction*float(profile.range))
		var endpoint: Vector3=hit.get("position",muzzle+direction*float(profile.range))
		var normal: Vector3=hit.get("normal",Vector3.UP)
		var pellet_headshot:=HIT_REGIONS.is_headshot(hit) if not hit.is_empty() else false
		var pellet_damage:=WEAPON_RULES.damage(profile,pellet_headshot)
		var applied:=false
		if not hit.is_empty():
			var object: Object=hit.get("collider")
			var environment_hit := object == null or not object.has_method("receive_hit")
			if object!=null and object.has_method("receive_hit"):
				applied=object.receive_hit(pellet_damage,direction,shots_fired*100+pellet,endpoint)
				if applied:
					applied_damage+=pellet_damage
					if pellet_headshot:headshots+=1
					var victim_skin:=str(object.get("warrior_id")) if object!=null else "outrage"
					_spawn_damage_feedback(endpoint,direction,pellet_damage,object.dead,blood_color_for_skin(victim_skin),pellet==0)
			elif object is RigidBody3D:
				object.apply_impulse(direction*2.6,endpoint-object.global_position)
			_spawn_impact(endpoint,normal,_surface_color_at(endpoint,normal,object),environment_hit)
		_spawn_tracer(muzzle,endpoint,"shotgun")
		pellet_results.append({"to":endpoint,"normal":normal,"hit":not hit.is_empty(),"headshot":pellet_headshot})
	if reticle!=null:
		reticle.notify_shot()
		if applied_damage>0.0:reticle.notify_hit(false)
	last_shot={"id":shots_fired,"weapon":"shotgun","pellets":pellet_results,"damage_applied":applied_damage>0.0,"damage":applied_damage,"headshots":headshots,"start":muzzle,"end":target,"guard_blocked":not guard_hit.is_empty()}
	return last_shot

func _spawn_tracer(start: Vector3, end: Vector3, weapon_id: String = "ak") -> void:
	var length := start.distance_to(end)
	if length < 0.03:
		return
	while active_tracers.size() >= 34:
		var oldest: Dictionary = active_tracers.pop_front()
		if is_instance_valid(oldest["node"]):
			oldest["node"].queue_free()
	tracer_serial += 1
	var root := Node3D.new()
	root.name = "%sTracer%03d" % [weapon_id.capitalize(), tracer_serial]
	add_child(root)
	var direction := (end - start).normalized()
	var style := _projectile_style(weapon_id)
	var projectile_color: Color = style.get("color", Color("fff1a8"))
	var inferno := bool(style.get("inferno", false))
	var hot_round := fx_rng.randf() < 0.12
	var chunky_round := fx_rng.randf() < 0.08
	var width := fx_rng.randf_range(0.036,0.058) * (1.90 if chunky_round else 1.0)
	var streak := minf(fx_rng.randf_range(1.00,1.55) * (1.25 if hot_round else 1.0), maxf(0.12,length * 0.58))
	var core := MeshInstance3D.new()
	core.name = "Core"
	var core_box := BoxMesh.new()
	core_box.size = Vector3(width,width,streak)
	core.mesh = core_box
	core.material_override = _projectile_material(projectile_color, 7.6 if hot_round else 6.5)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)
	stage._add_scene_outline(core,0.6)
	var halo := MeshInstance3D.new()
	halo.name = "Glow"
	var halo_box := BoxMesh.new()
	halo_box.size = Vector3(width * 4.2,width * 4.2,streak * 0.95)
	halo.mesh = halo_box
	var halo_color := projectile_color.lightened(0.30)
	halo.material_override = _projectile_material(halo_color, 5.8 if inferno else 4.8, 0.48)
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(halo)
	var head := MeshInstance3D.new()
	head.name = "BulletHead"
	var head_box := BoxMesh.new()
	head_box.size = Vector3.ONE * width * (4.4 if chunky_round else 3.6)
	head.mesh = head_box
	head.material_override = core.material_override
	head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head.position = Vector3(0,0,-streak * 0.52)
	root.add_child(head)
	if inferno:
		FLAME_PARTICLES.add_bullet_flames(root, projectile_color)
	root.global_position = start + direction * minf(streak * 0.5,length * 0.5)
	root.look_at(root.global_position + direction, Vector3.RIGHT if absf(direction.y)>0.98 else Vector3.UP)
	active_tracers.append({
		"node":root,"core":core,"halo":halo,"head":head,
		"start":start,"direction":direction,"length":length,"age":0.0,
		"duration":clampf(length / fx_rng.randf_range(235.0,285.0),0.028,0.12),
		"streak":streak,"width":width,"wobble":fx_rng.randf_range(0.0,0.018),
		"phase":fx_rng.randf_range(0.0,TAU),"spin":fx_rng.randf_range(-8.0,8.0),
			"trail_timer":0.0,"hot":hot_round,"color":projectile_color,"inferno":inferno
	})

func _spawn_trail_echo(position: Vector3, direction: Vector3, width: float, hot: bool, color: Color, inferno: bool) -> void:
	if direction.length_squared() < 0.0001:
		return
	while trail_echoes.size() >= 96:
		var old: Dictionary = trail_echoes.pop_front()
		if is_instance_valid(old.get("node")):
			old.node.queue_free()
	var echo := MeshInstance3D.new()
	echo.name = "BulletTrailEcho"
	var box := BoxMesh.new()
	var echo_len := fx_rng.randf_range(0.16,0.34) * (1.25 if hot else 1.0)
	box.size = Vector3(width * fx_rng.randf_range(2.0,2.8),width * fx_rng.randf_range(2.0,2.8),echo_len)
	echo.mesh = box
	var trail_color := color.lightened(0.20 if inferno else 0.10)
	echo.material_override = _projectile_material(trail_color, 5.6 if inferno else (4.8 if hot else 4.1), 0.42 if inferno else 0.34)
	echo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(echo)
	var jitter := Vector3(fx_rng.randf_range(-0.014,0.014),fx_rng.randf_range(-0.014,0.014),fx_rng.randf_range(-0.014,0.014))
	echo.global_position = position + jitter
	echo.look_at(echo.global_position + direction.normalized(), Vector3.RIGHT if absf(direction.y)>0.98 else Vector3.UP)
	echo.transparency = fx_rng.randf_range(0.05,0.20)
	trail_echoes.append({
		"node":echo,
		"age":0.0,
		"duration":fx_rng.randf_range(0.10,0.16),
		"drift":Vector3(fx_rng.randf_range(-0.05,0.05),fx_rng.randf_range(0.01,0.08),fx_rng.randf_range(-0.05,0.05)),
		"spin":fx_rng.randf_range(-4.0,4.0)
	})

func _spawn_world_muzzle_flash(point: Vector3, direction: Vector3) -> void:
	if direction.length_squared() < 0.0001:
		return
	var root := Node3D.new()
	root.name = "RemoteMuzzleBurst"
	add_child(root)
	root.global_position = point
	root.look_at(point + direction.normalized(), Vector3.RIGHT if absf(direction.y)>0.98 else Vector3.UP)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0,fx_rng.randf_range(0.35,0.55),0.10)
	light.light_energy = fx_rng.randf_range(2.8,4.4)
	light.omni_range = fx_rng.randf_range(1.4,2.0)
	root.add_child(light)
	var color := Color("fff0a2") if fx_rng.randf() > 0.10 else (Color("84edff") if fx_rng.randf() > 0.5 else Color("ff5f9a"))
	for i in range(2):
		var ray := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(fx_rng.randf_range(0.028,0.048),fx_rng.randf_range(0.028,0.048),fx_rng.randf_range(0.18,0.34))
		ray.mesh = box
		ray.material_override = _fx_material(color,5.0)
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ray.position = Vector3(0,0,-box.size.z*0.45)
		ray.rotation.z = i * PI * 0.5 + fx_rng.randf_range(-0.25,0.25)
		root.add_child(ray)
	var tween := root.create_tween().set_parallel(true)
	tween.tween_property(root,"scale",Vector3.ONE*1.45,0.05).from(Vector3.ONE*0.7)
	tween.chain().tween_callback(root.queue_free)

func _spawn_impact(
		point: Vector3,
		normal: Vector3 = Vector3.UP,
		surface_color: Color = Color("fff5c2"),
		surface_debris: bool = false
	) -> void:
	for i in range(impacts.size()-1,-1,-1):
		if not is_instance_valid(impacts[i]):
			impacts.remove_at(i)
	while impacts.size() >= 32:
		var old: Node3D = impacts.pop_front()
		if is_instance_valid(old):
			old.queue_free()
	var flash := MeshInstance3D.new()
	flash.name = "ShotImpactFlash"
	var sphere := SphereMesh.new()
	sphere.radius = 0.065
	sphere.height = 0.13
	flash.mesh = sphere
	flash.material_override = _surface_material(surface_color, 0.20) if surface_debris else impact_material
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flash)
	stage._add_scene_outline(flash,0.75)
	flash.global_position = point + normal * 0.018
	impacts.append(flash)
	var tween := flash.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash,"scale",Vector3.ONE * 1.9,0.055).from(Vector3.ONE * 0.45)
	tween.tween_property(flash,"scale",Vector3.ONE * 0.08,0.07)
	tween.tween_callback(flash.queue_free)
	var particle_count := fx_rng.randi_range(7,11) if surface_debris else fx_rng.randi_range(4,7)
	for i in range(particle_count):
		var chip := MeshInstance3D.new()
		chip.name = "SurfaceDebrisParticle" if surface_debris else "ImpactSpark"
		var box := BoxMesh.new()
		var debris_scale := fx_rng.randf_range(0.85,1.35) if surface_debris else 1.0
		box.size = Vector3(
			fx_rng.randf_range(0.018,0.035) * debris_scale,
			fx_rng.randf_range(0.018,0.035) * debris_scale,
			fx_rng.randf_range(0.07,0.16) * debris_scale
		)
		chip.mesh = box
		if surface_debris:
			var variation := 0.16 if i % 3 == 0 else (-0.10 if i % 3 == 1 else 0.0)
			chip.material_override = _surface_material(surface_color, variation)
		else:
			chip.material_override = impact_hot_material if i % 2 == 0 else impact_material
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chip)
		chip.global_position = point + normal * 0.025
		var tangent := Vector3(fx_rng.randf_range(-1.0,1.0),fx_rng.randf_range(-0.2,1.0),fx_rng.randf_range(-1.0,1.0)).normalized()
		var speed := (
			normal * fx_rng.randf_range(0.65,1.65)
			+ tangent * fx_rng.randf_range(0.45,1.45)
		) if surface_debris else (
			normal * fx_rng.randf_range(1.2,2.8)
			+ tangent * fx_rng.randf_range(0.8,2.2)
		)
		hit_effects.append({
			"node":chip,
			"age":0.0,
			"duration":fx_rng.randf_range(0.28,0.48) if surface_debris else fx_rng.randf_range(0.18,0.34),
			"velocity":speed,
			"number":false,
			"kind":"surface_debris" if surface_debris else "spark",
			"spin":fx_rng.randf_range(-11.0,11.0),
			"gravity":fx_rng.randf_range(3.5,6.5) if surface_debris else 9.8,
			"angular":Vector3(
				fx_rng.randf_range(-9.0,9.0),
				fx_rng.randf_range(-9.0,9.0),
				fx_rng.randf_range(-9.0,9.0)
			),
			"shrink_from":0.38 if surface_debris else 0.72,
		})

func _on_target_damaged(_target: Node3D, lethal: bool) -> void:
	hit_timer = 0.13
	lethal_hit = lethal
	if lethal:
		var id := _target.get_instance_id()
		if credited_kills.has(id): return
		credited_kills[id] = true
		kills += 1
		total_kills += 1
		score_pulse = 0.65
		if director != null: director.on_kill(_target)
	if reticle != null: reticle.notify_hit(lethal)
	if confirm_audio != null:
		confirm_audio.stream = confirm_kill if lethal else confirm_hit
		confirm_audio.play()
	_update_counter()

func _update_counter() -> void:
	if counter != null: counter.text = "ENTER / B: new run after defeat"
	if kill_label != null: kill_label.text = "KILLS  %d" % total_kills
	var alive := 0
	for target in targets:
		if is_instance_valid(target) and not target.dead: alive += 1
	if alive_label != null:
		alive_label.text = "ENEMIES  %d" % alive
	if wave_label != null and director != null:
		wave_label.text = "WAVE %02d   //   %d LEFT" % [director.wave,director.remaining_count()]

func is_game_over() -> bool:
	return director != null and director.dead

func set_training_mode(value: bool) -> void:
	# Explicit test/training switch; QA does NOT silently disable live gameplay.
	if director != null:
		director.attacks_enabled = not value
		director.advancement_enabled = not value
		if value: director.clear_projectiles()

func _physics_process(delta: float) -> void:
	if director == null: return
	if not OS.get_cmdline_user_args().has("--kw-qa") and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	director.tick(delta)

func _process(delta: float) -> void:
	hit_timer = maxf(0, hit_timer - delta)
	_update_feedback_effects(delta)
	for index in range(trail_echoes.size()-1,-1,-1):
		var echo_data: Dictionary = trail_echoes[index]
		var echo: MeshInstance3D = echo_data["node"]
		if not is_instance_valid(echo):
			trail_echoes.remove_at(index)
			continue
		echo_data["age"] = float(echo_data["age"]) + delta
		var ep := clampf(float(echo_data["age"]) / float(echo_data["duration"]),0.0,1.0)
		echo.global_position += (echo_data["drift"] as Vector3) * delta
		echo.rotate_object_local(Vector3.FORWARD,float(echo_data["spin"]) * delta)
		echo.transparency = lerpf(0.10,1.0,ep)
		var shrink := maxf(0.05,1.0-ep*0.82)
		echo.scale = Vector3(shrink,shrink,maxf(0.16,1.0-ep*0.55))
		if ep >= 1.0:
			echo.queue_free()
			trail_echoes.remove_at(index)
	for index in range(active_tracers.size()-1,-1,-1):
		var data: Dictionary = active_tracers[index]
		var node: Node3D = data["node"]
		if not is_instance_valid(node):
			active_tracers.remove_at(index)
			continue
		data["age"] += delta
		data["trail_timer"] = float(data.get("trail_timer",0.0)) + delta
		var p := minf(1.0, float(data["age"]) / float(data["duration"]))
		var length := float(data["length"])
		var streak := float(data["streak"])
		var travel := lerpf(minf(streak * 0.25,length * 0.25), maxf(streak * 0.25,length - streak * 0.25), p)
		node.global_position = data["start"] + data["direction"] * travel
		while float(data["trail_timer"]) >= 0.008:
			data["trail_timer"] = float(data["trail_timer"]) - 0.008
			var trail_pos: Vector3 = node.global_position - (data["direction"] as Vector3) * float(data["streak"]) * 0.42
			_spawn_trail_echo(
				trail_pos,
				data["direction"],
				float(data["width"]),
				bool(data.get("hot",false)),
				data.get("color", Color("fff1a8")) as Color,
				bool(data.get("inferno",false))
			)
		node.rotate_object_local(Vector3.FORWARD,float(data["spin"]) * delta)
		var halo: MeshInstance3D = data["halo"]
		var head: MeshInstance3D = data["head"]
		if is_instance_valid(halo):
			halo.position.x = sin(p * TAU * 1.25 + float(data["phase"])) * float(data["wobble"])
			halo.scale = Vector3(1.0 + sin(p * PI) * 0.32,1.0 + sin(p * PI) * 0.32,maxf(0.08,1.0-p*0.58))
		if is_instance_valid(head):
			head.position.x = cos(p * TAU + float(data["phase"])) * float(data["wobble"]) * 0.55
			head.scale = Vector3.ONE * (1.15 + sin(p * PI) * 0.60)
		if p >= 1.0:
			node.queue_free()
			active_tracers.remove_at(index)

func _build_confirm_audio() -> void:
	confirm_hit = _make_tick(false)
	confirm_kill = _make_tick(true)
	confirm_audio = AudioStreamPlayer.new()
	confirm_audio.name = "HitConfirmAudio"
	confirm_audio.volume_db = -80.0 if OS.get_cmdline_user_args().has("--kw-qa") else -14.0
	confirm_audio.bus="SFX"
	confirm_audio.max_polyphony = 3
	add_child(confirm_audio)

func _make_tick(lethal: bool) -> AudioStreamWAV:
	# Original quiet, dry confirmation tones; only on confirmed damage.
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := 0.065 if lethal else 0.030
	var samples := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	for i in range(samples):
		var t := float(i) / float(stream.mix_rate)
		var envelope := minf(1.0, t / 0.0015) * pow(1.0 - t / duration, 3.0)
		var wave := sin(TAU * (920.0 if lethal else 670.0) * t) * 0.50
		wave += sin(TAU * (1380.0 if lethal else 1340.0) * t) * 0.18
		bytes.encode_s16(i * 2, int(wave * envelope * 20000.0))
	stream.data = bytes
	return stream

func set_roaming_enabled(value: bool) -> void:
	roaming_enabled = value
	for target in targets:
		if is_instance_valid(target): target.roaming_enabled = value

func _build_score_hud() -> void:
	# Kept separate from the help overlay: TAB cannot hide combat feedback.
	var panel := Control.new()
	panel.name = "CombatScore"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.get_node("HUD").add_child(panel)
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -148
	panel.offset_right = -12
	panel.offset_top = 9
	panel.offset_bottom = 74
	var background := ColorRect.new()
	background.color = Color(0.025, 0.03, 0.055, 0.8)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	kill_label = Label.new()
	kill_label.name = "KillCounter"
	kill_label.position = Vector2(9, 2)
	kill_label.size = Vector2(118, 23)
	kill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	kill_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(kill_label)
	alive_label = Label.new()
	alive_label.name = "AliveCounter"
	alive_label.position = Vector2(9, 27)
	alive_label.size = Vector2(118, 15)
	alive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	alive_label.add_theme_font_size_override("font_size", 10)
	alive_label.add_theme_color_override("font_color", Color("9bb9ca"))
	panel.add_child(alive_label)
	wave_label = Label.new()
	wave_label.position = Vector2(0, 46)
	wave_label.size = Vector2(127, 19)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_label.add_theme_font_size_override("font_size", 10)
	wave_label.add_theme_color_override("font_color",Color("ffd68a"))
	panel.add_child(wave_label)
	kill_notice = Label.new()
	kill_notice.name = "KillNotice"
	kill_notice.text = "+1 KILL"
	kill_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kill_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kill_notice.add_theme_font_size_override("font_size", 13)
	kill_notice.add_theme_color_override("font_color", Color("ffd287"))
	kill_notice.add_theme_constant_override("outline_size", 3)
	stage.get_node("HUD").add_child(kill_notice)
	kill_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	kill_notice.offset_left = -48
	kill_notice.offset_right = 48
	kill_notice.offset_top = 33
	kill_notice.offset_bottom = 56
	kill_notice.hide()

func _spawn_damage_feedback(point: Vector3,direction: Vector3,amount: float,lethal: bool,blood_color: Color = Color("fa0512"),show_number: bool = true) -> void:
	# Cosmetic only. Randomness changes presentation, never hit direction or damage.
	while hit_effects.size() > 160:
		var oldest: Dictionary = hit_effects.pop_front()
		if is_instance_valid(oldest.node):
			oldest.node.queue_free()
	if director != null and show_number:
		director.hud.damage_number(point, amount, lethal)
	var blood_material := _fx_material(blood_color,5.4)
	var blood_hot := _fx_material(blood_color.lightened(0.30),7.2)
	var count := fx_rng.randi_range(38,52) if lethal else fx_rng.randi_range(20,28)
	var bonk := fx_rng.randf() < 0.10
	for i in range(count):
		var chip := MeshInstance3D.new()
		var box := BoxMesh.new()
		var base_size:=fx_rng.randf_range(0.15,0.27)*(2.15 if lethal and i<7 else 1.0)
		var shape_roll:=fx_rng.randf()
		if shape_roll<0.42:
			box.size=Vector3(base_size*fx_rng.randf_range(0.75,1.35),base_size*fx_rng.randf_range(0.65,1.25),base_size*fx_rng.randf_range(0.75,1.55))
		elif shape_roll<0.78:
			box.size=Vector3(base_size*fx_rng.randf_range(0.35,0.65),base_size*fx_rng.randf_range(0.45,0.85),base_size*fx_rng.randf_range(1.7,3.0))
		else:
			box.size=Vector3(base_size*fx_rng.randf_range(1.4,2.3),base_size*fx_rng.randf_range(0.25,0.55),base_size*fx_rng.randf_range(0.55,1.15))
		chip.mesh = box
		chip.material_override = blood_hot if i % 4 == 0 else blood_material
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chip)
		if i < 4:
			stage._add_scene_outline(chip,0.75)
		chip.global_position=point+Vector3(fx_rng.randf_range(-0.14,0.14),fx_rng.randf_range(-0.08,0.16),fx_rng.randf_range(-0.14,0.14))
		var radial:=Vector3(fx_rng.randf_range(-1.0,1.0),fx_rng.randf_range(-0.20,1.0),fx_rng.randf_range(-1.0,1.0)).normalized()
		var spray_sign:=1.0 if fx_rng.randf()>0.18 else -0.35
		var speed:=direction.normalized()*fx_rng.randf_range(1.0,4.4)*spray_sign+radial*fx_rng.randf_range(0.8,4.0)+Vector3.UP*fx_rng.randf_range(0.2,2.6)
		if bonk and i==0:speed*=1.7
		var angular:=Vector3(fx_rng.randf_range(-13.0,13.0),fx_rng.randf_range(-13.0,13.0),fx_rng.randf_range(-13.0,13.0))
		hit_effects.append({"node":chip,"age":0.0,"duration":fx_rng.randf_range(0.95,1.45) if lethal else fx_rng.randf_range(0.68,1.12),"velocity":speed,"number":false,"kind":"blood_chunk","gravity":fx_rng.randf_range(8.8,14.0),"drag":fx_rng.randf_range(0.20,0.85),"angular":angular})

func _update_feedback_effects(delta: float) -> void:
	score_pulse = maxf(0.0, score_pulse - delta)
	if kill_label != null:
		kill_label.modulate = Color.WHITE.lerp(Color("ffd18a"), minf(1.0, score_pulse * 3.0))
	if kill_notice != null:
		kill_notice.visible = score_pulse > 0.0
		kill_notice.modulate.a = minf(1.0, score_pulse * 5.0)
	for i in range(hit_effects.size() - 1, -1, -1):
		var effect: Dictionary = hit_effects[i]
		var node: Node3D = effect.node
		if not is_instance_valid(node):
			hit_effects.remove_at(i)
			continue
		effect.age += delta
		node.global_position += (effect.velocity as Vector3) * delta
		if effect.number:
			(node as Label3D).modulate.a = minf(1.0, (float(effect.duration) - float(effect.age)) * 6.0)
		else:
			var velocity: Vector3=effect.velocity
			velocity*=exp(-float(effect.get("drag",0.35))*delta)
			velocity.y-=float(effect.get("gravity",9.8))*delta
			effect.velocity=velocity
			if node is MeshInstance3D:
				(node as MeshInstance3D).rotation+=(effect.get("angular",Vector3.ZERO) as Vector3)*delta
			var ratio:=clampf(float(effect.age)/maxf(0.001,float(effect.duration)),0.0,1.0)
			var shrink_from:=clampf(float(effect.get("shrink_from",0.72)),0.0,0.96)
			var scale_factor:=1.0 if ratio<shrink_from else lerpf(1.0,0.05,(ratio-shrink_from)/maxf(0.04,1.0-shrink_from))
			node.scale=Vector3.ONE*scale_factor
		if float(effect.age) >= float(effect.duration):
			node.queue_free()
			hit_effects.remove_at(i)
