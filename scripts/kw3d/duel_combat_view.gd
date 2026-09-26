extends "res://scripts/kw3d/combat_view.gd"
## LAN duel HUD/presentation. All damage and kills remain server-authoritative.

func _update_counter() -> void:
	_set_label_text(counter,"ESC / START room menu   TAB help   First to 10 kills")
	_set_label_text(kill_label,"KILLS  %d" % total_kills)
	_set_label_text(alive_label,"LAN 1V1")
	var enemy_kills = 0
	if stage != null:
		for player in stage.room_state.get("players",[]):
			if int(player.get("id",0)) != stage.session.actor_id:
				enemy_kills = int(player.get("kills",0))
	_set_label_text(wave_label,"FIRST TO 10   //   ENEMY %d" % enemy_kills)

func apply_status(snapshot: Dictionary, local: Dictionary) -> void:
	total_kills = int(local.get("kills",total_kills))
	kills = total_kills
	var before = director.health
	director.health = float(local.get("hp",director.health))
	director.dead = director.health <= 0.0
	director.hud.set_health(director.health,100.0)
	stage._set_player_healthbar(director.health,100.0)
	if director.dead:
		var left = float(local.get("respawn_left",0.0))
		director.hud.banner.text = "DOWN  //  RESPAWN %.1fs" % left
		director.hud.banner_detail.text = "THE DUEL CONTINUES"
		director.hud.banner_time = 0.25
	else:
		director.hud.game_over_panel.hide()
	_update_counter()
