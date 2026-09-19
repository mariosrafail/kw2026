extends Node3D

const ARENA_AUDIO := preload("res://scripts/prototypes/kw_arena_audio.gd")
const GRENADE_SKILL := preload("res://scripts/prototypes/kw_grenade_skill.gd")
const SCENE_INK := preload("res://scripts/prototypes/kw_scene_ink.gd")
const AK_INK_HULL := preload("res://assets/prototypes/ak47_outline/hull.res")
const WEAPON_HOLD_HEIGHT := 0.80
var arena_audio: Node
var grenade_skill: Node3D
var comic_enabled := true
var offline_test_mode := "waves"

@export_range(0.0, 2.0, 0.05) var ragdoll_playfulness := 1.2
var locomotion: RefCounted
var combat: Node3D
var weapon_side := -1.0
var smoothed_weapon_side := -1.0
const CAMERA_SHOULDER_X := 1.20
const AIM_RETICLE := preload("res://scripts/prototypes/kw_aim_reticle.gd")
var camera_boom_z := 6.4
var camera_safe_fraction := 1.0
var camera_probe: SphereShape3D
const COMBAT_RANGE := preload("res://scripts/prototypes/kw_combat_range.gd")
var animation_impact_velocity := 0.0
const LOCOMOTION := preload("res://scripts/prototypes/kw_goofy_locomotion.gd")

var player: CharacterBody3D
var player_visual: Node3D
var camera_yaw: Node3D
var camera_pitch: Node3D
var camera: Camera3D
var status_label: Label
var help_panel: Control
var instructions_visible := true
@export_range(-30.0, -1.0, 0.5) var shooting_volume_db := -7.5
var weapon_aim_pivot: Node3D
var weapon_root: Node3D
var weapon_visual_wobble: Node3D
var weapon_muzzle: Marker3D
var ak_fire_audio: AudioStreamPlayer3D
var pixel_enabled := true
var pixel_materials: Array[WeakRef] = []
var pixel_post_layer: CanvasLayer
var aim_target := Vector3.ZERO

var head_rig: Node3D
var torso_rig: Node3D
var left_leg_rig: Node3D
var right_leg_rig: Node3D

var yaw := 0.0
var pitch := deg_to_rad(-10.0)
var low_gravity := false
var shot_cooldown := 0.0
var voxel_material_cache: Dictionary = {}
var body_yaw := 0.0
var aiming := false
var fire_held := false
var weapon_recoil := 0.0
var weapon_visual_side_kick := 0.0
var weapon_visual_lift_kick := 0.0
var weapon_visual_twist_kick := 0.0

var anim_time := 0.0
var walk_phase := 0.0
var move_blend := 0.0
var air_blend := 0.0
var was_on_floor := true
var previous_vertical_velocity := 0.0
var landing_kick := 0.0
var smoothed_horizontal_velocity := Vector3.ZERO
var previous_horizontal_velocity := Vector3.ZERO
var torso_spring_rotation := Vector3.ZERO
var torso_spring_velocity := Vector3.ZERO
var head_spring_rotation := Vector3.ZERO
var head_spring_velocity := Vector3.ZERO
var head_style: Node3D
var head_rest := Vector3.ZERO
var torso_rest := Vector3.ZERO
var left_leg_rest := Vector3.ZERO
var right_leg_rest := Vector3.ZERO
var head_last_body_yaw := 0.0
var head_was_grounded := false
var head_motion_initialized := false

const PIXEL_MATERIALS := preload("res://scripts/prototypes/kw_pixel_materials.gd")
const PIXEL_SCREEN := preload("res://scripts/prototypes/kw_pixel_screen.gdshader")
const WEAPON_HOLD_DISTANCE := 0.98
const WEAPON_HOLD_SIDE := 1.10
const MOVE_SPEED := 7.5
const SPRINT_SPEED := 11.0
const ACCEL := 28.0
const TURN_SPEED := 10.0
const JUMP_SPEED := 7.4
const GRAVITY := 19.5
const VOXEL_UNIT := 0.082
const RIG_CENTER_X := 2.0
const RIG_CENTER_Y := -4.0
const OUTRAGE_FULLBODY := preload("res://scenes/prototypes/characters/outrage_fullbody.tscn")
const AK47_VOXEL_BUILDER := preload("res://scripts/prototypes/ak47_voxel_builder.gd")
const AK47_SHOT_SFX := preload("res://assets/sounds/sfx/guns/ak47/ak_shoot.wav")
const AK_FIRE_INTERVAL := 0.10

