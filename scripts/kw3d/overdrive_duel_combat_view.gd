extends "res://scripts/kw3d/duel_combat_view.gd"
const RULES := preload("res://scripts/kw3d/duel_rules.gd")

func _room_player(id: int) -> Dictionary:
	if stage == null:return {}
	for p in stage.room_state.get("players",[]):
		if int(p.get("id",0)) == id:return p
	return {}

func _players() -> Array:
	if stage == null:return []
	return stage.room_state.get("players",[]) as Array

func _player_name(player: Dictionary,fallback: String) -> String:
	var name:=str(player.get("name",fallback)).strip_edges()
	return name.to_upper() if not name.is_empty() else fallback

func _player_score(player: Dictionary) -> int:
	return int(player.get("rounds",0))

func _scoreline() -> String:
	var players:=_players()
	if players.size()<2:return "WAITING FOR RIVAL"
	var first:=players[0] as Dictionary
	var second:=players[1] as Dictionary
	return "%s  %d   —   %d  %s"%[
		_player_name(first,"PLAYER 1"),_player_score(first),
		_player_score(second),_player_name(second,"PLAYER 2")
	]

func _match_point_text() -> String:
	var players:=_players()
	if players.size()<2:return ""
	var target:=int(stage.room_state.get("round_target",RULES.ROUND_TARGET))
	for raw in players:
		var player:=raw as Dictionary
		if _player_score(player)==target-1:
			return "MATCH POINT  //  %s"%_player_name(player,"PLAYER")
	return ""

func _update_counter() -> void:
	if stage == null:return
	var room: Dictionary = stage.room_state
	var local := _room_player(stage.session.actor_id)
	var phase := str(room.get("round_phase","LOBBY"))
	if counter != null:
		var skill_name := RULES.skill_name(str(local.get("hero",RULES.OUTRAGE)))
		var charges := int(local.get("skill_charges",0))
		var cd := float(local.get("skill_cd",0.0))
		_set_label_text(counter,"E / LB  %s  [%d]  %.1fs    G / RB grenade    ESC / START menu" % [skill_name,charges,cd])
	_set_label_text(kill_label,"ROUND %d" % int(room.get("round",0)))
	_set_label_text(alive_label,_scoreline())
	if wave_label != null:
		var match_point:=_match_point_text()
		if phase == "COUNTDOWN":
			_set_label_text(wave_label,(match_point+"  //  " if not match_point.is_empty() else "")+"FIGHT IN %.1f"%float(room.get("countdown",0.0)))
		elif phase == "OVERLOAD":
			_set_label_text(wave_label,"REACTOR OVERLOAD  //  MOVE TO CENTER")
		elif bool(room.get("core_available",false)):
			_set_label_text(wave_label,"OVERDRIVE CORE ONLINE  //  CLAIM = FULL SKILL")
		elif phase == "FIGHT":
			_set_label_text(wave_label,"CORE IN %.1fs  //  OVERLOAD %.1fs" % [float(room.get("core_delay",0.0)),maxf(0.0,RULES.OVERLOAD_AT-float(room.get("fight_time",0.0)))])
		elif phase == "DRAFT":
			_set_label_text(wave_label,"AUGMENT DRAFT")
		elif phase == "RESULT":
			_set_label_text(wave_label,"MATCH COMPLETE  //  READY UP FOR REMATCH")
		else:
			_set_label_text(wave_label,"FIRST TO %d ROUNDS" % RULES.ROUND_TARGET)

func apply_status(snapshot: Dictionary,local: Dictionary) -> void:
	total_kills = int(local.get("kills",total_kills))
	kills = total_kills
	var maximum := float(local.get("max_hp",100.0))
	director.health = float(local.get("hp",director.health))
	director.dead = director.health <= 0.0
	director.hud.set_health(director.health,maximum)
	stage._set_player_healthbar(director.health,maximum)
	if director.dead:
		director.hud.banner.text = "ROUND OVER"
		director.hud.banner_detail.text = "COUNTER-PICK YOUR NEXT BUILD"
		director.hud.banner_time = 0.25
	else:
		director.hud.game_over_panel.hide()
	_update_counter()
