extends SceneTree
var stage: Node3D
var d: RefCounted
var output := ""
var failures: Array[String] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=")
	run.call_deferred()
func check(value: bool, label: String) -> void:
	if not value and not failures.has(label):
		failures.append(label)
		push_error("WAVE_QA_FAIL "+label)
func capture(label: String) -> void:
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label+".png"))==OK,"capture_saved")
func aim_at(bot: Node3D) -> void:
	stage.player.global_position=bot.global_position+Vector3(0,0,6.0)
	stage.player_visual.rotation=Vector3.ZERO
	stage.body_yaw=0
	stage.camera.global_position=stage.player.global_position+Vector3(1.2,1.35,3.8)
	stage.camera.look_at(bot.visuals.get_node("TorsoRig/Torso_Upper").global_position,Vector3.UP)
	stage._update_weapon_pose(0)
func run() -> void:
	stage=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	d=stage.combat.director
	stage.combat.set_physics_process(false)
	d.attacks_enabled=false
	for i in range(60): await physics_frame
	stage.set_physics_process(false)
	stage.set_process_unhandled_input(false)
	stage.combat.set_roaming_enabled(false)
	check(d.wave==1 and d.wave_budget==3 and d.alive_count()==3,"initial_wave_three")
	check(d.health==100 and not d.dead,"player_full_health")
	check(d.hud.hp_text.text.contains("100 / 100"),"player_health_label")
	var tab:=InputEventKey.new(); tab.pressed=true; tab.physical_keycode=KEY_TAB
	stage._unhandled_input(tab)
	check(not stage.help_panel.visible,"tab_hides_help")
	check(d.hud.get_node("PlayerHealth").is_visible_in_tree(),"tab_keeps_health")
	check(stage.combat.kill_label.is_visible_in_tree(),"tab_keeps_score")
	await process_frame
	var hp_panel: Control=d.hud.get_node("PlayerHealth")
	check(Rect2(Vector2.ZERO,d.hud.size).encloses(hp_panel.get_global_rect()),"player_health_inside_screen")
	await capture("waves_gameplay")
	# Deterministic damage / unique kill healing through the actual player rifle.
	var bot: Node3D=stage.combat.targets[0]
	bot.roaming_enabled=false
	check(d.receive_player_damage(40,Vector3.ZERO),"player_can_take_damage")
	check(d.health==60,"health_decrement")
	check(not d.receive_player_damage(8,Vector3.ZERO),"brief_damage_grace")
	for n in range(2):
		aim_at(bot)
		stage.shot_cooldown=0
		if n==1:bot.health=5.0;bot._refresh_bar()
		stage._fire_physics_ball()
		check(bot.health==(95.0 if n==0 else 0.0),"rifle_damage_"+str(n))
		if n==0:
			check(not d.hud.damage_labels.is_empty(),"red_damage_created")
			var number: Label=d.hud.damage_labels.back().node
			check(number.get_theme_font_size("font_size")>=27,"damage_number_larger")
			var color:=number.get_theme_color("font_color")
			check(color.r>0.9 and color.g<0.4,"damage_number_red")
			await capture("large_red_damage")
			var scale_before:=number.scale
			for j in range(9): await process_frame
			check(number.scale.distance_to(scale_before)>0.1,"animated_number_pop")
		for i in range(2): await physics_frame
	check(bot.dead and d.health==68,"kill_heals_eight")
	var total: int=stage.combat.total_kills
	stage.combat._on_target_damaged(bot,true)
	check(d.health==68 and stage.combat.total_kills==total,"no_duplicate_heal_kill")
	await capture("kill_heal_health")
	d.health=98;d.hud.set_health(98,100,true)
	d.on_kill(bot)
	check(d.health==100,"heal_capped_at_max")
	print("RED_DAMAGE_HEALTH_HEAL_PASS")
	# Clear the other enemies: exactly one intermission and automatic next wave.
	for target in stage.combat.targets:
		if is_instance_valid(target) and not target.dead: target.receive_hit(100,Vector3.FORWARD,90000+target.get_instance_id())
	d.tick(0.016)
	check(d.phase=="REST","wave_waits_for_all_dead")
	for i in range(42): d.tick(0.1)
	check(d.wave==2 and d.wave_budget==5,"automatic_second_wave")
	for i in range(40):
		await physics_frame
		d.tick(0.1)
	check(d.alive_count()==5,"second_wave_more_enemies")
	# All six looks and bounded reinforcement load.
	d.begin_wave(3)
	for i in range(60):
		await physics_frame
		d.tick(0.1)
	var skins: Dictionary={}
	for target in stage.combat.targets:
		if is_instance_valid(target):
			skins[target.warrior_id]=true
			check(target.health_bar.texture.get_width()==128,"larger_enemy_bar")
			check(target.weapon_muzzle!=null,"visible_enemy_weapon")
	check(skins.size()==6,"six_distinct_enemy_looks")
	var observer:=Camera3D.new();stage.add_child(observer);observer.current=true
	observer.global_position=Vector3(27,18,19);observer.look_at(Vector3(0,1,-7),Vector3.UP);observer.fov=58
	await capture("six_enemy_skins_wave3")
	observer.current=false;stage.camera.current=true
	d.begin_wave(6)
	for i in range(100):
		await physics_frame
		d.tick(0.1)
		check(d.alive_count()<=8,"max_eight_live")
	check(d.wave_budget==13 and d.spawned==8,"reinforcement_budget")
	var victim: Node3D=stage.combat.targets[0]
	victim.receive_hit(100,Vector3.FORWARD,910001)
	for i in range(12):
		await physics_frame
		d.tick(0.1)
	check(d.spawned==9 and d.alive_count()==8,"reinforcement_replaces_dead_slot")
	# Force the first authored pad to be skipped while spawning a batch.
	stage.player.global_position=Vector3(-10,1.735,-9)
	d.begin_wave(1)
	for a in range(stage.combat.targets.size()):
		for b in range(a+1,stage.combat.targets.size()):
			check(stage.combat.targets[a].global_position.distance_to(stage.combat.targets[b].global_position)>2.1,"same_tick_spawn_separation")
	print("WAVES_SKINS_REINFORCEMENTS_PASS")
	# Real projectiles: swept path, cover, moving target can evade, no homing.
	stage._add_static_box("WaveTestFloor",Vector3(0,-0.5,65),Vector3(45,1,45),Color(0.14,0.17,0.22))
	stage.player.global_position=Vector3(0,1.715,65)
	stage.camera.global_position=stage.player.global_position+Vector3(1.2,1.35,6.4)
	stage.camera.look_at(stage.player.global_position+Vector3(0,0,-10),Vector3.UP)
	for i in range(3): await physics_frame
	d.health=100;d.damage_grace=0;d.hud.set_health(100,100,true)
	var origin:=Vector3(0,1.7,59)
	d.launch_bullet(origin,Vector3.BACK)
	for i in range(26):
		d._tick_projectiles(1.0/60.0)
		await physics_frame
	check(d.health==92,"hostile_projectile_damages_player")
	var wall:=StaticBody3D.new();stage.add_child(wall);wall.position=Vector3(0,1.7,62)
	var shape:=CollisionShape3D.new();var cube:=BoxShape3D.new();cube.size=Vector3(4,4,0.3);shape.shape=cube;wall.add_child(shape)
	for i in range(3): await physics_frame
	d.damage_grace=0;d.launch_bullet(origin,Vector3.BACK)
	for i in range(26):
		d._tick_projectiles(1.0/60.0)
		await physics_frame
	check(d.health==92,"cover_stops_enemy_damage")
	wall.queue_free()
	for i in range(3): await physics_frame
	d.launch_bullet(origin,Vector3.BACK)
	stage.player.global_position.x=3.0
	for i in range(32):
		d._tick_projectiles(1.0/60.0)
		await physics_frame
	check(d.health==92,"sidestep_dodges_projectile")
	d.clear_projectiles()
	# An autonomous enemy announces and fires; damage cancels a warning.
	var shooter: Node3D=stage.combat.targets[1]
	shooter.global_position=Vector3(0,1.715,58)
	shooter.movement_body.global_position=shooter.global_position
	shooter.roaming_enabled=false
	stage.player.global_position=Vector3(0,1.715,65)
	for i in range(3): await physics_frame
	d.attacks_enabled=true;d.attack_clock=0;d.cooldowns[shooter.get_instance_id()]=0
	d._tick_attacks(0.016)
	check(not d.warning.is_empty() and shooter.attack_warning,"enemy_shot_telegraphed")
	var before_shots: int=d.enemy_shots_fired
	for i in range(45): d._tick_attacks(1.0/60.0)
	check(d.enemy_shots_fired==before_shots+1,"enemy_occasionally_fires")
	check(not d.projectiles.is_empty(),"enemy_bolt_visible")
	d.clear_projectiles();d.attack_clock=0;d.cooldowns[shooter.get_instance_id()]=0
	d._tick_attacks(0.016)
	shooter.receive_hit(20,Vector3.FORWARD,930001)
	d._tick_attacks(0.016)
	check(d.warning.is_empty(),"hit_interrupts_enemy_charge")
	print("HOSTILE_BULLETS_COVER_DODGE_TELEGRAPH_PASS")
	# Clean game-over and input-driven restart, no kills or healing after death.
	d.damage_grace=0;d.receive_player_damage(200,Vector3.ZERO)
	check(d.dead and d.health==0 and d.phase=="DEAD","player_death")
	check(d.hud.game_over_panel.visible and d.projectiles.is_empty(),"death_clears_bullets_and_shows_restart")
	var shots: int=stage.combat.shots_fired
	stage.shot_cooldown=0;stage._fire_physics_ball()
	check(stage.combat.shots_fired==shots,"dead_cannot_shoot")
	d.on_kill(shooter);check(d.health==0,"dead_cannot_heal")
	await process_frame
	check(Rect2(Vector2.ZERO,d.hud.size).encloses(d.hud.death_stats.get_global_rect()),"gameover_text_inside_screen")
	await capture("wave_game_over")
	var enter:=InputEventKey.new();enter.physical_keycode=KEY_ENTER;enter.pressed=true
	stage._unhandled_input(enter)
	check(not d.dead and d.wave==1 and d.health==100,"enter_restarts_full_health_wave1")
	check(stage.combat.total_kills==0 and not d.hud.game_over_panel.visible,"restart_clears_score")
	check(stage.combat.roaming_enabled,"restart_restores_roaming")
	print("DEATH_RESTART_PASS")
	var f:=FileAccess.open(output.path_join("wave_results.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"failures":failures,"skins":skins.keys(),"enemy_shots":d.enemy_shots_fired,"player_hits":d.player_hits},"\t"));f.close()
	stage.queue_free()
	for i in range(10): await process_frame
	print("WAVE_QA_","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
