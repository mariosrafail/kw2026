extends Node2D
class_name KrogLaserVfx

const LASER_BASE_WIDTH := 9.0
const LASER_PULSE_SPEED := 11.0
const LASER_RANGE_PX := 3400.0
const LASER_HIT_WIDTH_PX := 13.5
const IMPACT_PARTICLE_AMOUNT := 20
const IMPACT_PARTICLE_LIFETIME := 0.2

var players: Dictionary = {}
var caster_peer_id := 0
var duration_sec := 5.0
var beam_color := Color(0.92, 0.28, 0.22, 0.95)

var _remaining := 0.0
var _line: Line2D
var _glow: Line2D
var _impact_particles: CPUParticles2D
var _impact_core_particles: CPUParticles2D

func _ready() -> void:
	_remaining = maxf(0.05, duration_sec)
	_build_visual()

func _process(delta: float) -> void:
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		queue_free()
		return
	_update_beam()

func _build_visual() -> void:
	_line = Line2D.new()
	_line.default_color = beam_color
	_line.width = LASER_BASE_WIDTH
	_line.texture_mode = Line2D.LINE_TEXTURE_NONE
	_line.joint_mode = Line2D.LINE_JOINT_ROUND
	_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	_line.antialiased = true
	_line.z_index = 160
	add_child(_line)

	_glow = Line2D.new()
	_glow.default_color = Color(beam_color.r, beam_color.g, beam_color.b, beam_color.a * 0.28)
	_glow.width = LASER_BASE_WIDTH * 2.1
	_glow.texture_mode = Line2D.LINE_TEXTURE_NONE
	_glow.joint_mode = Line2D.LINE_JOINT_ROUND
	_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	_glow.antialiased = true
	_glow.z_index = 159
	add_child(_glow)

	_impact_particles = CPUParticles2D.new()
	_impact_particles.z_index = 161
	_impact_particles.amount = IMPACT_PARTICLE_AMOUNT
	_impact_particles.lifetime = IMPACT_PARTICLE_LIFETIME
	_impact_particles.one_shot = false
	_impact_particles.explosiveness = 0.85
	_impact_particles.local_coords = true
	_impact_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_impact_particles.emission_sphere_radius = 2.0
	_impact_particles.direction = Vector2.LEFT
	_impact_particles.spread = 44.0
	_impact_particles.gravity = Vector2.ZERO
	_impact_particles.initial_velocity_min = 42.0
	_impact_particles.initial_velocity_max = 120.0
	_impact_particles.angular_velocity_min = -260.0
	_impact_particles.angular_velocity_max = 260.0
	_impact_particles.scale_amount_min = 0.38
	_impact_particles.scale_amount_max = 0.82
	_impact_particles.color = Color(beam_color.r, beam_color.g, beam_color.b, 0.86)
	_impact_particles.emitting = false
	add_child(_impact_particles)

	_impact_core_particles = CPUParticles2D.new()
	_impact_core_particles.z_index = 162
	_impact_core_particles.amount = 10
	_impact_core_particles.lifetime = 0.12
	_impact_core_particles.one_shot = false
	_impact_core_particles.explosiveness = 0.92
	_impact_core_particles.local_coords = true
	_impact_core_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_impact_core_particles.emission_sphere_radius = 1.0
	_impact_core_particles.direction = Vector2.LEFT
	_impact_core_particles.spread = 26.0
	_impact_core_particles.gravity = Vector2.ZERO
	_impact_core_particles.initial_velocity_min = 24.0
	_impact_core_particles.initial_velocity_max = 70.0
	_impact_core_particles.scale_amount_min = 0.26
	_impact_core_particles.scale_amount_max = 0.55
	_impact_core_particles.color = Color(1.0, 1.0, 1.0, 0.78)
	_impact_core_particles.emitting = false
	add_child(_impact_core_particles)

func _update_beam() -> void:
	var caster := players.get(caster_peer_id, null) as NetPlayer
	if caster == null or caster.get_health() <= 0:
		_line.clear_points()
		_glow.clear_points()
		return
	var start_pos := _beam_start_for_player(caster)
	var aim_dir := _aim_direction_for_player(caster, start_pos)
	if aim_dir.length_squared() <= 0.0001:
		aim_dir = Vector2.RIGHT
	var trace := _trace_world_endpoint(caster, start_pos, aim_dir)
	var end_pos := trace.get("end_pos", start_pos + aim_dir * LASER_RANGE_PX) as Vector2
	var has_contact := bool(trace.get("has_contact", false))

	var pulse := 0.92 + 0.08 * sin(Time.get_ticks_msec() / 1000.0 * LASER_PULSE_SPEED)
	_line.width = LASER_BASE_WIDTH * pulse
	_glow.width = LASER_BASE_WIDTH * 2.1 * pulse

	var local_start := to_local(start_pos)
	var local_end := to_local(end_pos)
	_line.points = PackedVector2Array([local_start, local_end])
	_glow.points = PackedVector2Array([local_start, local_end])
	_update_impact_particles(local_end, -aim_dir, has_contact)

