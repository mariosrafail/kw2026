extends RefCounted

class_name MainMenuShopController

func select_warrior_skin(host: Control, warrior_id: String, skin_index: int, silent: bool) -> void:
	var previous_pending_warrior_id := str(host.get("_pending_warrior_id")).strip_edges().to_lower()
	var normalized_warrior_id := warrior_id.strip_edges().to_lower()
	host.set("_pending_warrior_id", warrior_id.strip_edges().to_lower())
	host.set("_pending_warrior_skin", maxi(0, skin_index))
	host.call("_apply_warrior_skin_to_player", host.get("warrior_shop_preview"), str(host.get("_pending_warrior_id")), int(host.get("_pending_warrior_skin")))
	var warrior_ui = host.get("_warrior_ui")
	var warrior_name_label = host.get("warrior_name_label") as Label
	if warrior_name_label != null:
		warrior_name_label.text = "%s - %s" % [warrior_ui.warrior_display_name(str(host.get("_pending_warrior_id"))), warrior_ui.warrior_skin_label(str(host.get("_pending_warrior_id")), int(host.get("_pending_warrior_skin")))]
	if host != null and host.has_method("_refresh_warrior_skill_description_label"):
		host.call("_refresh_warrior_skill_description_label", str(host.get("_pending_warrior_id")))
	var should_rebuild_skin_grid := previous_pending_warrior_id != normalized_warrior_id
	if should_rebuild_skin_grid and host != null and host.has_method("_build_warrior_skin_grid"):
		host.call("_build_warrior_skin_grid", str(host.get("_pending_warrior_id")))
	host.call("_refresh_warrior_filter_button_state")
	refresh_warrior_grid_texts(host)
	refresh_warrior_action(host)
	if host != null and host.has_method("_refresh_selection_context_visuals"):
		host.call("_refresh_selection_context_visuals")

func equip_warrior_item(host: Control, warrior_id: String, skin_index: int) -> void:
	var previous_pending_warrior_id := str(host.get("_pending_warrior_id")).strip_edges().to_lower()
	var normalized_warrior_id := warrior_id.strip_edges().to_lower()
	host.set("selected_warrior_id", warrior_id.strip_edges().to_lower())
	host.set("selected_warrior_skin", maxi(0, skin_index))
	host.set("_pending_warrior_id", str(host.get("selected_warrior_id")))
	host.set("_pending_warrior_skin", int(host.get("selected_warrior_skin")))
	host.call("_set_equipped_warrior_skin", str(host.get("selected_warrior_id")), int(host.get("selected_warrior_skin")))
	host.call("_apply_warrior_skin_to_player", host.get("main_warrior_preview"), str(host.get("selected_warrior_id")), int(host.get("selected_warrior_skin")))
	host.call("_apply_warrior_skin_to_player", host.get("warrior_shop_preview"), str(host.get("selected_warrior_id")), int(host.get("selected_warrior_skin")))
	var owned_warrior_skins_by_warrior = host.get("owned_warrior_skins_by_warrior") as Dictionary
	host.set("owned_warrior_skins", owned_warrior_skins_by_warrior.get(str(host.get("selected_warrior_id")), PackedInt32Array([0])) as PackedInt32Array)
	var warrior_ui = host.get("_warrior_ui")
	var warrior_name_label = host.get("warrior_name_label") as Label
	if warrior_name_label != null:
		warrior_name_label.text = "%s - %s" % [warrior_ui.warrior_display_name(str(host.get("selected_warrior_id"))), warrior_ui.warrior_skin_label(str(host.get("selected_warrior_id")), int(host.get("selected_warrior_skin")))]
	if host != null and host.has_method("_refresh_warrior_skill_description_label"):
		host.call("_refresh_warrior_skill_description_label", str(host.get("selected_warrior_id")))
	var should_rebuild_skin_grid := previous_pending_warrior_id != normalized_warrior_id
	if should_rebuild_skin_grid and host != null and host.has_method("_build_warrior_skin_grid"):
		host.call("_build_warrior_skin_grid", str(host.get("selected_warrior_id")))
	host.call("_save_state")
	host.call("_auth_sync_wallet")
	if host != null and host.has_method("_sync_active_lobby_loadout_selection"):
		host.call("_sync_active_lobby_loadout_selection")
	host.call("_refresh_warrior_filter_button_state")
	refresh_warrior_grid_texts(host)
	refresh_warrior_action(host)
	if host != null and host.has_method("_refresh_selection_context_visuals"):
		host.call("_refresh_selection_context_visuals")
	if host != null and host.has_method("_pop_warrior_preview"):
		host.call("_pop_warrior_preview", host.get("main_warrior_preview"))
		host.call("_pop_warrior_preview", host.get("warrior_shop_preview"))

