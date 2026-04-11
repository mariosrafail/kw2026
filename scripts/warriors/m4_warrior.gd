extends WarriorProfile

const M4_SKILL_E := preload("res://scripts/warriors/skills/m4_skill_E.gd")

func _init() -> void:
	super._init("m4", "M4")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = M4_SKILL_E.new()
