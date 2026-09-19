extends RefCounted
## Endless local waves. Enemy bullets are visible, dodgeable and blocked by terrain.
const DUMMY := preload("res://scripts/prototypes/kw_training_dummy.gd")
const HUD := preload("res://scripts/prototypes/kw_arena_hud.gd")
const SKINS := ["tasko","gan","celler","nova","m4","crashout"]
const MAX_ALIVE := 8
const MAX_HEALTH := 100.0
const HEAL_PER_KILL := 8.0
const BULLET_DAMAGE := 8.0
const BULLET_SPEED := 21.0
const ATTACK_WARNING := 0.38
const PAD_POINTS := [Vector2(-10,-10),Vector2(10,-10),Vector2(0,-17),Vector2(-18,5),Vector2(18,5),Vector2(-18,-22),Vector2(18,-24),Vector2(-9,-22),Vector2(9,-22),Vector2(0,-10),Vector2(-12,11),Vector2(12,11),Vector2(0,13)]
var stage: Node3D
var combat: Node3D
var hud: Control
var health := MAX_HEALTH
var dead := false
var wave := 0
var wave_budget := 0
var spawned := 0
var phase := "WAVE"
var wait_time := 0.0
var spawn_clock := 0.0
var attack_clock := 4.0
var elapsed := 0.0
var bootstrapping := true
var damage_grace := 0.0
var attacks_enabled := true
var advancement_enabled := true
var suspended := false
var enemy_shots_fired := 0
var player_hits := 0
var healing_received := 0.0
var projectiles: Array[Dictionary] = []
var warning: Dictionary = {}
var cooldowns: Dictionary = {}
var rng := RandomNumberGenerator.new()
var spawn_probe: CapsuleShape3D
var bullet_material: Material

func setup(owner_combat: Node3D) -> void:
	combat = owner_combat
	stage = combat.stage
	rng.randomize()
	hud = HUD.new()
	stage.get_node("HUD").add_child(hud)
	hud.setup(stage)
	spawn_probe = CapsuleShape3D.new()
	spawn_probe.height=3.40
	spawn_probe.radius=0.62
	bullet_material=stage._material(Color("ff6949"),true,0.7)
	begin_wave(1)
	bootstrapping=false

func alive_count() -> int:
	var count := 0
	for bot in combat.targets:
		if is_instance_valid(bot) and not bot.dead: count+=1
	return count

func remaining_count() -> int:
	return alive_count()+maxi(0,wave_budget-spawned)

func _clear_warning() -> void:
	if not warning.is_empty():
		var bot: Node3D = (warning.bot as WeakRef).get_ref()
		if is_instance_valid(bot): bot.set_attack_warning(false)
	warning.clear()

func clear_projectiles() -> void:
	for bullet in projectiles:
		if is_instance_valid(bullet.node): bullet.node.queue_free()
	projectiles.clear()
	_clear_warning()

func _clear_targets() -> void:
	clear_projectiles()
	if stage.grenade_skill != null: stage.grenade_skill.clear_active(false)
	for bot in combat.targets:
		if is_instance_valid(bot):
			bot.collision_layer=0
			bot.set_physics_process(false)
			if is_instance_valid(bot.movement_body): bot.movement_body.collision_layer=0
			bot.queue_free()
	combat.targets.clear()
	combat.credited_kills.clear()
	cooldowns.clear()

func begin_wave(number: int) -> void:
	_clear_targets()
	wave=number
	wave_budget=mini(19,3+(wave-1)*2)
	spawned=0
	phase="WAVE"
	wait_time=0.0
	spawn_clock=0.0
	attack_clock=2.2
	combat.kills=0
	# The initial trio is immediately available; later reinforcements are staggered.
	for i in range(mini(3,wave_budget)):
		if not _spawn_next(): break
	spawn_clock=0.65
	hud.announce("WAVE %02d" % wave,"%d ENEMIES   //   +8 HP PER KILL" % wave_budget,2.3)
	if stage.arena_audio != null: stage.arena_audio.play_event("wave",Vector3.ZERO,-22.0)
	combat._update_counter()

