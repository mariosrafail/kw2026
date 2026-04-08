extends RefCounted

class_name PlayerModularVisual

const CHARACTER_ID_OUTRAGE := "outrage"
const CHARACTER_ID_EREBUS := "erebus"
const CHARACTER_ID_TASKO := "tasko"
const CHARACTER_ID_JUICE := "juice"
const CHARACTER_ID_MADAM := "madam"
const CHARACTER_ID_CELLER := "celler"
const CHARACTER_ID_KOTRO := "kotro"
const CHARACTER_ID_NOVA := "nova"
const CHARACTER_ID_HINDI := "hindi"
const CHARACTER_ID_LOKER := "loker"
const CHARACTER_ID_GAN := "gan"
const CHARACTER_ID_VEILA := "veila"
const GAN_HAIR_WIND_SHADER := preload("res://assets/shaders/gan_hair_wind.gdshader")

const LEGS_FRAME_SIZE := Vector2i(64, 64)
const TORSO_FRAME_SIZE := Vector2i(64, 64)
const HEAD_FRAME_SIZE := Vector2i(64, 64)

const OUTRAGE_WARRIOR_COLUMN := 1
const EREBUS_WARRIOR_COLUMN := 2
const TASKO_WARRIOR_COLUMN := 3
const MADAM_WARRIOR_COLUMN := 4
const CELLER_WARRIOR_COLUMN := 5
const KOTRO_WARRIOR_COLUMN := 6
const WARRIOR_FRAME_OFFSET_X := 64
const SYNC_POSE_LERP_SPEED := 18.0
const HEAD_LEFT_SOCKET_CORRECTION := 2.0
const HEAD_GROUNDED_AIM_OFFSET_SCALE := 0.45
const HEAD_GROUNDED_MAX_DRIFT := 7.5
const HEAD_GROUNDED_IDLE_ROTATION_MAX := 0.26
const HEAD_GROUNDED_WALK_ROTATION_MAX := 0.22
const STAIR_DESCEND_BLEND_IN_SPEED := 24.0
const STAIR_DESCEND_BLEND_OUT_SPEED := 12.0

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
	CHARACTER_ID_JUICE: {
		"head": "res://assets/warriors/juice/head.png",
		"torso": "res://assets/warriors/juice/torso.png",
		"legs": "res://assets/warriors/juice/legs.png",
	},
	CHARACTER_ID_MADAM: {
		"head": "res://assets/warriors/madam/head.png",
		"torso": "res://assets/warriors/madam/torso.png",
		"legs": "res://assets/warriors/madam/legs.png",
	},
	CHARACTER_ID_CELLER: {
		"head": "res://assets/warriors/celler/head.png",
		"torso": "res://assets/warriors/celler/torso.png",
		"legs": "res://assets/warriors/celler/legs.png",
	},
	CHARACTER_ID_KOTRO: {
		"head": "res://assets/warriors/kotro/head.png",
		"torso": "res://assets/warriors/kotro/torso.png",
		"legs": "res://assets/warriors/kotro/legs.png",
	},
	CHARACTER_ID_NOVA: {
		"head": "res://assets/warriors/nova/head.png",
		"torso": "res://assets/warriors/nova/torso.png",
		"legs": "res://assets/warriors/nova/legs.png",
	},
	CHARACTER_ID_HINDI: {
		"head": "res://assets/warriors/hindi/head.png",
		"torso": "res://assets/warriors/hindi/torso.png",
		"legs": "res://assets/warriors/hindi/legs.png",
	},
	CHARACTER_ID_LOKER: {
		"head": "res://assets/warriors/loker/head.png",
		"torso": "res://assets/warriors/loker/torso.png",
		"legs": "res://assets/warriors/loker/legs.png",
	},
	CHARACTER_ID_GAN: {
		"head": "res://assets/warriors/gan/head.png",
		"torso": "res://assets/warriors/gan/torso.png",
		"legs": "res://assets/warriors/gan/legs.png",
	},
	CHARACTER_ID_VEILA: {
		"head": "res://assets/warriors/veila/head.png",
		"torso": "res://assets/warriors/veila/torso.png",
		"legs": "res://assets/warriors/veila/legs.png",
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
var _leg_facing_sign := 1.0
var _anim_time := 0.0
var _air_blend := 0.0
var _move_blend := 0.0
var _stair_descend_blend := 0.0
var _was_on_floor := true
var _previous_horizontal_speed := 0.0
var _pose_blend_speed := 16.0
var _pose_blend_weight := 1.0
var _walk_cycle_sign := 1.0
var _head_aim_angle := 0.0
var _smoothed_velocity := Vector2.ZERO
var _velocity_impulse := Vector2.ZERO
var _shot_jolt_offset := Vector2.ZERO
var _shot_jolt_rotation := 0.0
var _gan_hair_material: ShaderMaterial
var _gan_hair_overlay_material: ShaderMaterial
var _gan_hair_overlay_sprite: Sprite2D

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

func build_pose_snapshot() -> Dictionary:
	return {
		"leg1": _snapshot_for_sprite(_legs_sprite),
		"leg2": _snapshot_for_sprite(_legs_sprite_2),
		"torso": _snapshot_for_sprite(_torso_sprite),
		"head": _snapshot_for_sprite(_head_sprite)
	}

func apply_pose_snapshot(state: Dictionary, delta: float) -> void:
	var weight := clampf(delta * SYNC_POSE_LERP_SPEED, 0.0, 1.0)
	_apply_snapshot_to_sprite(_legs_sprite, state.get("leg1", {}), weight)
	_apply_snapshot_to_sprite(_legs_sprite_2, state.get("leg2", {}), weight)
	_apply_snapshot_to_sprite(_torso_sprite, state.get("torso", {}), weight)
	_apply_snapshot_to_sprite(_head_sprite, state.get("head", {}), weight)

func apply_player_facing_from_angle(angle: float) -> void:
	_head_aim_angle = angle
	var looking_left := cos(angle) < 0.0
	_facing_sign = -1.0 if looking_left else 1.0
	_apply_facing_to_sprite(_head_sprite, "head", looking_left)
	_apply_facing_to_sprite(_torso_sprite, "torso", looking_left)

func _apply_leg_facing_from_sign(sign_value: float) -> void:
	if absf(sign_value) <= 0.0:
		return
	_leg_facing_sign = -1.0 if sign_value < 0.0 else 1.0
	var legs_looking_left := _leg_facing_sign < 0.0
	_apply_facing_to_sprite(_legs_sprite, "leg1", legs_looking_left)
	_apply_facing_to_sprite(_legs_sprite_2, "leg2", legs_looking_left)

func _apply_facing_to_sprite(sprite: Sprite2D, key: String, looking_left: bool) -> void:
	if sprite == null:
		return
	var base_position := _base_positions.get(key, sprite.position) as Vector2
	sprite.position.x = -base_position.x if looking_left else base_position.x
	sprite.position.y = base_position.y
	var current_scale := sprite.scale
	current_scale.x = -absf(current_scale.x) if looking_left else absf(current_scale.x)
	sprite.scale = current_scale

func update_walk_animation(delta: float, velocity: Vector2, on_floor: bool, stair_descend_blend: float = 0.0) -> void:
	_anim_time += delta
	var previous_smoothed_velocity: Vector2 = _smoothed_velocity
	var velocity_tracking: float = minf(1.0, delta * (16.0 if on_floor else 9.0))
	var impulse_tracking: float = minf(1.0, delta * 12.0)
	_smoothed_velocity = _smoothed_velocity.lerp(velocity, velocity_tracking)
	_velocity_impulse = _velocity_impulse.lerp(_smoothed_velocity - previous_smoothed_velocity, impulse_tracking)
	_shot_jolt_offset = _shot_jolt_offset.lerp(Vector2.ZERO, minf(1.0, delta * 18.0))
	_shot_jolt_rotation = lerpf(_shot_jolt_rotation, 0.0, minf(1.0, delta * 20.0))
	var horizontal_speed := absf(velocity.x)
	var movement_sign := signf(velocity.x)
	var speed_ratio := clampf(horizontal_speed / 245.0, 0.0, 1.8)
	_update_gan_hair_wind(horizontal_speed, on_floor)
	var grounded := on_floor and horizontal_speed > 8.0
	var idle_grounded := on_floor and not grounded
	_pose_blend_speed = 42.0 if grounded else 28.0 if on_floor else 20.0
	_pose_blend_weight = 1.0 if not on_floor else 0.55 if grounded else 0.4
	if absf(movement_sign) > 0.0:
		_apply_leg_facing_from_sign(movement_sign)
		_walk_cycle_sign = 1.0
	else:
		_apply_leg_facing_from_sign(_facing_sign)
	var phase_speed := lerpf(5.0, 17.5, clampf(speed_ratio, 0.0, 1.0))
	_was_on_floor = on_floor
	_previous_horizontal_speed = horizontal_speed
	_air_blend = 1.0 if not on_floor else move_toward(_air_blend, 0.0, delta * 14.0)
	_move_blend = move_toward(_move_blend, 1.0 if grounded else 0.0, delta * (9.0 if grounded else 7.0))
	var stair_target := clampf(stair_descend_blend, 0.0, 1.0)
	var stair_speed := STAIR_DESCEND_BLEND_IN_SPEED if stair_target > _stair_descend_blend else STAIR_DESCEND_BLEND_OUT_SPEED
	_stair_descend_blend = move_toward(_stair_descend_blend, stair_target, delta * stair_speed)
	if grounded:
		_walk_phase = wrapf(_walk_phase + delta * phase_speed, 0.0, TAU)
	else:
		var air_phase_decay: float = minf(1.0, delta * 7.0)
		_walk_phase = wrapf(lerpf(_walk_phase, 0.0, air_phase_decay), 0.0, TAU)

	if not on_floor:
		_apply_air_pose(velocity, _air_blend)
		return
	if _air_blend > 0.001:
		_apply_air_pose(velocity, _air_blend)
	elif idle_grounded:
		_apply_idle_pose()
		return

	if _stair_descend_blend > 0.001:
		_apply_stair_descend_pose(velocity, _stair_descend_blend)
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
	var landing_offset := 0.0
	var stop_sway := 0.0

	_apply_walk_to_leg(_legs_sprite, "leg1", lead_phase, stomp, leg_x_amp, leg_y_amp, landing_offset, stop_sway)
	_apply_walk_to_leg(_legs_sprite_2, "leg2", trail_phase, stomp, leg_x_amp, leg_y_amp, landing_offset, stop_sway)
	_apply_walk_to_torso(bounce, torso_sway, goofy_wobble, body_bob_amp, grounded, landing_offset, stop_sway)
	_apply_walk_to_head(bounce, head_wobble, goofy_wobble, head_bob_amp, grounded, landing_offset, stop_sway)

func _apply_air_pose(velocity: Vector2, blend: float) -> void:
	var horizontal_ratio := clampf(absf(velocity.x) / 245.0, 0.0, 1.0)
	var vertical_ratio := clampf(absf(velocity.y) / 700.0, 0.0, 1.0)
	var travel_tilt := clampf(velocity.x / 245.0, -1.0, 1.0)
	var flutter := sin(_anim_time * 11.0 + _goofy_seed * TAU) * 0.45
	var torso_lift := lerpf(5.5, 10.5, vertical_ratio) * blend
	var head_lift := lerpf(7.5, 13.5, vertical_ratio) * blend
	var leg_tuck := lerpf(6.5, 13.5, vertical_ratio) * blend
	var forward_splay := lerpf(4.5, 10.0, horizontal_ratio) * blend
	var back_splay := lerpf(2.5, 6.0, horizontal_ratio) * blend

	_apply_air_leg(_legs_sprite, "leg1", 1.0, torso_lift, leg_tuck, forward_splay, back_splay, flutter)
	_apply_air_leg(_legs_sprite_2, "leg2", -1.0, torso_lift, leg_tuck, forward_splay, back_splay, flutter)
	_apply_air_torso(torso_lift, travel_tilt, vertical_ratio, flutter, blend)
	_apply_air_head(head_lift, travel_tilt, vertical_ratio, flutter, blend)

func _apply_stair_descend_pose(velocity: Vector2, blend: float) -> void:
	var drift := clampf(velocity.x / 245.0, -1.0, 1.0)
	var drop_ratio := clampf(maxf(0.0, velocity.y) / 260.0, 0.0, 1.0)
	var lean := (0.22 + drop_ratio * 0.34) * blend
	var leg_spread := (5.5 + drop_ratio * 4.0) * blend
	var leg_drop := (2.0 + drop_ratio * 3.2) * blend
	var torso_raise := (2.0 + drop_ratio * 4.0) * blend
	var head_raise := (3.0 + drop_ratio * 5.0) * blend
	var sway := sin(_anim_time * 8.0 + _goofy_seed * TAU) * 0.18 * blend

	if _legs_sprite != null:
		var leg1_base := _base_positions.get("leg1", _legs_sprite.position) as Vector2
		_apply_pose(_legs_sprite, Vector2(
			(leg1_base.x * _leg_facing_sign) - leg_spread * _leg_facing_sign,
			leg1_base.y + leg_drop
		) + _secondary_drag(0.0035, 0.003) + _shot_jolt(0.24), (-lean * 1.8 - drift * 0.08 + sway) * _leg_facing_sign + _secondary_tilt(0.05) + _shot_jolt_rot(0.45))
	if _legs_sprite_2 != null:
		var leg2_base := _base_positions.get("leg2", _legs_sprite_2.position) as Vector2
		_apply_pose(_legs_sprite_2, Vector2(
			(leg2_base.x * _leg_facing_sign) + leg_spread * _leg_facing_sign,
			leg2_base.y + leg_drop * 0.86
		) + _secondary_drag(0.0035, 0.003) + _shot_jolt(0.24), (-lean * 1.35 - drift * 0.06 - sway * 0.7) * _leg_facing_sign + _secondary_tilt(0.05) + _shot_jolt_rot(0.45))
	if _torso_sprite != null:
		var torso_base := _base_positions.get("torso", _torso_sprite.position) as Vector2
		_apply_pose(_torso_sprite, Vector2(
			(torso_base.x * _facing_sign) - drift * 2.0 * blend,
			torso_base.y - torso_raise
		) + _secondary_drag(0.008, 0.007) + _shot_jolt(0.78), (lean + drift * 0.09) * _facing_sign + _secondary_tilt(0.1) + _shot_jolt_rot(0.95))
	if _head_sprite != null:
		var head_base := _base_positions.get("head", _head_sprite.position) as Vector2
		var head_anchor_x := _resolved_head_anchor_x(head_base.x)
		_apply_pose(_head_sprite, Vector2(
			_head_target_x(head_anchor_x, _head_aim_offset_x() * 0.3 - drift * 1.7 * blend, HEAD_GROUNDED_MAX_DRIFT + 1.0),
			head_base.y - head_raise
		) + _secondary_drag(0.01, 0.009) + _shot_jolt(1.0), (lean * 0.9 + drift * 0.08) * _facing_sign + _head_aim_rotation(0.24) + _secondary_tilt(0.08) + _shot_jolt_rot(1.0))

func _apply_idle_pose() -> void:
	var breath := sin(_anim_time * 2.3 + _goofy_seed * 3.4)
	var sway := sin(_anim_time * 1.6 + _goofy_seed * 5.1)
	var head_nod := sin(_anim_time * 2.0 + 0.6 + _goofy_seed * 6.4)
	if _legs_sprite != null:
		var leg1_base := _base_positions.get("leg1", _legs_sprite.position) as Vector2
		_apply_pose(_legs_sprite, Vector2(
			leg1_base.x * _leg_facing_sign - sway * 0.35 * _leg_facing_sign,
			leg1_base.y
		) + _secondary_drag(0.003, 0.002) + _shot_jolt(0.18), -0.02 + _secondary_tilt(0.035) + _shot_jolt_rot(0.35))
	if _legs_sprite_2 != null:
		var leg2_base := _base_positions.get("leg2", _legs_sprite_2.position) as Vector2
		_apply_pose(_legs_sprite_2, Vector2(
			leg2_base.x * _leg_facing_sign + sway * 0.35 * _leg_facing_sign,
			leg2_base.y
		) + _secondary_drag(0.003, 0.002) + _shot_jolt(0.18), 0.02 + _secondary_tilt(0.035) + _shot_jolt_rot(0.35))
	if _torso_sprite != null:
		var torso_base := _base_positions.get("torso", _torso_sprite.position) as Vector2
		_apply_pose(_torso_sprite, Vector2(
			(torso_base.x * _facing_sign) + sway * 0.55 * _facing_sign,
			torso_base.y + breath * 0.7
		) + _secondary_drag(0.008, 0.006) + _shot_jolt(0.7), sway * 0.02 + _secondary_tilt(0.08) + _shot_jolt_rot(0.9))
	if _head_sprite != null:
		var head_base := _base_positions.get("head", _head_sprite.position) as Vector2
		var head_anchor_x := _resolved_head_anchor_x(head_base.x)
		_apply_pose(_head_sprite, Vector2(
			_head_target_x(head_anchor_x, sway * 0.3 * _facing_sign + _head_aim_offset_x() * HEAD_GROUNDED_AIM_OFFSET_SCALE, HEAD_GROUNDED_MAX_DRIFT),
			head_base.y + breath * 1.2 + head_nod * 0.3
		) + _secondary_drag(0.009, 0.008) + _shot_jolt(1.0), sway * 0.012 + head_nod * 0.016 + _head_aim_rotation(HEAD_GROUNDED_IDLE_ROTATION_MAX) + _secondary_tilt(0.07) + _shot_jolt_rot(0.9))

func _apply_walk_to_leg(sprite: Sprite2D, key: String, phase: float, stomp: float, x_amp: float, y_amp: float, landing_offset: float, stop_sway: float) -> void:
	if sprite == null:
		return
	var base_position := _base_positions.get(key, sprite.position) as Vector2
	var cycle_x := -sin(phase)
	var cycle_y := -cos(phase)
	var lift := maxf(0.0, cycle_y)
	var drop := maxf(0.0, -cycle_y)
	_apply_pose(sprite, Vector2(
		(base_position.x * _leg_facing_sign) + (cycle_x * x_amp * _leg_facing_sign) - (stop_sway * 0.35 * signf(cycle_x) * _leg_facing_sign),
		base_position.y - (lift * y_amp) + (drop * 1.9) + (stomp * 0.45) + landing_offset
	) + _secondary_drag(0.0035, 0.0025) + _shot_jolt(0.24), cycle_x * 0.23 + cycle_y * 0.075 - stop_sway * 0.012 * signf(cycle_x) + _secondary_tilt(0.045) + _shot_jolt_rot(0.45))

func _apply_walk_to_torso(bounce: float, sway: float, goofy_wobble: float, bob_amp: float, grounded: bool, landing_offset: float, stop_sway: float) -> void:
	if _torso_sprite == null:
		return
	var base_position := _base_positions.get("torso", _torso_sprite.position) as Vector2
	var idle_breath := sin(_walk_phase * 0.45 + _goofy_seed * 3.1) * 0.35
	_apply_pose(_torso_sprite, Vector2(
		(base_position.x * _facing_sign) + sway * 1.4 * _facing_sign - stop_sway * 0.45 * _facing_sign,
		base_position.y - bounce * bob_amp + idle_breath + landing_offset * 0.55
	) + _secondary_drag(0.007, 0.005) + _shot_jolt(0.75), sway * 0.06 + goofy_wobble * 0.015 - stop_sway * 0.016 + _secondary_tilt(0.09) + _shot_jolt_rot(0.95))
	if not grounded:
		_torso_sprite.rotation *= 0.35

func _apply_walk_to_head(bounce: float, wobble: float, goofy_wobble: float, bob_amp: float, grounded: bool, landing_offset: float, stop_sway: float) -> void:
	if _head_sprite == null:
		return
	var base_position := _base_positions.get("head", _head_sprite.position) as Vector2
	var idle_float := sin(_walk_phase * 0.55 + 0.8 + _goofy_seed * 4.7) * 0.6
	var random_rot := sin(_walk_phase * 2.1 + _goofy_seed * 7.1) * 0.025
	var head_drag_x := -_smoothed_velocity.x * 0.02
	var backward_lean := -0.1 * _facing_sign
	var head_anchor_x := _resolved_head_anchor_x(base_position.x)
	_apply_pose(_head_sprite, Vector2(
		_head_target_x(head_anchor_x, head_drag_x * 0.5 + _head_aim_offset_x() * HEAD_GROUNDED_AIM_OFFSET_SCALE, HEAD_GROUNDED_MAX_DRIFT + 0.5),
		base_position.y - bounce * bob_amp + idle_float + landing_offset * 0.82
	) + _secondary_drag(0.01, 0.008) + _shot_jolt(1.0), backward_lean + wobble * 0.012 + goofy_wobble * 0.006 + random_rot * 0.5 - stop_sway * 0.004 + _head_aim_rotation(HEAD_GROUNDED_WALK_ROTATION_MAX) + _secondary_tilt(0.06) + _shot_jolt_rot(0.95))
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
	flutter: float
) -> void:
	if sprite == null:
		return
	var base_position := _base_positions.get(key, sprite.position) as Vector2
	var front_leg := side_sign > 0.0
	var x_shift := 0.0
	var y_shift := torso_lift - leg_tuck + absf(flutter) * 0.8
	var target_rotation := 0.0
	if front_leg:
		x_shift = -base_position.x + 17.5
		y_shift += 13.0
		target_rotation = -1.45 * _leg_facing_sign + flutter * 0.06
	else:
		x_shift = -back_splay - 15.0
		y_shift += 8.0
		target_rotation = 1.05 * _leg_facing_sign + flutter * 0.07
	_apply_pose(sprite, Vector2(
		(base_position.x * _leg_facing_sign) + (x_shift * _leg_facing_sign),
		base_position.y - y_shift
	) + _secondary_drag(0.004, 0.003) + _shot_jolt(0.26), target_rotation + _secondary_tilt(0.055) + _shot_jolt_rot(0.5))

