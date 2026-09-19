extends SceneTree
const RECOIL := preload("res://scripts/kw3d/ak_recoil.gd")
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
		push_error("AK_RECOIL_FAIL " + label)

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var hip = RECOIL.new()
	var ads = RECOIL.new()
	var hip_kicks: Array[Vector2] = []
	var ads_kicks: Array[Vector2] = []
	for i in range(12):
		hip_kicks.append(hip.kick(false))
		ads_kicks.append(ads.kick(true))
	check(hip_kicks[0].y > 0.0, "first_shot_climbs")
	check(hip_kicks[7].y > hip_kicks[0].y, "spray_builds")
	var hip_total := 0.0
	var ads_total := 0.0
	for kick in hip_kicks:
		hip_total += kick.y
	for kick in ads_kicks:
		ads_total += kick.y
	check(ads_total < hip_total * 0.76, "ads_reduces_recoil")
	check(absf(rad_to_deg(hip.debt().x)) < RECOIL.MAX_YAW_DEBT_DEG + 0.001, "yaw_bounded")
	check(rad_to_deg(hip.debt().y) < RECOIL.MAX_PITCH_DEBT_DEG + 0.001, "pitch_bounded")

	var clone = RECOIL.new()
	for i in range(12):
		var expected: Vector2 = hip_kicks[i]
		var actual: Vector2 = clone.kick(false)
		check(actual.distance_to(expected) < 0.000001, "deterministic_%02d" % i)

	var compensated = RECOIL.new()
	var first: Vector2 = compensated.kick(false)
	compensated.note_manual_look(0.0, -first.y * 0.55)
	check(compensated.debt().y < first.y * 0.50, "manual_counter_reduces_debt")
	var recovery = RECOIL.new()
	for i in range(6):
		recovery.kick(false)
	var before: float = recovery.debt().y
	for i in range(45):
		recovery.step(1.0 / 60.0, false)
	check(recovery.debt().y < before * 0.25, "release_recovers")
	recovery.reset()
	var first_again: Vector2 = recovery.kick(false)
	check(first_again.distance_to(hip_kicks[0]) < 0.000001, "reset_restores_first_shot")

	var burst = RECOIL.new()
	burst.kick(false)
	for i in range(20):
		burst.step(1.0 / 60.0, false)
	var after_pause: Vector2 = burst.kick(false)
	check(after_pause.distance_to(hip_kicks[0]) < 0.000001, "pause_resets_pattern")
	print("AK_RECOIL_QA_", "PASS" if failures.is_empty() else "FAIL", failures,
		" hip12_deg=", rad_to_deg(hip_total), " ads12_deg=", rad_to_deg(ads_total))
	quit(0 if failures.is_empty() else 1)