func _ready() -> void:
	# The baked preview exists only for the editor; runtime builds the same arena.
	var preview := get_node_or_null("EditorPreview")
	if preview != null:
		remove_child(preview)
		preview.free()
	randomize()
	_build_environment()
	_build_arena()
	_build_player()
	locomotion = LOCOMOTION.new()
	locomotion.setup(player, player_visual, head_rig, torso_rig, left_leg_rig, right_leg_rig, randi())
	_build_pixel_pass()
	_build_hud()
	arena_audio = ARENA_AUDIO.new()
	add_child(arena_audio)
	arena_audio.setup(self)
	combat = COMBAT_RANGE.new()
	add_child(combat)
	combat.setup(self)
	offline_test_mode = str(ProjectSettings.get_setting("kw3d/offline_test_mode", "waves")).strip_edges().to_lower()
	_apply_offline_test_mode()
	grenade_skill = GRENADE_SKILL.new()
	add_child(grenade_skill)
	grenade_skill.setup(self)
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--kw-qa"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _apply_offline_test_mode() -> void:
	if combat == null or combat.director == null:
		return
	if offline_test_mode == "sandbox":
		combat.director.advancement_enabled = false
		combat.director.attacks_enabled = false
		combat.set_roaming_enabled(false)
		combat.director.hud.announce("SANDBOX / AIM LAB", "3 STATIONARY TARGETS  //  NO WAVES  //  NO ENEMY FIRE", 3.2)
	else:
		offline_test_mode = "waves"
		combat.director.advancement_enabled = true
		combat.director.attacks_enabled = true
		combat.set_roaming_enabled(true)
	_update_status()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F10:
		ProjectSettings.set_setting("kw3d/open_offline_tests_on_load", true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		if arena_audio != null: arena_audio.toggle_music()
		return
	if combat != null and combat.is_game_over():
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER,KEY_B]:
			combat.director.restart_run()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		# Captured screen delta is independent of the low-resolution canvas scale.
		# FOV compensation keeps small ADS adjustments controllable, without smoothing lag.
		var sensitivity := tan(deg_to_rad(camera.fov) * 0.5) / tan(deg_to_rad(74.0) * 0.5)
		yaw -= event.screen_relative.x * 0.0016 * sensitivity
		pitch -= event.screen_relative.y * 0.0013 * sensitivity
		pitch = clamp(pitch, deg_to_rad(-48.0), deg_to_rad(30.0))
		camera_yaw.rotation.y = yaw
		camera_pitch.rotation.x = pitch

	if event is InputEventMouseButton:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			fire_held = false
			aiming = false
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			aiming = event.pressed
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not fire_held: shot_cooldown = maxf(0.0, shot_cooldown)
			fire_held = event.pressed

	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
			if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
				fire_held = false
				aiming = false
		elif event.physical_keycode == KEY_TAB:
			_toggle_instructions()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_B:
			if combat != null: combat.reset_targets()
		elif event.physical_keycode == KEY_G:
			if grenade_skill != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED: grenade_skill.requested = true
		elif event.physical_keycode == KEY_Q:
			weapon_side *= -1.0
			if arena_audio != null: arena_audio.play_event("switch", Vector3.ZERO, -22.0)
		elif event.physical_keycode == KEY_P:
			_set_pixel_enabled(not pixel_enabled)
		elif event.physical_keycode == KEY_O:
			_set_comic_enabled(not comic_enabled)
		elif event.physical_keycode == KEY_R:
			_spawn_chaos_drop()
		elif event.physical_keycode == KEY_F:
			low_gravity = not low_gravity
			_update_status()
