extends RefCounted
class_name PlayerModularVisualLegacy

const OUTRAGE_WARRIOR_COLUMN := 1
const EREBUS_WARRIOR_COLUMN := 2
const WARRIOR_FRAME_OFFSET_X := 64

# Sprite regions (row, col) in the spritesheets
const OUTRAGE_HEAD_INDEX := 0
const EREBUS_HEAD_INDEX := 0

const OUTRAGE_TORSO_INDEX := 0
const EREBUS_TORSO_INDEX := 0

const OUTRAGE_LEG_INDEX := 0
const EREBUS_LEG_INDEX := 0

var player_ref: Node
var visual_root: Node2D
var leg1_sprite: Sprite2D
var leg2_sprite: Sprite2D
var torso_sprite: Sprite2D
var head_sprite: Sprite2D
var warrior_column_index := 1  # Default to Outrage

func configure(player: Node, root: Node2D, leg1: Sprite2D, leg2: Sprite2D, torso: Sprite2D, head: Sprite2D) -> void:
	player_ref = player
	visual_root = root
	leg1_sprite = leg1
	leg2_sprite = leg2
	torso_sprite = torso
	head_sprite = head

func set_character_visual(character_id: String) -> void:
	var normalized := str(character_id).strip_edges().to_lower()
	print("[DBG MODULAR_VISUAL] set_character_visual called with %s" % character_id)
	match normalized:
		"erebus":
			warrior_column_index = EREBUS_WARRIOR_COLUMN
			print("[DBG MODULAR_VISUAL] Set to EREBUS (column %d)" % EREBUS_WARRIOR_COLUMN)
		_:  # Default to Outrage
			warrior_column_index = OUTRAGE_WARRIOR_COLUMN
			print("[DBG MODULAR_VISUAL] Set to OUTRAGE (column %d)" % OUTRAGE_WARRIOR_COLUMN)
	
	_apply_sprite_regions()

func _apply_sprite_regions() -> void:
	var offset := _warrior_region_offset()
	print("[DBG MODULAR_VISUAL] Applying sprite regions with offset: %s" % offset)
	
	if head_sprite != null:
		_set_sprite_region(head_sprite, OUTRAGE_HEAD_INDEX, offset)
	else:
		print("[DBG MODULAR_VISUAL] head_sprite is null!")
	if torso_sprite != null:
		_set_sprite_region(torso_sprite, OUTRAGE_TORSO_INDEX, offset)
	else:
		print("[DBG MODULAR_VISUAL] torso_sprite is null!")
	if leg1_sprite != null:
		_set_sprite_region(leg1_sprite, OUTRAGE_LEG_INDEX, offset)
	else:
		print("[DBG MODULAR_VISUAL] leg1_sprite is null!")
	if leg2_sprite != null:
		_set_sprite_region(leg2_sprite, OUTRAGE_LEG_INDEX, offset)
	else:
		print("[DBG MODULAR_VISUAL] leg2_sprite is null!")

func _warrior_region_offset() -> Vector2i:
	var column := maxi(1, warrior_column_index) - 1
	if column <= 0:
		return Vector2i.ZERO
	return Vector2i(column * WARRIOR_FRAME_OFFSET_X, 0)

func _set_sprite_region(sprite: Sprite2D, base_row_index: int, offset: Vector2i) -> void:
	if sprite == null or not sprite.region_enabled:
		print("[DBG MODULAR_VISUAL] _set_sprite_region: sprite is null or region not enabled")
		return
	
	var current_rect := sprite.region_rect
	var new_rect := _offset_region(current_rect, offset)
	print("[DBG MODULAR_VISUAL] Sprite region update: %s -> %s" % [current_rect, new_rect])
	sprite.region_rect = new_rect

func _offset_region(rect: Rect2, offset: Vector2i) -> Rect2:
	var new_rect := rect
	new_rect.position += offset
	return new_rect