func retry_wave() -> void:
	if dead:
		restart_run()
		return
	begin_wave(maxi(1,wave))
	if combat.reticle != null: combat.reticle.clear_feedback()

func restart_run() -> void:
	dead=false
	health=MAX_HEALTH
	damage_grace=1.2
	combat.roaming_enabled=true
	combat.total_kills=0
	combat.shots_fired=0
	combat.score_pulse=0.0
	stage.player.global_position=Vector3(0,2.2,6)
	stage.player.velocity=Vector3.ZERO
	stage.player_visual.visible=true
	stage.fire_held=false
	stage.aiming=false
	stage.shot_cooldown=0.0
	stage.ammo_in_mag=stage.AK_MAGAZINE.MAGAZINE_SIZE;stage.reload_remaining=0.0;stage._refresh_ammo_hud()
	stage.locomotion.reset()
	hud.reset_run()
	if stage.grenade_skill != null: stage.grenade_skill.clear_active(true)
	if stage.arena_audio != null:
		stage.arena_audio.foot_states.clear()
		stage.arena_audio.initialized = false
	begin_wave(1)
	if not OS.get_cmdline_user_args().has("--kw-qa") and DisplayServer.get_name() != "headless":
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _spawn_next() -> bool:
	if spawned >= wave_budget or alive_count() >= MAX_ALIVE: return false
	var candidate:=Vector3.ZERO
	var found:=false
	# Physics broadphase is not ready during stage._ready(). These three
	# authored floor pads are clear in the arena; later spawns are all probed.
	if bootstrapping and spawned < 3:
		var pad: Vector2=PAD_POINTS[spawned]
		candidate=Vector3(pad.x,1.735,pad.y)
		found=true
	for i in range(PAD_POINTS.size()):
		if found: break
		var point: Vector2=PAD_POINTS[(spawned+i+(wave-1)*3)%PAD_POINTS.size()]
		var ground:=PhysicsRayQueryParameters3D.create(Vector3(point.x,5,point.y),Vector3(point.x,-1,point.y),1)
		var hit:=stage.get_world_3d().direct_space_state.intersect_ray(ground)
		if hit.is_empty() or (hit.normal as Vector3).y<0.85: continue
		candidate=hit.position+Vector3(0,1.735,0)
		if candidate.distance_to(stage.player.global_position)<7.0: continue
		# Same-tick additions may not yet be in the physics broadphase.
		# Check reserved live positions as well, so two spawns never share a pad.
		var occupied := false
		for existing in combat.targets:
			if is_instance_valid(existing) and not existing.dead and existing.global_position.distance_to(candidate)<2.2:
				occupied=true
				break
		if occupied: continue
		var probe:=PhysicsShapeQueryParameters3D.new()
		probe.shape=spawn_probe
		probe.transform=Transform3D(Basis.IDENTITY,candidate+Vector3.UP*0.06)
		probe.collision_mask=11
		if not stage.get_world_3d().direct_space_state.intersect_shape(probe,1).is_empty(): continue
		found=true
		break
	if not found: return false
	var bot:=DUMMY.new()
	bot.name="Wave%02d_Enemy%02d" % [wave,spawned+1]
	bot.warrior_id=SKINS[(spawned+(wave-1)*2)%SKINS.size()]
	bot.roam_bounds=Rect2(-21,-27,42,42)
	bot.roam_seed=rng.randi()
	bot.roaming_enabled=combat.roaming_enabled
	bot.position=candidate
	bot.rotation.y=PI
	combat.add_child(bot)
	bot.set_style(stage.head_style.enabled,stage.pixel_enabled)
	bot.damaged.connect(combat._on_target_damaged)
	combat.targets.append(bot)
	cooldowns[bot.get_instance_id()]=rng.randf_range(1.2,2.8)
	spawned+=1
	# Small, collider-free entrance pulse; no black-box invulnerability period.
	var pulse:=MeshInstance3D.new()
	pulse.name="SpawnPulse"
	var ring:=TorusMesh.new()
	ring.inner_radius=0.63; ring.outer_radius=0.71
	pulse.mesh=ring
	pulse.material_override=stage._material(Color("84edff"),true,0.35)
	pulse.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	combat.add_child(pulse)
	stage._add_scene_outline(pulse,1.2)
	pulse.global_position=candidate+Vector3(0,-1.68,0)
	var tween:=pulse.create_tween()
	tween.tween_property(pulse,"scale",Vector3(1.5,0.04,1.5),0.65).from(Vector3(0.5,0.04,0.5))
	tween.tween_callback(pulse.queue_free)
	combat._update_counter()
	return true

