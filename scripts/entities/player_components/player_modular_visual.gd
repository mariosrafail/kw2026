extends RefCounted

class_name PlayerModularVisual

const CHARACTER_ID_OUTRAGE := "outrage"
const CHARACTER_ID_EREBUS := "erebus"
const CHARACTER_ID_TASKO := "tasko"

const LEGS_FRAME_SIZE := Vector2i(64, 64)
const TORSO_FRAME_SIZE := Vector2i(64, 64)
const HEAD_FRAME_SIZE := Vector2i(64, 64)

const OUTRAGE_WARRIOR_COLUMN := 1
const EREBUS_WARRIOR_COLUMN := 2
const TASKO_WARRIOR_COLUMN := 3
const WARRIOR_FRAME_OFFSET_X := 64

const PART_TEXTURE_PATHS := {
	CHARACTER_ID_OUTRAGE: {
		"head": "res://assets/warriors/outrage/head.png",
		"torso": "res://assets/warriors/outrage/torso.png",
		"legs": "res://assets/warriors/outrage/legs.png",
	},
	CHARACTER_ID_EREBUS: {
		"head": "res://assets/warriors/erebus/head.png",
		"torso": "res://assets/warriors/erebus/torso.png",
		"legs": "res://assets/warriors/erebus/legs.png",
	},
	CHARACTER_ID_TASKO: {
		"head": "res://assets/warriors/tasko/head.png",
		"torso": "res://assets/warriors/tasko/torso.png",
		"legs": "res://assets/warriors/tasko/legs.png",
	},
}

var _player: CharacterBody2D
var _player_sprite: Node2D
var _legs_sprite: Sprite2D
var _legs_sprite_2: Sprite2D
var _torso_sprite: Sprite2D
var _head_sprite: Sprite2D

var character_id := CHARACTER_ID_OUTRAGE
var selected_head_index := 1
var selected_torso_index := 1
var selected_legs_index := 1
var warrior_column_index := OUTRAGE_WARRIOR_COLUMN
var _part_texture_cache: Dictionary = {}
var _base_positions: Dictionary = {}
var _walk_phase := 0.0
var _goofy_seed := 0.0
var _facing_sign := 1.0
var _anim_time := 0.0
var _air_blend := 0.0
var _move_blend := 0.0
var _landing_impulse := 0.0
var _stop_impulse := 0.0
var _was_on_floor := true
var _previous_horizontal_speed := 0.0
var _pose_blend_speed := 16.0
var _pose_blend_weight := 1.0
var _walk_cycle_sign := 1.0
var _head_aim_angle := 0.0

func configure(player: CharacterBody2D, player_sprite: Node2D, legs_sprite: Sprite2D, legs_sprite_2: Sprite2D = null, torso_sprite: Sprite2D = null, head_sprite: Sprite2D = null) -> void:
	_player = player
	_player_sprite = player_sprite
	_legs_sprite = legs_sprite
	_legs_sprite_2 = legs_sprite_2
	_torso_sprite = torso_sprite
	_head_sprite = head_sprite
	if _legs_sprite != null:
		_base_positions["leg1"] = _legs_sprite.position
	if _legs_sprite_2 != null:
		_base_positions["leg2"] = _legs_sprite_2.position
	if _torso_sprite != null:
		_base_positions["torso"] = _torso_sprite.position
	if _head_sprite != null:
		_base_positions["head"] = _head_sprite.position
	if _player != null:
		var seed_source := float(int(_player.get_instance_id()) % 997)
		_goofy_seed = seed_source / 997.0

func apply_player_facing_from_angle(angle: float) -> void:
	_head_aim_angle = angle
	var looking_left := cos(angle) < 0.0
	_facing_sign = -1.0 if looking_left else 1.0
	_apply_facing_to_sprite(_head_sprite, "head", looking_left)
	_apply_facing_to_sprite(_torso_sprite, "torso", looking_left)
	_apply_facing_to_sprite(_legs_sprite, "leg1", looking_left)
	_apply_facing_to_sprite(_legs_sprite_2, "leg2", looking_left)

