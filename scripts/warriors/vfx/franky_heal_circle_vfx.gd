extends Node2D
class_name FrankyHealCircleVfx

const RING_SEGMENTS := 56
const RING_BASE_WIDTH := 5.0
const INNER_RING_SCALE := 0.72

var center_world := Vector2.ZERO
var duration_sec := 5.0
var radius_px := 165.0
var effect_color := Color(0.32, 0.92, 0.55, 1.0)

var _remaining := 0.0
var _outer_ring: Line2D
var _inner_ring: Line2D
var _pulse_particles: CPUParticles2D

func _ready() -> void:
	global_position = center_world
	_remaining = maxf(0.05, duration_sec)
	_build_visual()
	_update_ring_points()

func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		queue_free()
		return
	var phase := Time.get_ticks_msec() / 1000.0
	var pulse := 0.92 + 0.08 * sin(phase * 7.0)
	_outer_ring.width = RING_BASE_WIDTH * pulse
	_inner_ring.width = RING_BASE_WIDTH * 0.62 * pulse
	_pulse_particles.amount = int(round(18.0 + 6.0 * pulse))

func _build_visual() -> void:
	var core_color := Color(
		clampf(effect_color.r + 0.18, 0.0, 1.0),
		clampf(effect_color.g + 0.18, 0.0, 1.0),
		clampf(effect_color.b + 0.18, 0.0, 1.0),
		0.82
	)

	_outer_ring = Line2D.new()
	_outer_ring.default_color = Color(effect_color.r, effect_color.g, effect_color.b, 0.72)
	_outer_ring.width = RING_BASE_WIDTH
	_outer_ring.texture_mode = Line2D.LINE_TEXTURE_NONE
	_outer_ring.joint_mode = Line2D.LINE_JOINT_ROUND
	_outer_ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_outer_ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	_outer_ring.antialiased = true
	_outer_ring.closed = true
	_outer_ring.z_index = 58
	add_child(_outer_ring)

	_inner_ring = Line2D.new()
	_inner_ring.default_color = core_color
	_inner_ring.width = RING_BASE_WIDTH * 0.62
	_inner_ring.texture_mode = Line2D.LINE_TEXTURE_NONE
	_inner_ring.joint_mode = Line2D.LINE_JOINT_ROUND
	_inner_ring.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_inner_ring.end_cap_mode = Line2D.LINE_CAP_ROUND
	_inner_ring.antialiased = true
	_inner_ring.closed = true
	_inner_ring.z_index = 59
	add_child(_inner_ring)

	_pulse_particles = CPUParticles2D.new()
	_pulse_particles.z_index = 57
	_pulse_particles.position = Vector2.ZERO
	_pulse_particles.amount = 20
	_pulse_particles.lifetime = 0.46
	_pulse_particles.one_shot = false
	_pulse_particles.explosiveness = 0.0
	_pulse_particles.local_coords = true
	_pulse_particles.direction = Vector2.UP
	_pulse_particles.spread = 180.0
	_pulse_particles.gravity = Vector2.ZERO
	_pulse_particles.initial_velocity_min = 18.0
	_pulse_particles.initial_velocity_max = 56.0
	_pulse_particles.angular_velocity_min = -110.0
	_pulse_particles.angular_velocity_max = 110.0
	_pulse_particles.scale_amount_min = 0.55
	_pulse_particles.scale_amount_max = 1.15
	_pulse_particles.color = Color(effect_color.r, effect_color.g, effect_color.b, 0.44)
	_pulse_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_pulse_particles.emission_sphere_radius = maxf(14.0, radius_px * 0.88)
	_pulse_particles.emitting = true
	add_child(_pulse_particles)

func _update_ring_points() -> void:
	var outer_points := PackedVector2Array()
	var inner_points := PackedVector2Array()
	for i in range(RING_SEGMENTS):
		var t := float(i) / float(RING_SEGMENTS)
		var angle := t * TAU
		var dir := Vector2.RIGHT.rotated(angle)
		outer_points.append(dir * radius_px)
		inner_points.append(dir * radius_px * INNER_RING_SCALE)
	_outer_ring.points = outer_points
	_inner_ring.points = inner_points
