extends RefCounted
class_name CameraShake

const MAX_TRAUMA := 0.42
const DECAY := 2.8
const MAX_OFFSET := 6.0
const SPEED := 42.0

var trauma := 0.0
var noise_time := 0.0
var _explosion_override_until_msec := 0
var _explosion_decay := DECAY
var _explosion_max_offset := MAX_OFFSET

func step_offset(delta: float) -> Vector2:
	if trauma <= 0.0001:
		trauma = 0.0
		return Vector2.ZERO

	var now_msec := Time.get_ticks_msec()
	var max_offset := MAX_OFFSET
	var decay := DECAY
	if now_msec < _explosion_override_until_msec:
		max_offset = _explosion_max_offset
		decay = _explosion_decay

	noise_time += delta * SPEED
	var strength := trauma * trauma
	var x := sin(noise_time * 1.17 + 3.1) * max_offset * strength
	var y := cos(noise_time * 1.61 + 7.9) * max_offset * 0.72 * strength
	trauma = maxf(0.0, trauma - decay * delta)
	return Vector2(x, y)

func add_shake(amount: float) -> void:
	trauma = minf(MAX_TRAUMA, trauma + maxf(0.0, amount))

func add_explosion_shake(amount: float, max_trauma: float, max_offset: float, hold_sec: float = 0.0, decay: float = DECAY) -> void:
	var clamped_amount := maxf(0.0, amount)
	var target_max_trauma := clampf(max_trauma, 0.0, 1.0)
	trauma = minf(target_max_trauma, trauma + clamped_amount)
	if hold_sec > 0.0:
		_explosion_override_until_msec = Time.get_ticks_msec() + int(ceil(hold_sec * 1000.0))
		_explosion_max_offset = maxf(MAX_OFFSET, max_offset)
		_explosion_decay = maxf(0.01, decay)

func reset() -> void:
	trauma = 0.0
	noise_time = 0.0
	_explosion_override_until_msec = 0
	_explosion_decay = DECAY
	_explosion_max_offset = MAX_OFFSET
