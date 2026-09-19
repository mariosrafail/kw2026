extends Node
## Local prototype mix. Original arena music plus the project's existing movement/weapon SFX.
const MUSIC := preload("res://assets/prototypes/audio/kw_neon_riot_loop.res")
const STEPS := [preload("res://assets/sounds/sfx/ground/wood/wood_step_1.wav"), preload("res://assets/sounds/sfx/ground/wood/wood_step_2.wav"), preload("res://assets/sounds/sfx/ground/wood/wood_step_3.wav"), preload("res://assets/sounds/sfx/ground/wood/wood_step_4.wav")]
const SOUNDS := {
	"jump": preload("res://assets/sounds/sfx/ground/wood/wood_jump.wav"),
	"land": preload("res://assets/sounds/sfx/ground/wood/wood_land.wav"),
	"throw": preload("res://assets/sounds/sfx/guns/grenade/launcher_shoot.wav"),
	"bounce": preload("res://assets/sounds/sfx/ground/wood/wood_step_3.wav"),
	"explosion": preload("res://assets/sounds/sfx/guns/grenade/launcher_boom.wav"),
	"wave": preload("res://assets/sounds/sfx/general/levelup_bell.wav"),
	"heal": preload("res://assets/sounds/sfx/general/log_update.wav"),
	"death": preload("res://assets/sounds/sfx/general/death.wav"),
	"switch": preload("res://assets/sounds/sfx/menu_placeholders/menu_click.wav")
}
var stage: Node3D
var music: AudioStreamPlayer
var music_enabled := true
var qa_muted := false
var spatial_pool: Array[AudioStreamPlayer3D] = []
var ui_pool: Array[AudioStreamPlayer] = []
var foot_states: Dictionary = {}
var was_grounded := false
var initialized := false
var duck := 0.0
var heal_gate := 0.0
var event_counts: Dictionary = {}
var rng := RandomNumberGenerator.new()

func setup(owner_stage: Node3D) -> void:
	stage = owner_stage
	name = "ArenaAudio"
	qa_muted = OS.get_cmdline_user_args().has("--kw-qa")
	rng.randomize()
	music = AudioStreamPlayer.new()
	music.name = "FightSoundtrack"
	var loop := MUSIC.duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music.stream = loop
	music.volume_db = -80.0 if qa_muted else -23.0
	add_child(music)
	if not qa_muted: music.play()
	for i in range(12):
		var player := AudioStreamPlayer3D.new()
		player.name = "SpatialSFX%02d" % i
		player.max_polyphony = 1
		player.max_distance = 42.0
		player.unit_size = 6.0
		add_child(player)
		spatial_pool.append(player)
	for i in range(3):
		var player := AudioStreamPlayer.new()
		player.name = "UISFX%02d" % i
		add_child(player)
		ui_pool.append(player)

func toggle_music() -> void:
	music_enabled = not music_enabled
	if music_enabled and not music.playing and not qa_muted: music.play()

func play_event(key: String, point: Vector3 = Vector3.ZERO, volume: float = -16.0) -> void:
	if not SOUNDS.has(key): return
	if key == "heal":
		if heal_gate > 0.0: return
		heal_gate = 0.16
	event_counts[key] = int(event_counts.get(key, 0)) + 1
	if qa_muted: return
	if key in ["wave", "heal", "death", "switch"]:
		for player in ui_pool:
			if not player.playing:
				player.stream = SOUNDS[key]
				player.volume_db = volume
				player.play()
				break
	else:
		_play_spatial(SOUNDS[key], point, volume, 1.0)
	if key == "explosion": duck = 0.45

func _play_spatial(stream: AudioStream, point: Vector3, volume: float, pitch_value: float) -> void:
	if qa_muted: return
	var chosen: AudioStreamPlayer3D
	for player in spatial_pool:
		if not player.playing:
			chosen = player
			break
	if chosen == null: return # Cosmetic pool is bounded; never stack dozens of footsteps.
	chosen.stream = stream
	chosen.global_position = point
	chosen.volume_db = volume
	chosen.pitch_scale = pitch_value
	chosen.unit_size = 10.0 if volume >= -11.0 else 6.0
	chosen.play()

func _feet(key: int, motion: RefCounted, volume: float) -> void:
	if motion == null: return
	var prior: Array = foot_states.get(key, [false, false])
	for i in range(motion.feet.size()):
		var foot = motion.feet[i]
		if prior[i] and not foot.swinging and foot.phase != "AIR" and motion.actor.is_on_floor():
			event_counts["step"] = int(event_counts.get("step", 0)) + 1
			_play_spatial(STEPS[rng.randi_range(0, STEPS.size()-1)], foot.node.global_position, volume, rng.randf_range(0.92,1.08))
		prior[i] = foot.swinging
	foot_states[key] = prior

func _physics_process(delta: float) -> void:
	if stage == null or stage.player == null: return
	if stage.combat != null and stage.combat.director.suspended: return
	if not qa_muted and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return
	if stage.combat != null and stage.combat.is_game_over(): return
	var grounded: bool = stage.player.is_on_floor()
	if initialized:
		if was_grounded and not grounded and stage.player.velocity.y > 1.0:
			play_event("jump", stage.player.global_position, -17.0)
		elif grounded and not was_grounded:
			play_event("land", stage.player.global_position, -15.0)
	initialized = true
	was_grounded = grounded
	_feet(0, stage.locomotion, -18.0)
	var live_keys: Dictionary = {0:true}
	if stage.combat != null:
		for bot in stage.combat.targets:
			if not is_instance_valid(bot) or bot.dead: continue
			var key: int = bot.get_instance_id()
			live_keys[key] = true
			if bot.global_position.distance_to(stage.player.global_position) < 16.0:
				_feet(key, bot.locomotion, -26.0)
	for key in foot_states.keys():
		if not live_keys.has(key): foot_states.erase(key)

func _process(delta: float) -> void:
	if music == null: return
	duck = maxf(0.0, duck-delta)
	heal_gate = maxf(0.0, heal_gate-delta)
	var resting: bool = stage.combat != null and stage.combat.director.phase != "WAVE"
	var target := -23.0 if resting else -18.0
	if stage.fire_held: target -= 2.5
	if duck > 0.0: target -= 4.0
	if not music_enabled: target = -80.0
	if qa_muted: target = -80.0
	music.volume_db = lerpf(music.volume_db, target, 1.0-exp(-4.0*delta))
	var paused: bool = stage.combat != null and stage.combat.director.suspended
	music.stream_paused = paused or (not qa_muted and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not resting)
