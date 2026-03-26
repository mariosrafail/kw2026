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
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = OUTRAGE_SKILL_E.new()