func _physics_process(delta: float) -> void:
	if player == null:
		return
	if combat != null and combat.is_game_over():
		player.velocity = Vector3.ZERO
		return
	shot_cooldown = maxf(-delta, shot_cooldown - delta)

	var input_vec := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		input_vec.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input_vec.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		input_vec.y += 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input_vec.y -= 1.0
	input_vec = input_vec.normalized()

	var forward := -camera_yaw.global_transform.basis.z
	var right := camera_yaw.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	var direction := (right.normalized() * input_vec.x + forward.normalized() * input_vec.y).normalized()
	var sprinting := Input.is_physical_key_pressed(KEY_SHIFT) and not aiming
	var move_speed := SPRINT_SPEED if sprinting else MOVE_SPEED
	var target_x := direction.x * move_speed
	var target_z := direction.z * move_speed
	player.velocity.x = move_toward(player.velocity.x, target_x, ACCEL * delta)
	player.velocity.z = move_toward(player.velocity.z, target_z, ACCEL * delta)

	# Free camera while moving. While aiming, body faces the crosshair/camera
	# so A/D become strafe and S becomes backpedal, GTA-style.
	var face_direction := direction
	if aiming or fire_held:
		face_direction = forward.normalized()
	if face_direction.length_squared() > 0.001:
		var target_body_yaw := atan2(-face_direction.x, -face_direction.z)
		body_yaw = lerp_angle(body_yaw, target_body_yaw, clampf(TURN_SPEED * delta, 0.0, 1.0))
		player_visual.rotation.y = body_yaw

	var gravity_strength := GRAVITY * (0.32 if low_gravity else 1.0)
	if not player.is_on_floor():
		player.velocity.y -= gravity_strength * delta
	elif Input.is_physical_key_pressed(KEY_SPACE):
		player.velocity.y = JUMP_SPEED * (1.18 if low_gravity else 1.0)

	animation_impact_velocity = player.velocity.y
	player.move_and_slide()

	_update_third_person_camera(delta)
	_update_character_animation(delta)
	_update_weapon_pose(delta)
	if fire_held and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_fire_physics_ball()

	if player.global_position.y < -15.0:
		player.global_position = Vector3(0.0, 3.0, 6.0)
		player.velocity = Vector3.ZERO

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.025, 0.03, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.24, 0.42)
	env.ambient_light_energy = 1.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color(0.78, 0.84, 1.0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	add_child(sun)

	_add_neon_light(Vector3(-8.0, 4.0, -5.0), Color(0.0, 0.75, 1.0), 11.0)
	_add_neon_light(Vector3(8.0, 4.0, -5.0), Color(1.0, 0.12, 0.42), 11.0)

func _build_arena() -> void:
	# 48 x 48, four times the old floor area. Keep the central prototype layout.
	_add_static_box("Floor", Vector3(0, -0.5, -6), Vector3(48, 1, 48), Color(0.075, 0.08, 0.11))
	_add_static_box("BackWall", Vector3(0, 3.0, -30.0), Vector3(48, 7, 0.8), Color(0.055, 0.06, 0.09))
	_add_static_box("LeftWall", Vector3(-24.0, 2.0, -6), Vector3(0.8, 5, 48), Color(0.055, 0.06, 0.09))
	_add_static_box("RightWall", Vector3(24.0, 2.0, -6), Vector3(0.8, 5, 48), Color(0.055, 0.06, 0.09))
	_add_static_box("FrontWall", Vector3(0, 2.0, 18), Vector3(48, 5, 0.8), Color(0.055, 0.06, 0.09))
	_add_static_box("PlatformBlue", Vector3(-5.5, 0.65, -3.8), Vector3(5.2, 1.3, 3.2), Color(0.03, 0.26, 0.38))
	_add_static_box("PlatformPink", Vector3(5.5, 1.15, -5.0), Vector3(4.6, 2.3, 3.2), Color(0.36, 0.04, 0.15))
	_add_static_box("CenterBlock", Vector3(0, 0.9, 0), Vector3(3.2, 1.8, 3.2), Color(0.18, 0.08, 0.30))
	_add_ramp("RampA", Vector3(-4.8, 0.65, 2.5), Vector3(5.5, 0.7, 3.0), Vector3(-12, 0, 0), Color(0.10, 0.12, 0.20))
	_add_ramp("RampB", Vector3(5.4, 0.85, 3.0), Vector3(5, 0.7, 3), Vector3(15, 0, 0), Color(0.12, 0.08, 0.18))
	_add_static_box("LeftCover", Vector3(-14, 0.70, -12), Vector3(3, 1.4, 4), Color(0.035, 0.20, 0.28))
	_add_static_box("RightCover", Vector3(14, 0.70, -12), Vector3(3, 1.4, 4), Color(0.28, 0.035, 0.12))
	_add_static_box("RearCoverLeft", Vector3(-6, 0.5, -25), Vector3(3.5, 1, 2), Color(0.10, 0.12, 0.22))
	_add_static_box("RearCoverRight", Vector3(6, 0.5, -25), Vector3(3.5, 1, 2), Color(0.18, 0.08, 0.20))
	_add_ramp("OuterRampLeft", Vector3(-19, 0.45, -17), Vector3(3, 0.6, 5), Vector3(-8, 0, 0), Color(0.08, 0.15, 0.22))
	_add_ramp("OuterRampRight", Vector3(19, 0.45, -17), Vector3(3, 0.6, 5), Vector3(-8, 0, 0), Color(0.22, 0.06, 0.16))
	for z in [-28.0, -20.0, -12.0, -4.0, 4.0, 12.0, 16.0]:
		for side in [-1.0, 1.0]:
			var tint := Color(0, 0.8, 1) if side < 0 else Color(1, 0.08, 0.40)
			_add_neon_strip(Vector3(side * 22.8, 0.03, z), tint)
	for x in [-19.0, -13.0, -7.0, -1.0, 5.0, 11.0, 17.0]:
		_add_neon_strip(Vector3(x, 0.03, -28.8), Color(0, 0.8, 1) if x < 0 else Color(1, 0.1, 0.42))
	_add_bounce_pad(Vector3(-8, 0.15, 6.5), Color(0, 0.85, 1))
	_add_bounce_pad(Vector3(8, 0.15, 6.5), Color(1, 0.08, 0.4))
	_add_kw_sign()
func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Outrage3D"
	player.collision_layer = 2
	player.collision_mask = 9 # world and clone movement capsules; exact hitboxes are shot-only
	player.position = Vector3(0, 2.2, 6.0)
	add_child(player)

	var collision := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.52
	capsule_shape.height = 3.05
	collision.shape = capsule_shape
	player.add_child(collision)

	player_visual = Node3D.new()
	player_visual.name = "OutrageVisual"
	player.add_child(player_visual)
	_build_outage_voxel_body()
	capsule_shape.height = float(head_style.get_meta("capsule_height", 3.43))
	player_visual.rotation.y = body_yaw

	var name_tag := Label3D.new()
	name_tag.text = "OUTRAGE // STREET ZERO"
	# Own-player name is not needed in the aiming lane.
	name_tag.visible = false
	name_tag.position = Vector3(0, 1.9, 0)
	name_tag.font_size = 48
	name_tag.outline_size = 10
	name_tag.modulate = Color(0.72, 0.92, 1.0)
	name_tag.outline_modulate = Color(0.05, 0.05, 0.08)
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	player_visual.add_child(name_tag)

	camera_yaw = Node3D.new()
	camera_yaw.position = Vector3(0, 1.05, 0)
	player.add_child(camera_yaw)

	camera_pitch = Node3D.new()
	camera_yaw.add_child(camera_pitch)

	camera = Camera3D.new()
	# Slight over-the-shoulder framing, closer to a GTA-style third-person camera.
	camera.position = Vector3(CAMERA_SHOULDER_X, 1.35, 6.4)
	camera.fov = 74.0
	camera.current = true
	camera_pitch.add_child(camera)

	camera_yaw.rotation.y = yaw
	camera_pitch.rotation.x = pitch

func _build_outage_voxel_body() -> void:
	# One authored source for geometry, UVs, rest positions and pivots.
	head_style = OUTRAGE_FULLBODY.instantiate() as Node3D
	player_visual.add_child(head_style)
	head_rig = head_style.get_node("HeadRig") as Node3D
	torso_rig = head_style.get_node("TorsoRig") as Node3D
	left_leg_rig = head_style.get_node("LeftLegRig") as Node3D
	right_leg_rig = head_style.get_node("RightLegRig") as Node3D
	# Runtime separation only: authored Blockbench model stays untouched.
	head_rig.position += Vector3(0.0, 0.10, -0.20)
	torso_rig.position += Vector3(0.0, -0.12, 0.12)
	head_rest = head_rig.position
	torso_rest = torso_rig.position
	left_leg_rest = left_leg_rig.position
	right_leg_rest = right_leg_rig.position
	_build_held_ak()

func _build_held_ak() -> void:
	weapon_aim_pivot = Node3D.new()
	weapon_aim_pivot.name = "WeaponAimPivot"
	weapon_aim_pivot.position = Vector3(-WEAPON_HOLD_SIDE, torso_rest.y + WEAPON_HOLD_HEIGHT, -WEAPON_HOLD_DISTANCE)
	player_visual.add_child(weapon_aim_pivot)

	weapon_root = Node3D.new()
	weapon_root.name = "AK47Voxel"
	weapon_root.position = Vector3(0.10, 0.0, -0.24)
	weapon_root.rotation.y = PI * 0.5
	weapon_aim_pivot.add_child(weapon_root)
	AK47_VOXEL_BUILDER.build(weapon_root)
	_pixelize_weapon_materials()
	_build_weapon_outline()
	weapon_visual_wobble = Node3D.new()
	weapon_visual_wobble.name = "WeaponVisualWobble"
	weapon_root.add_child(weapon_visual_wobble)
	for child in weapon_root.get_children().duplicate():
		if child is MeshInstance3D:
			child.reparent(weapon_visual_wobble, false)

	weapon_muzzle = Marker3D.new()
	weapon_muzzle.name = "Muzzle"
	weapon_muzzle.position = Vector3(1.34, 0.02, 0.0)
	weapon_root.add_child(weapon_muzzle)

	_add_weapon_hand("RightHand", Vector3(0.31, -0.07, -0.50), Vector3(0.22, 0.22, 0.28))

	ak_fire_audio = AudioStreamPlayer3D.new()
	ak_fire_audio.name = "AKFireAudio"
	ak_fire_audio.stream = AK47_SHOT_SFX
	ak_fire_audio.volume_db = -80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db
	ak_fire_audio.max_distance = 28.0
	ak_fire_audio.unit_size = 2.8
	ak_fire_audio.max_polyphony = 8
	weapon_aim_pivot.add_child(ak_fire_audio)

func _add_weapon_hand(node_name: String, pos: Vector3, size: Vector3) -> void:
	var hand := MeshInstance3D.new()
	hand.name = node_name
	var box := BoxMesh.new()
	box.size = size
	hand.mesh = box
	hand.position = pos
	hand.set_meta("hold_rest",pos)
	hand.material_override = _material(Color(0.56, 0.11, 0.15), false, 0.0)
	weapon_aim_pivot.add_child(hand)
	_add_scene_outline(hand, 1.6)

func _update_third_person_camera(delta: float) -> void:
	if camera == null:
		return
	var weight := 1.0 - exp(-12.0 * maxf(delta, 0.0))
	camera_boom_z = lerpf(camera_boom_z, 3.80 if aiming else 6.40, weight)
	camera.fov = lerpf(camera.fov, 58.0 if aiming else 74.0, weight)
	# Zoom along the SAME optical ray: changing aim must not slide the crosshair
	# sideways/upwards off a stationary enemy as the shoulder camera transitions.
	var desired_local := Vector3(CAMERA_SHOULDER_X, 1.35, camera_boom_z)
	var origin := camera_yaw.global_position
	var desired_world := camera_pitch.to_global(desired_local)
	if camera_probe == null:
		camera_probe = SphereShape3D.new()
		camera_probe.radius = 0.18
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = camera_probe
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.motion = desired_world - origin
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	query.margin = 0.025
	var safe := get_world_3d().direct_space_state.cast_motion(query)
	var fraction := safe[0] if safe.size() >= 2 else 1.0
	if fraction < 0.999:
		fraction = maxf(0.0, fraction - 0.035 / maxf(query.motion.length(), 0.1))
	if fraction < camera_safe_fraction:
		camera_safe_fraction = fraction
	else:
		camera_safe_fraction = lerpf(camera_safe_fraction, fraction, 1.0 - exp(-16.0 * delta))
	camera.global_position = origin.lerp(desired_world, camera_safe_fraction)

func _get_aim_target() -> Vector3:
	if combat != null:
		return combat.camera_target()
	return camera.global_position - camera.global_basis.z * 120.0

func _update_weapon_pose(delta: float) -> void:
	if weapon_aim_pivot == null or weapon_root == null or camera == null:
		return
	aim_target = _get_aim_target()
	# A floating two-hand hold to the LEFT of the torso, rather than a pole in front.
	# During shoulder swapping the rifle follows an arc in front, not through the body.
	smoothed_weapon_side = move_toward(smoothed_weapon_side, weapon_side, maxf(0.0,delta)*7.0)
	var chest := _weapon_anchor()
	var forward := (aim_target - chest).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01: right = camera.global_basis.x.normalized()
	var swap_clearance := (1.0-absf(smoothed_weapon_side))*1.80
	var loose_amount := ragdoll_playfulness * (0.35 + move_blend * 0.65)
	var hand_bob := sin(anim_time * 8.2 + walk_phase * 0.18) * 0.055 * move_blend * loose_amount
	var hand_lag := sin(anim_time * 4.1 + 0.7) * 0.035 * loose_amount
	weapon_aim_pivot.global_position = chest + forward*(WEAPON_HOLD_DISTANCE+swap_clearance + 0.08*move_blend) + right*(WEAPON_HOLD_SIDE*smoothed_weapon_side + hand_lag) + Vector3.UP*hand_bob
	weapon_recoil = move_toward(weapon_recoil, 0.0, delta*9.5)
	weapon_visual_side_kick = move_toward(weapon_visual_side_kick,0.0,delta*1.8)
	weapon_visual_lift_kick = move_toward(weapon_visual_lift_kick,0.0,delta*1.8)
	weapon_visual_twist_kick = move_toward(weapon_visual_twist_kick,0.0,delta*2.2)
	var distance := weapon_aim_pivot.global_position.distance_to(aim_target)
	# Retract the hold at close cover so the barrel cannot extend past its target.
	var retraction := maxf(0.0,1.72-distance)
	weapon_root.position.x = 0.10 + sin(anim_time*5.7)*0.025*loose_amount
	weapon_root.position.y = sin(anim_time*7.4+1.1)*0.035*move_blend*loose_amount
	weapon_root.position.z = -0.30 + weapon_recoil*0.10 + retraction
	weapon_aim_pivot.look_at(aim_target, Vector3.UP)
	# Exact off-axis muzzle convergence, including targets close to the shoulder.
	var m := weapon_root.transform * weapon_muzzle.position
	var along := sqrt(maxf(0.00001,distance*distance-m.x*m.x-m.y*m.y))
	var local_target := Vector3(m.x,m.y,-along).normalized()
	weapon_aim_pivot.global_basis = weapon_aim_pivot.global_basis * Basis(Quaternion(local_target,Vector3.FORWARD))
	# The weapon is visually held by one floating hand. A bounded local wobble makes it funny
	# without changing the camera target or server-side hit direction.
	var one_hand_pitch := sin(anim_time*6.3+0.4)*0.045*loose_amount + weapon_recoil*0.055
	var one_hand_roll := sin(anim_time*4.8+1.6)*(0.075+0.045*move_blend)*loose_amount - weapon_recoil*0.14
	weapon_root.rotation = Vector3(0.0, PI*0.5, 0.0)
	if weapon_visual_wobble != null:
		weapon_visual_wobble.position = Vector3(weapon_visual_side_kick,weapon_visual_lift_kick,weapon_recoil*0.05)
		weapon_visual_wobble.rotation = Vector3(one_hand_pitch, 0.0, one_hand_roll + weapon_visual_twist_kick)
	for child in weapon_aim_pivot.get_children():
		if child.has_meta("hold_rest"):
			var hand_rest: Vector3 = child.get_meta("hold_rest")
			child.position = hand_rest + Vector3(sin(anim_time*5.2)*0.035*loose_amount + weapon_visual_side_kick*0.65, cos(anim_time*6.8)*0.025*loose_amount + weapon_visual_lift_kick*0.65, weapon_root.position.z+0.30)
			child.rotation = Vector3(one_hand_pitch*0.55, 0.0, one_hand_roll*0.7 + weapon_visual_twist_kick*0.65)
	if combat != null:
		combat.update_aim_feedback(weapon_muzzle.global_position, aim_target, chest)

func _update_character_animation(delta: float) -> void:
	if locomotion == null:
		return
	locomotion.playfulness = ragdoll_playfulness
	locomotion.update(delta, animation_impact_velocity)
	anim_time = locomotion.time
	walk_phase = locomotion.cycle * TAU
	move_blend = locomotion.move_blend
	air_blend = locomotion.air_blend
	landing_kick = locomotion.landing_kick
	torso_spring_rotation = locomotion.body_rotation
	torso_spring_velocity = locomotion.body_angular_velocity
	_update_head_gaze(delta, locomotion.secondary_head, player.is_on_floor())
	head_rig.rotation = head_spring_rotation
	was_on_floor = player.is_on_floor()
	previous_vertical_velocity = animation_impact_velocity

func _update_head_gaze(delta: float, secondary_motion: Vector3, grounded: bool) -> void:
	if camera == null or head_rig == null:
		return
	var dt := clampf(delta, 0.0001, 0.10)
	var camera_target := _get_aim_target()
	var look_local := player_visual.global_basis.inverse() * (camera_target - head_rig.global_position)
	look_local = look_local.normalized()
	var horizontal := Vector2(look_local.x, look_local.z).length()
	var requested_yaw := atan2(-look_local.x, -look_local.z)
	# Ease back toward neutral when the free-orbit camera goes behind the neck.
	# This avoids an owl-like 180-degree snap at the angle wrap.
	var rear_fade := smoothstep(-1.0, -0.65, cos(requested_yaw))
	var gaze_yaw := clampf(requested_yaw, -1.22, 1.22) * rear_fade
	var gaze_pitch := clampf(atan2(look_local.y, horizontal), -0.48, 0.60)
	var turn_speed := 0.0
	if head_motion_initialized:
		turn_speed = clampf(wrapf(body_yaw - head_last_body_yaw, -PI, PI) / dt, -8.0, 8.0)
	var focused := aiming or fire_held
	# Gaze pitch/yaw stay useful; most of the loose comedy goes into roll.
	var target := Vector3(secondary_motion.x * (0.18 if focused else 0.65), secondary_motion.y * 0.15, secondary_motion.z * (0.50 if focused else 1.0))
	target.y += gaze_yaw - turn_speed * (0.006 if focused else 0.015)
	target.x += gaze_pitch
	target.z += clampf(-turn_speed * 0.032, -0.18, 0.18) * ragdoll_playfulness
	if not grounded:
		target.z += sin(anim_time * 8.0) * 0.07 * ragdoll_playfulness
	if head_motion_initialized and grounded and not head_was_grounded:
		head_spring_velocity.x += clampf(landing_kick * 3.5, 0.12, 0.85)
	if head_motion_initialized and not grounded and head_was_grounded and player.velocity.y > 1.0:
		head_spring_velocity.x -= 0.32
	# A bounded, underdamped spring, not a physical body that can break aim/collision.
	var stiffness := Vector3(170, 190, 65) if focused else Vector3(75, 95, 42)
	var damping := Vector3(22, 24, 10) if focused else Vector3(9.0, 12.0, 5.8)
	var steps := maxi(1, int(ceil(dt / (1.0 / 120.0))))
	var step := dt / float(steps)
	for unused in range(steps):
		var error := target - head_spring_rotation
		error.y = wrapf(error.y, -PI, PI)
		head_spring_velocity += (error * stiffness - head_spring_velocity * damping) * step
		head_spring_rotation += head_spring_velocity * step
	# Keep it playful but never detach, flip, or complete a full spin.
	var limits := Vector3(0.90, 1.40, 0.62)
	for axis in range(3):
		if absf(head_spring_rotation[axis]) > limits[axis]:
			head_spring_rotation[axis] = clampf(head_spring_rotation[axis], -limits[axis], limits[axis])
			head_spring_velocity[axis] = 0.0
	head_last_body_yaw = body_yaw
	head_was_grounded = grounded
	head_motion_initialized = true

func _build_hud() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "HUD"
	canvas.layer = 10
	add_child(canvas)
	help_panel = Control.new()
	help_panel.name = "HelpPanel"
	help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(help_panel)
	help_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var title := Label.new()
	title.text = "KW // 3D CHAOS PROTOTYPE"
	title.position = Vector2(12, 8)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	help_panel.add_child(title)
	var help := Label.new()
	help.text = "WASD move   SHIFT sprint   SPACE jump   RMB aim   LMB fire\nG grenade   Q swap   B retry   O comic   P pixels   M music   TAB help\nMOUSE look   R chaos   F low gravity   ESC cursor   F10 test rooms"
	help.position = Vector2(12, 28)
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.86, 0.86, 0.92))
	help_panel.add_child(help)

	status_label = Label.new()
	status_label.position = Vector2(12, 76)
	status_label.add_theme_font_size_override("font_size", 11)
	help_panel.add_child(status_label)
	_update_status()

	var crosshair := AIM_RETICLE.new()
	crosshair.name = "Crosshair"
	canvas.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _update_status() -> void:
	if status_label:
		var world_status := "LOW GRAVITY" if low_gravity else "NORMAL GRAVITY"
		var ink_status := "COMIC INK: ON" if head_style != null and head_style.enabled else "COMIC INK: OFF"
		var test_status := "SANDBOX / AIM LAB" if offline_test_mode == "sandbox" else "WAVES / COMBAT RANGE"
		status_label.text = test_status + "  |  " + world_status + "  |  " + ink_status + ("  |  PIXEL: ON" if pixel_enabled else "  |  PIXEL: OFF")
		status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.55) if low_gravity else Color(0.4, 0.9, 1.0))
