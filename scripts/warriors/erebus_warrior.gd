## Erebus Warrior Profile
##
## Skills:
## - Skill1 (Q): Immunity Bubble - Temporary invulnerability for 5 seconds
## - Skill2 (E): Shield - Creates protective barrier

extends WarriorProfile

const EREBUS_SKILL_Q = preload("res://scripts/warriors/skills/erebus_skill_Q.gd")
const EREBUS_SKILL_E = preload("res://scripts/warriors/skills/erebus_skill_E.gd")

func _init() -> void:
	super._init("erebus", "Erebus")
	skill2_charge_required = 6

func _init_skills() -> void:
	skill1 = null
	skill2 = EREBUS_SKILL_E.new()
