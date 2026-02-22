extends RefCounted

class_name PlayerVitalsHud

const MAX_HEALTH := 100

var _health_label: Label
var _ammo_label: Label
var _death_audio: AudioStreamPlayer2D

var health := MAX_HEALTH
var ammo_count := 0
var is_reloading := false

func configure(health_label: Label, ammo_label: Label, death_audio: AudioStreamPlayer2D) -> void:
	_health_label = health_label
	_ammo_label = ammo_label
	_death_audio = death_audio
	_update_health_label()
	_update_ammo_label()

func set_health(value: int) -> bool:
	var previous_health := health
	health = clampi(value, 0, MAX_HEALTH)
	_update_health_label()
	if previous_health > 0 and health <= 0:
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
		_health_label.text = str(health)

func _update_ammo_label() -> void:
	if _ammo_label == null:
		return
	_ammo_label.text = "R" if is_reloading else str(ammo_count)

func _play_death_audio() -> void:
	if _death_audio == null or _death_audio.stream == null:
		return
	_death_audio.pitch_scale = randf_range(0.96, 1.04)
	_death_audio.stop()
	_death_audio.play()

