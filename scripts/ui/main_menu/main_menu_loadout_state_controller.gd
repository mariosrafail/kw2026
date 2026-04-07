extends RefCounted

class_name MainMenuLoadoutStateController

const DATA := preload("res://scripts/ui/main_menu/data.gd")

var _host: Control

func configure(host: Control) -> void:
	_host = host

func warrior_is_owned(warrior_id: String) -> bool:
	var owned_warriors := _host.get("owned_warriors") as PackedStringArray
	return owned_warriors.has(warrior_id.strip_edges().to_lower())

func warrior_skin_is_owned(warrior_id: String, skin_index: int) -> bool:
	var normalized := warrior_id.strip_edges().to_lower()
	var idx := maxi(0, skin_index)
	if not warrior_is_owned(normalized):
		return false
	if idx <= 0:
		return true
	var owned_warrior_skins_by_warrior := _host.get("owned_warrior_skins_by_warrior") as Dictionary
	var arr := owned_warrior_skins_by_warrior.get(normalized, PackedInt32Array([0])) as PackedInt32Array
	if arr == null:
		return false
	return arr.has(idx)

func equipped_warrior_skin(warrior_id: String) -> int:
	var normalized := warrior_id.strip_edges().to_lower()
	var equipped_warrior_skin_by_warrior := _host.get("equipped_warrior_skin_by_warrior") as Dictionary
	if equipped_warrior_skin_by_warrior.has(normalized):
		return maxi(0, int(equipped_warrior_skin_by_warrior.get(normalized, 0)))
	return 0

func set_equipped_warrior_skin(warrior_id: String, skin_index: int) -> void:
	var equipped_warrior_skin_by_warrior := _host.get("equipped_warrior_skin_by_warrior") as Dictionary
	equipped_warrior_skin_by_warrior[warrior_id.strip_edges().to_lower()] = maxi(0, skin_index)

func is_warrior_skin_owned(skin_index: int) -> bool:
	return warrior_skin_is_owned(str(_host.get("selected_warrior_id")), skin_index)

func weapon_is_owned(weapon_id: String) -> bool:
	var owned_weapons := _host.get("owned_weapons") as PackedStringArray
	return owned_weapons.has(weapon_id.strip_edges().to_lower())

func weapon_skin_is_owned(weapon_id: String, skin_index: int) -> bool:
	var normalized := weapon_id.strip_edges().to_lower()
	var owned_weapon_skins_by_weapon := _host.get("owned_weapon_skins_by_weapon") as Dictionary
	if not owned_weapon_skins_by_weapon.has(normalized):
		return skin_index == 0
	var arr := owned_weapon_skins_by_weapon[normalized] as PackedInt32Array
	if arr == null:
		return skin_index == 0
	return arr.has(skin_index)

func equipped_weapon_skin(weapon_id: String) -> int:
	var normalized := weapon_id.strip_edges().to_lower()
	var equipped_weapon_skin_by_weapon := _host.get("equipped_weapon_skin_by_weapon") as Dictionary
	if equipped_weapon_skin_by_weapon.has(normalized):
		return maxi(0, int(equipped_weapon_skin_by_weapon.get(normalized, 0)))
	return 0

func set_equipped_weapon_skin(weapon_id: String, skin_index: int) -> void:
	var normalized := weapon_id.strip_edges().to_lower()
	var equipped_weapon_skin_by_weapon := _host.get("equipped_weapon_skin_by_weapon") as Dictionary
	equipped_weapon_skin_by_weapon[normalized] = maxi(0, skin_index)

func weapon_item_button_text(weapon_id: String, skin_index: int) -> String:
	var weapon_name := weapon_id.to_upper()
	var skin_name := str(_host.call("_weapon_skin_label", weapon_id, skin_index))
	var base := "%s  -  %s" % [weapon_name, skin_name]
	if not weapon_is_owned(weapon_id):
		var weapon_cost := int(DATA.WEAPON_BASE_COST_BY_ID.get(weapon_id, 0))
		if weapon_cost <= 0:
			return "%s  [LOCKED]" % base
		return "%s  (%d)  [LOCKED]" % [base, weapon_cost]
	if weapon_skin_is_owned(weapon_id, skin_index):
		if weapon_id == str(_host.get("selected_weapon_id")) and skin_index == int(_host.get("selected_weapon_skin")):
			return "%s  [OWNED]" % base
		return base
	return "%s  (%d)  [LOCKED]" % [base, int(_host.call("_weapon_skin_cost", weapon_id, skin_index))]
