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

func configure(player: CharacterBody2D, player_sprite: Node2D, legs_sprite: Sprite2D, legs_sprite_2: Sprite2D = null, torso_sprite: Sprite2D = null, head_sprite: Sprite2D = null) -> void:
	_player = player
	_player_sprite = player_sprite
	_legs_sprite = legs_sprite
	_legs_sprite_2 = legs_sprite_2
	_torso_sprite = torso_sprite
	_head_sprite = head_sprite

func apply_player_facing_from_angle(angle: float) -> void:
	if _player_sprite == null:
		return
	var looking_left := cos(angle) < 0.0
	var current_scale := _player_sprite.scale
	current_scale.x = -absf(current_scale.x) if looking_left else absf(current_scale.x)
	_player_sprite.scale = current_scale

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
	var region_offset := _warrior_region_offset()

	if _legs_sprite != null:
		_legs_sprite.region_enabled = true
		_legs_sprite.region_rect = _offset_region(_region_from_index(_legs_sprite.texture, selected_legs_index, LEGS_FRAME_SIZE), region_offset)
	if _legs_sprite_2 != null:
		_legs_sprite_2.region_enabled = true
		_legs_sprite_2.region_rect = _offset_region(_region_from_index(_legs_sprite_2.texture, selected_legs_index, LEGS_FRAME_SIZE), region_offset)
	if _torso_sprite != null:
		_torso_sprite.region_enabled = true
		_torso_sprite.region_rect = _offset_region(_region_from_index(_torso_sprite.texture, selected_torso_index, TORSO_FRAME_SIZE), region_offset)
	if _head_sprite != null:
		_head_sprite.region_enabled = true
		_head_sprite.region_rect = _offset_region(_region_from_index(_head_sprite.texture, selected_head_index, HEAD_FRAME_SIZE), region_offset)

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

	var columns := maxi(1, texture_width / frame_width)
	var rows := maxi(1, texture_height / frame_height)
	var max_frames := maxi(1, columns * rows)
	var frame_index := clampi(index_1_based - 1, 0, max_frames - 1)
	var column := frame_index % columns
	var row := frame_index / columns
	return Rect2(column * frame_width, row * frame_height, frame_width, frame_height)

func _offset_region(region: Rect2, offset: Vector2i) -> Rect2:
	if offset == Vector2i.ZERO:
		return region
	var new_position := Vector2(region.position.x + float(offset.x), region.position.y + float(offset.y))
	return Rect2(new_position, region.size)

func _warrior_region_offset() -> Vector2i:
	var column := maxi(1, warrior_column_index) - 1
	if column <= 0:
		return Vector2i.ZERO
	return Vector2i(column * WARRIOR_FRAME_OFFSET_X, 0)
