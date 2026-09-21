extends Node3D

const ARENA_AUDIO := preload("res://scripts/prototypes/kw_arena_audio.gd")
const GRENADE_SKILL := preload("res://scripts/prototypes/kw_grenade_skill.gd")
const SCENE_INK := preload("res://scripts/prototypes/kw_scene_ink.gd")
const BORDERLANDS_EDGE := preload("res://scripts/prototypes/kw_borderlands_edge.gdshader")
const WEAPON_HOLD_HEIGHT := 0.72
var arena_audio: Node
var grenade_skill: Node3D
var comic_enabled := true
var offline_test_mode := "waves"

@export_range(0.0, 2.0, 0.05) var ragdoll_playfulness := 1.2
var locomotion: RefCounted
var combat: Node3D
var weapon_side := 1.0
var smoothed_weapon_side := 1.0
const CAMERA_SHOULDER_X := 1.20
const AIM_RETICLE := preload("res://scripts/prototypes/kw_aim_reticle.gd")
var camera_boom_z := 6.4
var camera_safe_fraction := 1.0
var camera_probe: SphereShape3D
const COMBAT_RANGE := preload("res://scripts/prototypes/kw_combat_range.gd")
var animation_impact_velocity := 0.0
const LOCOMOTION := preload("res://scripts/prototypes/kw_goofy_locomotion.gd")
const AIM_ASSIST := preload("res://scripts/kw3d/aim_assist.gd")
const SNIPER_SCOPE := preload("res://scripts/kw3d/sniper_scope.gdshader")

var player: CharacterBody3D
var player_visual: Node3D
var camera_yaw: Node3D
var camera_pitch: Node3D
var camera: Camera3D
var status_label: Label
var help_panel: Control
var instructions_visible := true
@export_range(-30.0, 0.0, 0.5) var shooting_volume_db := 0.0
var weapon_aim_pivot: Node3D
var weapon_root: Node3D
var weapon_visual_wobble: Node3D
var weapon_muzzle: Marker3D
var ak_fire_audio: AudioStreamPlayer3D
var ak_reload_audio: AudioStreamPlayer3D
var shotgun_fire_audio: AudioStreamPlayer3D
var shotgun_reload_audio: AudioStreamPlayer3D
var kar_fire_audio: AudioStreamPlayer3D
var kar_reload_audio: AudioStreamPlayer3D
var player_ammo_label: Label3D
var weapon_slot := 0
var ammo_by_weapon: Array[int]=[25,2,1]
var reload_by_weapon: Array[float]=[0.0,0.0,0.0]
var ammo_in_mag: int:
	get:return ammo_by_weapon[weapon_slot]
	set(value):ammo_by_weapon[weapon_slot]=value
var reload_remaining: float:
	get:return reload_by_weapon[weapon_slot]
	set(value):reload_by_weapon[weapon_slot]=value
var reload_mag_serial := 0
var ak_visual_root: Node3D
var shotgun_visual_root: Node3D
var kar_visual_root: Node3D
var sniper_scope_layer: CanvasLayer
var sniper_scope_rect: ColorRect
var inspect_time:=0.0
const INSPECT_DURATION:=1.65
var pixel_enabled := false
var borderlands_enabled := true
var pixel_materials: Array[WeakRef] = []
var pixel_post_layer: CanvasLayer
var borderlands_quad: MeshInstance3D
var player_health_bar: Sprite3D
var player_health_texture: ImageTexture
var player_damage_visual: Node
var player_health_value := 100.0
var aim_target := Vector3.ZERO
var aim_assist_active := false

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
var aim_recoil = AK_RECOIL_MODEL.new()
var weapon_visual_side_kick := 0.0
var weapon_visual_lift_kick := 0.0
var weapon_visual_twist_kick := 0.0
var offline_input_adapter: Node
var offline_jump_serial:=0
var offline_grenade_serial:=0
var sniper_sway_offset:=Vector2.ZERO
var sniper_sway_velocity:=Vector2.ZERO
var sniper_sway_phase:=0.0

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
const WEAPON_HOLD_DISTANCE := 0.92
const WEAPON_HOLD_SIDE := 0.74
const MOVE_SPEED := 7.5
const SPRINT_SPEED := 11.0
const SNIPER_AIM_MOVE_SPEED := 0.6
const SNIPER_SWAY_YAW_DEG:=0.82
const SNIPER_SWAY_PITCH_DEG:=0.46
const SNIPER_SWAY_SPRING:=34.0
const SNIPER_SWAY_DAMPING:=9.2
const ACCEL := 28.0
const TURN_SPEED := 10.0
const JUMP_SPEED := 8.8
const GRAVITY := 19.5
const VOXEL_UNIT := 0.082
const RIG_CENTER_X := 2.0
const RIG_CENTER_Y := -4.0
const OUTRAGE_FULLBODY := preload("res://scenes/prototypes/characters/outrage_fullbody.tscn")
const EREBUS_FULLBODY := preload("res://scenes/prototypes/characters/erebus_fullbody.tscn")
const AK47_VOXEL_BUILDER := preload("res://scripts/prototypes/ak47_voxel_builder.gd")
const KAR_VOXEL_BUILDER := preload("res://scripts/prototypes/kar_voxel_builder.gd")
const AK47_SHOT_SFX := preload("res://assets/sounds/sfx/guns/ak47/ak_shoot.wav")
const AK47_RELOAD_SFX := preload("res://assets/sounds/sfx/guns/ak47/ak_reload.wav")
const SHOTGUN_FIRE_SFX := preload("res://assets/sounds/sfx/guns/magnum/magnum_shoot.wav")
const SHOTGUN_RELOAD_SFX := preload("res://assets/sounds/sfx/guns/magnum/magnum_reload.wav")
const KAR_FIRE_SFX := preload("res://assets/sounds/sfx/guns/kar98/kar98_shoot.wav")
const KAR_RELOAD_SFX := preload("res://assets/sounds/sfx/guns/kar98/kar98_reload.wav")
const AK_RECOIL_MODEL := preload("res://scripts/kw3d/ak_recoil.gd")
const WEAPON_RULES := preload("res://scripts/kw3d/weapon_rules.gd")
const VOXEL_DAMAGE_VISUAL := preload("res://scripts/kw3d/voxel_damage_visual.gd")
const PORTABLE_INPUT := preload("res://scripts/kw3d/portable_input.gd")
@export_enum("outrage", "erebus") var player_warrior_id: String = "outrage"

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
	offline_input_adapter=PORTABLE_INPUT.new();add_child(offline_input_adapter)
	offline_input_adapter.enabled=true
	offline_input_adapter.yaw=yaw;offline_input_adapter.pitch=pitch;offline_input_adapter.weapon_slot=weapon_slot
	offline_input_adapter.action_requested.connect(_offline_control_action)
	offline_input_adapter.device_lost.connect(func():fire_held=false;aiming=false)
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

