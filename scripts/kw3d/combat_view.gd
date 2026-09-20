extends "res://scripts/prototypes/kw_combat_range.gd"
## Presentation adapter. In particular fire(), receive_player_damage and waves never run here.
func setup(owner_stage: Node3D) -> void:
	stage=owner_stage;name="NetworkCombatView"
	fx_rng.seed=913
	_setup_shooting_fx_materials()
	_build_hud();_build_confirm_audio()
	director=load("res://scripts/kw3d/director_view.gd").new();director.setup(stage)
	set_physics_process(false)
	_update_counter()
func _physics_process(_delta: float) -> void:pass
func reset_targets() -> void:stage.session.request_respawn()
func fire(_muzzle: Vector3,_target: Vector3,_chest: Vector3,_profile: Dictionary=WEAPON_RULES.AK,_weapon_id: String="ak") -> Dictionary:return {}
func _on_target_damaged(_target: Node3D,_lethal: bool) -> void:pass
func _update_counter() -> void:
	if counter!=null:counter.text="Esc / Start: network menu and controls. TAB: help. Online world does not pause."
	if kill_label!=null:kill_label.text="KILLS  %d"%total_kills
	if alive_label!=null:alive_label.text="CO-OP  %d PLAYERS"%stage.player_count
	if wave_label!=null and director!=null:wave_label.text="WAVE %02d  //  %d LEFT"%[director.wave,director.remaining]
func notify_hit(_point: Vector3,_direction: Vector3,_amount: float,lethal: bool) -> void:
	reticle.notify_hit(lethal)
	confirm_audio.stream=confirm_kill if lethal else confirm_hit;confirm_audio.play()
	if lethal:score_pulse=0.65
func apply_status(snapshot: Dictionary,local: Dictionary) -> void:
	director.wave=snapshot.wave;director.phase=snapshot.phase;director.remaining=snapshot.remaining
	total_kills=int(local.get("kills",total_kills));kills=total_kills
	var before: float=director.health
	director.health=local.get("hp",director.health)
	director.dead=director.health<=0
	director.hud.set_health(director.health,100.0)
	stage._set_player_healthbar(director.health,100.0)
	if director.dead and not director.hud.game_over_panel.visible and not stage.menu.visible:
		director.hud.show_death(director.wave,total_kills)
		director.hud.death_stats.text="TEAM STILL PLAYING"
	elif not director.dead:director.hud.game_over_panel.hide()
	_update_counter()
