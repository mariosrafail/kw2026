extends SceneTree
var output := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=")
	run.call_deferred()
func run() -> void:
	var stage: Node3D=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	stage._toggle_instructions()
	for i in range(5): await physics_frame
	stage.combat.director.begin_wave(3)
	var telegraphs:=0
	var peak_bullets:=0
	var peak_alive:=0
	var failed:=false
	for i in range(960):
		await physics_frame
		var d: RefCounted=stage.combat.director
		if not d.warning.is_empty(): telegraphs+=1
		peak_bullets=maxi(peak_bullets,d.projectiles.size())
		peak_alive=maxi(peak_alive,d.alive_count())
		if d.alive_count()>8 or d.health<0 or d.health>100: failed=true
		for bot in stage.combat.targets:
			if is_instance_valid(bot) and not bot.dead and not bot.transform.is_finite(): failed=true
		if i==780:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("live_wave_three.png"))
	var director: RefCounted=stage.combat.director
	if director.enemy_shots_fired<2 or peak_alive!=7 or telegraphs==0: failed=true
	print("LIVE_WAVE_METRICS shots=",director.enemy_shots_fired," health=",director.health," hits=",director.player_hits," telegraph_frames=",telegraphs," peak_bullets=",peak_bullets," peak_alive=",peak_alive)
	stage.queue_free()
	for i in range(10): await process_frame
	print("AUTONOMOUS_WAVE_","FAIL" if failed else "PASS")
	quit(1 if failed else 0)
