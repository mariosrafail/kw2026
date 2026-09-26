extends "res://scripts/kw3d/duel_client.gd"
const RULES := preload("res://scripts/kw3d/duel_rules.gd")
const ARENA := preload("res://scripts/kw3d/duel_arena.gd")
const DRAFT_UI := preload("res://scripts/kw3d/duel_draft_overlay.gd")
const OVERDRIVE_COMBAT := preload("res://scripts/kw3d/overdrive_duel_combat_view.gd")

var arena_nodes: Dictionary = {}
var draft_overlay: Control
var countdown_mark := -1

func _combat_script() -> Script:
	return OVERDRIVE_COMBAT

func _initial_online_warrior_id() -> String:
	# Overdrive assigns OUTRAGE / EREBUS server-side; menu-selected co-op warriors
	# must not replace the duel's fixed hero body before the welcome packet.
	return RULES.OUTRAGE

func _build_arena() -> void:
	arena_nodes = ARENA.build_client(self)
	_add_neon_light(Vector3(-10,6,-4),Color("20c9ff"),10.0)
	_add_neon_light(Vector3(10,6,4),Color("ff366e"),10.0)
	_add_neon_light(Vector3(0,7,0),Color("8b5cff"),12.0)

func _ready() -> void:
	super._ready()
	var layer := CanvasLayer.new()
	layer.layer = 55
	add_child(layer)
	draft_overlay = DRAFT_UI.new()
	layer.add_child(draft_overlay)
	draft_overlay.setup(self)
	_refresh_overdrive_ui()

func _welcome(payload: Dictionary) -> void:
	super._welcome(payload)
	var mine := _room_player(session.actor_id)
	var hero := str(mine.get("hero",RULES.OUTRAGE)).to_upper()
	DisplayServer.window_set_title("KW OVERDRIVE DUEL | "+hero)
	_refresh_overdrive_ui()

func _room_player(id: int) -> Dictionary:
	for p in room_state.get("players",[]):
		if int(p.get("id",0)) == id:return p
	return {}
func _apply_snapshot(snapshot: Dictionary) -> void:
	super._apply_snapshot(snapshot)
	_sync_rival_labels()
	_refresh_overdrive_ui()
	_sync_core_visual()

func _sync_rival_labels() -> void:
	for record in replicas.values():
		var state: Dictionary = record.get("next",{})
		if bool(state.get("bot",false)):continue
		var hero := str(state.get("hero",state.get("skin","player"))).to_upper()
		var username := str(state.get("name","RIVAL")).to_upper()
		var node: Node3D = record.get("node")
		if node == null:continue
		var tag:=node.get_node_or_null("VirtualUsername") as Label3D
		if tag!=null:
			tag.text = "%s  //  %s"%[username,hero]
			tag.modulate = Color("8aa0ff") if hero == "EREBUS" else Color("ff8a92")

func _control_action(action: String) -> void:
	if action == "skill":
		if session.connected and str(room_state.get("round_phase","")) in ["FIGHT","OVERLOAD"]:
			session.request_duel_skill()
		return
	super._control_action(action)

func choose_augment(card_id: String) -> void:
	if session.connected:
		session.choose_duel_augment(card_id)

func _decorate_prediction(simulation: Dictionary,_dt: float) -> void:
	var augments: Dictionary = local_state.get("augments",{})
	var speed := 1.0
	if float(local_state.get("haste",0.0)) > 0.0:speed *= 1.20
	if int(augments.get("grounded",0)) > 0:speed *= 0.93
	if int(augments.get("air_control",0)) > 0 and not player.is_on_floor():speed *= 1.18
	var hp := float(local_state.get("hp",100.0))
	var max_hp := float(local_state.get("max_hp",100.0))
	if int(augments.get("last_stand",0)) > 0 and hp <= max_hp*0.30:speed *= 1.15
	simulation["speed_multiplier"] = speed
	var phase := str(room_state.get("round_phase",""))
	if phase not in ["FIGHT","OVERLOAD"]:
		simulation["move"] = Vector2.ZERO
		simulation["fire"] = false
		simulation["jump"] = false

func _after_prediction_step(_dt: float) -> void:
	if str(room_state.get("round_phase","")) in ["FIGHT","OVERLOAD"]:
		ARENA.apply_jump_pad(player)
func _refresh_overdrive_ui() -> void:
	if draft_overlay != null:draft_overlay.refresh(room_state)
	if input_adapter == null:return
	var phase := str(room_state.get("round_phase",""))
	if phase == "DRAFT":
		input_adapter.suspend()
		if not options.has("qa-client"):Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif phase == "COUNTDOWN":
		input_adapter.suspend()
		if not options.has("qa-client"):Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		if combat != null:
			var count_value:=ceili(float(room_state.get("countdown",0.0)))
			if count_value>0 and count_value!=countdown_mark:
				countdown_mark=count_value
				combat.director.hud.show_countdown(str(count_value),0.72,Color("fff0b8"))
			combat.director.hud.banner.text = "ROUND %d" % int(room_state.get("round",0))
			combat.director.hud.banner_detail.text = "FIGHT IN %.1f" % float(room_state.get("countdown",0.0))
			combat.director.hud.banner_time = 0.25
	elif phase in ["FIGHT","OVERLOAD"] and menu != null and not menu.visible:
		countdown_mark=-1
		input_adapter.enabled = true
		if not options.has("qa-client"):Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _sync_core_visual() -> void:
	if arena_nodes.is_empty():return
	var core: MeshInstance3D = arena_nodes.get("core")
	if core == null:return
	var active := bool(room_state.get("core_available",false))
	var pulse := 1.0+sin(age*7.0)*0.09 if active else 0.84
	core.scale = Vector3.ONE*pulse
	var mat := core.material_override as StandardMaterial3D
	if mat != null:
		mat.emission_energy_multiplier = 4.8 if active else 0.55
		mat.albedo_color = Color("b583ff") if active else Color("433361")

