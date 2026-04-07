extends RefCounted

const DATA := preload("res://scripts/ui/main_menu/data.gd")
const WEAPON_UZI := DATA.WEAPON_UZI
const WEAPON_GRENADE := DATA.WEAPON_GRENADE
const WEAPON_AK47 := DATA.WEAPON_AK47
const WEAPON_KAR := DATA.WEAPON_KAR
const WEAPON_SHOTGUN := DATA.WEAPON_SHOTGUN

func load_state_or_defaults(path: String, defaults: Dictionary, required_weapon_id: String = "") -> Dictionary:
	var state := defaults.duplicate(true)
	if not FileAccess.file_exists(path):
		return state

	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return state

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return state
	var d := parsed as Dictionary

	state["coins"] = maxi(0, int(d.get("coins", int(state.get("coins", 0)))))
	state["clk"] = maxi(0, int(d.get("clk", int(state.get("clk", 0)))))
	state["selected_warrior_id"] = str(d.get("selected_warrior_id", str(state.get("selected_warrior_id", "outrage")))).strip_edges().to_lower()
	state["selected_warrior_skin"] = maxi(0, int(d.get("selected_warrior_skin", int(state.get("selected_warrior_skin", 0)))))

	var warrior_owned_arr: Variant = d.get("owned_warriors", null)
	if warrior_owned_arr is Array:
		var tmp_owned: Array = []
		for v in warrior_owned_arr:
			var wid := str(v).strip_edges().to_lower()
			if not wid.is_empty() and not tmp_owned.has(wid):
				tmp_owned.append(wid)
		if not tmp_owned.has("outrage"):
			tmp_owned.append("outrage")
		tmp_owned.sort()
		state["owned_warriors"] = tmp_owned

	var owned_arr: Variant = d.get("owned_warrior_skins", null)
	if owned_arr is Array:
		var tmp: Array = []
		for v in owned_arr:
			tmp.append(maxi(0, int(v)))
		if not tmp.has(0):
			tmp.append(0)
		tmp.sort()
		state["owned_warrior_skins"] = tmp

	var warrior_skins_dict: Variant = d.get("owned_warrior_skins_by_warrior", null)
	if warrior_skins_dict is Dictionary:
		var out_warrior_skins := {}
		for key in warrior_skins_dict.keys():
			var wid := str(key).strip_edges().to_lower()
			var arrv: Variant = warrior_skins_dict.get(key)
			var tmpw: Array = [0]
			if arrv is Array:
				for v in arrv:
					var idx := maxi(0, int(v))
					if not tmpw.has(idx):
						tmpw.append(idx)
			tmpw.sort()
			out_warrior_skins[wid] = tmpw
		state["owned_warrior_skins_by_warrior"] = out_warrior_skins

	var equipped_warrior_skins: Variant = d.get("equipped_warrior_skin_by_warrior", null)
	if equipped_warrior_skins is Dictionary:
		var out_equipped := {}
		for key in equipped_warrior_skins.keys():
			var wid := str(key).strip_edges().to_lower()
			out_equipped[wid] = maxi(0, int(equipped_warrior_skins.get(key, 0)))
		state["equipped_warrior_skin_by_warrior"] = out_equipped

	var w_owned: Variant = d.get("owned_weapons", null)
	if w_owned is Array:
		var tmpw: Array = []
		for v in w_owned:
			var s := str(v).strip_edges().to_lower()
			if not s.is_empty():
				tmpw.append(s)
		if not required_weapon_id.is_empty() and not tmpw.has(required_weapon_id):
			tmpw.append(required_weapon_id)
		state["owned_weapons"] = tmpw

	state["selected_weapon_id"] = str(d.get("selected_weapon_id", str(state.get("selected_weapon_id", "")))).strip_edges().to_lower()
	if str(state["selected_weapon_id"]).is_empty() and not required_weapon_id.is_empty():
		state["selected_weapon_id"] = required_weapon_id
	state["selected_weapon_skin"] = maxi(0, int(d.get("selected_weapon_skin", int(state.get("selected_weapon_skin", 0)))))
	state["username"] = str(d.get("username", str(state.get("username", "Player")))).strip_edges()
	state["music_volume"] = clampf(float(d.get("music_volume", float(state.get("music_volume", 0.8)))), 0.0, 1.0)
	state["sfx_volume"] = clampf(float(d.get("sfx_volume", float(state.get("sfx_volume", 0.4)))), 0.0, 1.0)
	state["particles_enabled"] = bool(d.get("particles_enabled", bool(state.get("particles_enabled", true))))
	state["screen_shake_enabled"] = bool(d.get("screen_shake_enabled", bool(state.get("screen_shake_enabled", true))))

	var skins_dict: Variant = d.get("owned_weapon_skins_by_weapon", null)
	if skins_dict is Dictionary:
		var out := {}
		for key in skins_dict.keys():
			var wid := str(key).strip_edges().to_lower()
			var arrv: Variant = skins_dict.get(key)
			var tmp: Array = [0]
			if arrv is Array:
				for v in arrv:
					tmp.append(maxi(0, int(v)))
			tmp.sort()
			out[wid] = tmp
		state["owned_weapon_skins_by_weapon"] = out

	return state