func _offline_control_action(action: String) -> void:
	if offline_input_adapter==null:return
	# Pause and wheel/D-pad weapon switching may consume the input event before _unhandled_input.
	if action=="pause":
		Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
		fire_held=false;aiming=false
		return
	if action=="weapon":
		_set_weapon_slot(int(offline_input_adapter.weapon_slot),true)
		return
	# Keyboard/mouse versions of these actions are still handled by the legacy offline event path.
	if str(offline_input_adapter.last_device)!="pad":return
	match action:
		"help":_toggle_instructions()
		"music":
			if arena_audio!=null:arena_audio.toggle_music()
		"comic":_set_comic_enabled(not comic_enabled)
		"pixels":_set_pixel_enabled(not pixel_enabled)
		"borderlands":_set_borderlands_enabled(not borderlands_enabled)
		"inspect":_start_weapon_inspect()

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
		var delta_yaw: float = -event.screen_relative.x * 0.0016 * sensitivity
		var delta_pitch: float = -event.screen_relative.y * 0.0013 * sensitivity
		yaw += delta_yaw
		pitch += delta_pitch
		aim_recoil.note_manual_look(delta_yaw,delta_pitch)
		pitch = clamp(pitch, deg_to_rad(-48.0), deg_to_rad(30.0))
		camera_yaw.rotation.y = yaw
		camera_pitch.rotation.x = pitch
		if offline_input_adapter!=null:
			offline_input_adapter.yaw=yaw;offline_input_adapter.pitch=pitch;offline_input_adapter.weapon_slot=weapon_slot

	if event is InputEventMouseButton:
		if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			_cycle_weapon(1 if event.button_index==MOUSE_BUTTON_WHEEL_DOWN else -1)
			get_viewport().set_input_as_handled();return
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
			# Fixed right-shoulder hold: no side swap.
			weapon_side=1.0;smoothed_weapon_side=1.0
		elif event.physical_keycode == KEY_P:
			_set_pixel_enabled(not pixel_enabled)
		elif event.physical_keycode == KEY_O:
			_set_comic_enabled(not comic_enabled)
		elif event.physical_keycode == KEY_Y:
			_set_borderlands_enabled(not borderlands_enabled)
		elif event.physical_keycode == KEY_R:
			_start_reload()
		elif event.physical_keycode == KEY_H:
			_start_weapon_inspect()
		elif event.physical_keycode == KEY_C:
			_spawn_chaos_drop()
		elif event.physical_keycode == KEY_F:
			low_gravity = not low_gravity
			_update_status()