func _apply_facing_to_sprite(sprite: Sprite2D, key: String, looking_left: bool) -> void:
	if sprite == null:
		return
	var base_position := _base_positions.get(key, sprite.position) as Vector2
	sprite.position.x = -base_position.x if looking_left else base_position.x
	sprite.position.y = base_position.y
	var current_scale := sprite.scale
	current_scale.x = -absf(current_scale.x) if looking_left else absf(current_scale.x)
	sprite.scale = current_scale

func update_walk_animation(delta: float, velocity: Vector2, on_floor: bool) -> void:
	_anim_time += delta
	var horizontal_speed := absf(velocity.x)
	var movement_sign := signf(velocity.x)
	var speed_ratio := clampf(horizontal_speed / 245.0, 0.0, 1.8)
	var grounded := on_floor and horizontal_speed > 8.0
	var idle_grounded := on_floor and not grounded
	_pose_blend_speed = 42.0 if grounded else 28.0 if on_floor else 20.0
	_pose_blend_weight = 0.55 if grounded else 0.4 if on_floor else clampf(delta * _pose_blend_speed, 0.0, 0.32)
	if absf(movement_sign) > 0.0:
		_walk_cycle_sign = 1.0 if movement_sign == _facing_sign else -1.0
	var phase_speed := lerpf(5.0, 17.5, clampf(speed_ratio, 0.0, 1.0))
	if on_floor and not _was_on_floor:
		_landing_impulse = min(1.0, 0.45 + clampf(absf(velocity.y) / 900.0, 0.0, 0.55))
	if on_floor and _previous_horizontal_speed > 55.0 and horizontal_speed < 8.0:
		_stop_impulse = min(1.0, 0.35 + clampf(_previous_horizontal_speed / 245.0, 0.0, 0.45))
	_was_on_floor = on_floor
	_previous_horizontal_speed = horizontal_speed
	_air_blend = move_toward(_air_blend, 1.0 if not on_floor else 0.0, delta * (10.0 if not on_floor else 14.0))
	_move_blend = move_toward(_move_blend, 1.0 if grounded else 0.0, delta * (9.0 if grounded else 7.0))
	_landing_impulse = move_toward(_landing_impulse, 0.0, delta * 4.4)
	_stop_impulse = move_toward(_stop_impulse, 0.0, delta * 5.2)
	if grounded:
		_walk_phase = wrapf(_walk_phase + delta * phase_speed, 0.0, TAU)
	else:
		_walk_phase = wrapf(lerpf(_walk_phase, 0.0, min(1.0, delta * 7.0)), 0.0, TAU)

	if _air_blend > 0.001:
		_apply_air_pose(velocity, _air_blend)
		if _air_blend >= 0.98:
			return
	elif idle_grounded:
		_apply_idle_pose()
		if _landing_impulse <= 0.001 and _stop_impulse <= 0.001:
			return

	if not grounded and not idle_grounded and _air_blend <= 0.001:
		_apply_idle_pose()
		return

	var lead_phase := _walk_phase
	var trail_phase := _walk_phase + PI
	if _walk_cycle_sign < 0.0:
		lead_phase = _walk_phase + PI
		trail_phase = _walk_phase
	var stride := sin(lead_phase)
	var counter_stride := sin(trail_phase)
	var lift_a := maxf(0.0, stride)
	var lift_b := maxf(0.0, counter_stride)
	var stomp := -absf(cos(_walk_phase * 2.0)) if grounded else 0.0
	var goofy_wobble := sin(_walk_phase * 0.5 + _goofy_seed * TAU) * 0.8
	var torso_sway := sin(_walk_phase + 0.7 + _goofy_seed * 1.7)
	var head_wobble := sin(_walk_phase * 1.5 + 1.2 + _goofy_seed * 2.3)
	var bounce := (lift_a + lift_b) * 0.5

	var move_weight := _move_blend
	var leg_x_amp := lerpf(0.0, 8.8, clampf(speed_ratio, 0.0, 1.0)) * move_weight
	var leg_y_amp := lerpf(0.0, 9.2, clampf(speed_ratio, 0.0, 1.0)) * move_weight
	var body_bob_amp := lerpf(0.0, 4.0, clampf(speed_ratio, 0.0, 1.0)) * move_weight
	var head_bob_amp := lerpf(0.0, 5.0, clampf(speed_ratio, 0.0, 1.0)) * move_weight
	var landing_offset := _landing_impulse * 5.0
	var stop_sway := _stop_impulse * 3.0

	_apply_walk_to_leg(_legs_sprite, "leg1", lead_phase, stomp, leg_x_amp, leg_y_amp, landing_offset, stop_sway)
	_apply_walk_to_leg(_legs_sprite_2, "leg2", trail_phase, stomp, leg_x_amp, leg_y_amp, landing_offset, stop_sway)
	_apply_walk_to_torso(bounce, torso_sway, goofy_wobble, body_bob_amp, grounded, landing_offset, stop_sway)
	_apply_walk_to_head(bounce, head_wobble, goofy_wobble, head_bob_amp, grounded, landing_offset, stop_sway)