func buy_warrior_if_needed(host: Control, warrior_id: String) -> bool:
	var normalized = warrior_id.strip_edges().to_lower()
	if bool(host.call("_warrior_is_owned", normalized)):
		return true
	var cost = int(host.call("_warrior_cost", normalized))
	if cost <= 0:
		return false
	if int(host.get("wallet_coins")) < cost:
		_set_auth_status(host, "Not enough coins")
		host.call("_shake", host.get("wallet_panel"))
		return false
	host.call("_auth_capture_wallet_sync_snapshot")
	host.set("wallet_coins", int(host.get("wallet_coins")) - cost)
	var owned_warriors = host.get("owned_warriors") as PackedStringArray
	owned_warriors.append(normalized)
	host.set("owned_warriors", owned_warriors)
	var owned_warrior_skins_by_warrior = host.get("owned_warrior_skins_by_warrior") as Dictionary
	var arr = owned_warrior_skins_by_warrior.get(normalized, PackedInt32Array([0])) as PackedInt32Array
	if arr == null:
		arr = PackedInt32Array([0])
	if not arr.has(0):
		arr.append(0)
		arr.sort()
	owned_warrior_skins_by_warrior[normalized] = arr
	host.set("owned_warrior_skins_by_warrior", owned_warrior_skins_by_warrior)
	host.call("_update_wallet_labels", false)
	host.call("_save_state")
	host.call("_auth_sync_wallet")
	return true

func buy_warrior_skin_if_needed(host: Control, warrior_id: String, skin_index: int) -> bool:
	var normalized = warrior_id.strip_edges().to_lower()
	var idx = maxi(0, skin_index)
	if bool(host.call("_warrior_skin_is_owned", normalized, idx)):
		return true
	var cost = int(host.call("_warrior_skin_cost", normalized, idx))
	if cost <= 0:
		return false
	if int(host.get("wallet_coins")) < cost:
		_set_auth_status(host, "Not enough coins")
		host.call("_shake", host.get("wallet_panel"))
		return false
	host.call("_auth_capture_wallet_sync_snapshot")
	host.set("wallet_coins", int(host.get("wallet_coins")) - cost)
	var owned_warrior_skins_by_warrior = host.get("owned_warrior_skins_by_warrior") as Dictionary
	var arr = owned_warrior_skins_by_warrior.get(normalized, PackedInt32Array([0])) as PackedInt32Array
	if arr == null:
		arr = PackedInt32Array([0])
	if not arr.has(idx):
		arr.append(idx)
		arr.sort()
	owned_warrior_skins_by_warrior[normalized] = arr
	host.set("owned_warrior_skins_by_warrior", owned_warrior_skins_by_warrior)
	host.set("owned_warrior_skins", owned_warrior_skins_by_warrior.get(normalized, PackedInt32Array([0])) as PackedInt32Array)
	host.call("_update_wallet_labels", false)
	host.call("_save_state")
	host.call("_auth_sync_wallet")
	return true

func confirm_buy_warrior_skin_and_equip(host: Control, warrior_id: String, skin_index: int) -> void:
	var normalized = warrior_id.strip_edges().to_lower()
	if not buy_warrior_skin_if_needed(host, normalized, skin_index):
		return
	equip_warrior_item(host, normalized, skin_index)

