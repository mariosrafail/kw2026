extends SceneTree
var failures: Array[String] = []
var shot_events := 0
var reload_events := 0
func check(value: bool,label: String) -> void:
	if not value:
		failures.append(label)
		push_error("AK_MAG_FAIL "+label)
func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	ProjectSettings.set_setting("kw3d/offline_test_mode","sandbox")
	var stage=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(5):await physics_frame
	stage.combat.set_training_mode(true);stage.combat.set_roaming_enabled(false)
	check(stage.ammo_in_mag==25,"offline_full_mag")
	var shots_before: int=stage.combat.shots_fired
	for i in range(25):
		stage.shot_cooldown=0.0
		stage._fire_physics_ball()
	check(stage.ammo_in_mag==0,"offline_25_consumed")
	check(stage.reload_remaining>0.9,"offline_auto_reload_started")
	stage.shot_cooldown=0.0
	stage._fire_physics_ball()
	check(stage.combat.shots_fired==shots_before+25,"offline_26th_blocked")
	for i in range(61):stage._tick_reload(1.0/60.0)
	check(stage.ammo_in_mag==25 and stage.reload_remaining<=0.0001,"offline_reload_completes")
	stage.ammo_in_mag=9;stage.reload_remaining=0.0
	check(stage._start_reload(false),"offline_manual_reload")
	for i in range(61):stage._tick_reload(1.0/60.0)
	check(stage.ammo_in_mag==25,"offline_manual_refill")
	check(stage.player_ammo_label!=null and "25 / 25" in stage.player_ammo_label.text,"ammo_hud_updates")
	stage._set_weapon_slot(1,false)
	check(stage.ammo_in_mag==2 and "SHOTGUN" in stage.player_ammo_label.text,"shotgun_slot_has_two_shells")
	stage.shot_cooldown=0.0;stage._fire_physics_ball();stage.shot_cooldown=0.0;stage._fire_physics_ball()
	check(stage.ammo_in_mag==0 and stage.reload_remaining>1.0,"shotgun_two_shell_auto_reload")
	stage._set_weapon_slot(0,false)
	check(stage.ammo_in_mag==25,"switch_back_preserves_ak_mag")
	stage.queue_free()
	for i in range(3):await process_frame

	var world=load("res://scripts/kw3d/authority_world.gd").new()
	root.add_child(world);world.attacks_enabled=false;world.add_player(1)
	var actor: Node3D=world.actors[1]
	actor.command=load("res://scripts/kw3d/actor_motor.gd").empty(actor.aim_yaw,actor.aim_pitch)
	actor.command.fire=true
	shot_events=0;reload_events=0
	world.event_created.connect(func(e: Dictionary):
		if str(e.type)=="shot":shot_events+=1
		if str(e.type)=="reload":reload_events+=1
	)
	for i in range(150):
		world.step();await physics_frame
	check(shot_events==25,"authority_exact_25_before_reload")
	check(actor.ammo==0 and actor.reload_clock>0.0,"authority_auto_reload_active")
	check(reload_events==1,"authority_single_auto_reload_event")
	actor.command.fire=false
	for i in range(61):
		world.step();await physics_frame
	check(actor.ammo==25 and actor.reload_clock<=0.0001,"authority_reload_refills")
	actor.ammo=7;actor.reload_clock=0.0;actor.command.reload=true
	world.step();await physics_frame
	check(actor.reload_clock>0.9 and actor.ammo==7,"authority_manual_reload_started")
	actor.command.reload=false
	for i in range(61):
		world.step();await physics_frame
	check(actor.ammo==25,"authority_manual_reload_refills")
	print("AK_MAGAZINE_RELOAD_","PASS" if failures.is_empty() else "FAIL",failures,
		" shot_events=",shot_events," reload_events=",reload_events)
	world.free();quit(0 if failures.is_empty() else 1)