func _kick_weapon_visuals() -> void:
	weapon_recoil = 1.0
	var goofy := 1.75 if randf() < 0.08 else 1.0
	weapon_visual_side_kick = clampf(weapon_visual_side_kick + randf_range(-0.055,0.055) * goofy,-0.12,0.12)
	weapon_visual_lift_kick = clampf(weapon_visual_lift_kick + randf_range(0.022,0.060) * goofy,0.0,0.13)
	weapon_visual_twist_kick = clampf(weapon_visual_twist_kick + randf_range(-0.085,0.085) * goofy,-0.19,0.19)

func _fire_physics_ball() -> void:
	if camera == null or combat == null or combat.is_game_over() or shot_cooldown > 0.00001:
		return
	shot_cooldown += AK_FIRE_INTERVAL
	_update_weapon_pose(0.0)
	_kick_weapon_visuals()
	_play_ak_fire_audio()
	var chest := _weapon_anchor()
	combat.fire(weapon_muzzle.global_position,aim_target,chest)
	_spawn_muzzle_flash()

func _play_ak_fire_audio() -> void:
	if ak_fire_audio == null or ak_fire_audio.stream == null:
		return
	# Dry rifle shot, louder than the previous pass, with the same small pitch variation.
	ak_fire_audio.pitch_scale = randf_range(0.975, 1.025)
	ak_fire_audio.play()

