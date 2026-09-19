extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(value: bool,key: String) -> void:
	if not value:failures.append(key);push_error("AUTHORITY_COMBAT_FAIL "+key)
func run() -> void:
	var world=load("res://scripts/kw3d/authority_world.gd").new();root.add_child(world)
	world.add_player(1);world.add_player(2)
	world.actors[1].position=Vector3(-10,1.735,0);world.actors[2].position=Vector3(10,1.735,0)
	world.actors[1].locomotion.reset();world.actors[2].locomotion.reset()
	for a in world.actors.values():
		if a.is_bot:a.brain.enabled=false
	world.round_live=true
	for i in range(720):
		world.step();await physics_frame
		for id in [1,2]:check(world.actors[id].health>=0 and world.actors[id].health<=100,"health_bounded")
	check(world.next_bolt>=4,"frequent_authoritative_enemy_fire")
	check(world.actors[1].health<100 or world.actors[2].health<100,"real_bolts_hit_player_shapes")
	check(not world.damage(2,20,Vector3.FORWARD,1,Vector3.ZERO),"friendly_fire_off")
	var injured: Node3D=world.actors[1] if world.actors[1].health<100 and world.actors[1].health>0 else world.actors[2]
	var before: float=injured.health
	world.damage(1000,100,Vector3.FORWARD,injured.actor_id,Vector3.ZERO)
	check(injured.health==minf(100,before+8),"only_scoring_actor_heals")
	print("AUTHORITY_LIVE_COMBAT_","PASS" if failures.is_empty() else "FAIL",failures," shots=",world.next_bolt," hp1=",world.actors[1].health," hp2=",world.actors[2].health)
	world.free();quit(0 if failures.is_empty() else 1)