func _apply_air_pose(velocity: Vector2, blend: float) -> void:
	var horizontal_ratio := clampf(absf(velocity.x) / 245.0, 0.0, 1.0)
	var vertical_ratio := clampf(absf(velocity.y) / 700.0, 0.0, 1.0)
	var rising := velocity.y < 0.0
	var travel_tilt := clampf(velocity.x / 245.0, -1.0, 1.0)
	var flutter := sin(_anim_time * 11.0 + _goofy_seed * TAU) * 0.45
	var torso_lift := lerpf(5.5, 10.5, vertical_ratio) * blend
	var head_lift := lerpf(7.5, 13.5, vertical_ratio) * blend
	var leg_tuck := lerpf(6.5, 13.5, vertical_ratio) * blend
	var forward_splay := lerpf(4.5, 10.0, horizontal_ratio) * blend
	var back_splay := lerpf(2.5, 6.0, horizontal_ratio) * blend

	_apply_air_leg(_legs_sprite, "leg1", 1.0, torso_lift, leg_tuck, forward_splay, back_splay, rising, flutter)
	_apply_air_leg(_legs_sprite_2, "leg2", -1.0, torso_lift, leg_tuck, forward_splay, back_splay, rising, flutter)
	_apply_air_torso(torso_lift, travel_tilt, vertical_ratio, rising, flutter, blend)
	_apply_air_head(head_lift, travel_tilt, vertical_ratio, rising, flutter, blend)

func _apply_idle_pose() -> void:
	var breath := sin(_anim_time * 2.3 + _goofy_seed * 3.4)
	var sway := sin(_anim_time * 1.6 + _goofy_seed * 5.1)
	var head_nod := sin(_anim_time * 2.0 + 0.6 + _goofy_seed * 6.4)
	if _legs_sprite != null:
		var leg1_base := _base_positions.get("leg1", _legs_sprite.position) as Vector2
		_apply_pose(_legs_sprite, Vector2(
			leg1_base.x * _facing_sign - sway * 0.35 * _facing_sign - _stop_impulse * 1.2 * _facing_sign,
			leg1_base.y + _landing_impulse * 1.4
		), -0.02 - _stop_impulse * 0.05)
	if _legs_sprite_2 != null:
		var leg2_base := _base_positions.get("leg2", _legs_sprite_2.position) as Vector2
		_apply_pose(_legs_sprite_2, Vector2(
			leg2_base.x * _facing_sign + sway * 0.35 * _facing_sign + _stop_impulse * 1.2 * _facing_sign,
			leg2_base.y + _landing_impulse * 1.4
		), 0.02 + _stop_impulse * 0.05)
	if _torso_sprite != null:
		var torso_base := _base_positions.get("torso", _torso_sprite.position) as Vector2
		_apply_pose(_torso_sprite, Vector2(
			(torso_base.x * _facing_sign) + sway * 0.55 * _facing_sign,
			torso_base.y + breath * 0.7 + _landing_impulse * 2.2 + _stop_impulse * 0.9
		), sway * 0.02 - _stop_impulse * 0.025)
	if _head_sprite != null:
		var head_base := _base_positions.get("head", _head_sprite.position) as Vector2
		_apply_pose(_head_sprite, Vector2(
			(head_base.x * _facing_sign) + sway * 0.65 * _facing_sign + _head_aim_offset_x() * 0.55,
			head_base.y + breath * 1.2 + head_nod * 0.3 + _landing_impulse * 3.0 + _stop_impulse * 1.1
		), sway * 0.035 + head_nod * 0.025 - _stop_impulse * 0.04 + _head_aim_rotation(0.22))

