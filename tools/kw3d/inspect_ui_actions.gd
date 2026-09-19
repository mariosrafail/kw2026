extends SceneTree
func _initialize() -> void:
	for action in ["ui_accept","ui_cancel","ui_up","ui_down","ui_left","ui_right","ui_focus_next","ui_focus_prev"]:
		var rows: Array[String]=[]
		for e in InputMap.action_get_events(action):
			rows.append(str(e))
		print("UI_ACTION ",action," ",rows)
	quit()
