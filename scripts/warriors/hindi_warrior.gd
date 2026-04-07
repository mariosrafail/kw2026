extends WarriorProfile

const HINDI_SKILL_E := preload("res://scripts/warriors/skills/hindi_skill_E.gd")

func _init() -> void:
	super._init("hindi", "Hindi")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = HINDI_SKILL_E.new()