func confirm_buy_warrior_then_maybe_skin(host: Control, warrior_id: String, skin_index: int) -> void:
	var normalized = warrior_id.strip_edges().to_lower()
	var idx = maxi(0, skin_index)
	if not buy_warrior_if_needed(host, normalized):
		return
	if bool(host.call("_warrior_skin_is_owned", normalized, idx)):
		equip_warrior_item(host, normalized, idx)
		return
	var skin_cost = int(host.call("_warrior_skin_cost", normalized, idx))
	if int(host.get("wallet_coins")) < skin_cost:
		_set_auth_status(host, "Not enough coins for skin")
		host.call("_shake", host.get("wallet_panel"))
		return
	var warrior_ui = host.get("_warrior_ui")
	host.call(
		"_ask_confirm",
		"Buy skin?",
		"Buy %s - %s for %d coins?" % [warrior_ui.warrior_display_name(normalized), warrior_ui.warrior_skin_label(normalized, idx), skin_cost],
		Callable(host, "_confirm_buy_warrior_skin_and_equip").bind(normalized, idx)
	)

func on_warrior_item_button_pressed(host: Control, warrior_id: String, skin_index: int) -> void:
	var normalized = warrior_id.strip_edges().to_lower()
	var idx = maxi(0, skin_index)
	select_warrior_skin(host, normalized, idx, true)
	var warrior_ui = host.get("_warrior_ui")
	if not bool(host.call("_warrior_is_owned", normalized)):
		var warrior_cost = int(host.call("_warrior_cost", normalized))
		host.call(
			"_ask_confirm",
			"Buy warrior?",
			"Buy %s for %d coins? You need the warrior before its skins." % [warrior_ui.warrior_display_name(normalized), warrior_cost],
			Callable(host, "_confirm_buy_warrior_then_maybe_skin").bind(normalized, idx)
		)
		return
	if bool(host.call("_warrior_skin_is_owned", normalized, idx)):
		equip_warrior_item(host, normalized, idx)
		return
	var cost = int(host.call("_warrior_skin_cost", normalized, idx))
	host.call(
		"_ask_confirm",
		"Buy skin?",
		"Buy %s - %s for %d coins?" % [warrior_ui.warrior_display_name(normalized), warrior_ui.warrior_skin_label(normalized, idx), cost],
		Callable(host, "_confirm_buy_warrior_skin_and_equip").bind(normalized, idx)
	)

func refresh_warrior_grid_texts(host: Control) -> void:
	var warrior_grid = host.get("warrior_grid") as GridContainer
	var warrior_skin_grid = host.get("warrior_skin_grid") as GridContainer
	var warrior_ui = host.get("_warrior_ui")
	for grid in [warrior_grid, warrior_skin_grid]:
		if grid == null:
			continue
		for child in grid.get_children():
			var button = child as Button
			if button != null:
				warrior_ui.update_warrior_item_button(host, button)

func refresh_warrior_action(host: Control) -> void:
	var warrior_action_button = host.get("warrior_action_button") as Button
	if warrior_action_button == null:
		return
	warrior_action_button.visible = false
	warrior_action_button.disabled = true
	return
	var warrior_ui = host.get("_warrior_ui")
	var status = str(warrior_ui.warrior_item_status_text(host, str(host.get("_pending_warrior_id")), int(host.get("_pending_warrior_skin"))))
	if status == "OWNED":
		warrior_action_button.text = "OWNED"
		warrior_action_button.disabled = false
		return
	warrior_action_button.text = status
	warrior_action_button.disabled = false

func on_warrior_action_pressed(host: Control) -> void:
	var warrior_action_button = host.get("warrior_action_button")
	host.call("_button_press_anim", warrior_action_button)
	var pending_warrior_id = str(host.get("_pending_warrior_id"))
	var pending_warrior_skin = int(host.get("_pending_warrior_skin"))
	if not bool(host.call("_warrior_is_owned", pending_warrior_id)):
		var warrior_cost = int(host.call("_warrior_cost", pending_warrior_id))
		if int(host.get("wallet_coins")) < warrior_cost:
			host.call("_shake", host.get("wallet_panel"))
			return
		confirm_buy_warrior_then_maybe_skin(host, pending_warrior_id, pending_warrior_skin)
		return
	if bool(host.call("_warrior_skin_is_owned", pending_warrior_id, pending_warrior_skin)):
		equip_warrior_item(host, pending_warrior_id, pending_warrior_skin)
		return
	var cost = int(host.call("_warrior_skin_cost", pending_warrior_id, pending_warrior_skin))
	if int(host.get("wallet_coins")) < cost:
		host.call("_shake", host.get("wallet_panel"))
		return
	confirm_buy_warrior_skin_and_equip(host, pending_warrior_id, pending_warrior_skin)

