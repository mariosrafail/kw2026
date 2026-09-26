extends SceneTree
## Visual QA helper: launches the real 3D prototype and auto-casts one warrior skill.

var warrior_id := "aevilok"


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--warrior="):
			warrior_id = arg.trim_prefix("--warrior=").strip_edges().to_lower()
	run.call_deferred()


func run() -> void:
	var stage: Variant = load("res://scenes/prototypes/kw_3d_prototype.tscn").instantiate()
	stage.use_menu_warrior_selection = false
	stage.player_warrior_id = warrior_id
	root.add_child(stage)
	for i in range(45):
		await process_frame
	stage.combat.set_training_mode(true)
	stage.combat.set_roaming_enabled(false)
	if stage.warrior_skill.cast():
		# Visual inspection helper only: hold the effect open long enough for a
		# human/desktop screenshot pass without changing gameplay balance.
		stage.warrior_skill.active_left = 60.0
		stage.warrior_skill.cooldown_left = 60.0
		stage._update_warrior_skill_hud(60.0, 60.0)