func _spawn_muzzle_flash() -> void:
	if weapon_muzzle == null:
		return
	var root := Node3D.new()
	root.name = "MuzzleBurst"
	weapon_muzzle.add_child(root)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0,randf_range(0.35,0.55),0.10)
	light.light_energy = randf_range(5.8,7.8)
	light.omni_range = randf_range(2.0,2.8)
	root.add_child(light)
	var flash_color := Color("fff0a2") if randf() > 0.12 else (Color("84edff") if randf() > 0.5 else Color("ff5f9a"))
	for i in range(3):
		var ray := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(randf_range(0.055,0.085),randf_range(0.055,0.085),randf_range(0.32,0.62))
		ray.mesh = box
		ray.material_override = _material(flash_color,true,randf_range(4.0,7.0))
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ray.position = Vector3(0,0,-box.size.z*0.45)
		ray.rotation.z = i * TAU / 3.0 + randf_range(-0.25,0.25)
		root.add_child(ray)
	var ember := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * randf_range(0.055,0.085)
	ember.mesh = cube
	ember.material_override = _material(Color("ff7b45"),true,5.0)
	ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ember.position = Vector3(randf_range(-0.04,0.04),randf_range(-0.04,0.04),-0.22)
	root.add_child(ember)
	var tween := root.create_tween().set_parallel(true)
	tween.tween_property(root,"scale",Vector3.ONE*1.55,0.055).from(Vector3.ONE*0.70)
	tween.chain().tween_callback(root.queue_free)

