## Tasko Warrior Profile
##
## Skills:
## - Skill1 (Q): Invisibility Field - pink circle at aim, hide/silence inside (enemies only)
## - Skill2 (E): Mine - persistent ground mine that explodes on touch

extends WarriorProfile

const TASKO_SKILL_Q := preload("res://scripts/warriors/skills/tasko_skill_Q.gd")
const TASKO_SKILL_E := preload("res://scripts/warriors/skills/tasko_skill_E.gd")

func _init() -> void:
	super._init("tasko", "Tasko")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = TASKO_SKILL_E.new()