func _physics_process(delta: float) -> void:
	if player == null:
		return
	if combat != null and combat.director != null:
		_set_player_healthbar(combat.director.health,100.0)
	if combat != null and combat.is_game_over():
		player.velocity = Vector3.ZERO
		return
	shot_cooldown = maxf(-delta, shot_cooldown - delta)
	_tick_reload(delta)

	var input_vec:=Vector2.ZERO
	var jump_pressed:=false
	var using_pad: bool=offline_input_adapter!=null and bool(offline_input_adapter.enabled) and int(offline_input_adapter.pad_id)>=0 and str(offline_input_adapter.last_device)=="pad"
	var sprinting:=false
	if using_pad:
		offline_input_adapter.fov=camera.fov
		var command: Dictionary=offline_input_adapter.sample(delta)
		if int(command.get("weapon",weapon_slot))!=weapon_slot:_set_weapon_slot(int(command.weapon),false)
		yaw=float(command.yaw);pitch=float(command.pitch);aiming=bool(command.aim);fire_held=bool(command.fire)
		input_vec=command.move as Vector2
		var sniper_scoped_pad:=aiming and weapon_slot==2
		sprinting=bool(command.sprint) and not sniper_scoped_pad
		if bool(command.get("reload",false)):_start_reload()
		if int(command.js)>offline_jump_serial:
			offline_jump_serial=int(command.js);jump_pressed=true
		if int(command.gs)>offline_grenade_serial:
			offline_grenade_serial=int(command.gs)
			if grenade_skill!=null:grenade_skill.requested=true
	else:
		if offline_input_adapter!=null:
			offline_input_adapter.yaw=yaw;offline_input_adapter.pitch=pitch;offline_input_adapter.weapon_slot=weapon_slot
		if Input.is_physical_key_pressed(KEY_A):input_vec.x-=1.0
		if Input.is_physical_key_pressed(KEY_D):input_vec.x+=1.0
		if Input.is_physical_key_pressed(KEY_W):input_vec.y+=1.0
		if Input.is_physical_key_pressed(KEY_S):input_vec.y-=1.0
		input_vec=input_vec.normalized()
		var sniper_scoped_keys:=aiming and weapon_slot==2
		sprinting=Input.is_physical_key_pressed(KEY_SHIFT) and not sniper_scoped_keys
		jump_pressed=Input.is_physical_key_pressed(KEY_SPACE)

	var forward := -camera_yaw.global_transform.basis.z
	var right := camera_yaw.global_transform.basis.x
	forward.y = 0.0
	right.y = 0.0
	var direction := (right.normalized() * input_vec.x + forward.normalized() * input_vec.y).normalized()
	var sniper_scoped:=aiming and weapon_slot==2
	var move_speed:=SNIPER_AIM_MOVE_SPEED if sniper_scoped else SPRINT_SPEED if sprinting else MOVE_SPEED
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
	elif jump_pressed:
		player.velocity.y = JUMP_SPEED * (1.18 if low_gravity else 1.0)

	animation_impact_velocity = player.velocity.y
	player.move_and_slide()

	var recoil_recovery: Vector2 = aim_recoil.step(delta, fire_held)
	yaw = wrapf(yaw + recoil_recovery.x, -PI, PI)
	pitch = clampf(pitch + recoil_recovery.y, deg_to_rad(-48.0), deg_to_rad(30.0))
	_apply_offline_aim_assist(delta)
	var sway_delta:=_step_sniper_scope_sway(delta,input_vec.length(),aiming and weapon_slot==2)
	yaw=wrapf(yaw+sway_delta.x,-PI,PI);pitch=clampf(pitch+sway_delta.y,deg_to_rad(-48.0),deg_to_rad(30.0))
	camera_yaw.rotation.y = yaw
	camera_pitch.rotation.x = pitch

	_update_third_person_camera(delta)
	_update_character_animation(delta)
	_update_weapon_pose(delta)
	if fire_held and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_fire_physics_ball()
	if ammo_in_mag<=0 and reload_remaining<=0.0 and not combat.is_game_over():
		_start_reload()
	if offline_input_adapter!=null:
		offline_input_adapter.yaw=yaw;offline_input_adapter.pitch=pitch;offline_input_adapter.weapon_slot=weapon_slot

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
	var is_erebus := player_warrior_id == "erebus"
	player.name = "Erebus3D" if is_erebus else "Outrage3D"
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
	player_visual.name = "ErebusVisual" if is_erebus else "OutrageVisual"
	player.add_child(player_visual)
	_build_outage_voxel_body()
	player_damage_visual=VOXEL_DAMAGE_VISUAL.new()
	player_visual.add_child(player_damage_visual)
	player_damage_visual.setup(head_style,["HeadRig","TorsoRig","LeftLegRig","RightLegRig"],137)
	player_damage_visual.set_pixel_enabled(pixel_enabled)
	capsule_shape.height = float(head_style.get_meta("capsule_height", 3.43))
	player_visual.rotation.y = body_yaw

	var name_tag := Label3D.new()
	name_tag.text = "EREBUS // NIGHT CORE" if is_erebus else "OUTRAGE // STREET ZERO"
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
	_build_player_healthbar()

func _build_player_healthbar() -> void:
	player_health_bar = Sprite3D.new()
	player_health_bar.name = "PlayerHealthBar"
	player_health_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	player_health_bar.pixel_size = 0.013
	player_health_bar.position = Vector3(0,2.52,0)
	player_health_bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	player_health_bar.render_priority=127
	player.add_child(player_health_bar)
	player_ammo_label=Label3D.new()
	player_ammo_label.name="PlayerAmmoUI"
	player_ammo_label.position=Vector3(0,2.82,0)
	player_ammo_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	player_ammo_label.font_size=34
	player_ammo_label.pixel_size=0.0065
	player_ammo_label.outline_size=7
	player_ammo_label.modulate=Color("fff2c7")
	player_ammo_label.outline_modulate=Color("141520")
	player_ammo_label.render_priority=127
	player.add_child(player_ammo_label)
	_set_player_healthbar(100.0,100.0)
	_refresh_ammo_hud()

func _set_player_healthbar(value: float, maximum: float = 100.0) -> void:
	player_health_value = clampf(value,0.0,maximum)
	if player_damage_visual!=null:player_damage_visual.set_health(player_health_value,maximum)
	if player_health_bar == null:return
	var image := Image.create(128,18,false,Image.FORMAT_RGBA8)
	image.fill(Color("111726"))
	image.fill_rect(Rect2i(2,2,124,14),Color("351621"))
	var width := int(round(120.0*player_health_value/maxf(1.0,maximum)))
	if width > 0:
		image.fill_rect(Rect2i(4,4,width,10),Color("ff586e"))
		image.fill_rect(Rect2i(4,4,width,2),Color("ff9aac"))
	for i in range(1,5):image.fill_rect(Rect2i(4+i*24,4,1,10),Color("562333"))
	if player_health_texture == null:
		player_health_texture=ImageTexture.create_from_image(image)
		player_health_bar.texture=player_health_texture
	else:player_health_texture.update(image)
	player_health_bar.visible = player_visual == null or player_visual.visible
	if player_ammo_label!=null:player_ammo_label.visible=player_health_bar.visible