func _process(delta: float) -> void:
	super._process(delta)
	_sync_core_visual()
func _style_local_human(style: Node3D,state: Dictionary) -> void:
	_apply_hero_style(style,str(state.get("hero",state.get("skin",RULES.OUTRAGE))))

func _style_remote_human(style: Node3D,state: Dictionary) -> void:
	_apply_hero_style(style,str(state.get("hero",state.get("skin",RULES.OUTRAGE))))

func _apply_hero_style(root: Node3D,hero: String) -> void:
	if hero != RULES.EREBUS or bool(root.get_meta("overdrive_erebus",false)):return
	root.set_meta("overdrive_erebus",true)
	for node in root.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		var material := mesh.material_override
		if material is ShaderMaterial:
			var copy := material.duplicate() as ShaderMaterial
			var base: Variant = copy.get_shader_parameter("base_color")
			if base is Color:
				copy.set_shader_parameter("base_color",(base as Color).lerp(Color("6471b6"),0.58))
			mesh.material_override = copy
		elif material is StandardMaterial3D:
			var copy := material.duplicate() as StandardMaterial3D
			copy.albedo_color = copy.albedo_color.lerp(Color("6471b6"),0.58)
			mesh.material_override = copy
	var light := OmniLight3D.new()
	light.name = "ErebusVoidGlow"
	light.light_color = Color("6f82ff")
	light.light_energy = 0.7
	light.omni_range = 3.2
	light.position = Vector3(0,0.8,0)
	root.add_child(light)

func _event(e: Dictionary) -> void:
	super._event(e)
	match str(e.get("type","")):
		"round_start":
			_stop_death_camera()
			combat.director.hud.hide_round_result()
			combat.director.hud.show_countdown("FIGHT!",0.58,Color("76efbd"))
			countdown_mark=-1
			var players: Array=room_state.get("players",[]) as Array
			var left_name:="PLAYER 1"
			var right_name:="PLAYER 2"
			if players.size()>0:left_name=str((players[0] as Dictionary).get("name",left_name)).to_upper()
			if players.size()>1:right_name=str((players[1] as Dictionary).get("name",right_name)).to_upper()
			combat.director.hud.announce("ROUND %d" % int(e.get("round",0)),"%s  VS  %s"%[left_name,right_name],1.2)
		"round_over":
			if e.has("room"):room_state=e.room
			var winner := int(e.get("winner",0))
			var loser := int(e.get("loser",0))
			var player:=_room_player(winner)
			var winner_name:=str(player.get("name",player.get("hero","PLAYER"))).to_upper()
			var winner_score:=int(player.get("rounds",0))
			var target:=int(room_state.get("round_target",RULES.ROUND_TARGET))
			var players: Array=room_state.get("players",[]) as Array
			var left_score:=int((players[0] as Dictionary).get("rounds",0)) if players.size()>0 else 0
			var right_score:=int((players[1] as Dictionary).get("rounds",0)) if players.size()>1 else 0
			var detail:="MATCH POINT  //  ONE MORE" if winner_score==target-1 else "DRAFT NEXT"
			combat.director.hud.announce(winner_name+" TAKES THE ROUND","%d / %d  //  %s"%[winner_score,target,detail],2.0)
			combat.director.hud.show_round_result(winner_name+" TAKES THE ROUND","%d  —  %d"%[left_score,right_score],detail,2.2,Color("ffd166") if winner==session.actor_id else Color("ff6c84"))
			var focus_point:=player_visual.global_position
			if loser==session.actor_id:
				focus_point=player.global_position+Vector3.UP*0.8
			elif replicas.has(loser):
				var loser_record:=replicas[loser] as Dictionary
				if is_instance_valid(loser_record.node):focus_point=loser_record.node.global_position+Vector3.UP*0.8
			_start_death_camera(winner,focus_point)
			input_adapter.rumble(0.88,0.18) if winner==session.actor_id else input_adapter.rumble(0.46,0.12)
		"core_online":
			combat.director.hud.announce("OVERDRIVE CORE ONLINE","CLAIM IT TO REFILL YOUR SKILL",1.4)
		"core_claim":
			var hero := str(e.get("hero","PLAYER")).to_upper()
			combat.director.hud.announce(hero+" CLAIMED THE CORE","SKILL FULL",1.2)
		"overload":
			combat.director.hud.announce("REACTOR OVERLOAD","OUTER RING IS BURNING",2.0)
		"skill":
			if int(e.get("actor",0)) == session.actor_id:input_adapter.rumble(0.48,0.10)
	_refresh_overdrive_ui()

func open_controls_menu() -> void:
	if menu == null:return
	menu.message.text = "OVERDRIVE DUEL\nE / LB / L1: hero skill   G / RB / R1: grenade\nWheel / D-pad: AK, Shotgun, KAR   First to 5 rounds."
