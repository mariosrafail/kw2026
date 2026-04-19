extends WarriorProfile

const WOMAN_SKILL_E := preload("res://scripts/warriors/skills/woman_skill_E.gd")

func _init() -> void:
	super._init("woman", "Woman")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = WOMAN_SKILL_E.new()
