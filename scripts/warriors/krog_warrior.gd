extends WarriorProfile

const KROG_SKILL_E := preload("res://scripts/warriors/skills/krog_skill_E.gd")

func _init() -> void:
	super._init("krog", "Krog")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = KROG_SKILL_E.new()
