extends RefCounted
## Read-only local HUD state. Never ticks waves or owns authoritative health.
var stage: Node3D
var hud: Control
var health =100.0
var dead =false
var phase ="WAITING"
var suspended =false
var wave =0
var remaining =0
func setup(view: Node3D) -> void:
	stage=view
	hud=load("res://scripts/prototypes/kw_arena_hud.gd").new()
	stage.get_node("HUD").add_child(hud);hud.setup(stage)
	for label in hud.game_over_panel.find_children("*","Label",true,false):
		if "TRY AGAIN" in label.text:label.text="ESC / START  -  RESPAWN MENU"
func remaining_count() -> int:return remaining
func retry_wave() -> void:stage.session.request_respawn()
func restart_run() -> void:stage.session.request_respawn()