func _apply_air_torso(torso_lift: float, travel_tilt: float, vertical_ratio: float, flutter: float, blend: float) -> void:
	if _torso_sprite == null:
		return
	var base_position := _base_positions.get("torso", _torso_sprite.position) as Vector2
	_apply_pose(_torso_sprite, Vector2(
		(base_position.x * _facing_sign) + travel_tilt * 2.8 * blend,
		base_position.y - torso_lift - vertical_ratio * 2.4 * blend + flutter * 0.35 * blend
	) + _secondary_drag(0.01, 0.009) + _shot_jolt(0.8), (0.16 * _facing_sign + travel_tilt * 0.075 + flutter * 0.02) * blend + _secondary_tilt(0.12) + _shot_jolt_rot(1.0))

func _apply_air_head(head_lift: float, travel_tilt: float, vertical_ratio: float, flutter: float, blend: float) -> void:
	if _head_sprite == null:
		return
	var base_position := _base_positions.get("head", _head_sprite.position) as Vector2
	var float_wobble := sin(_anim_time * 14.5 + _goofy_seed * 11.0) * 0.8
	var head_anchor_x := _resolved_head_anchor_x(base_position.x)
	_apply_pose(_head_sprite, Vector2(
		_head_target_x(head_anchor_x, (travel_tilt * 0.28 + flutter * 0.06) * blend + _head_aim_offset_x() * 0.32, 8.0),
		base_position.y - head_lift - vertical_ratio * 3.1 * blend + float_wobble * 0.35 * blend
	) + _secondary_drag(0.016, 0.013) + _shot_jolt(1.1), (0.04 * _facing_sign + travel_tilt * 0.012 + flutter * 0.006 + float_wobble * 0.02) * blend + _head_aim_rotation(0.28) + _secondary_tilt(0.16) + _shot_jolt_rot(1.2))