func _apply_body_fire_recoil(_shot_yaw: float) -> void:
	if player == null:return
	var strength:=1.0 if weapon_slot==0 else 1.45 if weapon_slot==1 else 1.90
	# Visual recoil only: never move the CharacterBody or alter gameplay position.
	if locomotion != null:
		locomotion.body_offset_velocity += Vector3(0.0,0.10,0.72)*strength
		locomotion.head_offset_velocity += Vector3(0.0,0.07,0.46)*strength
		locomotion.body_angular_velocity.x -= 0.82*strength
	head_spring_velocity.x -= 0.18*strength
	head_spring_velocity.z += 0.11*strength

func _build_outage_voxel_body() -> void:
	# One authored source for geometry, UVs, rest positions and pivots.
	var body_scene: PackedScene = EREBUS_FULLBODY if player_warrior_id == "erebus" else OUTRAGE_FULLBODY
	head_style = body_scene.instantiate() as Node3D
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
	for ak_part in weapon_root.get_children():
		if ak_part is MeshInstance3D:_add_scene_outline(ak_part,1.15)
	weapon_visual_wobble = Node3D.new()
	weapon_visual_wobble.name = "WeaponVisualWobble"
	weapon_root.add_child(weapon_visual_wobble)
	ak_visual_root=Node3D.new();ak_visual_root.name="AKVisual";weapon_visual_wobble.add_child(ak_visual_root)
	for child in weapon_root.get_children().duplicate():
		if child is MeshInstance3D:
			child.reparent(ak_visual_root,false)
	shotgun_visual_root=Node3D.new();shotgun_visual_root.name="ShotgunVisual";weapon_visual_wobble.add_child(shotgun_visual_root)
	_build_shotgun_visual()
	kar_visual_root=Node3D.new();kar_visual_root.name="KARVisual";weapon_visual_wobble.add_child(kar_visual_root)
	_build_kar_visual()

	weapon_muzzle = Marker3D.new()
	weapon_muzzle.name = "Muzzle"
	weapon_muzzle.position = Vector3(1.34, 0.02, 0.0)
	weapon_root.add_child(weapon_muzzle)

	_add_weapon_hand("RightHand", Vector3(0.31, -0.07, -0.50), Vector3(0.22, 0.22, 0.28))

	ak_fire_audio = AudioStreamPlayer3D.new()
	ak_fire_audio.name = "AKFireAudio"
	ak_fire_audio.stream = AK47_SHOT_SFX
	ak_fire_audio.volume_db = -80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db
	ak_fire_audio.bus="SFX"
	ak_fire_audio.max_distance = 34.0
	ak_fire_audio.unit_size = 2.8
	ak_fire_audio.max_polyphony = 8
	weapon_aim_pivot.add_child(ak_fire_audio)

	ak_reload_audio = AudioStreamPlayer3D.new()
	ak_reload_audio.name = "AKReloadAudio"
	ak_reload_audio.stream = AK47_RELOAD_SFX
	ak_reload_audio.volume_db = -80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db - 3.0
	ak_reload_audio.bus="SFX"
	ak_reload_audio.max_distance = 28.0
	ak_reload_audio.unit_size = 2.6
	weapon_aim_pivot.add_child(ak_reload_audio)

	shotgun_fire_audio=AudioStreamPlayer3D.new();shotgun_fire_audio.name="ShotgunFireAudio";shotgun_fire_audio.stream=SHOTGUN_FIRE_SFX
	shotgun_fire_audio.volume_db=-80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db+1.0
	shotgun_fire_audio.bus="SFX";shotgun_fire_audio.pitch_scale=0.82;shotgun_fire_audio.max_distance=40.0;shotgun_fire_audio.unit_size=3.2;shotgun_fire_audio.max_polyphony=4
	weapon_aim_pivot.add_child(shotgun_fire_audio)
	shotgun_reload_audio=AudioStreamPlayer3D.new();shotgun_reload_audio.name="ShotgunReloadAudio";shotgun_reload_audio.stream=SHOTGUN_RELOAD_SFX
	shotgun_reload_audio.volume_db=-80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db-2.0
	shotgun_reload_audio.bus="SFX";shotgun_reload_audio.pitch_scale=0.92;shotgun_reload_audio.max_distance=30.0;shotgun_reload_audio.unit_size=2.8
	weapon_aim_pivot.add_child(shotgun_reload_audio)
	kar_fire_audio=AudioStreamPlayer3D.new();kar_fire_audio.name="KARFireAudio";kar_fire_audio.stream=KAR_FIRE_SFX
	kar_fire_audio.volume_db=-80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db+1.5
	kar_fire_audio.bus="SFX";kar_fire_audio.max_distance=58.0;kar_fire_audio.unit_size=4.2;kar_fire_audio.max_polyphony=3
	weapon_aim_pivot.add_child(kar_fire_audio)
	kar_reload_audio=AudioStreamPlayer3D.new();kar_reload_audio.name="KARReloadAudio";kar_reload_audio.stream=KAR_RELOAD_SFX
	kar_reload_audio.volume_db=-80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db-1.0
	kar_reload_audio.bus="SFX";kar_reload_audio.max_distance=34.0;kar_reload_audio.unit_size=3.0
	weapon_aim_pivot.add_child(kar_reload_audio)
	_set_weapon_slot(0,false)

func _build_kar_visual() -> void:
	KAR_VOXEL_BUILDER.build(kar_visual_root)
	var cache: Dictionary={}
	for part in kar_visual_root.get_children():
		if not part is MeshInstance3D:continue
		var original:=part.material_override as StandardMaterial3D
		if original==null:continue
		var key:=original.get_instance_id()
		if not cache.has(key):
			var mat:=PIXEL_MATERIALS.from_standard(original,0.018)
			mat.set_shader_parameter("comic_enabled",comic_enabled);mat.set_shader_parameter("pixel_enabled",pixel_enabled)
			cache[key]=mat;pixel_materials.append(weakref(mat))
		part.material_override=cache[key]
		_add_scene_outline(part,1.10)