func select_weapon_skin(host: Control, weapon_id: String, skin_index: int, silent: bool) -> void:
	host.set("_pending_weapon_id", weapon_id.strip_edges().to_lower())
	host.set("_pending_weapon_skin", maxi(0, skin_index))
	host.call("_set_weapon_icon_sprite", host.get("weapon_shop_preview"), str(host.get("_pending_weapon_id")), 1.0, int(host.get("_pending_weapon_skin")))
	host.call("_apply_weapon_skin_visual", host.get("weapon_shop_preview"), str(host.get("_pending_weapon_id")), int(host.get("_pending_weapon_skin")))
	var weapon_ui = host.get("_weapon_ui")
	var weapon_name_label = host.get("weapon_name_label") as Label
	if weapon_name_label != null:
		weapon_name_label.text = "%s - %s" % [weapon_ui.weapon_display_name(str(host.get("_pending_weapon_id"))), str(host.call("_weapon_skin_label", str(host.get("_pending_weapon_id")), int(host.get("_pending_weapon_skin"))))]
	refresh_weapon_grid_texts(host)
	if host != null and host.has_method("_refresh_selection_context_visuals"):
		host.call("_refresh_selection_context_visuals")
	if not silent:
		host.call("_pop", host.get("weapon_shop_preview"))

func equip_weapon_item(host: Control, weapon_id: String, skin_index: int) -> void:
	host.set("selected_weapon_id", weapon_id.strip_edges().to_lower())
	host.set("selected_weapon_skin", maxi(0, skin_index))
	host.set("_pending_weapon_id", str(host.get("selected_weapon_id")))
	host.set("_pending_weapon_skin", int(host.get("selected_weapon_skin")))
	host.call("_set_equipped_weapon_skin", str(host.get("selected_weapon_id")), int(host.get("selected_weapon_skin")))
	host.call("_set_weapon_icon_sprite", host.get("main_weapon_icon"), str(host.get("_visible_weapon_id")), 1.0, int(host.get("_visible_weapon_skin")))
	host.call("_apply_weapon_skin_visual", host.get("main_weapon_icon"), str(host.get("_visible_weapon_id")), int(host.get("_visible_weapon_skin")))
	host.call("_set_weapon_icon_sprite", host.get("weapon_shop_preview"), str(host.get("selected_weapon_id")), 1.0, int(host.get("selected_weapon_skin")))
	host.call("_apply_weapon_skin_visual", host.get("weapon_shop_preview"), str(host.get("selected_weapon_id")), int(host.get("selected_weapon_skin")))
	var weapon_ui = host.get("_weapon_ui")
	var weapon_name_label = host.get("weapon_name_label") as Label
	if weapon_name_label != null:
		weapon_name_label.text = "%s - %s" % [weapon_ui.weapon_display_name(str(host.get("selected_weapon_id"))), str(host.call("_weapon_skin_label", str(host.get("selected_weapon_id")), int(host.get("selected_weapon_skin"))))]
	host.set("_weapon_filter_weapon_id", str(host.get("selected_weapon_id")))
	host.call("_refresh_weapon_filter_button_state")
	host.call("_save_state")
	host.call("_auth_sync_wallet")
	if host != null and host.has_method("_sync_active_lobby_loadout_selection"):
		host.call("_sync_active_lobby_loadout_selection")
	refresh_weapon_grid_texts(host)
	if host != null and host.has_method("_refresh_selection_context_visuals"):
		host.call("_refresh_selection_context_visuals")
	host.call("_pop", host.get("main_weapon_icon"))
	host.call("_pop", host.get("weapon_shop_preview"))

