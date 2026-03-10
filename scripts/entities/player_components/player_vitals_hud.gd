extends RefCounted

class_name PlayerVitalsHud

const MAX_HEALTH := 100
const HEALTH_BAR_MAX_WIDTH := 61.0
const HEALTH_BAR_HEIGHT := 2.0

var _health_label: Label
var _health_bar_green: Sprite2D
var _ammo_label: Label
var _death_audio: AudioStreamPlayer2D
var _damage_feedback_cb: Callable = Callable()
var _before_death_cb: Callable = Callable()
var _sfx_suppressed_cb: Callable = Callable()

var health := MAX_HEALTH
var ammo_count := 0
var is_reloading := false

func configure(
	health_label: Label,
	health_bar_green: Sprite2D,
	ammo_label: Label,
	death_audio: AudioStreamPlayer2D,
	damage_feedback_cb: Callable = Callable(),
	before_death_cb: Callable = Callable(),
	sfx_suppressed_cb: Callable = Callable()
) -> void:
	_health_label = health_label
	_health_bar_green = health_bar_green
	_ammo_label = ammo_label
	_death_audio = death_audio
	_damage_feedback_cb = damage_feedback_cb
	_before_death_cb = before_death_cb
	_sfx_suppressed_cb = sfx_suppressed_cb
	_update_health_label()
	_update_ammo_label()

func set_health(value: int) -> bool:
	var previous_health := health
	health = clampi(value, 0, MAX_HEALTH)
	_update_health_label()
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

func _update_health_label() -> void:
	if _health_label != null:
		_health_label.visible = false
	if _health_bar_green == null:
		return
	var width := 0.0
	if health > 0:
		if health >= MAX_HEALTH:
			width = HEALTH_BAR_MAX_WIDTH
		else:
			width = floor(((float(health - 1) / float(MAX_HEALTH - 1)) * (HEALTH_BAR_MAX_WIDTH - 1.0)) + 1.0)
	_health_bar_green.visible = width > 0.0
	_health_bar_green.region_enabled = true
	_health_bar_green.region_rect = Rect2(0.0, 0.0, width, HEALTH_BAR_HEIGHT)

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