func _build_shotgun_visual() -> void:
	_add_weapon_box(shotgun_visual_root,"SG_Stock",Vector3(-0.36,-0.02,0),Vector3(0.62,0.22,0.24),Color("6d4030"))
	_add_weapon_box(shotgun_visual_root,"SG_Receiver",Vector3(0.18,0.01,0),Vector3(0.62,0.25,0.22),Color("30343b"))
	_add_weapon_box(shotgun_visual_root,"SG_Barrel",Vector3(0.88,0.055,0),Vector3(0.92,0.12,0.14),Color("b7c0c8"))
	_add_weapon_box(shotgun_visual_root,"SG_Pump",Vector3(0.62,-0.09,0),Vector3(0.42,0.18,0.25),Color("8a5238"))
	_add_weapon_box(shotgun_visual_root,"SG_Grip",Vector3(0.02,-0.22,0),Vector3(0.20,0.36,0.22),Color("20232a"))
	_add_weapon_box(shotgun_visual_root,"SG_Sight",Vector3(0.30,0.18,0),Vector3(0.10,0.08,0.10),Color("ffcf70"))

func _add_weapon_box(parent: Node3D,title: String,pos: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new();mesh.name=title
	var box:=BoxMesh.new();box.size=size;mesh.mesh=box;mesh.position=pos
	mesh.material_override=_material(color,false,0.0);parent.add_child(mesh);_add_scene_outline(mesh,1.25)
	return mesh

func _set_weapon_slot(slot: int,play_fx: bool=true) -> void:
	weapon_slot=clampi(slot,0,2)
	inspect_time=0.0
	if ak_visual_root!=null:ak_visual_root.visible=weapon_slot==0
	if shotgun_visual_root!=null:shotgun_visual_root.visible=weapon_slot==1
	if kar_visual_root!=null:kar_visual_root.visible=weapon_slot==2
	if weapon_muzzle!=null:weapon_muzzle.position=Vector3(float(WEAPON_RULES.by_slot(weapon_slot).muzzle_x),0.02,0.0)
	if play_fx and arena_audio!=null:arena_audio.play_event("switch",Vector3.ZERO,-18.0)
	aim_recoil.reset();shot_cooldown=maxf(shot_cooldown,0.08);_refresh_ammo_hud();_update_scope_visibility()

func _cycle_weapon(direction: int) -> void:
	_set_weapon_slot(posmod(weapon_slot+direction,3),true)

func _start_weapon_inspect() -> void:
	if reload_remaining>0.0 or fire_held:return
	inspect_time=INSPECT_DURATION
	aiming=false
	_update_scope_visibility()

func _add_weapon_hand(node_name: String, pos: Vector3, size: Vector3) -> void:
	var hand := MeshInstance3D.new()
	hand.name = node_name
	var box := BoxMesh.new()
	box.size = size
	hand.mesh = box
	hand.position = pos
	hand.set_meta("hold_rest",pos)
	var hand_color := Color("df7126") if player_warrior_id == "erebus" else Color(0.56, 0.11, 0.15)
	hand.material_override = _material(hand_color, false, 0.0)
	weapon_aim_pivot.add_child(hand)
	_add_scene_outline(hand, 1.6)

func _best_offline_aim_assist_target() -> Vector3:
	if camera==null or combat==null:return Vector3(INF,INF,INF)
	var best_point:=Vector3(INF,INF,INF)
	var best_angle:=AIM_ASSIST.CONE_DEG+0.001
	for target in combat.targets:
		if not is_instance_valid(target) or bool(target.dead):continue
		var torso:=target.visuals.get_node_or_null("TorsoRig") as Node3D
		if torso==null:continue
		var point:=torso.global_position+Vector3.UP*0.34
		if not AIM_ASSIST.eligible(camera.global_position,yaw,pitch,point):continue
		if not _aim_assist_line_clear(point):continue
		var angle:=AIM_ASSIST.angle_degrees(camera.global_position,yaw,pitch,point)
		if angle<best_angle:
			best_angle=angle;best_point=point
	return best_point

func _aim_assist_line_clear(point: Vector3) -> bool:
	if camera==null or player==null:return false
	var query:=PhysicsRayQueryParameters3D.create(camera.global_position,point,1,[player.get_rid()])
	query.hit_from_inside=true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _apply_offline_aim_assist(delta: float) -> void:
	aim_assist_active=false
	if not aiming or weapon_slot==2:return
	var point:=_best_offline_aim_assist_target()
	if not point.is_finite():return
	var before:=AIM_ASSIST.angle_degrees(camera.global_position,yaw,pitch,point)
	var assisted:=AIM_ASSIST.step(yaw,pitch,camera.global_position,point,delta)
	yaw=wrapf(assisted.x,-PI,PI)
	pitch=clampf(assisted.y,deg_to_rad(-48.0),deg_to_rad(30.0))
	var after:=AIM_ASSIST.angle_degrees(camera.global_position,yaw,pitch,point)
	aim_assist_active=after+0.0001<before

func _step_sniper_scope_sway(delta: float,movement_factor: float,scoped: bool) -> Vector2:
	var previous:=sniper_sway_offset
	if not scoped:
		sniper_sway_offset=Vector2.ZERO;sniper_sway_velocity=Vector2.ZERO;sniper_sway_phase=0.0
		return -previous
	var movement:=clampf(movement_factor,0.0,1.0)
	if movement>0.015:sniper_sway_phase=fposmod(sniper_sway_phase+delta*lerpf(4.6,6.4,movement),TAU)
	var target:=Vector2(
		deg_to_rad(SNIPER_SWAY_YAW_DEG)*sin(sniper_sway_phase),
		deg_to_rad(SNIPER_SWAY_PITCH_DEG)*sin(sniper_sway_phase*1.73+0.65))*movement
	# Underdamped spring: movement creates sway; releasing movement eases back instead of snapping still.
	var acceleration: Vector2=(target-sniper_sway_offset)*SNIPER_SWAY_SPRING-sniper_sway_velocity*SNIPER_SWAY_DAMPING
	sniper_sway_velocity+=acceleration*delta
	sniper_sway_offset+=sniper_sway_velocity*delta
	sniper_sway_offset.x=clampf(sniper_sway_offset.x,deg_to_rad(-1.15),deg_to_rad(1.15))
	sniper_sway_offset.y=clampf(sniper_sway_offset.y,deg_to_rad(-0.72),deg_to_rad(0.72))
	return sniper_sway_offset-previous

func _update_third_person_camera(delta: float) -> void:
	if camera == null:return
	var weight := 1.0-exp(-12.0*maxf(delta,0.0))
	var sniper_ads:=aiming and weapon_slot==2 and inspect_time<=0.0
	var target_boom:=2.65 if sniper_ads else 3.80 if aiming else 6.40
	var target_fov:=27.0 if sniper_ads else 58.0 if aiming else 74.0
	camera_boom_z=lerpf(camera_boom_z,target_boom,weight)
	camera.fov=lerpf(camera.fov,target_fov,weight)
	_update_scope_visibility()
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
	if weapon_aim_pivot == null or weapon_root == null or camera == null:return
	if inspect_time>0.0:
		inspect_time=maxf(0.0,inspect_time-maxf(0.0,delta))
		if inspect_time<=0.0:_update_scope_visibility()
	aim_target = _get_aim_target()
	# Fixed right-shoulder hold: keeps the weapon near the camera/crosshair side and
	# removes lateral shoulder swapping as a source of visual aim instability.
	weapon_side=1.0
	smoothed_weapon_side=move_toward(smoothed_weapon_side,1.0,maxf(0.0,delta)*10.0)
	var chest := _weapon_anchor()
	var forward := (aim_target - chest).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() < 0.01: right = camera.global_basis.x.normalized()
	var swap_clearance := 0.0
	var loose_amount := ragdoll_playfulness * (0.28 + move_blend * 0.45)
	var hand_bob := sin(anim_time*8.2+walk_phase*0.18)*0.032*move_blend*loose_amount
	var hand_lag := sin(anim_time*4.1+0.7)*0.014*loose_amount
	weapon_aim_pivot.global_position = chest + forward*(WEAPON_HOLD_DISTANCE+swap_clearance + 0.08*move_blend) + right*(WEAPON_HOLD_SIDE*smoothed_weapon_side + hand_lag) + Vector3.UP*hand_bob
	weapon_recoil = move_toward(weapon_recoil, 0.0, delta*9.5)
	weapon_visual_side_kick = move_toward(weapon_visual_side_kick,0.0,delta*3.4)
	weapon_visual_lift_kick = move_toward(weapon_visual_lift_kick,0.0,delta*2.8)
	weapon_visual_twist_kick = move_toward(weapon_visual_twist_kick,0.0,delta*3.6)
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
	var one_hand_roll := sin(anim_time*4.8+1.6)*(0.042+0.025*move_blend)*loose_amount - weapon_recoil*0.11
	var active_profile: Dictionary=WEAPON_RULES.by_slot(weapon_slot)
	var reload_progress := 0.0 if reload_remaining<=0.0 else 1.0-clampf(reload_remaining/float(active_profile.reload),0.0,1.0)
	var reload_arc := pow(maxf(0.0,sin(PI*reload_progress)),0.72)
	var reload_snap := sin(TAU*reload_progress)*0.08*reload_arc
	weapon_root.rotation = Vector3(0.0, PI*0.5, 0.0)
	if weapon_visual_wobble != null:
		var inspect_progress:=0.0 if inspect_time<=0.0 else 1.0-clampf(inspect_time/INSPECT_DURATION,0.0,1.0)
		var inspect_arc:=pow(maxf(0.0,sin(PI*inspect_progress)),0.72)
		var inspect_turn:=sin(PI*inspect_progress)*1.18
		var inspect_roll:=sin(TAU*inspect_progress)*0.18*inspect_arc
		weapon_visual_wobble.position=Vector3(-0.16*inspect_arc+weapon_visual_side_kick,0.18*inspect_arc-0.17*reload_arc+weapon_visual_lift_kick,0.34*inspect_arc+0.16*reload_arc+weapon_recoil*0.05)
		weapon_visual_wobble.rotation=Vector3(one_hand_pitch-0.28*inspect_arc-0.22*reload_arc,inspect_turn+0.08*reload_arc,one_hand_roll+inspect_roll+weapon_visual_twist_kick+0.62*reload_arc+reload_snap)
	for child in weapon_aim_pivot.get_children():
		if child.has_meta("hold_rest"):
			var hand_rest: Vector3 = child.get_meta("hold_rest")
			child.position = hand_rest + Vector3(sin(anim_time*5.2)*0.035*loose_amount + weapon_visual_side_kick*0.65,-0.10*reload_arc+cos(anim_time*6.8)*0.025*loose_amount + weapon_visual_lift_kick*0.65,weapon_root.position.z+0.30+0.10*reload_arc)
			child.rotation = Vector3(one_hand_pitch*0.55-0.12*reload_arc,0.0,one_hand_roll*0.7 + weapon_visual_twist_kick*0.65+0.38*reload_arc)
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
	help.text = "WASD move   SHIFT sprint   SPACE jump   RMB aim+magnet   LMB fire   R reload\nWHEEL weapon   H inspect   G grenade   O comic   P pixels   Y Borderlands   M music\nKAR: RMB scope // NO magnet // near-still movement   TAB help   ESC cursor   F10 test rooms"
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

	sniper_scope_layer=CanvasLayer.new();sniper_scope_layer.name="SniperScopeLayer";sniper_scope_layer.layer=22;add_child(sniper_scope_layer)
	sniper_scope_rect=ColorRect.new();sniper_scope_rect.name="SniperScope";sniper_scope_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sniper_scope_rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var scope_mat:=ShaderMaterial.new();scope_mat.shader=SNIPER_SCOPE;sniper_scope_rect.material=scope_mat
	sniper_scope_layer.add_child(sniper_scope_rect);sniper_scope_layer.visible=false
	_refresh_ammo_hud()

func _update_scope_visibility() -> void:
	var scoped:=weapon_slot==2 and aiming and inspect_time<=0.0 and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED
	if sniper_scope_layer!=null:sniper_scope_layer.visible=scoped
	var crosshair:=get_node_or_null("HUD/Crosshair") as Control
	if crosshair!=null:crosshair.visible=not scoped
	if weapon_aim_pivot!=null:weapon_aim_pivot.visible=not scoped

func _refresh_ammo_hud() -> void:
	if player_ammo_label==null:return
	var profile: Dictionary=WEAPON_RULES.by_slot(weapon_slot)
	var maximum:=int(profile.magazine)
	if reload_remaining>0.0:
		player_ammo_label.text="%s  %d / %d  //  RELOAD %.1f" % [str(profile.label),ammo_in_mag,maximum,reload_remaining]
		player_ammo_label.modulate=Color("ffcf70")
	else:
		player_ammo_label.text="%s  %d / %d" % [str(profile.label),ammo_in_mag,maximum]
		player_ammo_label.modulate=Color("ff7b76") if ammo_in_mag<=maxi(1,int(ceil(maximum*0.20))) else Color("fff2c7")

func _tick_reload(delta: float) -> void:
	var changed:=false
	for slot in range(3):
		if reload_by_weapon[slot]<=0.0:continue
		var before: float=reload_by_weapon[slot]
		reload_by_weapon[slot]=maxf(0.0,reload_by_weapon[slot]-delta)
		if before>0.0 and reload_by_weapon[slot]<=0.0:
			ammo_by_weapon[slot]=int(WEAPON_RULES.by_slot(slot).magazine)
		changed=true
	if changed or reload_remaining>0.0:_refresh_ammo_hud()

func _start_reload(play_fx: bool = true) -> bool:
	var profile: Dictionary=WEAPON_RULES.by_slot(weapon_slot)
	if inspect_time>0.0:return false
	if reload_remaining>0.0 or ammo_in_mag>=int(profile.magazine):return false
	if combat!=null and combat.is_game_over():return false
	reload_remaining=float(profile.reload)
	aim_recoil.reset()
	if play_fx:
		var audio:=ak_reload_audio if weapon_slot==0 else shotgun_reload_audio if weapon_slot==1 else kar_reload_audio
		if audio!=null:audio.play()
		if weapon_slot!=2:_spawn_reload_magazine()
	_refresh_ammo_hud()
	return true

func _spawn_reload_magazine() -> void:
	if weapon_root==null:return
	reload_mag_serial+=1
	var mag := MeshInstance3D.new()
	mag.name="ReloadMag%02d"%reload_mag_serial
	var box:=BoxMesh.new();box.size=Vector3(0.15,0.36,0.09);mag.mesh=box
	mag.material_override=_material(Color("24262d"),false,0.0)
	mag.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mag)
	mag.global_transform=Transform3D(weapon_root.global_basis,weapon_root.to_global(Vector3(0.38,-0.20,0.0)))
	_add_scene_outline(mag,0.85)
	var start:=mag.global_position
	var side_dir:=weapon_root.global_basis.z.normalized()*0.18
	var tween:=mag.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(mag,"global_position",start+Vector3.DOWN*1.15+side_dir,0.55)
	tween.tween_property(mag,"rotation",mag.rotation+Vector3(1.6,0.8,-1.2),0.55)
	tween.tween_property(mag,"scale",Vector3.ONE*0.65,0.55)
	tween.chain().tween_callback(mag.queue_free)