func buy_weapon_if_needed(host: Control, weapon_id: String) -> bool:
	var normalized = weapon_id.strip_edges().to_lower()
	if bool(host.call("_weapon_is_owned", normalized)):
		return true
	if bool(host.get("_auth_logged_in")) and not str(host.get("_auth_token")).is_empty() and not bool(host.get("_auth_wallet_sync_supported")):
		print("[AUTH][BUY_WEAPON] local-only user=%s reason=wallet_update_missing weapon=%s" % [str(host.get("player_username")), normalized])
		_set_auth_status(host, "Weapon purchase is local only (server won't save it)")
	var cost = int(host.call("_weapon_base_cost", normalized))
	if cost <= 0:
		return false
	if int(host.get("wallet_coins")) < cost:
		_set_auth_status(host, "Not enough coins")
		host.call("_shake", host.get("wallet_panel"))
		return false
	host.call("_auth_capture_wallet_sync_snapshot")
	host.set("wallet_coins", int(host.get("wallet_coins")) - cost)
	var owned_weapons = host.get("owned_weapons") as PackedStringArray
	owned_weapons.append(normalized)
	host.set("owned_weapons", owned_weapons)
	host.call("_update_wallet_labels", false)
	host.call("_save_state")
	host.call("_auth_sync_wallet")
	return true

func buy_weapon_skin_if_needed(host: Control, weapon_id: String, skin_index: int) -> bool:
	var normalized = weapon_id.strip_edges().to_lower()
	var idx = maxi(0, skin_index)
	if bool(host.call("_weapon_skin_is_owned", normalized, idx)):
		return true
	if bool(host.get("_auth_logged_in")) and not str(host.get("_auth_token")).is_empty() and not bool(host.get("_auth_wallet_sync_supported")):
		print("[AUTH][BUY_WEAPON_SKIN] local-only user=%s reason=wallet_update_missing weapon=%s skin=%d" % [str(host.get("player_username")), normalized, idx])
		_set_auth_status(host, "Weapon-skin purchase is local only (server won't save it)")
	var cost = int(host.call("_weapon_skin_cost", normalized, idx))
	if cost <= 0:
		return false
	if int(host.get("wallet_coins")) < cost:
		_set_auth_status(host, "Not enough coins")
		host.call("_shake", host.get("wallet_panel"))
		return false
	host.call("_auth_capture_wallet_sync_snapshot")
	host.set("wallet_coins", int(host.get("wallet_coins")) - cost)
	var owned_weapon_skins_by_weapon = host.get("owned_weapon_skins_by_weapon") as Dictionary
	var arr = owned_weapon_skins_by_weapon.get(normalized, PackedInt32Array([0])) as PackedInt32Array
	if not arr.has(idx):
		arr.append(idx)
		arr.sort()
	owned_weapon_skins_by_weapon[normalized] = arr
	host.set("owned_weapon_skins_by_weapon", owned_weapon_skins_by_weapon)
	host.call("_update_wallet_labels", false)
	host.call("_save_state")
	host.call("_auth_sync_wallet")
	return true

func confirm_buy_weapon_skin_and_equip(host: Control, weapon_id: String, skin_index: int) -> void:
	var normalized = weapon_id.strip_edges().to_lower()
	if not buy_weapon_skin_if_needed(host, normalized, skin_index):
		return
	equip_weapon_item(host, normalized, skin_index)

func confirm_buy_weapon_then_maybe_skin(host: Control, weapon_id: String, skin_index: int) -> void:
	var normalized = weapon_id.strip_edges().to_lower()
	var idx = maxi(0, skin_index)
	if not buy_weapon_if_needed(host, normalized):
		return
	if bool(host.call("_weapon_skin_is_owned", normalized, idx)):
		equip_weapon_item(host, normalized, idx)
		return
	var skin_cost = int(host.call("_weapon_skin_cost", normalized, idx))
	var skin_name = str(host.call("_weapon_skin_label", normalized, idx))
	host.call("_ask_confirm", "Buy skin?", "Buy %s - %s for %d coins?" % [normalized.to_upper(), skin_name, skin_cost], Callable(host, "_confirm_buy_weapon_skin_and_equip").bind(normalized, idx), normalized, idx)