func _apply_walk_to_leg(sprite: Sprite2D, key: String, phase: float, stomp: float, x_amp: float, y_amp: float, landing_offset: float, stop_sway: float) -> void:
	if sprite == null:
		return
	var base_position := _base_positions.get(key, sprite.position) as Vector2
	var cycle_x := -sin(phase)
	var cycle_y := -cos(phase)
	var lift := maxf(0.0, cycle_y)
	var drop := maxf(0.0, -cycle_y)
	_apply_pose(sprite, Vector2(
		(base_position.x * _facing_sign) + (cycle_x * x_amp * _facing_sign) - (stop_sway * 0.35 * signf(cycle_x) * _facing_sign),
		base_position.y - (lift * y_amp) + (drop * 1.9) + (stomp * 0.45) + landing_offset
	), cycle_x * 0.23 + cycle_y * 0.075 - stop_sway * 0.012 * signf(cycle_x))

func _apply_walk_to_torso(bounce: float, sway: float, goofy_wobble: float, bob_amp: float, grounded: bool, landing_offset: float, stop_sway: float) -> void:
	if _torso_sprite == null:
		return
	var base_position := _base_positions.get("torso", _torso_sprite.position) as Vector2
	var idle_breath := sin(_walk_phase * 0.45 + _goofy_seed * 3.1) * 0.35
	_apply_pose(_torso_sprite, Vector2(
		(base_position.x * _facing_sign) + sway * 1.4 * _facing_sign - stop_sway * 0.45 * _facing_sign,
		base_position.y - bounce * bob_amp + idle_breath + landing_offset * 0.55 + _stop_impulse * 0.8
	), sway * 0.06 + goofy_wobble * 0.015 - stop_sway * 0.016)
	if not grounded:
		_torso_sprite.rotation *= 0.35

func _apply_walk_to_head(bounce: float, wobble: float, goofy_wobble: float, bob_amp: float, grounded: bool, landing_offset: float, stop_sway: float) -> void:
	if _head_sprite == null:
		return
	var base_position := _base_positions.get("head", _head_sprite.position) as Vector2
	var idle_float := sin(_walk_phase * 0.55 + 0.8 + _goofy_seed * 4.7) * 0.6
	var random_rot := sin(_walk_phase * 2.1 + _goofy_seed * 7.1) * 0.055
	_apply_pose(_head_sprite, Vector2(
		(base_position.x * _facing_sign) + wobble * 1.2 * _facing_sign - stop_sway * 0.6 * _facing_sign + _head_aim_offset_x(),
		base_position.y - bounce * bob_amp + idle_float + landing_offset * 0.82 + _stop_impulse * 1.2
	), wobble * 0.11 + goofy_wobble * 0.04 + random_rot - stop_sway * 0.02 + _head_aim_rotation(0.26))
	if not grounded:
		_head_sprite.rotation *= 0.55