func _set_authoritative_weapon_state(state: Dictionary,force: bool=false) -> void:
	var server_slot:=clampi(int(state.get("weapon",weapon_slot)),0,2)
	var server_ammo: Array[int]=[
		clampi(int(state.get("ak_ammo",ammo_by_weapon[0])),0,int(WEAPON_RULES.AK.magazine)),
		clampi(int(state.get("sg_ammo",ammo_by_weapon[1])),0,int(WEAPON_RULES.SHOTGUN.magazine)),
		clampi(int(state.get("kar_ammo",ammo_by_weapon[2])),0,int(WEAPON_RULES.KAR.magazine))]
	var server_reload: Array[float]=[
		clampf(float(state.get("ak_reload",reload_by_weapon[0])),0.0,float(WEAPON_RULES.AK.reload)),
		clampf(float(state.get("sg_reload",reload_by_weapon[1])),0.0,float(WEAPON_RULES.SHOTGUN.reload)),
		clampf(float(state.get("kar_reload",reload_by_weapon[2])),0.0,float(WEAPON_RULES.KAR.reload))]
	if force:
		ammo_by_weapon=server_ammo;reload_by_weapon=server_reload;_set_weapon_slot(server_slot,false)
	else:
		for slot in range(3):
			if server_reload[slot]>0.0 and reload_by_weapon[slot]<=0.0 and slot==weapon_slot:_start_reload(true)
			ammo_by_weapon[slot]=server_ammo[slot];reload_by_weapon[slot]=server_reload[slot]
		if server_slot!=weapon_slot:_set_weapon_slot(server_slot,false)
	_refresh_ammo_hud()

