extends RefCounted
class_name CameraShake

const MAX_TRAUMA := 0.42
const DECAY := 2.8
const MAX_OFFSET := 6.0
const SPEED := 42.0

var trauma := 0.0
var noise_time := 0.0

func step_offset(delta: float) -> Vector2:
	if trauma <= 0.0001:
		trauma = 0.0
		return Vector2.ZERO

	noise_time += delta * SPEED
	var strength := trauma * trauma
	var x := sin(noise_time * 1.17 + 3.1) * MAX_OFFSET * strength
	var y := cos(noise_time * 1.61 + 7.9) * MAX_OFFSET * 0.72 * strength
	trauma = maxf(0.0, trauma - DECAY * delta)
	return Vector2(x, y)

func add_shake(amount: float) -> void:
	trauma = minf(MAX_TRAUMA, trauma + maxf(0.0, amount))

func reset() -> void:
	trauma = 0.0
	noise_time = 0.0
