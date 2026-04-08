extends WarriorProfile

const AEVILOK_SKILL_E := preload("res://scripts/warriors/skills/aevilok_skill_E.gd")

func _init() -> void:
	super._init("aevilok", "Aevilok")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = AEVILOK_SKILL_E.new()
