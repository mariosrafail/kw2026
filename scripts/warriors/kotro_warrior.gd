extends WarriorProfile

const KOTRO_SKILL_E := preload("res://scripts/warriors/skills/kotro_skill_E.gd")

func _init() -> void:
	super._init("kotro", "Kotro")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = KOTRO_SKILL_E.new()
