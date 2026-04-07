extends WarriorProfile

const CELLER_SKILL_E := preload("res://scripts/warriors/skills/celler_skill_E.gd")

func _init() -> void:
	super._init("celler", "C3ll3r")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = CELLER_SKILL_E.new()