func _beam_start_for_player(player: NetPlayer) -> Vector2:
	if player == null:
		return Vector2.ZERO
	var head_node := player.get_node_or_null("VisualRoot/head") as Node2D
	if head_node != null:
		return head_node.global_position
	return player.global_position + Vector2(0.0, -14.0)

func _aim_direction_for_player(player: NetPlayer, start_pos: Vector2) -> Vector2:
	if player == null:
		return Vector2.RIGHT
	if player.has_method("get_aim_angle"):
		var angle := float(player.call("get_aim_angle"))
		return Vector2.RIGHT.rotated(angle).normalized()
	var fallback := Vector2.RIGHT
	if player.has_method("get_muzzle_world_position"):
		var muzzle := player.call("get_muzzle_world_position") as Vector2
		var muzzle_dir := muzzle - start_pos
		if muzzle_dir.length_squared() > 0.0001:
			fallback = muzzle_dir.normalized()
	return fallback

func _trace_world_endpoint(caster: NetPlayer, start_pos: Vector2, aim_dir: Vector2) -> Dictionary:
	if caster == null:
		return {"end_pos": start_pos + aim_dir * LASER_RANGE_PX, "has_contact": false}
	var world := caster.get_world_2d()
	if world == null:
		return {"end_pos": start_pos + aim_dir * LASER_RANGE_PX, "has_contact": false}
	var wall_end := start_pos + aim_dir * LASER_RANGE_PX
	var wall_hit := false
	var query := PhysicsRayQueryParameters2D.create(start_pos, wall_end, 1)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = _ray_exclusions(caster)
	var hit := world.direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		wall_end = hit.get("position", wall_end) as Vector2
		wall_hit = true

	var wall_dist := start_pos.distance_to(wall_end)
	var best_hit_dist := wall_dist + 1.0
	for player_value in players.values():
		var target := player_value as NetPlayer
		if target == null or target == caster or target.get_health() <= 0:
			continue
		var target_center := target.global_position
		var along := (target_center - start_pos).dot(aim_dir)
		if along < 0.0 or along > wall_dist:
			continue
		var closest := start_pos + aim_dir * along
		var target_radius := target.get_hit_radius() if target.has_method("get_hit_radius") else 12.0
		var combined_radius := target_radius + LASER_HIT_WIDTH_PX
		var lateral := target_center.distance_to(closest)
		if lateral > combined_radius:
			continue
		var inside := maxf(0.0, combined_radius * combined_radius - lateral * lateral)
		var contact_dist := maxf(0.0, along - sqrt(inside))
		if contact_dist < best_hit_dist:
			best_hit_dist = contact_dist
	if best_hit_dist <= wall_dist:
		return {"end_pos": start_pos + aim_dir * best_hit_dist, "has_contact": true}
	return {"end_pos": wall_end, "has_contact": wall_hit}

func _update_impact_particles(local_end: Vector2, reverse_dir: Vector2, has_contact: bool) -> void:
	if _impact_particles == null or _impact_core_particles == null:
		return
	_impact_particles.position = local_end
	_impact_core_particles.position = local_end
	var reverse := reverse_dir
	if reverse.length_squared() <= 0.0001:
		reverse = Vector2.LEFT
	else:
		reverse = reverse.normalized()
	_impact_particles.direction = reverse
	_impact_core_particles.direction = reverse
	_impact_particles.color = Color(beam_color.r, beam_color.g, beam_color.b, 0.86)
	_impact_core_particles.color = Color(beam_color.r * 0.95 + 0.05, beam_color.g * 0.95 + 0.05, beam_color.b * 0.95 + 0.05, 0.92)
	_impact_particles.emitting = has_contact
	_impact_core_particles.emitting = has_contact

func _ray_exclusions(caster: NetPlayer) -> Array:
	var exclusions: Array = [caster]
	for player_value in players.values():
		var player := player_value as NetPlayer
		if player == null or player == caster:
			continue
		exclusions.append(player)
	return exclusions
