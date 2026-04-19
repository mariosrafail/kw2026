extends WarriorProfile

const CRASHOUT_SKILL_E := preload("res://scripts/warriors/skills/crashout_skill_E.gd")

func _init() -> void:
	super._init("crashout", "CrashOut")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = CRASHOUT_SKILL_E.new()
