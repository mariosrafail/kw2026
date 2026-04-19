extends WarriorProfile

const CTRLALT_SKILL_E := preload("res://scripts/warriors/skills/ctrlalt_skill_E.gd")

func _init() -> void:
	super._init("ctrlalt", "Ctrlalt")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = CTRLALT_SKILL_E.new()
