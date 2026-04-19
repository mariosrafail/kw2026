extends WarriorProfile

const SINK_SKILL_E := preload("res://scripts/warriors/skills/sink_skill_E.gd")

func _init() -> void:
	super._init("sink", "Sink")
	skill2_charge_required = 5

func _init_skills() -> void:
	skill1 = null
	skill2 = SINK_SKILL_E.new()