func save_state(path: String, state: Dictionary) -> void:
	var json := JSON.stringify(state)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(json)

func apply_menu_state(host: Control, path: String) -> void:
	var fallback_username := OS.get_environment("USERNAME").strip_edges()
	if fallback_username.is_empty():
		fallback_username = "Player"
	var default_warrior := str(host.call("_default_warrior_id"))
	var default_owned_warriors := host.call("_default_owned_warriors") as PackedStringArray
	var default_warrior_skins := host.call("_default_owned_warrior_skins_by_warrior") as Dictionary
	var default_equipped_warrior_skins := host.call("_default_equipped_warrior_skin_by_warrior") as Dictionary
	var defaults := {
		"coins": 1000000,
		"clk": 50000,
		"music_volume": 0.8,
		"sfx_volume": 0.4,
		"particles_enabled": true,
		"screen_shake_enabled": true,
		"username": fallback_username,
		"owned_warriors": Array(default_owned_warriors),
		"owned_warrior_skins": [0],
		"owned_warrior_skins_by_warrior": default_warrior_skins,
		"equipped_warrior_skin_by_warrior": default_equipped_warrior_skins,
		"selected_warrior_id": default_warrior,
		"selected_warrior_skin": 0,
		"owned_weapons": [WEAPON_UZI, WEAPON_GRENADE],
		"owned_weapon_skins_by_weapon": {WEAPON_UZI: [0], WEAPON_GRENADE: [0], WEAPON_AK47: [0], WEAPON_KAR: [0], WEAPON_SHOTGUN: [0]},
		"equipped_weapon_skin_by_weapon": {WEAPON_UZI: 0, WEAPON_GRENADE: 0, WEAPON_AK47: 0, WEAPON_KAR: 0, WEAPON_SHOTGUN: 0},
		"selected_weapon_id": WEAPON_UZI,
		"selected_weapon_skin": 0,
	}
	var st := load_state_or_defaults(path, defaults, WEAPON_UZI)
	var music_slider := host.get("music_slider") as HSlider
	if music_slider != null:
		music_slider.value = clampf(float(st.get("music_volume", 0.8)), 0.0, 1.0)
	var sfx_slider := host.get("sfx_slider") as HSlider
	if sfx_slider != null:
		sfx_slider.value = clampf(float(st.get("sfx_volume", 0.4)), 0.0, 1.0)
	host.call("_set_particles_enabled", bool(st.get("particles_enabled", true)), false)
	host.call("_set_screen_shake_enabled", bool(st.get("screen_shake_enabled", true)), false)

	host.set("wallet_coins", int(st.get("coins", 0)))
	host.set("wallet_clk", int(st.get("clk", 0)))
	host.set("player_username", str(st.get("username", fallback_username)).strip_edges())
	if str(host.get("player_username")).is_empty():
		host.set("player_username", fallback_username)

	host.set("owned_warriors", PackedStringArray(st.get("owned_warriors", Array(default_owned_warriors)) as Array))
	host.set("owned_warrior_skins", PackedInt32Array(st.get("owned_warrior_skins", [0]) as Array))
	host.set("selected_warrior_id", str(st.get("selected_warrior_id", default_warrior)).strip_edges().to_lower())
	host.set("selected_warrior_skin", maxi(0, int(st.get("selected_warrior_skin", 0))))
	var warrior_skin_dict := st.get("owned_warrior_skins_by_warrior", default_warrior_skins) as Dictionary
	host.set("owned_warrior_skins_by_warrior", host.call("_normalize_owned_warrior_skins_dict", warrior_skin_dict))
	var equipped_warrior := st.get("equipped_warrior_skin_by_warrior", default_equipped_warrior_skins) as Dictionary
	host.set("equipped_warrior_skin_by_warrior", host.call("_normalize_equipped_warrior_skins_dict", equipped_warrior.duplicate(true)))
	for wid in PackedStringArray(host.call("_warrior_ui_warrior_ids")):
		var owned_warrior_skins_by_warrior := host.get("owned_warrior_skins_by_warrior") as Dictionary
		if not owned_warrior_skins_by_warrior.has(wid):
			owned_warrior_skins_by_warrior[wid] = PackedInt32Array([0])
			host.set("owned_warrior_skins_by_warrior", owned_warrior_skins_by_warrior)
		var equipped_warrior_skin_by_warrior := host.get("equipped_warrior_skin_by_warrior") as Dictionary
		if not equipped_warrior_skin_by_warrior.has(wid):
			equipped_warrior_skin_by_warrior[wid] = 0
			host.set("equipped_warrior_skin_by_warrior", equipped_warrior_skin_by_warrior)

	host.set("owned_weapons", PackedStringArray(st.get("owned_weapons", [WEAPON_UZI]) as Array))
	host.set("selected_weapon_id", str(st.get("selected_weapon_id", WEAPON_UZI)).strip_edges().to_lower())
	host.set("selected_weapon_skin", maxi(0, int(st.get("selected_weapon_skin", 0))))

	var allowed := PackedStringArray([WEAPON_UZI, WEAPON_AK47, WEAPON_KAR, WEAPON_SHOTGUN, WEAPON_GRENADE])
	var filtered_owned := PackedStringArray()
	for wid in host.get("owned_weapons") as PackedStringArray:
		var w := str(wid).strip_edges().to_lower()
		if allowed.has(w):
			filtered_owned.append(w)
	host.set("owned_weapons", filtered_owned)
	if not (host.get("owned_weapons") as PackedStringArray).has(WEAPON_UZI):
		var owned_weapons := host.get("owned_weapons") as PackedStringArray
		owned_weapons.append(WEAPON_UZI)
		host.set("owned_weapons", owned_weapons)
	if not (host.get("owned_weapons") as PackedStringArray).has(WEAPON_GRENADE):
		var owned_weapons := host.get("owned_weapons") as PackedStringArray
		owned_weapons.append(WEAPON_GRENADE)
		host.set("owned_weapons", owned_weapons)
	if not (host.get("owned_warriors") as PackedStringArray).has(default_warrior):
		var owned_warriors := host.get("owned_warriors") as PackedStringArray
		owned_warriors.append(default_warrior)
		host.set("owned_warriors", owned_warriors)

	var out := {}
	var skins_dict := st.get("owned_weapon_skins_by_weapon", {}) as Dictionary
	for key in skins_dict.keys():
		var wid := str(key).strip_edges().to_lower()
		if not allowed.has(wid):
			continue
		var arr := skins_dict.get(key, [0]) as Array
		out[wid] = PackedInt32Array(arr)
	host.set("owned_weapon_skins_by_weapon", out)

	for wid in allowed:
		var owned_weapon_skins_by_weapon := host.get("owned_weapon_skins_by_weapon") as Dictionary
		if not owned_weapon_skins_by_weapon.has(wid):
			owned_weapon_skins_by_weapon[wid] = PackedInt32Array([0])
			host.set("owned_weapon_skins_by_weapon", owned_weapon_skins_by_weapon)
		var equipped_weapon_skin_by_weapon := host.get("equipped_weapon_skin_by_weapon") as Dictionary
		if not equipped_weapon_skin_by_weapon.has(wid):
			equipped_weapon_skin_by_weapon[wid] = 0
			host.set("equipped_weapon_skin_by_weapon", equipped_weapon_skin_by_weapon)

	var eq := st.get("equipped_weapon_skin_by_weapon", {}) as Dictionary
	if eq != null:
		var equipped_weapon_skin_by_weapon := host.get("equipped_weapon_skin_by_weapon") as Dictionary
		for key in eq.keys():
			var wid := str(key).strip_edges().to_lower()
			if not allowed.has(wid):
				continue
			equipped_weapon_skin_by_weapon[wid] = maxi(0, int(eq.get(key, 0)))
		host.set("equipped_weapon_skin_by_weapon", equipped_weapon_skin_by_weapon)

	if not bool(host.call("_warrior_is_owned", str(host.get("selected_warrior_id")))):
		host.set("selected_warrior_id", default_warrior)
	if not bool(host.call("_warrior_skin_is_owned", str(host.get("selected_warrior_id")), int(host.get("selected_warrior_skin")))):
		host.set("selected_warrior_skin", 0)
	host.call("_set_equipped_warrior_skin", str(host.get("selected_warrior_id")), int(host.get("selected_warrior_skin")))
	host.set("_pending_warrior_id", str(host.get("selected_warrior_id")))
	host.set("_pending_warrior_skin", int(host.get("selected_warrior_skin")))
	if not bool(host.call("_weapon_is_owned", str(host.get("selected_weapon_id")))):
		host.set("selected_weapon_id", WEAPON_UZI)
	if not bool(host.call("_weapon_skin_is_owned", str(host.get("selected_weapon_id")), int(host.get("selected_weapon_skin")))):
		host.set("selected_weapon_skin", 0)
	host.call("_set_equipped_weapon_skin", str(host.get("selected_weapon_id")), int(host.get("selected_weapon_skin")))
	host.set("_pending_weapon_id", str(host.get("selected_weapon_id")))
	host.set("_pending_weapon_skin", int(host.get("selected_weapon_skin")))

