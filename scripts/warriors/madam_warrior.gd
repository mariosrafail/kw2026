extends WarriorProfile

const MADAM_SKILL_E := preload("res://scripts/warriors/skills/madam_skill_E.gd")

func _init() -> void:
	super._init("madam", "Madam")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = MADAM_SKILL_E.new()