func _spawn_chaos_drop() -> void:
	for i in range(18):
		var crate := RigidBody3D.new()
		crate.name = "ChaosCrate"
		crate.mass = randf_range(0.5, 2.2)
		crate.position = Vector3(randf_range(-8.5, 8.5), randf_range(8.0, 14.0), randf_range(-7.5, 6.5))
		add_child(crate)

		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		var size := randf_range(0.45, 1.2)
		box.size = Vector3(size, size, size)
		mesh.mesh = box
		var chaos_color := Color.from_hsv(randf(), 0.82, 1.0)
		mesh.material_override = _material(chaos_color, true, 1.4)
		crate.add_child(mesh)
		_add_scene_outline(mesh)

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = box.size
		collision.shape = shape
		crate.add_child(collision)

		var physics_mat := PhysicsMaterial.new()
		physics_mat.bounce = 0.48
		physics_mat.friction = 0.45
		crate.physics_material_override = physics_mat
		crate.linear_velocity = Vector3(randf_range(-2, 2), randf_range(-1, 1), randf_range(-2, 2))
		crate.angular_velocity = Vector3(randf_range(-7, 7), randf_range(-7, 7), randf_range(-7, 7))
		_destroy_later(crate, 14.0)

func _add_static_box(node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color, false, 0.0)
	body.add_child(mesh)
	_add_scene_outline(mesh)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _add_ramp(node_name: String, pos: Vector3, size: Vector3, rot: Vector3, color: Color) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = pos
	body.rotation_degrees = rot
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color, false, 0.0)
	body.add_child(mesh)
	_add_scene_outline(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _add_neon_strip(pos: Vector3, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.6, 0.04, 0.12)
	mesh.mesh = box
	mesh.position = pos
	mesh.material_override = _material(color, true, 4.0)
	add_child(mesh)
	_add_scene_outline(mesh)

func _add_neon_light(pos: Vector3, color: Color, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = radius
	light.shadow_enabled = true
	add_child(light)

func _add_bounce_pad(pos: Vector3, color: Color) -> void:
	var pad := StaticBody3D.new()
	pad.position = pos
	add_child(pad)
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.15
	cylinder.bottom_radius = 1.15
	cylinder.height = 0.22
	mesh.mesh = cylinder
	mesh.material_override = _material(color, true, 2.4)
	pad.add_child(mesh)
	_add_scene_outline(mesh)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 1.15
	shape.height = 0.22
	collision.shape = shape
	pad.add_child(collision)

func _add_kw_sign() -> void:
	var sign := Label3D.new()
	sign.text = "KW"
	sign.position = Vector3(0, 6.2, -29.45)
	sign.font_size = 180
	sign.outline_size = 18
	sign.modulate = Color(0.9, 0.95, 1.0)
	sign.outline_modulate = Color(1.0, 0.08, 0.38)
	add_child(sign)
func _material(color: Color, emissive: bool, energy: float) -> ShaderMaterial:
	if pixel_materials.size() >= 128:
		_prune_pixel_materials()
	var mat := PIXEL_MATERIALS.solid(color, emissive, energy)
	mat.set_shader_parameter("pixel_enabled", pixel_enabled)
	mat.set_shader_parameter("comic_enabled", comic_enabled)
	pixel_materials.append(weakref(mat))
	return mat

func _destroy_later(node: Node, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(node):
		node.queue_free()

func _pixelize_weapon_materials() -> void:
	var cache: Dictionary = {}
	for child in weapon_root.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null or not mesh.material_override is StandardMaterial3D:
			continue
		var original := mesh.material_override as StandardMaterial3D
		var key := original.get_instance_id()
		if not cache.has(key):
			var mat := PIXEL_MATERIALS.from_standard(original, 0.025)
			mat.set_shader_parameter("noise_strength", 0.07)
			mat.set_shader_parameter("comic_enabled", comic_enabled)
			mat.set_shader_parameter("pixel_enabled", pixel_enabled)
			cache[key] = mat
			pixel_materials.append(weakref(mat))
		mesh.material_override = cache[key]

func _build_pixel_pass() -> void:
	pixel_post_layer = CanvasLayer.new()
	pixel_post_layer.name = "PixelWorldPass"
	pixel_post_layer.layer = 1
	add_child(pixel_post_layer)
	var rect := ColorRect.new()
	rect.name = "PixelWorldOnly"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PIXEL_SCREEN
	rect.material = mat
	pixel_post_layer.add_child(rect)

func _set_pixel_enabled(value: bool) -> void:
	pixel_enabled = value
	if pixel_post_layer != null:
		pixel_post_layer.visible = value
	_prune_pixel_materials()
	for reference in pixel_materials:
		var mat := reference.get_ref() as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("pixel_enabled", value)
	if head_style != null:
		head_style.set_pixel_enabled(value)
	if combat != null: combat.sync_style()
	_update_status()

func _prune_pixel_materials() -> void:
	for index in range(pixel_materials.size() - 1, -1, -1):
		if pixel_materials[index].get_ref() == null:
			pixel_materials.remove_at(index)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if grenade_skill != null: grenade_skill.requested = false
		fire_held = false
		aiming = false
		if combat != null and combat.director != null and not OS.get_cmdline_user_args().has("--kw-qa"): combat.director.suspended = true
	elif what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if combat != null and combat.director != null and not OS.get_cmdline_user_args().has("--kw-qa"): combat.director.suspended = false

func _toggle_instructions() -> void:
	instructions_visible = not instructions_visible
	if is_instance_valid(help_panel): help_panel.visible = instructions_visible

func _weapon_anchor() -> Vector3:
	# Shoulder-height support, with small gait motion instead of the full loose torso swing.
	var bob := clampf(torso_rig.position.y - torso_rest.y, -0.10, 0.10)
	return player_visual.to_global(Vector3(0.0, torso_rest.y + WEAPON_HOLD_HEIGHT + bob * 0.35, torso_rest.z))

func _add_scene_outline(mesh: MeshInstance3D, width: float = 2.6) -> void:
	SCENE_INK.add_to(mesh, comic_enabled, width)

func _build_weapon_outline() -> void:
	var shell := MeshInstance3D.new()
	shell.name = "WorldInkOutline"
	shell.mesh = AK_INK_HULL
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/prototypes/kw_comic_ink.gdshader")
	material.set_shader_parameter("width_pixels", 1.6)
	shell.material_override = material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.extra_cull_margin = 0.15
	shell.visible = comic_enabled
	weapon_root.add_child(shell)
	shell.add_to_group("kw_world_ink")

func _set_comic_enabled(value: bool) -> void:
	comic_enabled = value
	if head_style != null: head_style.set_enabled(value)
	_prune_pixel_materials()
	for reference in pixel_materials:
		var material := reference.get_ref() as ShaderMaterial
		if material != null: material.set_shader_parameter("comic_enabled", value)
	for shell in get_tree().get_nodes_in_group("kw_world_ink"):
		if is_ancestor_of(shell): shell.visible = value
	if combat != null: combat.sync_style()
	_update_status()