func _apply_air_leg(
	sprite: Sprite2D,
	key: String,
	side_sign: float,
	torso_lift: float,
	leg_tuck: float,
	forward_splay: float,
	back_splay: float,
	rising: bool,
	flutter: float
) -> void:
	if sprite == null:
		return
	var base_position := _base_positions.get(key, sprite.position) as Vector2
	var front_leg := side_sign > 0.0
	var x_shift := 0.0
	var y_shift := torso_lift - leg_tuck + absf(flutter) * 0.8
	if rising:
		x_shift = forward_splay if front_leg else -back_splay
		y_shift += 3.2 if front_leg else -2.0
	else:
		x_shift = back_splay * 0.7 if front_leg else -back_splay
		y_shift += 1.0 if front_leg else -1.0
	_apply_pose(sprite, Vector2(
		(base_position.x * _facing_sign) + (x_shift * _facing_sign),
		base_position.y - y_shift
	), ((0.52 if rising and front_leg else 0.2 if rising else -0.12 if front_leg else -0.28) * _facing_sign) + flutter * 0.06)

func _apply_air_torso(torso_lift: float, travel_tilt: float, vertical_ratio: float, rising: bool, flutter: float, blend: float) -> void:
	if _torso_sprite == null:
		return
	var base_position := _base_positions.get("torso", _torso_sprite.position) as Vector2
	_apply_pose(_torso_sprite, Vector2(
		(base_position.x * _facing_sign) + travel_tilt * 2.8 * blend,
		base_position.y - torso_lift - vertical_ratio * 2.4 * blend + flutter * 0.35 * blend
	), ((0.16 if rising else -0.08) * _facing_sign + travel_tilt * 0.075 + flutter * 0.02) * blend)

func _apply_air_head(head_lift: float, travel_tilt: float, vertical_ratio: float, rising: bool, flutter: float, blend: float) -> void:
	if _head_sprite == null:
		return
	var base_position := _base_positions.get("head", _head_sprite.position) as Vector2
	var float_wobble := sin(_anim_time * 14.5 + _goofy_seed * 11.0) * 0.8
	_apply_pose(_head_sprite, Vector2(
		(base_position.x * _facing_sign) + (travel_tilt * 2.1 + flutter * 0.55) * blend + _head_aim_offset_x() * 0.7,
		base_position.y - head_lift - vertical_ratio * 3.1 * blend + float_wobble * 0.35 * blend
	), ((0.24 if rising else -0.1) * _facing_sign + travel_tilt * 0.08 + flutter * 0.035 + float_wobble * 0.03) * blend + _head_aim_rotation(0.32))

func _apply_pose(sprite: Sprite2D, target_position: Vector2, target_rotation: float) -> void:
	if sprite == null:
		return
	sprite.position = sprite.position.lerp(target_position, _pose_blend_weight)
	sprite.rotation = lerp_angle(sprite.rotation, target_rotation, _pose_blend_weight)

func _head_aim_rotation(max_rotation: float) -> float:
	var local_angle := wrapf(_head_aim_angle, -PI, PI)
	if _facing_sign < 0.0:
		local_angle = wrapf(_head_aim_angle - PI, -PI, PI)
	return clampf(local_angle * 0.32, -max_rotation, max_rotation)

func _head_aim_offset_x() -> float:
	return _head_aim_rotation(0.28) * 6.5 * _facing_sign

func set_character_visual(new_character_id: String) -> void:
	var normalized := new_character_id.strip_edges().to_lower()
	if normalized != CHARACTER_ID_EREBUS and normalized != CHARACTER_ID_TASKO:
		normalized = CHARACTER_ID_OUTRAGE
	character_id = normalized
	if normalized == CHARACTER_ID_EREBUS:
		warrior_column_index = EREBUS_WARRIOR_COLUMN
	elif normalized == CHARACTER_ID_TASKO:
		warrior_column_index = TASKO_WARRIOR_COLUMN
	else:
		warrior_column_index = OUTRAGE_WARRIOR_COLUMN
	_apply_modular_character_visuals()