func _update_status() -> void:
	if status_label:
		var world_status := "LOW GRAVITY" if low_gravity else "NORMAL GRAVITY"
		var ink_status := "COMIC INK: ON" if head_style != null and head_style.enabled else "COMIC INK: OFF"
		var test_status := "SANDBOX / AIM LAB" if offline_test_mode == "sandbox" else "WAVES / COMBAT RANGE"
		var edge_status := "EDGES: ON" if borderlands_enabled else "EDGES: OFF"
		status_label.text = test_status + "  |  " + world_status + "  |  " + ink_status + ("  |  PIXEL: ON" if pixel_enabled else "  |  PIXEL: OFF") + "  |  " + edge_status
		status_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.55) if low_gravity else Color(0.4, 0.9, 1.0))
func _kick_weapon_visuals() -> void:
	weapon_recoil=1.0 if weapon_slot==0 else 1.45 if weapon_slot==1 else 1.75
	var goofy:=1.75 if randf()<0.08 else 1.0
	var strength:=1.0 if weapon_slot==0 else 1.65 if weapon_slot==1 else 2.05
	weapon_visual_side_kick = clampf(weapon_visual_side_kick + randf_range(-0.055,0.055)*goofy*strength,-0.18,0.18)
	weapon_visual_lift_kick = clampf(weapon_visual_lift_kick + randf_range(0.022,0.060)*goofy*strength,0.0,0.20)
	weapon_visual_twist_kick = clampf(weapon_visual_twist_kick + randf_range(-0.085,0.085)*goofy*strength,-0.28,0.28)

