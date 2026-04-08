extends WarriorProfile

const GAN_SKILL_E := preload("res://scripts/warriors/skills/gan_skill_E.gd")

func _init() -> void:
	super._init("gan", "Gan")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = GAN_SKILL_E.new()
