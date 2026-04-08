extends WarriorProfile

const FRANKY_SKILL_E := preload("res://scripts/warriors/skills/franky_skill_E.gd")

func _init() -> void:
	super._init("franky", "Franky")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = FRANKY_SKILL_E.new()