func on_kill(_target: Node3D) -> void:
	if dead: return
	var restored:=minf(HEAL_PER_KILL,MAX_HEALTH-health)
	health+=restored
	healing_received+=restored
	hud.set_health(health,MAX_HEALTH)
	hud.notify_heal(restored)
	if restored>0 and stage.arena_audio != null: stage.arena_audio.play_event("heal",Vector3.ZERO,-24.0)

func receive_player_damage(amount: float, source: Vector3) -> bool:
	if dead or amount<=0 or damage_grace>0: return false
	health=maxf(0,health-amount)
	player_hits+=1
	damage_grace=0.38
	hud.set_health(health,MAX_HEALTH)
	hud.notify_hurt(amount)
	stage._set_player_healthbar(health,MAX_HEALTH)
	var hit_direction: Vector3 = (stage.player.global_position-source).normalized()
	combat._spawn_damage_feedback(stage.player.global_position+Vector3(0,1.15,0),hit_direction,amount,health<=0,combat.blood_color_for_skin("outrage"),false)
	# Visual-only flinch, never a camera kick or an aim displacement.
	var local: Vector3=stage.player_visual.global_basis.inverse()*hit_direction
	stage.locomotion.body_angular_velocity+=Vector3(local.z,0,-local.x)*0.9
	if health<=0:
		dead=true
		phase="DEAD"
		stage.fire_held=false
		stage.aiming=false
		stage.player.velocity=Vector3.ZERO
		clear_projectiles()
		combat.set_roaming_enabled(false)
		hud.show_death(wave,combat.total_kills)
		if stage.grenade_skill != null: stage.grenade_skill.clear_active(false)
		if stage.arena_audio != null: stage.arena_audio.play_event("death",Vector3.ZERO,-17.0)
		if not OS.get_cmdline_user_args().has("--kw-qa"): Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	return true

func tick(delta: float) -> void:
	if dead or suspended: return
	var dt:=clampf(delta,0.0,0.1)
	elapsed+=dt
	damage_grace=maxf(0,damage_grace-dt)
	if advancement_enabled:
		if phase=="REST":
			wait_time-=dt
			if wait_time<=0:
				begin_wave(wave+1)
				return
		elif phase=="WAVE":
			spawn_clock-=dt
			if spawn_clock<=0 and spawned<wave_budget and alive_count()<MAX_ALIVE:
				_spawn_next()
				spawn_clock=0.85
			if spawned>=wave_budget and alive_count()==0:
				phase="REST"
				wait_time=4.0
				_clear_warning()
				hud.announce("WAVE %02d CLEAR" % wave,"NEXT WAVE IN 4 SECONDS",3.4)
		_update_wave_text()
	_tick_projectiles(dt)
	if dead: return
	if attacks_enabled and phase=="WAVE": _tick_attacks(dt)
	elif not warning.is_empty(): _clear_warning()

func _update_wave_text() -> void:
	combat._update_counter()