func _fire_physics_ball() -> void:
	if camera == null or combat == null or combat.is_game_over() or shot_cooldown > 0.00001:return
	if inspect_time>0.0:return
	if reload_remaining>0.0:return
	if ammo_in_mag<=0:
		_start_reload();return
	var profile: Dictionary=WEAPON_RULES.by_slot(weapon_slot)
	ammo_in_mag-=1;_refresh_ammo_hud();shot_cooldown+=float(profile.fire_interval)
	_update_weapon_pose(0.0);_kick_weapon_visuals();_play_weapon_fire_audio()
	var chest := _weapon_anchor()
	if weapon_slot==0:combat.fire(weapon_muzzle.global_position,aim_target,chest,WEAPON_RULES.AK,"ak")
	elif weapon_slot==1:combat.fire_shotgun(weapon_muzzle.global_position,aim_target,chest)
	else:combat.fire(weapon_muzzle.global_position,aim_target,chest,WEAPON_RULES.KAR,"kar")
	_apply_body_fire_recoil(yaw)
	var aim_kick: Vector2=aim_recoil.kick(aiming)
	if weapon_slot==1:aim_kick+=aim_recoil.kick(aiming)
	elif weapon_slot==2:
		aim_kick+=aim_recoil.kick(aiming)*1.55
	yaw=wrapf(yaw+aim_kick.x,-PI,PI);pitch=clampf(pitch+aim_kick.y,deg_to_rad(-48.0),deg_to_rad(30.0))
	camera_yaw.rotation.y=yaw;camera_pitch.rotation.x=pitch
	_spawn_muzzle_flash()
	if ammo_in_mag<=0:_start_reload()

func _play_weapon_fire_audio() -> void:
	if weapon_slot==0:
		_play_ak_fire_audio();return
	if weapon_slot==1:
		if shotgun_fire_audio!=null and shotgun_fire_audio.stream!=null:
			shotgun_fire_audio.pitch_scale=randf_range(0.78,0.86);shotgun_fire_audio.play()
		return
	if kar_fire_audio!=null and kar_fire_audio.stream!=null:
		kar_fire_audio.pitch_scale=randf_range(0.96,1.02);kar_fire_audio.play()

func _play_ak_fire_audio() -> void:
	if ak_fire_audio == null or ak_fire_audio.stream == null:return
	ak_fire_audio.pitch_scale = randf_range(0.975, 1.025);ak_fire_audio.play()

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
	pixel_post_layer.visible=pixel_enabled
	add_child(pixel_post_layer)
	var rect := ColorRect.new()
	rect.name = "PixelWorldOnly"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = PIXEL_SCREEN
	rect.material = mat
	pixel_post_layer.add_child(rect)
	_build_borderlands_pass()

func _build_borderlands_pass() -> void:
	borderlands_quad = MeshInstance3D.new()
	borderlands_quad.name = "BorderlandsEdgePass"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	borderlands_quad.mesh = quad
	borderlands_quad.extra_cull_margin = 16384.0
	borderlands_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = BORDERLANDS_EDGE
	# Leave the final transparent/world-UI priority range free for health/name/ammo UI.
	mat.render_priority = 90
	borderlands_quad.material_override = mat
	borderlands_quad.visible = borderlands_enabled
	add_child(borderlands_quad)

func _set_borderlands_enabled(value: bool) -> void:
	borderlands_enabled = value
	if borderlands_quad != null:
		borderlands_quad.visible = value
	_update_status()

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
	for damage_visual in get_tree().get_nodes_in_group("kw_damage_visual"):
		if damage_visual is Node and is_ancestor_of(damage_visual):damage_visual.set_pixel_enabled(value)
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
	for damage_visual in get_tree().get_nodes_in_group("kw_damage_visual"):
		if damage_visual is Node and is_ancestor_of(damage_visual):damage_visual.set_comic_enabled(value)
	_update_status()