func _apply_pose(sprite: Sprite2D, target_position: Vector2, target_rotation: float) -> void:
	if sprite == null:
		return
	var follow_weight := _pose_follow_weight(sprite)
	sprite.position = sprite.position.lerp(target_position, follow_weight)
	sprite.rotation = lerp_angle(sprite.rotation, target_rotation, follow_weight)

func _secondary_drag(x_scale: float, y_scale: float) -> Vector2:
	return Vector2(
		-_smoothed_velocity.x * x_scale - _velocity_impulse.x * x_scale * 8.0,
		-_smoothed_velocity.y * y_scale - _velocity_impulse.y * y_scale * 7.0
	)

func _secondary_tilt(max_rotation: float) -> float:
	return clampf(
		-_smoothed_velocity.x * 0.0008 - _velocity_impulse.x * 0.01,
		-max_rotation,
		max_rotation
	)

func _shot_jolt(weight: float) -> Vector2:
	return _shot_jolt_offset * weight

func _shot_jolt_rot(weight: float) -> float:
	return _shot_jolt_rotation * weight

func _head_target_x(anchor_x: float, extra_x: float, max_distance: float) -> float:
	return clampf(anchor_x + extra_x, anchor_x - max_distance, anchor_x + max_distance)

func _resolved_head_anchor_x(base_x: float) -> float:
	var anchor_x := base_x * _facing_sign
	if _facing_sign < 0.0:
		anchor_x += HEAD_LEFT_SOCKET_CORRECTION
	return anchor_x

