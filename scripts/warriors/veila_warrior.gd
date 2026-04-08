extends WarriorProfile

const VEILA_SKILL_E := preload("res://scripts/warriors/skills/veila_skill_E.gd")

func _init() -> void:
	super._init("veila", "Veila")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = VEILA_SKILL_E.new()
