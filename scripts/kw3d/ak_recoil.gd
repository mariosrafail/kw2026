extends RefCounted
## Shared AK aim recoil for offline and network play. No bullet spread: this moves the real aim ray.
const PITCH_PATTERN_DEG := [0.32,0.38,0.44,0.52,0.60,0.68,0.74,0.80,0.86,0.90,0.94,0.98]
const YAW_PATTERN_DEG := [0.00,0.05,0.08,0.10,0.11,-0.06,-0.09,-0.11,-0.12,0.08,0.10,-0.08]
const ADS_SCALE := 0.72
const RESET_DELAY := 0.28
const RECOVERY_DELAY := 0.075
const PITCH_RECOVERY_DEG_PER_SEC := 9.5
const YAW_RECOVERY_DEG_PER_SEC := 12.0
const MAX_PITCH_DEBT_DEG := 11.0
const MAX_YAW_DEBT_DEG := 1.8

var shot_index := 0
var since_shot := 999.0
var pitch_debt := 0.0
var yaw_debt := 0.0

func reset() -> void:
	shot_index = 0
	since_shot = 999.0
	pitch_debt = 0.0
	yaw_debt = 0.0
func kick(aiming: bool) -> Vector2:
	var index := mini(shot_index, PITCH_PATTERN_DEG.size() - 1)
	var scale := ADS_SCALE if aiming else 1.0
	var pitch_kick := deg_to_rad(float(PITCH_PATTERN_DEG[index]) * scale)
	var yaw_kick := deg_to_rad(float(YAW_PATTERN_DEG[index]) * scale)
	var pitch_limit := deg_to_rad(MAX_PITCH_DEBT_DEG)
	var yaw_limit := deg_to_rad(MAX_YAW_DEBT_DEG)
	var next_pitch := clampf(pitch_debt + pitch_kick, 0.0, pitch_limit)
	var next_yaw := clampf(yaw_debt + yaw_kick, -yaw_limit, yaw_limit)
	var applied := Vector2(next_yaw - yaw_debt, next_pitch - pitch_debt)
	yaw_debt = next_yaw
	pitch_debt = next_pitch
	shot_index += 1
	since_shot = 0.0
	return applied

func note_manual_look(delta_yaw: float, delta_pitch: float) -> void:
	if pitch_debt > 0.0 and delta_pitch < 0.0:
		pitch_debt = maxf(0.0, pitch_debt + delta_pitch)
	if absf(yaw_debt) > 0.000001 and delta_yaw * yaw_debt < 0.0:
		var amount := minf(absf(yaw_debt), absf(delta_yaw))
		yaw_debt -= signf(yaw_debt) * amount
func step(dt: float, trigger_held: bool) -> Vector2:
	since_shot += maxf(0.0, dt)
	if since_shot >= RESET_DELAY:
		shot_index = 0
	if trigger_held or since_shot < RECOVERY_DELAY:
		return Vector2.ZERO
	var pitch_amount := minf(pitch_debt, deg_to_rad(PITCH_RECOVERY_DEG_PER_SEC) * dt)
	var yaw_amount := minf(absf(yaw_debt), deg_to_rad(YAW_RECOVERY_DEG_PER_SEC) * dt)
	var result := Vector2.ZERO
	if yaw_amount > 0.0:
		result.x = -signf(yaw_debt) * yaw_amount
		yaw_debt += result.x
	if pitch_amount > 0.0:
		result.y = -pitch_amount
		pitch_debt -= pitch_amount
	return result

func debt() -> Vector2:
	return Vector2(yaw_debt, pitch_debt)
