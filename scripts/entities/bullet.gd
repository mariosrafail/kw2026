extends Node2D
class_name NetProjectile

const IMPACT_LINGER_TIME := 0.08
const TRAIL_MAX_POINTS := 11
const TRAIL_SAMPLE_INTERVAL := 0.02

@onready var visual: Sprite2D = $Visual
@onready var trail: Line2D = $Trail

var projectile_id := 0
var owner_peer_id := 0
var lag_comp_ms := 0
var trail_origin: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var life_time := 2.0
var hit_radius := 8.0
var life_remaining := 2.0
var impact_time_remaining := 0.0
var has_impacted := false
var trail_world_points: Array[Vector2] = []
var trail_sample_accumulator := 0.0
var force_impact_segment_visual := false

func configure(
	color: Color,
	start_velocity: Vector2,
	new_projectile_id: int,
	new_owner_peer_id: int,
	new_lag_comp_ms: int,
	new_trail_origin: Vector2,
	visual_config: Dictionary = {},
	new_hit_radius: float = 8.0,
	new_life_time: float = 2.0
) -> void:
	projectile_id = new_projectile_id
	owner_peer_id = new_owner_peer_id
	lag_comp_ms = max(0, new_lag_comp_ms)
	trail_origin = new_trail_origin
	velocity = start_velocity
	life_time = maxf(0.15, new_life_time)
	hit_radius = maxf(1.0, new_hit_radius)
	life_remaining = life_time
	impact_time_remaining = 0.0
	has_impacted = false
	trail_sample_accumulator = 0.0
	force_impact_segment_visual = false
	rotation = velocity.angle()

	var head_scale := maxf(0.2, float(visual_config.get("head_scale", 0.85)))
	var trail_width := maxf(0.5, float(visual_config.get("trail_width", 3.6)))
	var trail_alpha := clampf(float(visual_config.get("trail_alpha", 0.52)), 0.0, 1.0)
	var effective_trail_alpha := trail_alpha * 0.35

	if visual != null:
		visual.visible = false
		visual.scale = Vector2.ONE * head_scale
		visual.modulate = Color(color.r, color.g, color.b, 0.0)
	if trail != null:
		trail.default_color = Color(color.r, color.g, color.b, effective_trail_alpha)
		trail.width = trail_width
		trail.antialiased = true
		trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		trail.joint_mode = Line2D.LINE_JOINT_ROUND
		var light_r := lerpf(color.r, 1.0, 0.55)
		var light_g := lerpf(color.g, 1.0, 0.55)
		var light_b := lerpf(color.b, 1.0, 0.55)
		var fade_gradient := Gradient.new()
		# 0.0 is near the weapon (lighter); 1.0 is toward impact (darker).
		fade_gradient.add_point(0.0, Color(light_r, light_g, light_b, effective_trail_alpha * 0.10))
		fade_gradient.add_point(0.48, Color(light_r, light_g, light_b, effective_trail_alpha * 0.06))
		fade_gradient.add_point(0.82, Color(color.r * 0.72, color.g * 0.72, color.b * 0.72, effective_trail_alpha * 0.30))
		fade_gradient.add_point(1.0, Color(color.r * 0.45, color.g * 0.45, color.b * 0.45, effective_trail_alpha * 0.75))
		trail.gradient = fade_gradient
		var taper := Curve.new()
		taper.add_point(Vector2(0.0, 0.04))
		taper.add_point(Vector2(0.65, 0.42))
		taper.add_point(Vector2(1.0, 0.74))
		trail.width_curve = taper
		trail_world_points.clear()
		trail_world_points.append(global_position)
		_rebuild_trail()

func step(delta: float) -> void:
	if has_impacted:
		impact_time_remaining -= delta
		return

	global_position += velocity * delta
	life_remaining -= delta
	_update_trail(delta)

func is_expired() -> bool:
	if has_impacted:
		return impact_time_remaining <= 0.0
	return life_remaining <= 0.0

func get_hit_radius() -> float:
	return hit_radius

func can_deal_damage() -> bool:
	return not has_impacted and life_remaining > 0.0

func get_trail_origin() -> Vector2:
	return trail_origin

func mark_impact(impact_position: Vector2, trail_start_position: Vector2 = Vector2.INF) -> void:
	if has_impacted:
		return
	has_impacted = true
	impact_time_remaining = IMPACT_LINGER_TIME
	velocity = Vector2.ZERO
	global_position = impact_position
	if trail_start_position.is_finite():
		force_impact_segment_visual = true
		trail_world_points.clear()
		trail_world_points.append(trail_start_position)
		trail_world_points.append(impact_position)
	elif trail_world_points.is_empty():
		force_impact_segment_visual = false
		trail_world_points.append(impact_position)
	else:
		force_impact_segment_visual = false
		# Force the trail head to the true impact point so it never visually overshoots.
		trail_world_points[trail_world_points.size() - 1] = impact_position
	_rebuild_trail()

func _update_trail(delta: float, force_sample: bool = false) -> void:
	if trail == null:
		return

	if trail_world_points.is_empty():
		trail_world_points.append(global_position)
		_rebuild_trail()
		return

	if not force_sample:
		trail_sample_accumulator += delta
		if trail_sample_accumulator < TRAIL_SAMPLE_INTERVAL:
			return

	trail_sample_accumulator = 0.0
	trail_world_points.append(global_position)
	while trail_world_points.size() > TRAIL_MAX_POINTS:
		trail_world_points.remove_at(0)
	_rebuild_trail()

func _rebuild_trail() -> void:
	if trail == null:
		return

	if trail_world_points.is_empty():
		trail.points = PackedVector2Array()
		return

	if has_impacted and force_impact_segment_visual and trail_world_points.size() >= 2:
		var impact_points := PackedVector2Array()
		for world_point in trail_world_points:
			impact_points.append(to_local(world_point))
		trail.points = impact_points
		return

	var visible_world_points: Array[Vector2] = []
	var newest: Vector2 = trail_world_points[trail_world_points.size() - 1]
	visible_world_points.append(newest)

	for i in range(trail_world_points.size() - 2, -1, -1):
		var from_point: Vector2 = visible_world_points[visible_world_points.size() - 1]
		var to_point: Vector2 = trail_world_points[i]
		var segment: Vector2 = to_point - from_point
		if segment.length_squared() <= 0.0001:
			continue

		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from_point, to_point, 3)
		query.collide_with_bodies = true
		query.collide_with_areas = false
		var hit: Dictionary = get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			var clipped_end: Vector2 = hit.get("position", to_point) as Vector2
			visible_world_points.append(clipped_end)
			break

		visible_world_points.append(to_point)

	var points := PackedVector2Array()
	for i in range(visible_world_points.size() - 1, -1, -1):
		points.append(to_local(visible_world_points[i]))
	trail.points = points