func _tick_attacks(dt: float) -> void:
	attack_clock-=dt
	for key in cooldowns: cooldowns[key]=maxf(0,float(cooldowns[key])-dt)
	if not warning.is_empty():
		var bot: Node3D=(warning.bot as WeakRef).get_ref()
		if not is_instance_valid(bot) or bot.dead:
			_clear_warning()
			return
		if bot.flash_time>0 or bot.brain.stagger>0:
			_clear_warning() # A hit interrupts the announced shot.
			attack_clock=0.22
			return
		warning.time-=dt
		bot.aim_weapon(warning.target)
		if float(warning.time)<=0:
			var muzzle: Vector3=bot.weapon_muzzle.global_position
			var target: Vector3=warning.target
			if _line_clear(bot.global_position+Vector3(0,0.25,0),muzzle) and _line_clear(muzzle,target):
				launch_bullet(muzzle,(target-muzzle).normalized())
				bot.notify_enemy_fire()
			bot.set_attack_warning(false)
			cooldowns[bot.get_instance_id()]=rng.randf_range(1.8,3.0)
			warning.clear()
			attack_clock=rng.randf_range(0.30,0.58)-minf(0.12,float(wave-1)*0.02)
		return
	if attack_clock>0 or projectiles.size()>=7: return
	var ready: Array[Node3D]=[]
	for bot in combat.targets:
		if not is_instance_valid(bot) or bot.dead or float(cooldowns.get(bot.get_instance_id(),0))>0: continue
		if bot.global_position.distance_to(stage.player.global_position)>34.0: continue
		if _line_clear(bot.global_position+Vector3(0,0.4,0),stage.player.global_position+Vector3(0,0.05,0)): ready.append(bot)
	if ready.is_empty():
		attack_clock=0.35
		return
	var shooter: Node3D=ready[rng.randi_range(0,ready.size()-1)]
	var aim: Vector3=stage.player.global_position+Vector3(rng.randf_range(-0.2,0.2),0.08,0)
	warning={"bot":weakref(shooter),"target":aim,"time":ATTACK_WARNING}
	shooter.set_attack_warning(true)
	shooter.aim_weapon(aim)

func _line_clear(from: Vector3, to: Vector3) -> bool:
	if from.distance_squared_to(to)<0.0001: return true
	var query:=PhysicsRayQueryParameters3D.create(from,to,1)
	query.hit_from_inside=true
	return stage.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func launch_bullet(origin: Vector3, direction: Vector3) -> void:
	if dead or direction.length_squared()<0.01: return
	while projectiles.size()>=8:
		var old: Dictionary=projectiles.pop_front()
		if is_instance_valid(old.node): old.node.queue_free()
	var shot:=MeshInstance3D.new()
	shot.name="HostileBolt"
	var mesh:=BoxMesh.new()
	mesh.size=Vector3(0.12,0.12,0.40)
	shot.mesh=mesh
	shot.material_override=bullet_material
	shot.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	combat.add_child(shot)
	stage._add_scene_outline(shot,1.0)
	shot.global_position=origin
	shot.look_at(origin+direction,Vector3.RIGHT if absf(direction.y)>0.98 else Vector3.UP)
	projectiles.append({"node":shot,"position":origin,"velocity":direction.normalized()*BULLET_SPEED,"age":0.0,"source":origin})
	enemy_shots_fired+=1

func _tick_projectiles(dt: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var shot: Dictionary=projectiles[i]
		if not is_instance_valid(shot.node):
			projectiles.remove_at(i)
			continue
		var from: Vector3=shot.position
		var to: Vector3=from+(shot.velocity as Vector3)*dt
		var query:=PhysicsRayQueryParameters3D.create(from,to,3) # terrain + player; no cosmetic collider
		query.hit_from_inside=true
		var hit:=stage.get_world_3d().direct_space_state.intersect_ray(query)
		shot.age+=dt
		if not hit.is_empty() or float(shot.age)>3.2:
			var hits_player: bool=not hit.is_empty() and hit.collider==stage.player
			var source: Vector3=shot.source
			shot.node.queue_free()
			projectiles.remove_at(i)
			if hits_player:
				receive_player_damage(BULLET_DAMAGE,source)
				if dead: return
		else:
			shot.position=to
			shot.node.global_position=to
