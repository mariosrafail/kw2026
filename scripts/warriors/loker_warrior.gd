extends WarriorProfile

const LOKER_SKILL_E := preload("res://scripts/warriors/skills/loker_skill_E.gd")

func _init() -> void:
	super._init("loker", "Loker")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = LOKER_SKILL_E.new()