func set_modular_part_indices(head_index: int, torso_index: int, legs_index: int) -> void:
	selected_head_index = maxi(1, head_index)
	selected_torso_index = maxi(1, torso_index)
	selected_legs_index = maxi(1, legs_index)
	_apply_modular_character_visuals()

func _apply_modular_character_visuals() -> void:
	var head_tex := _part_texture(character_id, "head", _head_sprite.texture if _head_sprite != null else null)
	var torso_tex := _part_texture(character_id, "torso", _torso_sprite.texture if _torso_sprite != null else null)
	var legs_tex := _part_texture(character_id, "legs", _legs_sprite.texture if _legs_sprite != null else null)

	if _legs_sprite != null:
		_legs_sprite.texture = legs_tex
		_legs_sprite.region_enabled = true
		_legs_sprite.region_rect = _region_from_index(_legs_sprite.texture, selected_legs_index, LEGS_FRAME_SIZE)
	if _legs_sprite_2 != null:
		_legs_sprite_2.texture = legs_tex
		_legs_sprite_2.region_enabled = true
		_legs_sprite_2.region_rect = _region_from_index(_legs_sprite_2.texture, selected_legs_index, LEGS_FRAME_SIZE)
	if _torso_sprite != null:
		_torso_sprite.texture = torso_tex
		_torso_sprite.region_enabled = true
		_torso_sprite.region_rect = _region_from_index(_torso_sprite.texture, selected_torso_index, TORSO_FRAME_SIZE)
	if _head_sprite != null:
		_head_sprite.texture = head_tex
		_head_sprite.region_enabled = true
		_head_sprite.region_rect = _region_from_index(_head_sprite.texture, selected_head_index, HEAD_FRAME_SIZE)

	var tint := Color(0.78, 0.84, 1.0, 1.0) if character_id == CHARACTER_ID_EREBUS else Color(1, 1, 1, 1)
	if character_id == CHARACTER_ID_TASKO:
		tint = Color(1.0, 0.65, 0.92, 1.0)
	if _legs_sprite != null:
		_legs_sprite.modulate = tint
	if _legs_sprite_2 != null:
		_legs_sprite_2.modulate = tint
	if _torso_sprite != null:
		_torso_sprite.modulate = tint
	if _head_sprite != null:
		_head_sprite.modulate = tint

func _region_from_index(texture: Texture2D, index_1_based: int, frame_size: Vector2i) -> Rect2:
	if texture == null:
		return Rect2(0, 0, frame_size.x, frame_size.y)
	var frame_width := frame_size.x
	var frame_height := frame_size.y
	var texture_width := int(texture.get_width())
	var texture_height := int(texture.get_height())
	if frame_width <= 0 or frame_height <= 0 or texture_width <= 0 or texture_height <= 0:
		return Rect2(0, 0, frame_width, frame_height)

	var columns := maxi(1, int(texture_width / float(frame_width)))
	var rows := maxi(1, int(texture_height / float(frame_height)))
	var max_frames := maxi(1, columns * rows)
	var frame_index := clampi(index_1_based - 1, 0, max_frames - 1)
	var column := frame_index % columns
	var row := int(frame_index / float(columns))
	return Rect2(column * frame_width, row * frame_height, frame_width, frame_height)

func _part_texture(warrior_id: String, part_name: String, fallback: Texture2D) -> Texture2D:
	var normalized := warrior_id.strip_edges().to_lower()
	if not PART_TEXTURE_PATHS.has(normalized):
		return fallback
	var part_paths := PART_TEXTURE_PATHS.get(normalized, {}) as Dictionary
	var path := str(part_paths.get(part_name, "")).strip_edges()
	if path.is_empty():
		return fallback
	if _part_texture_cache.has(path):
		var cached := _part_texture_cache[path] as Texture2D
		return cached if cached != null else fallback
	var loaded := load(path) as Texture2D
	_part_texture_cache[path] = loaded
	return loaded if loaded != null else fallback
