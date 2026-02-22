## Warrior Factory - Creates warrior instances by ID
##
## Single point of creation for all warriors
## Usage: 
##   var warrior = WarriorFactory.create_warrior("outrage")

extends RefCounted
class_name WarriorFactory

const OUTRAGE_WARRIOR := preload("res://scripts/warriors/outrage_warrior.gd")
const EREBUS_WARRIOR := preload("res://scripts/warriors/erebus_warrior.gd")
const TASKO_WARRIOR := preload("res://scripts/warriors/tasko_warrior.gd")

static func create_warrior(warrior_id: String) -> WarriorProfile:
	match warrior_id.to_lower():
		"outrage":
			return OUTRAGE_WARRIOR.new()
		"erebus":
			return EREBUS_WARRIOR.new()
		"tasko":
			return TASKO_WARRIOR.new()
		_:
			push_error("Unknown warrior: %s" % warrior_id)
			return null

static func is_valid_warrior(warrior_id: String) -> bool:
	return warrior_id.to_lower() in ["outrage", "erebus", "tasko"]

static func get_all_warrior_ids() -> Array[String]:
	return ["outrage", "erebus", "tasko"]

static func get_warrior_name(warrior_id: String) -> String:
	match warrior_id.to_lower():
		"outrage":
			return "Outrage"
		"erebus":
			return "Erebus"
		"tasko":
			return "Tasko"
		_:
			return "Unknown"
