extends "res://scripts/prototypes/kw_grenade_skill.gd"
## Visual-only grenade adapter: authority supplies trajectory, fuse and damage events.
var authoritative_cooldown =0.0
var received_at =0
func throw_grenade() -> bool:return false
func detonate(_point: Vector3) -> Dictionary:return {}
func set_cooldown(value: float) -> void:
	authoritative_cooldown=value;received_at=Time.get_ticks_msec()
func _physics_process(delta: float) -> void:
	cooldown_left=maxf(0,authoritative_cooldown-float(Time.get_ticks_msec()-received_at)/1000.0)
	_tick_effects(delta);_update_hud()
	if stage.input_adapter!=null and stage.input_adapter.last_device=="pad":
		skill_label.text=("RB / R1  GRENADE  READY" if cooldown_left<=0 else "RB / R1  %.1fs"%cooldown_left)
func show_blast(point: Vector3) -> void:
	_spawn_explosion(point)
	if stage.arena_audio!=null:stage.arena_audio.play_event("explosion",point,-9.0)