func _pose_follow_weight(sprite: Sprite2D) -> float:
	var follow_weight := _pose_blend_weight
	if sprite == _head_sprite:
		follow_weight *= 0.95
	elif sprite == _torso_sprite:
		follow_weight *= 0.82
	else:
		follow_weight *= 0.9
	return clampf(follow_weight, 0.08, 1.0)

func trigger_shot_jolt(aim_angle: float) -> void:
	var recoil_dir := Vector2.LEFT.rotated(aim_angle)
	_shot_jolt_offset += recoil_dir * 2.4
	_shot_jolt_offset += Vector2(randf_range(-0.7, 0.7), randf_range(-0.9, 0.5))
	_shot_jolt_rotation += randf_range(-0.09, 0.09)

func _head_aim_rotation(max_rotation: float) -> float:
	var local_angle := wrapf(_head_aim_angle, -PI, PI)
	if _facing_sign < 0.0:
		local_angle = wrapf(_head_aim_angle - PI, -PI, PI)
	return clampf(local_angle * 1.0, -max_rotation, max_rotation)

func _head_aim_offset_x() -> float:
	return _head_aim_rotation(0.6) * 14.0 * _facing_sign

func set_character_visual(new_character_id: String) -> void:
	var normalized := new_character_id.strip_edges().to_lower()
	if normalized != CHARACTER_ID_EREBUS and normalized != CHARACTER_ID_TASKO and normalized != CHARACTER_ID_JUICE and normalized != CHARACTER_ID_MADAM and normalized != CHARACTER_ID_CELLER and normalized != CHARACTER_ID_KOTRO and normalized != CHARACTER_ID_NOVA and normalized != CHARACTER_ID_HINDI and normalized != CHARACTER_ID_LOKER and normalized != CHARACTER_ID_GAN and normalized != CHARACTER_ID_VEILA:
		normalized = CHARACTER_ID_OUTRAGE
	character_id = normalized
	if normalized == CHARACTER_ID_EREBUS:
		warrior_column_index = EREBUS_WARRIOR_COLUMN
	elif normalized == CHARACTER_ID_TASKO:
		warrior_column_index = TASKO_WARRIOR_COLUMN
	elif normalized == CHARACTER_ID_MADAM:
		warrior_column_index = MADAM_WARRIOR_COLUMN
	elif normalized == CHARACTER_ID_CELLER:
		warrior_column_index = CELLER_WARRIOR_COLUMN
	elif normalized == CHARACTER_ID_KOTRO:
		warrior_column_index = KOTRO_WARRIOR_COLUMN
	elif normalized == CHARACTER_ID_NOVA:
		warrior_column_index = KOTRO_WARRIOR_COLUMN
	elif normalized == CHARACTER_ID_HINDI:
		warrior_column_index = KOTRO_WARRIOR_COLUMN
	elif normalized == CHARACTER_ID_LOKER:
		warrior_column_index = KOTRO_WARRIOR_COLUMN
	elif normalized == CHARACTER_ID_GAN:
		warrior_column_index = KOTRO_WARRIOR_COLUMN
	elif normalized == CHARACTER_ID_VEILA:
		warrior_column_index = KOTRO_WARRIOR_COLUMN
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
	_update_gan_hair_wind(0.0, false)

	var tint := Color(0.78, 0.84, 1.0, 1.0) if character_id == CHARACTER_ID_EREBUS else Color(1, 1, 1, 1)
	if character_id == CHARACTER_ID_TASKO:
		tint = Color(1.0, 0.65, 0.92, 1.0)
	elif character_id == CHARACTER_ID_JUICE:
		# Juice body parts use their authored texture colors directly.
		tint = Color(1, 1, 1, 1)
	elif character_id == CHARACTER_ID_MADAM:
		tint = Color(1, 1, 1, 1)
	elif character_id == CHARACTER_ID_CELLER:
		tint = Color(1, 1, 1, 1)
	elif character_id == CHARACTER_ID_KOTRO:
		tint = Color(1, 1, 1, 1)
	elif character_id == CHARACTER_ID_NOVA:
		tint = Color(1, 1, 1, 1)
	elif character_id == CHARACTER_ID_HINDI:
		tint = Color(1, 1, 1, 1)
	elif character_id == CHARACTER_ID_LOKER:
		tint = Color(1, 1, 1, 1)
	elif character_id == CHARACTER_ID_GAN:
		tint = Color(1, 1, 1, 1)
	elif character_id == CHARACTER_ID_VEILA:
		tint = Color(1, 1, 1, 1)
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

