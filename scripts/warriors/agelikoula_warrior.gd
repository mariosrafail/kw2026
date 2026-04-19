extends WarriorProfile

const AGELIKOULA_SKILL_E := preload("res://scripts/warriors/skills/agelikoula_skill_E.gd")

func _init() -> void:
	super._init("agelikoula", "Agelikoula")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = AGELIKOULA_SKILL_E.new()
