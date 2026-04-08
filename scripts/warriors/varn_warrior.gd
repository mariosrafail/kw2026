extends WarriorProfile

const VARN_SKILL_E := preload("res://scripts/warriors/skills/varn_skill_E.gd")

func _init() -> void:
	super._init("varn", "Varn")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = VARN_SKILL_E.new()
