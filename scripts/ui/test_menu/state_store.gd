extends RefCounted

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
