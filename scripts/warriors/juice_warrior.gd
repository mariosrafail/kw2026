extends WarriorProfile

const JUICE_SKILL_E := preload("res://scripts/warriors/skills/juice_skill_E.gd")

func _init() -> void:
	super._init("juice", "Juice")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = JUICE_SKILL_E.new()
