extends RefCounted

class_name PlayerVitalsHud

const MAX_HEALTH := 100
const HEALTH_BAR_MAX_WIDTH := 61.0
const HEALTH_BAR_HEIGHT := 2.0
const DAMAGE_LAG_FOLLOW_SPEED := 6.0

var _health_label: Label
var _health_bar_green: Sprite2D
var _health_bar_damage_lag: Sprite2D
var _ammo_label: Label
var _death_audio: AudioStreamPlayer2D
var _damage_feedback_cb: Callable = Callable()
var _before_death_cb: Callable = Callable()
var _sfx_suppressed_cb: Callable = Callable()

var health := MAX_HEALTH
var max_health := MAX_HEALTH
var ammo_count := 0
var is_reloading := false
var _damage_lag_width := HEALTH_BAR_MAX_WIDTH
var _damage_lag_target_width := HEALTH_BAR_MAX_WIDTH

func configure(
	health_label: Label,
	health_bar_green: Sprite2D,
	health_bar_damage_lag: Sprite2D,
	ammo_label: Label,
	death_audio: AudioStreamPlayer2D,
	damage_feedback_cb: Callable = Callable(),
	before_death_cb: Callable = Callable(),
	sfx_suppressed_cb: Callable = Callable()
) -> void:
	_health_label = health_label
	_health_bar_green = health_bar_green
	_health_bar_damage_lag = health_bar_damage_lag
	_ammo_label = ammo_label
	_death_audio = death_audio
	_damage_feedback_cb = damage_feedback_cb
	_before_death_cb = before_death_cb
	_sfx_suppressed_cb = sfx_suppressed_cb
	_update_health_label()
	_update_ammo_label()
	_damage_lag_width = _resolved_health_width()
	_damage_lag_target_width = _damage_lag_width
	_update_damage_lag_bar()

func set_health(value: int) -> bool:
	var previous_health := health
	health = clampi(value, 0, max_health)
	_update_health_label()
	var current_width := _resolved_health_width()
	if health < previous_health:
		_damage_lag_target_width = current_width
	elif health > previous_health:
		_damage_lag_width = current_width
		_damage_lag_target_width = current_width
	_update_damage_lag_bar()
	if health < previous_health and health > 0 and _damage_feedback_cb.is_valid():
		_damage_feedback_cb.call()
	if previous_health > 0 and health <= 0:
		if _before_death_cb.is_valid():
			_before_death_cb.call()
		_play_death_audio()
		return true
	return false

func apply_damage(amount: int) -> int:
	set_health(health - max(0, amount))
	return health

func set_ammo(value: int, reloading: bool = false) -> void:
	ammo_count = maxi(0, value)
	is_reloading = reloading
	_update_ammo_label()

func get_health() -> int:
	return health

func set_max_health(value: int, clamp_current: bool = true) -> void:
	max_health = maxi(1, value)
	if clamp_current:
		health = clampi(health, 0, max_health)
	_update_health_label()
	var current_width := _resolved_health_width()
	_damage_lag_width = current_width
	_damage_lag_target_width = current_width
	_update_damage_lag_bar()

func tick(delta: float) -> void:
	if _health_bar_damage_lag == null:
		return
	if _damage_lag_width <= _damage_lag_target_width:
		_damage_lag_width = _damage_lag_target_width
		_update_damage_lag_bar()
		return
	_damage_lag_width = lerpf(_damage_lag_width, _damage_lag_target_width, minf(1.0, delta * DAMAGE_LAG_FOLLOW_SPEED))
	if absf(_damage_lag_width - _damage_lag_target_width) <= 0.1:
		_damage_lag_width = _damage_lag_target_width
	_update_damage_lag_bar()

func get_max_health() -> int:
	return max_health

func _update_health_label() -> void:
	if _health_label != null:
		_health_label.visible = false
	if _health_bar_green == null:
		return
	var width := _resolved_health_width()
	_health_bar_green.visible = width > 0.0
	_health_bar_green.region_enabled = true
	_health_bar_green.region_rect = Rect2(0.0, 0.0, width, HEALTH_BAR_HEIGHT)

func _resolved_health_width() -> float:
	var width := 0.0
	if health > 0:
		if health >= max_health:
			width = HEALTH_BAR_MAX_WIDTH
		else:
			if max_health <= 1:
				width = HEALTH_BAR_MAX_WIDTH
			else:
				width = floor(((float(health - 1) / float(max_health - 1)) * (HEALTH_BAR_MAX_WIDTH - 1.0)) + 1.0)
	return width

func _update_damage_lag_bar() -> void:
	if _health_bar_damage_lag == null:
		return
	var width := clampf(_damage_lag_width, 0.0, HEALTH_BAR_MAX_WIDTH)
	_health_bar_damage_lag.visible = width > 0.0
	_health_bar_damage_lag.region_enabled = true
	_health_bar_damage_lag.region_rect = Rect2(0.0, 0.0, width, HEALTH_BAR_HEIGHT)

func _update_ammo_label() -> void:
	if _ammo_label == null:
		return
	_ammo_label.text = "R" if is_reloading else str(ammo_count)

func _play_death_audio() -> void:
	if _sfx_suppressed_cb.is_valid() and bool(_sfx_suppressed_cb.call()):
		return
	if _death_audio == null or _death_audio.stream == null:
		return
	_death_audio.pitch_scale = randf_range(0.96, 1.04)
	_death_audio.stop()
	_death_audio.play()
