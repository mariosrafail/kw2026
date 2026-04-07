extends RefCounted

class_name MainMenuLobbyFlowController

var _host: Control

func configure(host: Control) -> void:
	_host = host

func on_play_pressed() -> void:
	if bool(_host.get("_play_lobby_transition_running")):
		return
	_host.call("_button_press_anim", _host.get("play_button"))
	await run_play_lobby_transition()
	open_lobby_menu_flow()
	fade_out_play_lobby_transition()

func open_lobby_menu_flow() -> void:
	var intro_fx: Variant = _host.get("_intro_fx")
	if intro_fx != null and intro_fx.has_method("set_lobby_music_active"):
		intro_fx.call("set_lobby_music_active", true, 0.55)
	var lobby_overlay_ctrl: Variant = _host.get("_lobby_overlay_ctrl")
	if lobby_overlay_ctrl != null and lobby_overlay_ctrl.has_method("open"):
		lobby_overlay_ctrl.call("open", _host.get("play_button"))
	_host.call("_sync_lobby_overlay_interaction_state")
	_host.call("_refresh_global_overlay_ui_state")
	_host.call("_refresh_meta_ui_visibility")

func run_play_lobby_transition() -> void:
	var fx_layer := _host.get("_fx_layer") as Control
	var play_button := _host.get("play_button") as Button
	if fx_layer == null or play_button == null:
		return
	cleanup_play_lobby_transition()
	_host.set("_play_lobby_transition_running", true)
	cache_play_lobby_fade_targets()

	var panel := PanelContainer.new()
	panel.name = "PlayLobbyTransition"
	panel.z_index = 980
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate = Color(1, 1, 1, 1)
	panel.top_level = true

	var source_rect := play_button.get_global_rect()
	panel.global_position = source_rect.position
	panel.size = source_rect.size

	var style := StyleBoxFlat.new()
	var menu_clr_base: Color = _host.get("MENU_CLR_BASE")
	var menu_clr_highlight: Color = _host.get("MENU_CLR_HIGHLIGHT")
	var menu_clr_accent: Color = _host.get("MENU_CLR_ACCENT")
	style.bg_color = Color(menu_clr_base.r, menu_clr_base.g, menu_clr_base.b, 0.0)
	style.border_color = menu_clr_highlight
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 5
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)
	fx_layer.add_child(panel)
	_host.set("_play_lobby_panel", panel)

	var viewport_rect := _host.get_viewport_rect()
	var duration := maxf(0.12, float(_host.get("play_lobby_expand_duration")))
	var tween := _host.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_host.set("_play_lobby_tween", tween)
	tween.parallel().tween_property(panel, "global_position", viewport_rect.position, duration)
	tween.parallel().tween_property(panel, "size", viewport_rect.size, duration)
	tween.parallel().tween_property(style, "bg_color", Color(menu_clr_accent.r, menu_clr_accent.g, menu_clr_accent.b, 0.0), duration * 0.75)

	var fade_targets := _host.get("_play_lobby_fade_targets") as Array
	var fade_base_alpha := _host.get("_play_lobby_fade_base_alpha") as Dictionary
	for target in fade_targets:
		var item := target as CanvasItem
		if item == null or not is_instance_valid(item):
			continue
		var item_path := str(item.get_path())
		var base_alpha := float(fade_base_alpha.get(item_path, item.modulate.a))
		item.modulate.a = clampf(base_alpha, 0.0, 1.0)
		tween.parallel().tween_property(item, "modulate:a", 0.0, duration * 0.82)
	await tween.finished
	_host.set("_play_lobby_tween", null)

func fade_out_play_lobby_transition() -> void:
	var panel := _host.get("_play_lobby_panel") as PanelContainer
	if panel == null or not is_instance_valid(panel):
		cleanup_play_lobby_transition()
		return
	var fade_duration := maxf(0.08, float(_host.get("play_lobby_border_fade_duration")))
	var fade := _host.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	fade.tween_property(panel, "modulate:a", 0.0, fade_duration)
	fade.finished.connect(Callable(self, "cleanup_play_lobby_transition"))

func cleanup_play_lobby_transition() -> void:
	var tween := _host.get("_play_lobby_tween") as Tween
	if tween != null:
		tween.kill()
	_host.set("_play_lobby_tween", null)
	var panel := _host.get("_play_lobby_panel") as PanelContainer
	if panel != null and is_instance_valid(panel):
		panel.queue_free()
	_host.set("_play_lobby_panel", null)
	_host.set("_play_lobby_transition_running", false)