func _snapshot_for_sprite(sprite: Sprite2D) -> Dictionary:
	if sprite == null:
		return {}
	return {
		"position": sprite.position,
		"rotation": sprite.rotation,
		"scale": sprite.scale
	}

func _apply_snapshot_to_sprite(sprite: Sprite2D, snapshot: Variant, weight: float) -> void:
	if sprite == null or not (snapshot is Dictionary):
		return
	var pose := snapshot as Dictionary
	var position_value = pose.get("position", sprite.position)
	if position_value is Vector2:
		sprite.position = sprite.position.lerp(position_value, weight)
	var rotation_value = pose.get("rotation", sprite.rotation)
	if rotation_value is float:
		sprite.rotation = lerp_angle(sprite.rotation, rotation_value, weight)
	var scale_value = pose.get("scale", sprite.scale)
	if scale_value is Vector2:
		sprite.scale = sprite.scale.lerp(scale_value, weight)

func _ensure_gan_hair_material() -> void:
	if _gan_hair_material != null:
		if _gan_hair_overlay_material != null:
			return
	else:
		_gan_hair_material = ShaderMaterial.new()
		_gan_hair_material.shader = GAN_HAIR_WIND_SHADER
	_ensure_gan_hair_overlay_material()
	_gan_hair_material.set_shader_parameter("walk_strength", 0.0)
	_gan_hair_material.set_shader_parameter("air_factor", 0.0)
	_gan_hair_material.set_shader_parameter("facing_sign", 1.0)
	_gan_hair_overlay_material.set_shader_parameter("walk_strength", 1.0)
	_gan_hair_overlay_material.set_shader_parameter("air_factor", 0.25)
	_gan_hair_overlay_material.set_shader_parameter("facing_sign", 1.0)

