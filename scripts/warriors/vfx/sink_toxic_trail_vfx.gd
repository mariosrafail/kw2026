extends Node2D

class_name SinkToxicTrailVfx

const PARTICLE_COUNT := 26
const MIN_PARTICLE_SPEED := 16.0
const MAX_PARTICLE_SPEED := 48.0
const MIN_PARTICLE_RADIUS := 8.0
const MAX_PARTICLE_RADIUS := 20.0
const BASE_DRIFT_X := 16.0
const EDGE_RING_COLOR := Color(0.88, 1.0, 0.82, 0.42)

var duration_sec := 1.65
var base_radius_px := 44.0
var toxic_color := Color(0.41, 1.0, 0.38, 1.0)

var _rng := RandomNumberGenerator.new()
var _elapsed_sec := 0.0
var _particles: Array = []

func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = 30
	_rng.seed = int(Time.get_ticks_usec()) ^ int(global_position.x * 19.0) ^ int(global_position.y * 31.0)
	_spawn_particles()

func _process(delta: float) -> void:
	_elapsed_sec += maxf(0.0, delta)
	if _elapsed_sec >= maxf(0.05, duration_sec):
		queue_free()
		return
	for index in range(_particles.size()):
		var particle := _particles[index] as Dictionary
		particle["position"] = (particle.get("position", Vector2.ZERO) as Vector2) + (particle.get("velocity", Vector2.ZERO) as Vector2) * delta
		particle["rotation"] = float(particle.get("rotation", 0.0)) + float(particle.get("rotation_speed", 0.0)) * delta
		var noise := sin(_elapsed_sec * float(particle.get("wobble_speed", 1.0)) + float(particle.get("phase", 0.0)))
		var drift := Vector2(noise * float(particle.get("drift_strength", 0.0)) * delta, 0.0)
		particle["position"] = (particle.get("position", Vector2.ZERO) as Vector2) + drift
		_particles[index] = particle
	queue_redraw()

func _draw() -> void:
	var life_ratio := clampf(1.0 - (_elapsed_sec / maxf(0.05, duration_sec)), 0.0, 1.0)
	var cloud_scale := 0.84 + (1.0 - life_ratio) * 0.42
	var soft_ring := toxic_color.lerp(Color.WHITE, 0.22)
	draw_circle(Vector2.ZERO, base_radius_px * cloud_scale, Color(toxic_color.r, toxic_color.g, toxic_color.b, 0.11 * life_ratio))
	draw_arc(Vector2.ZERO, base_radius_px * (0.62 + (1.0 - life_ratio) * 0.22), 0.0, TAU, 48, Color(soft_ring.r, soft_ring.g, soft_ring.b, 0.10 * life_ratio), 3.0)
	for particle_value in _particles:
		var particle := particle_value as Dictionary
		var birth_delay := float(particle.get("birth_delay", 0.0))
		if _elapsed_sec < birth_delay:
			continue
		var local_elapsed := _elapsed_sec - birth_delay
		var particle_life := maxf(0.1, float(particle.get("life_sec", 0.6)))
		var t := clampf(local_elapsed / particle_life, 0.0, 1.0)
		if t >= 1.0:
			continue
		var position := particle.get("position", Vector2.ZERO) as Vector2
		var radius := lerpf(float(particle.get("start_radius", MIN_PARTICLE_RADIUS)), float(particle.get("end_radius", MAX_PARTICLE_RADIUS)), t)
		var alpha := (1.0 - t) * life_ratio
		var body_color := toxic_color.lerp(Color(0.86, 1.0, 0.78, 1.0), 0.35 + t * 0.2)
		draw_circle(position, radius, Color(body_color.r, body_color.g, body_color.b, 0.16 * alpha))
		draw_circle(position + Vector2(0.0, -radius * 0.16), radius * 0.56, Color(0.9, 1.0, 0.84, 0.11 * alpha))
		draw_arc(position, radius * 0.82, 0.0, TAU, 20, Color(EDGE_RING_COLOR.r, EDGE_RING_COLOR.g, EDGE_RING_COLOR.b, 0.12 * alpha), 2.0)

func _spawn_particles() -> void:
	_particles.clear()
	for index in range(PARTICLE_COUNT):
		var angle := _rng.randf_range(-PI, PI)
		var ring_radius := _rng.randf_range(0.0, base_radius_px * 0.4)
		var base_position := Vector2(cos(angle), sin(angle) * 0.35) * ring_radius
		base_position.y += _rng.randf_range(-4.0, 6.0)
		var rise_speed := _rng.randf_range(MIN_PARTICLE_SPEED, MAX_PARTICLE_SPEED)
		var velocity := Vector2(
			_rng.randf_range(-BASE_DRIFT_X, BASE_DRIFT_X),
			-rise_speed
		)
		_particles.append({
			"position": base_position,
			"velocity": velocity,
			"start_radius": _rng.randf_range(MIN_PARTICLE_RADIUS, MAX_PARTICLE_RADIUS),
			"end_radius": _rng.randf_range(MAX_PARTICLE_RADIUS * 0.72, MAX_PARTICLE_RADIUS * 1.55),
			"life_sec": _rng.randf_range(duration_sec * 0.38, duration_sec * 0.92),
			"birth_delay": _rng.randf_range(0.0, duration_sec * 0.22),
			"phase": _rng.randf_range(-PI, PI),
			"wobble_speed": _rng.randf_range(1.8, 4.2),
			"drift_strength": _rng.randf_range(10.0, 24.0),
			"rotation": _rng.randf_range(-PI, PI),
			"rotation_speed": _rng.randf_range(-1.2, 1.2),
		})
