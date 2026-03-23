extends RefCounted

func ensure_cursor_manager(host: Node, cursor_manager_script: Script, cursor_manager_name: String) -> void:
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return
	var root: Window = tree.get_root()
	if root == null:
		return
	var existing: Node = root.get_node_or_null(cursor_manager_name)
	if existing != null:
		if existing.has_method("set_cursor_context"):
			existing.call("set_cursor_context", "menu")
		return
	var cm: Node = cursor_manager_script.new()
	cm.name = cursor_manager_name
	root.call_deferred("add_child", cm)
	host.call_deferred("_apply_menu_cursor_context")

func apply_menu_cursor_context(host: Node, cursor_manager_name: String) -> void:
	var tree: SceneTree = host.get_tree()
	if tree == null:
		return
	var root: Window = tree.get_root()
	if root == null:
		return
	var cm: Node = root.get_node_or_null(cursor_manager_name)
	if cm != null and cm.has_method("set_cursor_context"):
		cm.call("set_cursor_context", "menu")

func handle_input(host: Node, event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			var confirm_overlay: Control = host.get("_confirm_overlay_ui") as Control
			if confirm_overlay != null and confirm_overlay.visible:
				confirm_overlay.visible = false
				host.get_viewport().set_input_as_handled()
				return
			var lobby_overlay_ctrl: Object = host.get("_lobby_overlay_ctrl") as Object
			if lobby_overlay_ctrl != null and bool(lobby_overlay_ctrl.call("is_visible")):
				lobby_overlay_ctrl.call("hide")
				host.get_viewport().set_input_as_handled()
				return
			if host.get("_current_screen") == host.get("screen_weapons"):
				host.call("_on_weapons_back_pressed")
				host.get_viewport().set_input_as_handled()
				return
			if host.get("_current_screen") == host.get("screen_warriors"):
				host.call("_on_warriors_back_pressed")
				host.get_viewport().set_input_as_handled()
				return
			if host.get("_current_screen") == host.get("screen_options"):
				host.call("_on_options_back_pressed")
				host.get_viewport().set_input_as_handled()
				return
			host.get_viewport().set_input_as_handled()
			host.get_tree().quit()
		elif key_event.pressed and not key_event.echo and key_event.keycode == KEY_F4:
			toggle_fullscreen()
			host.get_viewport().set_input_as_handled()

func handle_unhandled_input(host: Node, event: InputEvent) -> void:
	# Fallback in case UI consumes events on some editor runs.
	handle_input(host, event)

func toggle_fullscreen() -> void:
	var current_mode: int = DisplayServer.window_get_mode()
	if current_mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
