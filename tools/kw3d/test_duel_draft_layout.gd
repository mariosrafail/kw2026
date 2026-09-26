extends SceneTree

const DRAFT := preload("res://scripts/kw3d/duel_draft_overlay.gd")

class FakeSession extends RefCounted:
	var actor_id := 1

class FakeStage extends Node3D:
	var session := FakeSession.new()
	func choose_augment(_card_id: String) -> void: pass

var failures: Array[String]=[]

func check(value: bool,label: String) -> void:
	if value:return
	failures.append(label)
	push_error("DUEL_DRAFT_LAYOUT_FAIL "+label)

func _initialize() -> void:
	run.call_deferred()

func _inside(outer: Rect2,inner: Rect2) -> bool:
	return inner.position.x>=outer.position.x-0.5 and inner.position.y>=outer.position.y-0.5 and inner.end.x<=outer.end.x+0.5 and inner.end.y<=outer.end.y+0.5

func _check_size(overlay: Control,viewport_size: Vector2,label: String) -> void:
	overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	overlay.position=Vector2.ZERO
	overlay.size=viewport_size
	overlay._layout_overlay()
	await process_frame
	await process_frame
	var screen:=Rect2(Vector2.ZERO,viewport_size)
	check(_inside(screen,overlay.root_box.get_rect()),label+"_root_inside")
	for index in range(overlay.cards.get_child_count()):
		var card:=overlay.cards.get_child(index) as Control
		check(_inside(screen,card.get_global_rect()),label+"_card_"+str(index)+"_inside")

func run() -> void:
	var host:=Control.new()
	root.add_child(host)
	host.size=Vector2(800,450)
	var fake:=FakeStage.new()
	root.add_child(fake)
	var overlay:=DRAFT.new()
	host.add_child(overlay)
	overlay.setup(fake)
	var room: Dictionary={
		"round_phase":"DRAFT","draft_chooser":1,
		"draft_pool":["heavy_rounds","feather_trigger","glass_cannon","air_control","grounded","vamp_shot"],
		"players":[{"id":1,"hero":"outrage"},{"id":2,"hero":"erebus"}]
	}
	overlay.refresh(room)
	for unused in range(3):await process_frame
	await _check_size(overlay,Vector2(800,450),"medium")
	await _check_size(overlay,Vector2(640,360),"small")
	await _check_size(overlay,Vector2(520,300),"compact")
	print("DUEL_DRAFT_LAYOUT_","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)
