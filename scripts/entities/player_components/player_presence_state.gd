extends RefCounted

class_name PlayerPresenceState

var _player: CharacterBody2D
var _visual_root: Node2D
var _body_collision_shape: CollisionShape2D

var _sfx_suppressed := false
var _forced_hidden_reasons: Dictionary = {}
var _forced_sfx_suppressed_reasons: Dictionary = {}
var _respawn_collision_override_active := false
var _respawn_saved_collision_layer := 0
var _respawn_saved_collision_mask := 0

func configure(player: CharacterBody2D, visual_root: Node2D, body_collision_shape: CollisionShape2D) -> void:
	_player = player
	_visual_root = visual_root
	_body_collision_shape = body_collision_shape

func is_sfx_suppressed() -> bool:
	return _sfx_suppressed or not _forced_sfx_suppressed_reasons.is_empty()

func set_sfx_suppressed(value: bool) -> void:
	_sfx_suppressed = value
	_refresh_state()

func set_forced_hidden(reason: String, enabled: bool) -> void:
	var key := reason.strip_edges()
	if key.is_empty():
		key = "default"
	if enabled:
		_forced_hidden_reasons[key] = true
	else:
		_forced_hidden_reasons.erase(key)
	_refresh_state()

func set_forced_sfx_suppressed(reason: String, enabled: bool) -> void:
	var key := reason.strip_edges()
	if key.is_empty():
		key = "default"
	if enabled:
		_forced_sfx_suppressed_reasons[key] = true
	else:
		_forced_sfx_suppressed_reasons.erase(key)
	_refresh_state()

func is_respawn_hidden() -> bool:
	return bool(_forced_hidden_reasons.get("respawn_wait", false))

func reset_for_respawn() -> void:
	_forced_hidden_reasons.clear()
	_forced_sfx_suppressed_reasons.clear()
	_refresh_state()

func _refresh_state() -> void:
	if _player == null:
		return
	var forced_visible := _forced_hidden_reasons.is_empty()
	_player.visible = forced_visible
	if _visual_root != null:
		_visual_root.visible = forced_visible
	var respawn_hidden := is_respawn_hidden()
	if _body_collision_shape != null:
		_body_collision_shape.set_deferred("disabled", respawn_hidden)
	if respawn_hidden:
		if not _respawn_collision_override_active:
			_respawn_saved_collision_layer = _player.collision_layer
			_respawn_saved_collision_mask = _player.collision_mask
			_respawn_collision_override_active = true
		_player.set_deferred("collision_layer", 0)
		_player.set_deferred("collision_mask", 0)
	elif _respawn_collision_override_active:
		_player.set_deferred("collision_layer", _respawn_saved_collision_layer)
		_player.set_deferred("collision_mask", _respawn_saved_collision_mask)
		_respawn_collision_override_active = false