func _ensure_gan_hair_overlay_material() -> void:
	if _gan_hair_overlay_material != null:
		return
	_gan_hair_overlay_material = ShaderMaterial.new()
	_gan_hair_overlay_material.shader = GAN_HAIR_WIND_SHADER

func _ensure_gan_hair_overlay_sprite() -> void:
	if _head_sprite == null:
		return
	if _gan_hair_overlay_sprite != null and is_instance_valid(_gan_hair_overlay_sprite):
		return
	var parent_node := _head_sprite.get_parent()
	if not (parent_node is Node):
		return
	var parent := parent_node as Node
	var overlay := Sprite2D.new()
	overlay.name = "GanHairWindOverlay"
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.centered = _head_sprite.centered
	overlay.visible = false
	parent.add_child(overlay)
	if parent is Node2D:
		var parent_2d := parent as Node2D
		parent_2d.move_child(overlay, mini(parent_2d.get_child_count() - 1, _head_sprite.get_index() + 1))
	_gan_hair_overlay_sprite = overlay

func _sync_gan_hair_overlay_from_head() -> void:
	if _head_sprite == null:
		return
	_ensure_gan_hair_overlay_sprite()
	if _gan_hair_overlay_sprite == null:
		return
	_gan_hair_overlay_sprite.texture = _head_sprite.texture
	_gan_hair_overlay_sprite.region_enabled = _head_sprite.region_enabled
	_gan_hair_overlay_sprite.region_rect = _head_sprite.region_rect
	_gan_hair_overlay_sprite.hframes = _head_sprite.hframes
	_gan_hair_overlay_sprite.vframes = _head_sprite.vframes
	_gan_hair_overlay_sprite.frame = _head_sprite.frame
	_gan_hair_overlay_sprite.frame_coords = _head_sprite.frame_coords
	_gan_hair_overlay_sprite.flip_h = _head_sprite.flip_h
	_gan_hair_overlay_sprite.flip_v = _head_sprite.flip_v
	_gan_hair_overlay_sprite.offset = _head_sprite.offset
	_gan_hair_overlay_sprite.position = _head_sprite.position + Vector2(0.0, -1.0)
	_gan_hair_overlay_sprite.rotation = _head_sprite.rotation
	_gan_hair_overlay_sprite.scale = _head_sprite.scale * Vector2(1.05, 1.05)
	_gan_hair_overlay_sprite.z_as_relative = _head_sprite.z_as_relative
	_gan_hair_overlay_sprite.z_index = _head_sprite.z_index + 1
	_gan_hair_overlay_sprite.modulate = Color(1.18, 1.22, 1.3, 0.88)
	_gan_hair_overlay_sprite.material = _gan_hair_overlay_material