func build_menu_state_snapshot(host: Control) -> Dictionary:
	var owned_warriors_list: Array = []
	for wid in host.get("owned_warriors") as PackedStringArray:
		owned_warriors_list.append(str(wid))

	var owned_warrior_skins_dict: Dictionary = {}
	for wid in (host.get("owned_warrior_skins_by_warrior") as Dictionary).keys():
		var warrior_arr := (host.get("owned_warrior_skins_by_warrior") as Dictionary).get(wid, PackedInt32Array([0])) as PackedInt32Array
		var warrior_out: Array = []
		if warrior_arr != null:
			for s in warrior_arr:
				warrior_out.append(int(s))
		owned_warrior_skins_dict[str(wid)] = warrior_out

	var owned_warrior_skin_list: Array = []
	for v in host.get("owned_warrior_skins") as PackedInt32Array:
		owned_warrior_skin_list.append(int(v))

	var owned_weapons_list: Array = []
	for w in host.get("owned_weapons") as PackedStringArray:
		owned_weapons_list.append(str(w))

	var owned_weapon_skins_dict: Dictionary = {}
	for wid in (host.get("owned_weapon_skins_by_weapon") as Dictionary).keys():
		var arr := (host.get("owned_weapon_skins_by_weapon") as Dictionary).get(wid, PackedInt32Array([0])) as PackedInt32Array
		var out_arr: Array = []
		if arr != null:
			for s in arr:
				out_arr.append(int(s))
		owned_weapon_skins_dict[str(wid)] = out_arr

	return {
		"coins": int(host.get("wallet_coins")),
		"clk": int(host.get("wallet_clk")),
		"music_volume": (host.get("music_slider") as HSlider).value if host.get("music_slider") != null else 0.8,
		"sfx_volume": (host.get("sfx_slider") as HSlider).value if host.get("sfx_slider") != null else 0.4,
		"particles_enabled": bool(host.get("particles_enabled")),
		"screen_shake_enabled": bool(host.get("screen_shake_enabled")),
		"username": str(host.get("player_username")),
		"owned_warriors": owned_warriors_list,
		"owned_warrior_skins": owned_warrior_skin_list,
		"owned_warrior_skins_by_warrior": owned_warrior_skins_dict,
		"equipped_warrior_skin_by_warrior": host.get("equipped_warrior_skin_by_warrior"),
		"selected_warrior_id": str(host.get("selected_warrior_id")),
		"selected_warrior_skin": int(host.get("selected_warrior_skin")),
		"owned_weapons": owned_weapons_list,
		"owned_weapon_skins_by_weapon": owned_weapon_skins_dict,
		"equipped_weapon_skin_by_weapon": host.get("equipped_weapon_skin_by_weapon"),
		"selected_weapon_id": str(host.get("selected_weapon_id")),
		"selected_weapon_skin": int(host.get("selected_weapon_skin")),
	}