func on_weapon_item_button_pressed(host: Control, weapon_id: String, skin_index: int) -> void:
	var normalized = weapon_id.strip_edges().to_lower()
	var idx = maxi(0, skin_index)
	var needs_weapon = not bool(host.call("_weapon_is_owned", normalized))
	var needs_skin = not bool(host.call("_weapon_skin_is_owned", normalized, idx))
	if needs_weapon or needs_skin:
		if needs_weapon:
			var base_cost = int(host.call("_weapon_base_cost", normalized))
			host.call("_ask_confirm", "Buy gun?", "Buy %s for %d coins?" % [normalized.to_upper(), base_cost], Callable(host, "_confirm_buy_weapon_then_maybe_skin").bind(normalized, idx), normalized, idx)
		else:
			var skin_cost = int(host.call("_weapon_skin_cost", normalized, idx))
			var skin_name = str(host.call("_weapon_skin_label", normalized, idx))
			host.call("_ask_confirm", "Buy skin?", "Buy %s - %s for %d coins?" % [normalized.to_upper(), skin_name, skin_cost], Callable(host, "_confirm_buy_weapon_skin_and_equip").bind(normalized, idx), normalized, idx)
		return
	select_weapon_skin(host, normalized, idx, true)
	equip_weapon_item(host, normalized, idx)

func refresh_weapon_grid_texts(host: Control) -> void:
	var weapon_grid = host.get("weapon_grid") as GridContainer
	var weapon_ui = host.get("_weapon_ui")
	if weapon_grid == null:
		return
	for child in weapon_grid.get_children():
		var button = child as Button
		if button != null:
			weapon_ui.update_weapon_item_button(host, button)

func refresh_weapon_action(host: Control) -> void:
	var weapon_action_button = host.get("weapon_action_button") as Button
	if weapon_action_button == null:
		return
	weapon_action_button.visible = false
	weapon_action_button.disabled = true
	return
	var pending_weapon_id = str(host.get("_pending_weapon_id"))
	var pending_weapon_skin = int(host.get("_pending_weapon_skin"))
	if not bool(host.call("_weapon_is_owned", pending_weapon_id)):
		var weapon_cost = int(host.call("_weapon_base_cost", pending_weapon_id))
		weapon_action_button.disabled = weapon_cost <= 0
		weapon_action_button.text = "BUY GUN  (%d)" % weapon_cost
		return
	if bool(host.call("_weapon_skin_is_owned", pending_weapon_id, pending_weapon_skin)):
		if pending_weapon_id == str(host.get("selected_weapon_id")) and pending_weapon_skin == int(host.get("selected_weapon_skin")):
			weapon_action_button.text = "OWNED"
			weapon_action_button.disabled = false
		else:
			weapon_action_button.text = "OWNED"
			weapon_action_button.disabled = false
		return
	weapon_action_button.disabled = false
	weapon_action_button.text = "BUY SKIN  (%d)" % int(host.call("_weapon_skin_cost", pending_weapon_id, pending_weapon_skin))

func on_weapon_action_pressed(host: Control) -> void:
	host.call("_button_press_anim", host.get("weapon_action_button"))
	var pending_weapon_id = str(host.get("_pending_weapon_id"))
	var pending_weapon_skin = int(host.get("_pending_weapon_skin"))
	if not bool(host.call("_weapon_is_owned", pending_weapon_id)):
		confirm_buy_weapon_then_maybe_skin(host, pending_weapon_id, pending_weapon_skin)
		return
	if bool(host.call("_weapon_skin_is_owned", pending_weapon_id, pending_weapon_skin)):
		equip_weapon_item(host, pending_weapon_id, pending_weapon_skin)
		return
	var cost = int(host.call("_weapon_skin_cost", pending_weapon_id, pending_weapon_skin))
	if int(host.get("wallet_coins")) < cost:
		host.call("_shake", host.get("wallet_panel"))
		return
	confirm_buy_weapon_skin_and_equip(host, pending_weapon_id, pending_weapon_skin)

func _set_auth_status(host: Control, text: String) -> void:
	var auth_status_label = host.get("_auth_status_label") as Label
	if auth_status_label != null:
		auth_status_label.text = text
