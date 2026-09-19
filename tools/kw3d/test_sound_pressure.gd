extends "res://tools/kw3d/test_combat_polish.gd"
func run() -> void:
	stage=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	stage.set_physics_process(false)
	stage.set_process_unhandled_input(false)
	stage.combat.set_physics_process(false)
	stage.grenade_skill.set_physics_process(false)
	stage._toggle_instructions()
	stage._add_static_box("PressureFloor",Vector3(0,-0.5,65),Vector3(40,1,40),Color(0.1,0.12,0.2))
	for i in range(3):
		var bot: Node3D=stage.combat.targets[i]
		bot.set_physics_process(false)
		bot.global_position=Vector3(float(i-1)*3.0,1.715,60)
		bot.movement_body.global_position=bot.global_position
		bot._update_shapes()
	stage.player.global_position=Vector3(0,1.715,72)
	for i in range(5): await physics_frame
	var d: RefCounted=stage.combat.director
	d.attack_clock=0
	d.damage_grace=999
	for bot in stage.combat.targets: d.cooldowns[bot.get_instance_id()]=0.0
	var start: int=d.enemy_shots_fired
	for i in range(600):
		d._tick_attacks(1.0/60.0)
		d._tick_projectiles(1.0/60.0)
	var shots: int=d.enemy_shots_fired-start
	check(shots>=8,"higher_pressure_at_least_eight_shots_in_ten_seconds")
	check(d.projectiles.size()<=8,"hostile_pool_bounded")
	print("ENEMY_PRESSURE_PASS shots_per_10_seconds=",shots)
	d.clear_projectiles()
	check(stage.arena_audio.music.stream.get_length()>5.0,"soundtrack_decodes")
	for key in stage.arena_audio.SOUNDS:
		check(stage.arena_audio.SOUNDS[key].get_length()>0.0,"sfx_decodes_"+str(key))
	print("AUDIO_SOURCE_DECODE_PASS music_seconds=",stage.arena_audio.music.stream.get_length())
	d.dead=true
	var mute:=InputEventKey.new(); mute.pressed=true; mute.physical_keycode=KEY_M
	stage._unhandled_input(mute)
	check(not stage.arena_audio.music_enabled,"music_toggle_after_death")
	stage._unhandled_input(mute)
	check(stage.arena_audio.music_enabled,"music_toggle_back_on")
	d.dead=false
	stage.grenade_skill.requested=true
	stage._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not stage.grenade_skill.requested,"focus_loss_clears_pending_throw")
	stage.get_node("HUD").visible=false
	observer=Camera3D.new()
	stage.add_child(observer)
	observer.current=true
	observer.position=Vector3(8,5.5,70)
	observer.look_at(Vector3(0,1,62),Vector3.UP)
	observer.fov=52
	stage.grenade_skill.detonate(Vector3(0,0.2,62))
	stage.grenade_skill._tick_effects(0.10)
	await capture("explosion_clear_view")
	stage.grenade_skill._tick_effects(0.18)
	await capture("explosion_smoke_shockwave")
	stage.get_node("HUD").visible=true
	stage._toggle_instructions()
	stage.camera.current=true
	await capture("hud_all_controls")
	stage.queue_free()
	for i in range(10): await process_frame
	print("SOUND_PRESSURE_VISUAL_QA_","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
