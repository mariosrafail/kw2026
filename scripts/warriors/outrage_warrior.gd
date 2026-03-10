## Outrage Warrior Profile
##
## Skills:
## - Skill1 (Q): Bomb Blast - Explosive projectile that damages area
## - Skill2 (E): Damage Boost - Temporary damage multiplier

extends WarriorProfile

const OUTRAGE_SKILL_Q := preload("res://scripts/warriors/skills/outrage_skill_Q.gd")
const OUTRAGE_SKILL_E := preload("res://scripts/warriors/skills/outrage_skill_E.gd")

func _init() -> void:
	super._init("outrage", "Outrage")

func _init_skills() -> void:
	skill1 = OUTRAGE_SKILL_Q.new()
	skill2 = OUTRAGE_SKILL_E.new()
