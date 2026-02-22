## Outrage Warrior Profile
##
## Skills:
## - Skill1 (Q): Bomb Blast - Explosive projectile that damages area
## - Skill2 (E): Damage Boost - Temporary damage multiplier

extends WarriorProfile

const OUTRAGE_BOMB_SKILL := preload("res://scripts/warriors/skills/outrage_bomb_skill.gd")
const OUTRAGE_BOOST_SKILL := preload("res://scripts/warriors/skills/outrage_damage_boost_skill.gd")

func _init() -> void:
	super._init("outrage", "Outrage")

func _init_skills() -> void:
	skill1 = OUTRAGE_BOMB_SKILL.new()
	skill2 = OUTRAGE_BOOST_SKILL.new()
