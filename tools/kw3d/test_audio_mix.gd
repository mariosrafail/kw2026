extends SceneTree
var failures: Array[String]=[]
func check(v: bool,label: String)->void:
	if not v:
		failures.append(label);push_error("AUDIO_MIX_FAIL "+label)
func _initialize()->void:run.call_deferred()

func bus_index(name: String)->int:
	for i in range(AudioServer.get_bus_count()):
		if AudioServer.get_bus_name(i)==name:return i
	return -1

func run()->void:
	var ctrl=load("res://scripts/ui/main_menu/main_menu_options_controller.gd").new()
	ctrl.set_sound_buses_volume_linear(0.7)
	ctrl.set_audio_bus_volume_linear("Music",0.8)
	var sfx:=bus_index("SFX");var music:=bus_index("Music")
	check(sfx>=0 and music>=0,"music_sfx_buses_exist")
	check(absf(AudioServer.get_bus_volume_db(sfx)-linear_to_db(0.7))<0.02,"sfx_slider_controls_bus")
	check(absf(AudioServer.get_bus_volume_db(music)-linear_to_db(0.8))<0.02,"music_slider_controls_bus")
	ProjectSettings.set_setting("kw3d/offline_test_mode","sandbox")
	var stage=load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	root.add_child(stage)
	for i in range(5):await process_frame
	check(stage.ak_fire_audio.bus=="SFX","ak_fire_on_sfx")
	check(stage.ak_reload_audio.bus=="SFX","ak_reload_on_sfx")
	check(stage.shotgun_fire_audio.bus=="SFX","shotgun_fire_on_sfx")
	check(stage.shotgun_reload_audio.bus=="SFX","shotgun_reload_on_sfx")
	check(stage.kar_fire_audio.bus=="SFX","kar_fire_on_sfx")
	check(stage.kar_reload_audio.bus=="SFX","kar_reload_on_sfx")
	check(stage.arena_audio.music.bus=="Music","fight_music_on_music")
	for p in stage.arena_audio.spatial_pool:check(p.bus=="SFX","arena_spatial_on_sfx")
	for p in stage.arena_audio.ui_pool:check(p.bus=="SFX","arena_ui_on_sfx")
	check(stage.shooting_volume_db>=-3.1,"weapon_base_volume_boosted")
	print("AUDIO_MIX_","PASS" if failures.is_empty() else "FAIL",failures,
		" sfx_db=",AudioServer.get_bus_volume_db(sfx)," music_db=",AudioServer.get_bus_volume_db(music))
	stage.queue_free();quit(0 if failures.is_empty() else 1)
