extends Node2D
class_name VarnSwarmVfx

const RETURN_DURATION_SEC := 0.8
const OUTBOUND_DURATION_SEC := 0.5
const FOLLOW_OFFSET := Vector2(-18.0, -26.0)

var players: Dictionary = {}
var caster_peer_id := 0
var target_peer_ids: Array[int] = []
var duration_sec := 5.0
var flies_per_target := 5
var fly_texture: Texture2D
var fly_color := Color(0.78, 0.88, 0.22, 1.0)

var _elapsed := 0.0
var _flies: Array = []
var _fly_rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 61
	_fly_rng.seed = int(Time.get_ticks_usec()) ^ int(maxi(1, caster_peer_id) * 7919)
	_spawn_flies()

func _process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	var outbound_t := clampf(_elapsed / maxf(0.05, OUTBOUND_DURATION_SEC), 0.0, 1.0)
	var returning := _elapsed > duration_sec
	var return_t := clampf((_elapsed - duration_sec) / maxf(0.05, RETURN_DURATION_SEC), 0.0, 1.0)
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null:
		queue_free()
		return
	var caster_anchor := caster.global_position + FOLLOW_OFFSET
	for idx in range(_flies.size()):
		var fly := _flies[idx] as Dictionary
		var node := fly.get("node", null) as Node2D
		if node == null:
			continue
		var target_peer_id := int(fly.get("target_peer_id", 0))
		var target := players.get(target_peer_id, null) as NetPlayer
		var orbit_center := caster_anchor
		if target != null and target.get_health() > 0:
			orbit_center = target.global_position + Vector2(0.0, -18.0)
		var orbit_angle := float(fly.get("orbit_angle", 0.0)) + delta * float(fly.get("orbit_speed", 1.0))
		fly["orbit_angle"] = orbit_angle
		var orbit_radius := float(fly.get("orbit_radius", 18.0))
		var bob_amp := float(fly.get("bob_amp", 2.0))
		var bob_speed := float(fly.get("bob_speed", 8.0))
		var local_orbit := Vector2.RIGHT.rotated(orbit_angle) * orbit_radius
		local_orbit.y += sin(orbit_angle * bob_speed) * bob_amp
		var orbit_pos := orbit_center + local_orbit
		var final_pos := orbit_pos
		if returning:
			final_pos = orbit_pos.lerp(caster_anchor, return_t)
		elif outbound_t < 1.0:
			var start_spread := Vector2.RIGHT.rotated(orbit_angle * 1.7) * minf(8.0, orbit_radius * 0.25)
			final_pos = (caster_anchor + start_spread).lerp(orbit_pos, outbound_t)
		node.global_position = final_pos
		node.rotation = orbit_angle + sin(orbit_angle * 0.9) * 0.25
		fly["last_pos"] = final_pos
		_flies[idx] = fly
	if returning and return_t >= 1.0:
		queue_free()

func _spawn_flies() -> void:
	var resolved_targets: Array[int] = []
	for peer_value in target_peer_ids:
		var peer_id := int(peer_value)
		if peer_id <= 0:
			continue
		resolved_targets.append(peer_id)
	if resolved_targets.is_empty():
		resolved_targets.append(caster_peer_id)
	for target_peer_id in resolved_targets:
		for _i in range(maxi(1, flies_per_target)):
			var fly_node := Node2D.new()
			var sprite := Sprite2D.new()
			sprite.centered = true
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sprite.texture = fly_texture
			sprite.modulate = fly_color
			sprite.scale = Vector2.ONE * _fly_rng.randf_range(0.58, 0.86)
			fly_node.add_child(sprite)
			add_child(fly_node)
			var orbit_angle := _fly_rng.randf_range(-PI, PI)
			var orbit_speed := _fly_rng.randf_range(2.6, 5.9) * (-1.0 if _fly_rng.randf() < 0.5 else 1.0)
			var fly := {
				"node": fly_node,
				"target_peer_id": target_peer_id,
				"orbit_angle": orbit_angle,
				"orbit_speed": orbit_speed,
				"orbit_radius": _fly_rng.randf_range(14.0, 36.0),
				"bob_amp": _fly_rng.randf_range(1.2, 4.2),
				"bob_speed": _fly_rng.randf_range(5.5, 10.5),
				"last_pos": Vector2.ZERO,
			}
			_flies.append(fly)
