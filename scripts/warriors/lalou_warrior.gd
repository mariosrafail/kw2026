extends WarriorProfile

const LALOU_SKILL_E := preload("res://scripts/warriors/skills/lalou_skill_E.gd")

func _init() -> void:
	super._init("lalou", "Lalou")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = LALOU_SKILL_E.new()
