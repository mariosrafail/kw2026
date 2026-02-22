## Tasko Warrior Profile
##
## Skills:
## - Skill1 (Q): Invisibility Field - pink circle at aim, hide/silence inside (enemies only)
## - Skill2 (E): Mine - persistent ground mine that explodes on touch

extends WarriorProfile

const TASKO_INVIS_FIELD_SKILL := preload("res://scripts/warriors/skills/tasko_invisibility_field_skill.gd")
const TASKO_MINE_SKILL := preload("res://scripts/warriors/skills/tasko_mine_skill.gd")

func _init() -> void:
	super._init("tasko", "Tasko")

func _init_skills() -> void:
	skill1 = TASKO_INVIS_FIELD_SKILL.new()
	skill2 = TASKO_MINE_SKILL.new()

