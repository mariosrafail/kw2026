extends WarriorProfile

const RP_SKILL_E := preload("res://scripts/warriors/skills/rp_skill_E.gd")

func _init() -> void:
	super._init("rp", "Raining Pleasure")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = RP_SKILL_E.new()