func _update_gan_hair_wind(horizontal_speed: float, on_floor: bool) -> void:
	if _head_sprite == null:
		return
	if character_id != CHARACTER_ID_GAN:
		if _head_sprite.material == _gan_hair_material:
			_head_sprite.material = null
		if _gan_hair_overlay_sprite != null and is_instance_valid(_gan_hair_overlay_sprite):
			_gan_hair_overlay_sprite.visible = false
		return

	_ensure_gan_hair_material()
	_ensure_gan_hair_overlay_sprite()
	_sync_gan_hair_overlay_from_head()
	var foreign_material_active := _head_sprite.material != null and _head_sprite.material != _gan_hair_material
	if not foreign_material_active and _head_sprite.material != _gan_hair_material:
		_head_sprite.material = _gan_hair_material

	var walk_strength := clampf(horizontal_speed / 230.0, 0.0, 1.0)
	walk_strength = maxf(walk_strength, 0.45)
	var air_factor := 0.0 if on_floor else clampf(horizontal_speed / 320.0, 0.0, 0.45)
	if _head_sprite.material == _gan_hair_material:
		_gan_hair_material.set_shader_parameter("walk_strength", walk_strength)
		_gan_hair_material.set_shader_parameter("air_factor", air_factor)
		_gan_hair_material.set_shader_parameter("facing_sign", _facing_sign)
	if _gan_hair_overlay_sprite != null and is_instance_valid(_gan_hair_overlay_sprite):
		_gan_hair_overlay_sprite.visible = true
		_gan_hair_overlay_material.set_shader_parameter("walk_strength", maxf(0.95, walk_strength * 1.35))
		_gan_hair_overlay_material.set_shader_parameter("air_factor", maxf(0.25, air_factor * 1.6))
		_gan_hair_overlay_material.set_shader_parameter("facing_sign", _facing_sign)
