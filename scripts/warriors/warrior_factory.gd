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
const JUICE_WARRIOR := preload("res://scripts/warriors/juice_warrior.gd")
const MADAM_WARRIOR := preload("res://scripts/warriors/madam_warrior.gd")
const CELLER_WARRIOR := preload("res://scripts/warriors/celler_warrior.gd")
const KOTRO_WARRIOR := preload("res://scripts/warriors/kotro_warrior.gd")
const NOVA_WARRIOR := preload("res://scripts/warriors/nova_warrior.gd")
const HINDI_WARRIOR := preload("res://scripts/warriors/hindi_warrior.gd")
const LOKER_WARRIOR := preload("res://scripts/warriors/loker_warrior.gd")
const GAN_WARRIOR := preload("res://scripts/warriors/gan_warrior.gd")
const VEILA_WARRIOR := preload("res://scripts/warriors/veila_warrior.gd")
const KROG_WARRIOR := preload("res://scripts/warriors/krog_warrior.gd")
const AEVILOK_WARRIOR := preload("res://scripts/warriors/aevilok_warrior.gd")
const FRANKY_WARRIOR := preload("res://scripts/warriors/franky_warrior.gd")
const VARN_WARRIOR := preload("res://scripts/warriors/varn_warrior.gd")
const LALOU_WARRIOR := preload("res://scripts/warriors/lalou_warrior.gd")
const M4_WARRIOR := preload("res://scripts/warriors/m4_warrior.gd")
const RP_WARRIOR := preload("res://scripts/warriors/rp_warrior.gd")

static func create_warrior(warrior_id: String) -> WarriorProfile:
	match warrior_id.to_lower():
		"outrage":
			return OUTRAGE_WARRIOR.new()
		"erebus":
			return EREBUS_WARRIOR.new()
		"tasko":
			return TASKO_WARRIOR.new()
		"juice":
			return JUICE_WARRIOR.new()
		"madam":
			return MADAM_WARRIOR.new()
		"celler":
			return CELLER_WARRIOR.new()
		"kotro":
			return KOTRO_WARRIOR.new()
		"nova":
			return NOVA_WARRIOR.new()
		"hindi":
			return HINDI_WARRIOR.new()
		"loker":
			return LOKER_WARRIOR.new()
		"gan":
			return GAN_WARRIOR.new()
		"veila":
			return VEILA_WARRIOR.new()
		"krog":
			return KROG_WARRIOR.new()
		"aevilok":
			return AEVILOK_WARRIOR.new()
		"franky":
			return FRANKY_WARRIOR.new()
		"varn":
			return VARN_WARRIOR.new()
		"lalou":
			return LALOU_WARRIOR.new()
		"m4":
			return M4_WARRIOR.new()
		"rp":
			return RP_WARRIOR.new()
		_:
			push_error("Unknown warrior: %s" % warrior_id)
			return null

static func is_valid_warrior(warrior_id: String) -> bool:
	return warrior_id.to_lower() in ["outrage", "erebus", "tasko", "juice", "madam", "celler", "kotro", "nova", "hindi", "loker", "gan", "veila", "krog", "aevilok", "franky", "varn", "lalou", "m4", "rp"]

static func get_all_warrior_ids() -> Array[String]:
	return ["outrage", "erebus", "tasko", "juice", "madam", "celler", "kotro", "nova", "hindi", "loker", "gan", "veila", "krog", "aevilok", "franky", "varn", "lalou", "m4", "rp"]

static func get_warrior_name(warrior_id: String) -> String:
	match warrior_id.to_lower():
		"outrage":
			return "Outrage"
		"erebus":
			return "Erebus"
		"tasko":
			return "Tasko"
		"juice":
			return "Juice"
		"madam":
			return "Madam"
		"celler":
			return "C3ll3r"
		"kotro":
			return "Kotro"
		"nova":
			return "Nova"
		"hindi":
			return "Hindi"
		"loker":
			return "Loker"
		"gan":
			return "Gan"
		"veila":
			return "Veila"
		"krog":
			return "Krog"
		"aevilok":
			return "Aevilok"
		"franky":
			return "Franky"
		"varn":
			return "Varn"
		"lalou":
			return "Lalou"
		"m4":
			return "M4"
		"rp":
			return "Raining Pleasure"
		_:
			return "Unknown"
