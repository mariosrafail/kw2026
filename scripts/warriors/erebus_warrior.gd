## Erebus Warrior Profile
##
## Skills:
## - Skill1 (Q): Immunity Bubble - Temporary invulnerability for 5 seconds
## - Skill2 (E): Shield - Creates protective barrier

extends WarriorProfile

const EREBUS_IMMUNITY_SKILL = preload("res://scripts/skills/erebus_immunity_skill.gd")
const EREBUS_SHIELD_SKILL = preload("res://scripts/warriors/skills/erebus_shield_skill.gd")

func _init() -> void:
	super._init("erebus", "Erebus")

func _init_skills() -> void:
	skill1 = EREBUS_IMMUNITY_SKILL.new()
	skill2 = EREBUS_SHIELD_SKILL.new()
