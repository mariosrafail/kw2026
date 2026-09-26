extends SceneTree

var failures: Array[String]=[]

func check(value: bool,label: String)->void:
	if not value:
		failures.append(label)
		push_error("COMBAT_READABILITY_FAIL "+label)

func _initialize()->void:
	run.call_deferred()

func run()->void:
	ProjectSettings.set_setting("kw3d/offline_test_mode","sandbox")
	var stage=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(6):await process_frame
	var hud=stage.combat.director.hud
	check(hud!=null,"hud_exists")
	if hud!=null:
		hud.notify_directional_damage(Vector3(0,0,1),28.0,false)
		hud._process(0.016)
		var center: Vector2=hud.size*0.5
		check(hud.damage_direction_arrow.visible,"direction_arrow_visible")
		check(hud.damage_direction_arrow.position.y<center.y,"front_source_maps_to_top")
		hud.notify_directional_damage(Vector3(-1,0,0),55.0,true)
		hud._process(0.016)
		check(hud.damage_direction_arrow.position.x>center.x,"right_source_maps_to_right")
		check(hud.damage_direction_arrow.color.is_equal_approx(Color("fff0a8")),"headshot_direction_color")
		hud.add_kill_feed("Neon_Rift_417","Void_Claw_222","kar",true,true,false)
		check(hud.kill_feed.size()==1,"kill_feed_entry_created")
		var line: Label=hud.kill_feed[0].label as Label
		check("NEON_RIFT_417" in line.text and "VOID_CLAW_222" in line.text,"kill_feed_names")
		check("HS / KAR" in line.text,"kill_feed_headshot_weapon")
		check(line.get_theme_color("font_color").is_equal_approx(Color("82f3c6")),"local_killer_feed_color")
		hud._process(4.3)
		check(hud.kill_feed.is_empty(),"kill_feed_expires")
		check(not bool(line.get_meta("kw_kill_feed_active",true)),"kill_feed_label_returns_to_pool")
	stage.queue_free()
	for i in range(2):await process_frame

	var world=load("res://scripts/kw3d/duel_authority_world.gd").new()
	root.add_child(world)
	await process_frame
	world.add_player(1);world.add_player(2)
	var p1: Node3D=world.actors[1]
	var p2: Node3D=world.actors[2]
	p1.display_name="NEON_RIFT_417"
	p2.display_name="VOID_CLAW_222"
	world.phase="MATCH"
	world.round_phase="FIGHT"
	p2.health=5.0
	p2.damage_grace=0.0
	var events: Array[Dictionary]=[]
	world.event_created.connect(func(e: Dictionary):events.append(e.duplicate(true)))
	check(world.damage(2,10.0,Vector3.FORWARD,1,p2.global_position,true,"kar"),"duel_lethal_damage_applied")
	var kill: Dictionary={}
	for e in events:
		if str(e.get("type",""))=="kill":kill=e
	check(not kill.is_empty(),"authoritative_kill_event_exists")
	if not kill.is_empty():
		check(str(kill.get("weapon",""))=="kar","kill_event_weapon")
		check(bool(kill.get("headshot",false)),"kill_event_headshot")
		check(str(kill.get("killer_name",""))=="NEON_RIFT_417","kill_event_killer_name")
		check(str(kill.get("victim_name",""))=="VOID_CLAW_222","kill_event_victim_name")
	print("COMBAT_READABILITY_","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