func cache_play_lobby_fade_targets() -> void:
	var fade_targets := _host.get("_play_lobby_fade_targets") as Array
	var fade_base_alpha := _host.get("_play_lobby_fade_base_alpha") as Dictionary
	fade_targets.clear()
	fade_base_alpha.clear()
	var targets: Array[CanvasItem] = []
	var play_button := _host.get("play_button") as Button
	var options_button := _host.get("options_button") as Button
	var exit_button := _host.get("exit_button") as Button
	var auth_footer_panel := _host.get("_auth_footer_panel") as PanelContainer
	var auth_logout_button := _host.get("_auth_logout_button") as Button
	var logo_node: Variant = _host.get("logo_node")
	if play_button != null:
		targets.append(play_button)
	if options_button != null:
		targets.append(options_button)
	if exit_button != null:
		targets.append(exit_button)
	if auth_footer_panel != null and is_instance_valid(auth_footer_panel):
		targets.append(auth_footer_panel)
	elif auth_logout_button != null and is_instance_valid(auth_logout_button):
		targets.append(auth_logout_button)
	if logo_node != null and logo_node is CanvasItem:
		targets.append(logo_node as CanvasItem)

	for item in targets:
		if item == null or not is_instance_valid(item):
			continue
		if fade_targets.has(item):
			continue
		fade_targets.append(item)
		fade_base_alpha[str(item.get_path())] = item.modulate.a

func restore_play_lobby_fade_targets() -> void:
	var fade_targets := _host.get("_play_lobby_fade_targets") as Array
	var fade_base_alpha := _host.get("_play_lobby_fade_base_alpha") as Dictionary
	for target in fade_targets:
		var item := target as CanvasItem
		if item == null or not is_instance_valid(item):
			continue
		var item_path := str(item.get_path())
		item.modulate.a = clampf(float(fade_base_alpha.get(item_path, 1.0)), 0.0, 1.0)
	fade_targets.clear()
	fade_base_alpha.clear()

func run_play_lobby_reverse_transition() -> void:
	var fade_targets := _host.get("_play_lobby_fade_targets") as Array
	if fade_targets.is_empty():
		return
	var fx_layer := _host.get("_fx_layer") as Control
	var play_button := _host.get("play_button") as Button
	if fx_layer == null or play_button == null:
		restore_play_lobby_fade_targets()
		return
	cleanup_play_lobby_transition()
	_host.set("_play_lobby_transition_running", true)

	var panel := PanelContainer.new()
	panel.name = "PlayLobbyTransitionReverse"
	panel.z_index = 980
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate = Color(1, 1, 1, 1)
	panel.top_level = true

	var viewport_rect := _host.get_viewport_rect()
	panel.global_position = viewport_rect.position
	panel.size = viewport_rect.size

	var style := StyleBoxFlat.new()
	var menu_clr_base: Color = _host.get("MENU_CLR_BASE")
	var menu_clr_highlight: Color = _host.get("MENU_CLR_HIGHLIGHT")
	var menu_clr_accent: Color = _host.get("MENU_CLR_ACCENT")
	style.bg_color = Color(menu_clr_accent.r, menu_clr_accent.g, menu_clr_accent.b, 0.0)
	style.border_color = menu_clr_highlight
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 5
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	panel.add_theme_stylebox_override("panel", style)
	fx_layer.add_child(panel)
	_host.set("_play_lobby_panel", panel)

	var target_rect := play_button.get_global_rect()
	var duration := maxf(0.12, float(_host.get("play_lobby_shrink_duration")))
	var tween := _host.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_host.set("_play_lobby_tween", tween)
	tween.parallel().tween_property(panel, "global_position", target_rect.position, duration)
	tween.parallel().tween_property(panel, "size", target_rect.size, duration)
	tween.parallel().tween_property(style, "bg_color", Color(menu_clr_base.r, menu_clr_base.g, menu_clr_base.b, 0.0), duration * 0.86)

	var fade_base_alpha := _host.get("_play_lobby_fade_base_alpha") as Dictionary
	for target in fade_targets:
		var item := target as CanvasItem
		if item == null or not is_instance_valid(item):
			continue
		var item_path := str(item.get_path())
		var base_alpha := clampf(float(fade_base_alpha.get(item_path, 1.0)), 0.0, 1.0)
		item.modulate.a = 0.0
		tween.parallel().tween_property(item, "modulate:a", base_alpha, duration * 0.92)

	await tween.finished
	_host.set("_play_lobby_tween", null)
	cleanup_play_lobby_transition()
	restore_play_lobby_fade_targets()

func run_lobby_menu_loading_sequence() -> void:
	var lobby_overlay_ctrl: Variant = _host.get("_lobby_overlay_ctrl")
	if lobby_overlay_ctrl != null:
		_host.call("_show_menu_loading_overlay", "LOADING LOBBIES...")
		await lobby_overlay_ctrl.call("run_loading_sequence")
		_host.call("_hide_menu_loading_overlay")

func on_lobby_overlay_closed() -> void:
	var intro_fx: Variant = _host.get("_intro_fx")
	if intro_fx != null and intro_fx.has_method("set_lobby_music_active"):
		intro_fx.call("set_lobby_music_active", false, 0.55)
	_host.call("_hide_menu_loading_overlay")
	await run_play_lobby_reverse_transition()
	restore_play_lobby_fade_targets()
	_host.call("_sync_lobby_overlay_interaction_state")
	_host.call("_refresh_global_overlay_ui_state")
	_host.call("_refresh_meta_ui_visibility")
