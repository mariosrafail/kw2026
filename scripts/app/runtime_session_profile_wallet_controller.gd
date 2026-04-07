extends RefCounted


func apply_profile_payload(host: Node, payload: Dictionary) -> void:
	var coins: int = int(payload.get("coins", 0))
	var clk: int = int(payload.get("clk", 0))
	set_wallet(host, coins, clk)

	var owned_skins_by_character: Dictionary = host.get("owned_skins_by_character") as Dictionary
	owned_skins_by_character.clear()
	var owned_raw: Array = payload.get("owned_skins", []) as Array
	for item in owned_raw:
		if not (item is Dictionary):
			continue
		var entry: Dictionary = item as Dictionary
		var character_id: String = normalize_character_id(str(entry.get("character_id", "")))
		var skin_index: int = int(entry.get("skin_index", 0))
		if character_id.is_empty() or skin_index <= 0:
			continue
		var arr: PackedInt32Array = owned_skins_by_character.get(character_id, PackedInt32Array()) as PackedInt32Array
		if not arr.has(skin_index):
			arr.append(skin_index)
		owned_skins_by_character[character_id] = arr
	host.set("owned_skins_by_character", owned_skins_by_character)

	update_wallet_label(host)
	host.call("_setup_skin_picker")

func set_wallet(host: Node, coins: int, clk: int) -> void:
	host.set("wallet_coins", maxi(0, coins))
	host.set("wallet_clk", maxi(0, clk))
	update_wallet_label(host)

func update_wallet_label(host: Node) -> void:
	var wallet_label: Label = host.get("wallet_label") as Label
	if wallet_label == null:
		return
	var wallet_coins: int = int(host.get("wallet_coins"))
	var wallet_clk: int = int(host.get("wallet_clk"))
	wallet_label.text = "Coins: %d | CLK: %d" % [wallet_coins, wallet_clk]

func normalize_character_id(raw: String) -> String:
	var normalized: String = raw.strip_edges().to_lower()
	if normalized != "erebus" and normalized != "tasko" and normalized != "juice" and normalized != "madam" and normalized != "celler" and normalized != "kotro":
		normalized = "outrage"
	return normalized

func is_skin_owned(host: Node, character_id: String, skin_index: int) -> bool:
	if skin_index <= 1:
		return true
	var normalized: String = normalize_character_id(character_id)
	var owned_skins_by_character: Dictionary = host.get("owned_skins_by_character") as Dictionary
	var arr: PackedInt32Array = owned_skins_by_character.get(normalized, PackedInt32Array()) as PackedInt32Array
	return arr.has(skin_index)

func skin_cost_coins(character_id: String, skin_index: int) -> int:
	# Must match auth API pricing (tools/auth_api/app.py::_skin_cost_coins).
	var normalized: String = normalize_character_id(character_id)
	if skin_index <= 1:
		return 0
	if normalized == "outrage":
		return 10
	return 10
