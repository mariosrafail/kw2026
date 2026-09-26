extends Node3D

const ARENA_AUDIO := preload("res://scripts/prototypes/kw_arena_audio.gd")
const GRENADE_SKILL := preload("res://scripts/prototypes/kw_grenade_skill.gd")
const WARRIOR_SKILL_CONTROLLER := preload("res://scripts/prototypes/kw_warrior_skill_controller.gd")
const WARRIOR_SKILL_RULES := preload("res://scripts/kw3d/warrior_skill_rules.gd")
const SCENE_INK := preload("res://scripts/prototypes/kw_scene_ink.gd")
const BORDERLANDS_EDGE := preload("res://scripts/prototypes/kw_borderlands_edge.gdshader")
const WEAPON_HOLD_HEIGHT := 0.72
var arena_audio: Node
var grenade_skill: Node3D
var warrior_skill: Node
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
const WARRIOR_HAND_STYLE := preload("res://scripts/prototypes/warrior_hand_style.gd")
const WARRIOR_RENDER_LOD := preload("res://scripts/prototypes/kw_warrior_render_lod.gd")
const VIRTUAL_PROFILE := preload("res://scripts/kw3d/virtual_profile.gd")
const FLAME_PARTICLES := preload("res://scripts/prototypes/kw_flame_particles.gd")

var player: CharacterBody3D
var player_visual: Node3D
var camera_yaw: Node3D
var camera_pitch: Node3D
var camera: Camera3D
var status_label: Label
var warrior_skill_label: Label
var warrior_skill_bar: ProgressBar
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
var grenade_launcher_fire_audio: AudioStreamPlayer3D
var grenade_launcher_reload_audio: AudioStreamPlayer3D
var player_ammo_label: Label3D
var player_name_tag: Label3D
var ammo_hud_last_slot := -1
var ammo_hud_last_ammo := -1
var ammo_hud_last_maximum := -1
var ammo_hud_last_reload_tenth := -1
var weapon_slot := 0
var ammo_by_weapon: Array[int]=[25,2,1,1]
var reload_by_weapon: Array[float]=[0.0,0.0,0.0,0.0]
var ammo_in_mag: int:
	get:return ammo_by_weapon[weapon_slot]
	set(value):ammo_by_weapon[weapon_slot]=value
var reload_remaining: float:
	get:return reload_by_weapon[weapon_slot]
	set(value):reload_by_weapon[weapon_slot]=value
var reload_mag_serial := 0
var reload_mag_pool: Array[MeshInstance3D]=[]
var active_reload_mags: Array[Dictionary]=[]
var ak_visual_root: Node3D
var shotgun_visual_root: Node3D
var kar_visual_root: Node3D
var grenade_launcher_visual_root: Node3D
var local_weapon_visual_built: Array[bool]=[true,false,false,false]
var sniper_scope_layer: CanvasLayer
var sniper_scope_rect: ColorRect
var inspect_time:=0.0
const INSPECT_DURATION:=1.65
var pixel_enabled := false
var borderlands_enabled := true
var pixel_materials: Array[WeakRef] = []
var neon_strip_specs: Array[Dictionary] = []
var arena_static_visual_specs: Array[Dictionary] = []
var arena_static_batch_open := false
var pixel_post_layer: CanvasLayer
var borderlands_quad: MeshInstance3D
var player_health_bar: Sprite3D
var player_health_texture: ImageTexture
var player_health_image: Image
var player_health_bar_width := -1
var player_health_maximum := 100.0
var player_damage_visual: Node
var player_health_value := 100.0
var aim_target := Vector3.ZERO
var aim_assist_active := false
var aim_assist_ray_query:=PhysicsRayQueryParameters3D.new()
var aim_assist_ray_exclude: Array[RID]=[]

var head_rig: Node3D
var torso_rig: Node3D
var left_leg_rig: Node3D
var right_leg_rig: Node3D
var left_hand_rig: Node3D
var right_hand_rig: Node3D

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
var visual_sprinting := false
var weapon_sprint_blend := 0.0
var weapon_swap_time := 0.0
var weapon_swap_direction := 1.0
const WEAPON_SWAP_VISUAL_DURATION := 0.22
var offline_input_adapter: Node
var offline_jump_serial:=0
var offline_grenade_serial:=0
var sniper_sway_offset:=Vector2.ZERO
var sniper_sway_velocity:=Vector2.ZERO
var sniper_sway_phase:=0.0
var aevilok_burst_pool: Array[Dictionary]=[]
var active_aevilok_bursts: Array[Dictionary]=[]
var aevilok_burst_meshes: Array[SphereMesh]=[]
var aevilok_burst_materials: Array[ShaderMaterial]=[]
const MAX_AEVILOK_BURSTS:=3

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
const KOSAS_FULLBODY := preload("res://scenes/prototypes/characters/kosas_fullbody.tscn")
const AEVILOK_FULLBODY := preload("res://scenes/prototypes/characters/aevilok_fullbody.tscn")
const LOKER_FULLBODY := preload("res://scenes/prototypes/characters/loker_fullbody.tscn")
const OUTRAGE_SKINS := preload("res://scripts/prototypes/outrage_skin_style.gd")
const EREBUS_SKINS := preload("res://scripts/prototypes/erebus_skin_style.gd")
const KOSAS_STYLE := preload("res://scripts/prototypes/kosas_warrior_style.gd")
const AEVILOK_STYLE := preload("res://scripts/prototypes/aevilok_warrior_style.gd")
const LOKER_STYLE := preload("res://scripts/prototypes/loker_warrior_style.gd")
const AK47_VOXEL_BUILDER := preload("res://scripts/prototypes/ak47_voxel_builder.gd")
const KAR_VOXEL_BUILDER := preload("res://scripts/prototypes/kar_voxel_builder.gd")
const AK47_SHOT_SFX := preload("res://assets/sounds/sfx/guns/ak47/ak_shoot.wav")
const AK47_RELOAD_SFX := preload("res://assets/sounds/sfx/guns/ak47/ak_reload.wav")
const SHOTGUN_FIRE_SFX := preload("res://assets/sounds/sfx/guns/magnum/magnum_shoot.wav")
const SHOTGUN_RELOAD_SFX := preload("res://assets/sounds/sfx/guns/magnum/magnum_reload.wav")
const KAR_FIRE_SFX := preload("res://assets/sounds/sfx/guns/kar98/kar98_shoot.wav")
const KAR_RELOAD_SFX := preload("res://assets/sounds/sfx/guns/kar98/kar98_reload.wav")
const GRENADE_LAUNCHER_FIRE_SFX := preload("res://assets/sounds/sfx/guns/grenade/launcher_shoot.wav")
const GRENADE_LAUNCHER_RELOAD_SFX := preload("res://assets/sounds/sfx/guns/grenade/launcher_reload.wav")
const AK_RECOIL_MODEL := preload("res://scripts/kw3d/ak_recoil.gd")
const WEAPON_RULES := preload("res://scripts/kw3d/weapon_rules.gd")
const VOXEL_DAMAGE_VISUAL := preload("res://scripts/kw3d/voxel_damage_visual.gd")
const PORTABLE_INPUT := preload("res://scripts/kw3d/portable_input.gd")
@export_enum("outrage", "erebus", "kosas", "aevilok", "loker") var player_warrior_id: String = "outrage"
@export var use_menu_warrior_selection := true
@export_range(0, 4, 1) var outrage_skin_id := 0
@export_range(0, 1, 1) var erebus_skin_id := 0
@export var use_menu_warrior_skin_selection := true
@export_range(0, 4, 1) var ak_skin_id := 0
@export_range(0, 4, 1) var kar_skin_id := 0
@export var use_menu_weapon_skin_selection := true

func _ready() -> void:
	# The baked preview exists only for the editor; runtime builds the same arena.
	if use_menu_warrior_selection:
		var requested_warrior := str(ProjectSettings.get_setting("kw3d/selected_warrior_id", player_warrior_id)).strip_edges().to_lower()
		if requested_warrior in ["outrage", "erebus", "kosas", "aevilok", "loker"]:
			player_warrior_id = requested_warrior
	if use_menu_warrior_skin_selection and player_warrior_id == "outrage":
		outrage_skin_id = clampi(
			int(ProjectSettings.get_setting("kw3d/selected_outrage_skin", outrage_skin_id)),
			0,
			OUTRAGE_SKINS.skin_count() - 1
		)
	elif use_menu_warrior_skin_selection and player_warrior_id == "erebus":
		erebus_skin_id = clampi(
			int(ProjectSettings.get_setting("kw3d/selected_erebus_skin", erebus_skin_id)),
			0,
			EREBUS_SKINS.skin_count() - 1
		)
	if use_menu_weapon_skin_selection:
		ak_skin_id = clampi(
			int(ProjectSettings.get_setting("kw3d/selected_ak_skin", ak_skin_id)),
			0,
			AK47_VOXEL_BUILDER.skin_count() - 1
		)
		kar_skin_id = clampi(
			int(ProjectSettings.get_setting("kw3d/selected_kar_skin", kar_skin_id)),
			0,
			KAR_VOXEL_BUILDER.skin_count() - 1
		)
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
	warrior_skill = WARRIOR_SKILL_CONTROLLER.new()
	add_child(warrior_skill)
	warrior_skill.setup(self)
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
	if action=="skill":
		if warrior_skill!=null:warrior_skill.cast()
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
			elif event.physical_keycode == KEY_E:
				if warrior_skill != null: warrior_skill.cast()
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
	_tick_aevilok_flame_bursts(delta)
	_tick_reload_magazines(delta)
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
	visual_sprinting=sprinting

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
	if fire_held and (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED or OS.get_cmdline_user_args().has("--kw-qa")):
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
	env.background_color = Color(0.07, 0.085, 0.14)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.48, 0.68)
	env.ambient_light_energy = 2.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_color = Color(0.86, 0.90, 1.0)
	sun.light_energy = 2.85
	sun.shadow_enabled = true
	add_child(sun)

	_add_neon_light(Vector3(-8.0, 4.0, -5.0), Color(0.0, 0.75, 1.0), 11.0)
	_add_neon_light(Vector3(8.0, 4.0, -5.0), Color(1.0, 0.12, 0.42), 11.0)
	# Wide neutral fills brighten the whole test arena, especially the centre and
	# rear lanes where the neon-only setup still left characters in silhouette.
	_add_arena_fill_light("ArenaFillFront", Vector3(0.0, 7.5, 10.0), Color(0.82, 0.88, 1.0), 4.0, 17.0)
	_add_arena_fill_light("ArenaFillCenter", Vector3(0.0, 8.0, -4.0), Color(0.90, 0.92, 1.0), 4.6, 19.0)
	_add_arena_fill_light("ArenaFillRear", Vector3(0.0, 7.5, -20.0), Color(0.78, 0.84, 1.0), 4.2, 18.0)
	_add_arena_fill_light("ArenaFillLeft", Vector3(-15.0, 6.0, -7.0), Color(0.50, 0.82, 1.0), 3.4, 15.0)
	_add_arena_fill_light("ArenaFillRight", Vector3(15.0, 6.0, -7.0), Color(1.0, 0.52, 0.72), 3.4, 15.0)
	# Extra arena fills keep the whole testing map readable while preserving the
	# cyan/magenta neon contrast. These are spread through front/mid/back lanes.
	_add_neon_light(Vector3(-17.0, 5.0, 10.0), Color(0.10, 0.78, 1.0), 13.0)
	_add_neon_light(Vector3(17.0, 5.0, 10.0), Color(1.0, 0.18, 0.48), 13.0)
	_add_neon_light(Vector3(-17.0, 5.0, -20.0), Color(0.08, 0.66, 1.0), 13.0)
	_add_neon_light(Vector3(17.0, 5.0, -20.0), Color(1.0, 0.15, 0.38), 13.0)
	_add_neon_light(Vector3(0.0, 6.0, 7.0), Color(0.58, 0.68, 1.0), 12.0)
	_add_neon_light(Vector3(0.0, 6.0, -19.0), Color(0.72, 0.40, 1.0), 12.0)

func _build_arena() -> void:
	arena_static_batch_open=true
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
	_finalize_static_arena_visuals()
	arena_static_batch_open=false
	for z in [-28.0, -20.0, -12.0, -4.0, 4.0, 12.0, 16.0]:
		for side in [-1.0, 1.0]:
			var tint := Color(0, 0.8, 1) if side < 0 else Color(1, 0.08, 0.40)
			_add_neon_strip(Vector3(side * 22.8, 0.03, z), tint)
	for x in [-19.0, -13.0, -7.0, -1.0, 5.0, 11.0, 17.0]:
		_add_neon_strip(Vector3(x, 0.03, -28.8), Color(0, 0.8, 1) if x < 0 else Color(1, 0.1, 0.42))
	_finalize_neon_strips()
	_add_bounce_pad(Vector3(-8, 0.15, 6.5), Color(0, 0.85, 1))
	_add_bounce_pad(Vector3(8, 0.15, 6.5), Color(1, 0.08, 0.4))
	_add_kw_sign()
func _build_player() -> void:
	player = CharacterBody3D.new()
	var is_erebus := player_warrior_id == "erebus"
	var is_kosas := player_warrior_id == "kosas"
	var is_aevilok := player_warrior_id == "aevilok"
	var is_loker := player_warrior_id == "loker"
	player.name = "Loker3D" if is_loker else ("Aevilok3D" if is_aevilok else ("Kosas3D" if is_kosas else ("Erebus3D" if is_erebus else "Outrage3D")))
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
	player_visual.name = "LokerVisual" if is_loker else ("AevilokVisual" if is_aevilok else ("KosasVisual" if is_kosas else ("ErebusVisual" if is_erebus else "OutrageVisual")))
	player.add_child(player_visual)
	_build_outage_voxel_body()
	player_damage_visual=VOXEL_DAMAGE_VISUAL.new()
	player_visual.add_child(player_damage_visual)
	player_damage_visual.setup(head_style,["HeadRig","TorsoRig","LeftLegRig","RightLegRig"],137)
	player_damage_visual.set_pixel_enabled(pixel_enabled)
	# Add the photo face after damage registration so it stays a clean photo
	# texture instead of being converted into the damage/toon material pipeline.
	if player_warrior_id == "erebus":
		EREBUS_SKINS.apply(head_style, erebus_skin_id)
	capsule_shape.height = float(head_style.get_meta("capsule_height", 3.43))
	player_visual.rotation.y = body_yaw

	player_name_tag = Label3D.new()
	player_name_tag.name = "PlayerNameTag"
	player_name_tag.text = VIRTUAL_PROFILE.local_username()
	player_name_tag.visible = true
	player_name_tag.position = Vector3(0, 3.17, 0)
	player_name_tag.font_size = 34
	player_name_tag.pixel_size = 0.0063
	player_name_tag.outline_size = 7
	player_name_tag.modulate = Color("9bf8e3")
	player_name_tag.outline_modulate = Color("10131f")
	player_name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	player_name_tag.render_priority = 127
	player_visual.add_child(player_name_tag)

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

func _set_player_virtual_name(value: String) -> void:
	if player_name_tag!=null:player_name_tag.text=VIRTUAL_PROFILE.sanitize_username(value)

func _set_player_healthbar(value: float, maximum: float = 100.0) -> void:
	var next_maximum:=maxf(1.0,maximum)
	var next_value:=clampf(value,0.0,next_maximum)
	var health_changed:=not is_equal_approx(next_value,player_health_value) or not is_equal_approx(next_maximum,player_health_maximum)
	player_health_value=next_value
	player_health_maximum=next_maximum
	if health_changed and player_damage_visual!=null:player_damage_visual.set_health(player_health_value,player_health_maximum)
	if player_health_bar == null:return
	var width := int(round(120.0*player_health_value/player_health_maximum))
	if player_health_image==null:player_health_image=Image.create(128,18,false,Image.FORMAT_RGBA8)
	if player_health_texture==null or width!=player_health_bar_width:
		player_health_bar_width=width
		player_health_image.fill(Color("111726"))
		player_health_image.fill_rect(Rect2i(2,2,124,14),Color("351621"))
		if width > 0:
			player_health_image.fill_rect(Rect2i(4,4,width,10),Color("ff586e"))
			player_health_image.fill_rect(Rect2i(4,4,width,2),Color("ff9aac"))
		for i in range(1,5):player_health_image.fill_rect(Rect2i(4+i*24,4,1,10),Color("562333"))
		if player_health_texture == null:
			player_health_texture=ImageTexture.create_from_image(player_health_image)
			player_health_bar.texture=player_health_texture
		else:player_health_texture.update(player_health_image)
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
	var body_scene: PackedScene = LOKER_FULLBODY if player_warrior_id == "loker" else (AEVILOK_FULLBODY if player_warrior_id == "aevilok" else (KOSAS_FULLBODY if player_warrior_id == "kosas" else (EREBUS_FULLBODY if player_warrior_id == "erebus" else OUTRAGE_FULLBODY)))
	head_style = body_scene.instantiate() as Node3D
	WARRIOR_HAND_STYLE.ensure_hands(head_style)
	if player_warrior_id == "outrage":
		OUTRAGE_SKINS.apply(head_style, outrage_skin_id)
	elif player_warrior_id == "kosas":
		KOSAS_STYLE.apply(head_style)
	elif player_warrior_id == "aevilok":
		AEVILOK_STYLE.apply(head_style)
	elif player_warrior_id == "loker":
		LOKER_STYLE.apply(head_style)
	WARRIOR_RENDER_LOD.apply(head_style)
	if player_warrior_id=="aevilok":AEVILOK_STYLE.enable_wing_batch(head_style)
	player_visual.add_child(head_style)
	head_rig = head_style.get_node("HeadRig") as Node3D
	torso_rig = head_style.get_node("TorsoRig") as Node3D
	left_leg_rig = head_style.get_node("LeftLegRig") as Node3D
	right_leg_rig = head_style.get_node("RightLegRig") as Node3D
	left_hand_rig = head_style.get_node_or_null("LeftHandRig") as Node3D
	right_hand_rig = head_style.get_node_or_null("RightHandRig") as Node3D
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
	AK47_VOXEL_BUILDER.build(weapon_root, ak_skin_id)
	_pixelize_weapon_materials()
	weapon_visual_wobble = Node3D.new()
	weapon_visual_wobble.name = "WeaponVisualWobble"
	weapon_root.add_child(weapon_visual_wobble)
	ak_visual_root=Node3D.new();ak_visual_root.name="AKVisual";weapon_visual_wobble.add_child(ak_visual_root)
	for child in weapon_root.get_children().duplicate():
		if child is MeshInstance3D or child is GPUParticles3D:
			child.reparent(ak_visual_root,false)
	_batch_weapon_visual(ak_visual_root,"AK",1.15)
	shotgun_visual_root=Node3D.new();shotgun_visual_root.name="ShotgunVisual";weapon_visual_wobble.add_child(shotgun_visual_root)
	kar_visual_root=Node3D.new();kar_visual_root.name="KARVisual";weapon_visual_wobble.add_child(kar_visual_root)
	grenade_launcher_visual_root=Node3D.new();grenade_launcher_visual_root.name="GrenadeLauncherVisual";weapon_visual_wobble.add_child(grenade_launcher_visual_root)

	weapon_muzzle = Marker3D.new()
	weapon_muzzle.name = "Muzzle"
	weapon_muzzle.position = Vector3(1.34, 0.02, 0.0)
	weapon_root.add_child(weapon_muzzle)

	ak_fire_audio = AudioStreamPlayer3D.new()
	ak_fire_audio.name = "AKFireAudio"
	ak_fire_audio.stream = AK47_SHOT_SFX
	ak_fire_audio.volume_db = -80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db
	ak_fire_audio.bus="SFX"
	ak_fire_audio.max_distance = 34.0
	ak_fire_audio.unit_size = 2.8
	ak_fire_audio.max_polyphony = 8
	weapon_muzzle.add_child(ak_fire_audio)

	ak_reload_audio = AudioStreamPlayer3D.new()
	ak_reload_audio.name = "AKReloadAudio"
	ak_reload_audio.stream = AK47_RELOAD_SFX
	ak_reload_audio.volume_db = -80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db - 3.0
	ak_reload_audio.bus="SFX"
	ak_reload_audio.max_distance = 28.0
	ak_reload_audio.unit_size = 2.6
	weapon_root.add_child(ak_reload_audio)

	shotgun_fire_audio=AudioStreamPlayer3D.new();shotgun_fire_audio.name="ShotgunFireAudio";shotgun_fire_audio.stream=SHOTGUN_FIRE_SFX
	shotgun_fire_audio.volume_db=-80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db+1.0
	shotgun_fire_audio.bus="SFX";shotgun_fire_audio.pitch_scale=0.82;shotgun_fire_audio.max_distance=40.0;shotgun_fire_audio.unit_size=3.2;shotgun_fire_audio.max_polyphony=4
	weapon_muzzle.add_child(shotgun_fire_audio)
	shotgun_reload_audio=AudioStreamPlayer3D.new();shotgun_reload_audio.name="ShotgunReloadAudio";shotgun_reload_audio.stream=SHOTGUN_RELOAD_SFX
	shotgun_reload_audio.volume_db=-80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db-2.0
	shotgun_reload_audio.bus="SFX";shotgun_reload_audio.pitch_scale=0.92;shotgun_reload_audio.max_distance=30.0;shotgun_reload_audio.unit_size=2.8
	weapon_root.add_child(shotgun_reload_audio)
	kar_fire_audio=AudioStreamPlayer3D.new();kar_fire_audio.name="KARFireAudio";kar_fire_audio.stream=KAR_FIRE_SFX
	kar_fire_audio.volume_db=-80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db+1.5
	kar_fire_audio.bus="SFX";kar_fire_audio.max_distance=58.0;kar_fire_audio.unit_size=4.2;kar_fire_audio.max_polyphony=3
	weapon_muzzle.add_child(kar_fire_audio)
	kar_reload_audio=AudioStreamPlayer3D.new();kar_reload_audio.name="KARReloadAudio";kar_reload_audio.stream=KAR_RELOAD_SFX
	kar_reload_audio.volume_db=-80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db-1.0
	kar_reload_audio.bus="SFX";kar_reload_audio.max_distance=34.0;kar_reload_audio.unit_size=3.0
	weapon_root.add_child(kar_reload_audio)
	grenade_launcher_fire_audio=AudioStreamPlayer3D.new();grenade_launcher_fire_audio.name="GrenadeLauncherFireAudio";grenade_launcher_fire_audio.stream=GRENADE_LAUNCHER_FIRE_SFX
	grenade_launcher_fire_audio.volume_db=-80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db+1.0
	grenade_launcher_fire_audio.bus="SFX";grenade_launcher_fire_audio.max_distance=48.0;grenade_launcher_fire_audio.unit_size=4.5
	weapon_muzzle.add_child(grenade_launcher_fire_audio)
	grenade_launcher_reload_audio=AudioStreamPlayer3D.new();grenade_launcher_reload_audio.name="GrenadeLauncherReloadAudio";grenade_launcher_reload_audio.stream=GRENADE_LAUNCHER_RELOAD_SFX
	grenade_launcher_reload_audio.volume_db=-80.0 if OS.get_cmdline_user_args().has("--kw-qa") else shooting_volume_db-1.0
	grenade_launcher_reload_audio.bus="SFX";grenade_launcher_reload_audio.max_distance=34.0;grenade_launcher_reload_audio.unit_size=3.2
	weapon_root.add_child(grenade_launcher_reload_audio)
	_set_weapon_slot(0,false)

func _build_kar_visual() -> void:
	KAR_VOXEL_BUILDER.build(kar_visual_root, kar_skin_id)
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
	_batch_weapon_visual(kar_visual_root,"KAR",1.10)


func _build_grenade_launcher_visual(parent: Node3D) -> void:
	_add_weapon_box(parent,"GL_Stock",Vector3(-0.38,-0.02,0),Vector3(0.62,0.24,0.28),Color("4e3b2c"))
	_add_weapon_box(parent,"GL_Receiver",Vector3(0.12,0.02,0),Vector3(0.48,0.34,0.34),Color("30353a"))
	_add_weapon_box(parent,"GL_Chamber",Vector3(0.48,0.02,0),Vector3(0.34,0.38,0.38),Color("657078"))
	_add_weapon_box(parent,"GL_Barrel",Vector3(0.92,0.03,0),Vector3(0.62,0.27,0.27),Color("252a2e"))
	_add_weapon_box(parent,"GL_Muzzle",Vector3(1.27,0.03,0),Vector3(0.16,0.36,0.36),Color("14181b"))
	_add_weapon_box(parent,"GL_Grip",Vector3(0.02,-0.25,0),Vector3(0.20,0.38,0.22),Color("24201c"))
	_add_weapon_box(parent,"GL_Sight",Vector3(0.38,0.25,0),Vector3(0.13,0.08,0.10),Color("d7b04c"))
	_batch_weapon_visual(parent,"GL",1.25)

func projectile_style_for_weapon(weapon_id: String) -> Dictionary:
	var id := weapon_id.strip_edges().to_lower()
	match id:
		"ak", "ak47":
			return {
				"color": AK47_VOXEL_BUILDER.main_color(ak_skin_id),
				"inferno": AK47_VOXEL_BUILDER.skin_name(ak_skin_id) == "INFERNO",
			}
		"shotgun":
			return {"color": Color("6d4030"), "inferno": false}
		"kar":
			return {"color": KAR_VOXEL_BUILDER.main_color(kar_skin_id), "inferno": false}
		"grenade_launcher", "launcher", "gl":
			return {"color": Color("d7b04c"), "inferno": false}
		_:
			return {"color": Color("fff1a8"), "inferno": false}

func _build_shotgun_visual() -> void:
	_add_weapon_box(shotgun_visual_root,"SG_Stock",Vector3(-0.36,-0.02,0),Vector3(0.62,0.22,0.24),Color("6d4030"))
	_add_weapon_box(shotgun_visual_root,"SG_Receiver",Vector3(0.18,0.01,0),Vector3(0.62,0.25,0.22),Color("30343b"))
	_add_weapon_box(shotgun_visual_root,"SG_Barrel",Vector3(0.88,0.055,0),Vector3(0.92,0.12,0.14),Color("b7c0c8"))
	_add_weapon_box(shotgun_visual_root,"SG_Pump",Vector3(0.62,-0.09,0),Vector3(0.42,0.18,0.25),Color("8a5238"))
	_add_weapon_box(shotgun_visual_root,"SG_Grip",Vector3(0.02,-0.22,0),Vector3(0.20,0.36,0.22),Color("20232a"))
	_add_weapon_box(shotgun_visual_root,"SG_Sight",Vector3(0.30,0.18,0),Vector3(0.10,0.08,0.10),Color("ffcf70"))
	_batch_weapon_visual(shotgun_visual_root,"SHOTGUN",1.25)

func _add_weapon_box(parent: Node3D,title: String,pos: Vector3,size: Vector3,color: Color) -> MeshInstance3D:
	var mesh:=MeshInstance3D.new();mesh.name=title
	var box:=BoxMesh.new();box.size=size;mesh.mesh=box;mesh.position=pos
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.material_override=_material(color,false,0.0);parent.add_child(mesh)
	return mesh

func _batch_weapon_visual(root: Node3D,label: String,outline_width: float=1.20) -> void:
	if root==null or bool(root.get_meta("kw_weapon_batched",false)):return
	var parts: Array[MeshInstance3D]=[]
	for child in root.get_children():
		var part:=child as MeshInstance3D
		if part!=null and part.mesh is BoxMesh and part.visible:
			parts.append(part)
	if parts.is_empty():return
	var seed_outline:=SCENE_INK.add_to(parts[0],comic_enabled,outline_width)
	var groups: Dictionary={}
	for part in parts:
		var material:=part.material_override
		if material==null:continue
		var key:=str(material.get_instance_id())
		if not groups.has(key):groups[key]=[]
		(groups[key] as Array).append(part)
	var fill_serial:=0
	for key in groups:
		var grouped:=groups[key] as Array
		if grouped.size()<2:continue
		var first:=grouped[0] as MeshInstance3D
		var cube:=BoxMesh.new();cube.size=Vector3.ONE;cube.material=first.material_override
		var multimesh:=MultiMesh.new();multimesh.transform_format=MultiMesh.TRANSFORM_3D;multimesh.mesh=cube;multimesh.instance_count=grouped.size()
		for index in range(grouped.size()):
			var source:=grouped[index] as MeshInstance3D
			var source_box:=source.mesh as BoxMesh
			multimesh.set_instance_transform(index,source.transform*Transform3D(Basis.from_scale(source_box.size),Vector3.ZERO))
			source.visible=false
		var batch:=MultiMeshInstance3D.new();batch.name="WeaponFillBatch_%s_%02d"%[label,fill_serial];fill_serial+=1
		batch.multimesh=multimesh;batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(batch)
	if seed_outline!=null and seed_outline.mesh!=null:
		var first_size: Vector3=(parts[0].mesh as BoxMesh).size
		var outline_mm:=MultiMesh.new();outline_mm.transform_format=MultiMesh.TRANSFORM_3D;outline_mm.mesh=seed_outline.mesh;outline_mm.instance_count=parts.size()
		for index in range(parts.size()):
			var source:=parts[index]
			var size: Vector3=(source.mesh as BoxMesh).size
			var ratio:=Vector3(size.x/maxf(0.0001,first_size.x),size.y/maxf(0.0001,first_size.y),size.z/maxf(0.0001,first_size.z))
			outline_mm.set_instance_transform(index,source.transform*seed_outline.transform*Transform3D(Basis.from_scale(ratio),Vector3.ZERO))
		seed_outline.visible=false;seed_outline.layers=0
		if seed_outline.is_in_group("kw_world_ink"):seed_outline.remove_from_group("kw_world_ink")
		var outline_batch:=MultiMeshInstance3D.new();outline_batch.name="WeaponInkBatch_%s"%label;outline_batch.multimesh=outline_mm
		outline_batch.material_override=seed_outline.material_override;outline_batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		outline_batch.visible=comic_enabled;outline_batch.add_to_group("kw_world_ink");root.add_child(outline_batch)
	root.set_meta("kw_weapon_batched",true)

func _set_weapon_slot(slot: int,play_fx: bool=true) -> void:
	var previous_slot:=weapon_slot
	var next_slot:=clampi(slot,0,3)
	weapon_slot=next_slot
	if weapon_slot!=previous_slot and weapon_visual_wobble!=null:
		var forward_delta:=posmod(weapon_slot-previous_slot,4)
		weapon_swap_direction=1.0 if forward_delta in [1,2] else -1.0
		weapon_swap_time=WEAPON_SWAP_VISUAL_DURATION
	inspect_time=0.0
	_ensure_local_weapon_visual(weapon_slot)
	if ak_visual_root!=null:ak_visual_root.visible=weapon_slot==0
	if shotgun_visual_root!=null:shotgun_visual_root.visible=weapon_slot==1
	if kar_visual_root!=null:kar_visual_root.visible=weapon_slot==2
	if grenade_launcher_visual_root!=null:grenade_launcher_visual_root.visible=weapon_slot==3
	if weapon_muzzle!=null:weapon_muzzle.position=Vector3(float(WEAPON_RULES.by_slot(weapon_slot).muzzle_x),0.02,0.0)
	_pose_weapon_hands()
	if play_fx and arena_audio!=null:arena_audio.play_event("switch",Vector3.ZERO,-18.0)
	aim_recoil.reset();shot_cooldown=maxf(shot_cooldown,0.08);_refresh_ammo_hud();_update_scope_visibility()

func _ensure_local_weapon_visual(slot: int) -> void:
	if slot<0 or slot>=local_weapon_visual_built.size() or local_weapon_visual_built[slot]:return
	match slot:
		1:_build_shotgun_visual()
		2:_build_kar_visual()
		3:_build_grenade_launcher_visual(grenade_launcher_visual_root)
	local_weapon_visual_built[slot]=true

func _cycle_weapon(direction: int) -> void:
	_set_weapon_slot(posmod(weapon_slot+direction,4),true)

func _start_weapon_inspect() -> void:
	if reload_remaining>0.0 or fire_held:return
	inspect_time=INSPECT_DURATION
	aiming=false
	_update_scope_visibility()

func _pose_weapon_hands() -> void:
	if weapon_visual_wobble == null:
		return
	if left_hand_rig == null or right_hand_rig == null:
		return
	var right_grip := Vector3(-0.04, -0.12, -0.12)
	var left_grip := Vector3(0.50, -0.05, 0.09)
	var right_direction := Vector3(-0.10, 0.34, 0.94)
	var left_direction := Vector3(-0.20, 0.28, 0.94)
	match weapon_slot:
		1:
			right_grip = Vector3(0.02, -0.22, -0.12)
			left_grip = Vector3(0.62, -0.10, 0.09)
			right_direction = Vector3(-0.12, 0.32, 0.94)
			left_direction = Vector3(-0.22, 0.26, 0.94)
		2:
			right_grip = Vector3(-0.14, -0.27, -0.12)
			left_grip = Vector3(0.58, -0.07, 0.09)
			right_direction = Vector3(-0.10, 0.30, 0.95)
			left_direction = Vector3(-0.20, 0.24, 0.95)
		3:
			right_grip = Vector3(0.00, -0.24, -0.12)
			left_grip = Vector3(0.66, -0.06, 0.09)
			right_direction = Vector3(-0.10, 0.32, 0.94)
			left_direction = Vector3(-0.18, 0.25, 0.95)
	_place_hand_on_grip(right_hand_rig, weapon_visual_wobble, right_grip, right_direction, 0.08)
	_place_hand_on_grip(left_hand_rig, weapon_visual_wobble, left_grip, left_direction, -0.10)


func _pose_outage_weapon_hands() -> void:
	# Compatibility alias for existing QA/tools while every warrior now shares
	# the same two-hand weapon pose implementation.
	_pose_weapon_hands()


func _place_hand_on_grip(hand: Node3D, pivot: Node3D, grip_local: Vector3, finger_direction: Vector3, twist: float) -> void:
	if hand == null or pivot == null:
		return
	var direction := finger_direction.normalized()
	var basis := Basis(Quaternion(Vector3.UP, direction))
	basis = basis.rotated(direction, twist)
	hand.global_transform = pivot.global_transform * Transform3D(basis, grip_local)

func _best_offline_aim_assist_target() -> Vector3:
	if camera==null or combat==null:return Vector3(INF,INF,INF)
	var best_point:=Vector3(INF,INF,INF)
	var camera_position:=camera.global_position
	var forward:=AIM_ASSIST.forward(yaw,pitch)
	var best_alignment:=cos(deg_to_rad(AIM_ASSIST.CONE_DEG))
	var max_range_sq:=AIM_ASSIST.MAX_RANGE*AIM_ASSIST.MAX_RANGE
	for target in combat.targets:
		if not is_instance_valid(target) or bool(target.dead):continue
		var torso:=target.visuals.get_node_or_null("TorsoRig") as Node3D
		if torso==null:continue
		var point:=torso.global_position+Vector3.UP*0.34
		var offset:=point-camera_position
		var distance_sq:=offset.length_squared()
		if distance_sq<=0.0001 or distance_sq>max_range_sq:continue
		var alignment:=forward.dot(offset/sqrt(distance_sq))
		if alignment<best_alignment:continue
		if not _aim_assist_line_clear(point):continue
		best_alignment=alignment;best_point=point
	return best_point

func _aim_assist_line_clear(point: Vector3) -> bool:
	if camera==null or player==null:return false
	if aim_assist_ray_exclude.is_empty():
		aim_assist_ray_exclude.append(player.get_rid())
		aim_assist_ray_query.exclude=aim_assist_ray_exclude
		aim_assist_ray_query.collision_mask=1
		aim_assist_ray_query.hit_from_inside=true
	aim_assist_ray_query.from=camera.global_position;aim_assist_ray_query.to=point
	return get_world_3d().direct_space_state.intersect_ray(aim_assist_ray_query).is_empty()

func _apply_offline_aim_assist(delta: float) -> void:
	aim_assist_active=false
	if not aiming or weapon_slot in [2,3]:return
	var point:=_best_offline_aim_assist_target()
	if not point.is_finite():return
	var before_yaw:=yaw
	var before_pitch:=pitch
	var assisted:=AIM_ASSIST.step(yaw,pitch,camera.global_position,point,delta)
	yaw=wrapf(assisted.x,-PI,PI)
	pitch=clampf(assisted.y,deg_to_rad(-48.0),deg_to_rad(30.0))
	aim_assist_active=absf(angle_difference(before_yaw,yaw))>0.000001 or absf(before_pitch-pitch)>0.000001

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
		var sprint_target:=1.0 if visual_sprinting and not aiming and not fire_held and reload_remaining<=0.0 and inspect_time<=0.0 else 0.0
		weapon_sprint_blend=move_toward(weapon_sprint_blend,sprint_target,maxf(0.0,delta)*(5.8 if sprint_target>weapon_sprint_blend else 8.5))
		var sprint_bob:=sin(anim_time*10.5)*0.028*weapon_sprint_blend*clampf(move_blend,0.0,1.0)
		var land_drop:=clampf(landing_kick*1.55,0.0,0.34)
		weapon_swap_time=maxf(0.0,weapon_swap_time-maxf(0.0,delta))
		var swap_progress:=1.0-clampf(weapon_swap_time/WEAPON_SWAP_VISUAL_DURATION,0.0,1.0) if weapon_swap_time>0.0 else 1.0
		var swap_arc:=sin(PI*swap_progress) if weapon_swap_time>0.0 else 0.0
		weapon_visual_wobble.position=Vector3(
			-0.16*inspect_arc+weapon_visual_side_kick+0.16*weapon_sprint_blend+0.12*weapon_swap_direction*swap_arc,
			0.18*inspect_arc-0.17*reload_arc+weapon_visual_lift_kick-0.20*weapon_sprint_blend-land_drop*0.22+sprint_bob-0.30*swap_arc,
			0.34*inspect_arc+0.16*reload_arc+weapon_recoil*0.05+0.12*weapon_sprint_blend+land_drop*0.08+0.08*swap_arc)
		weapon_visual_wobble.rotation=Vector3(
			one_hand_pitch-0.28*inspect_arc-0.22*reload_arc-0.18*weapon_sprint_blend+land_drop*0.20-0.16*swap_arc,
			inspect_turn+0.08*reload_arc+0.10*weapon_sprint_blend,
			one_hand_roll+inspect_roll+weapon_visual_twist_kick+0.62*reload_arc+reload_snap-0.40*weapon_sprint_blend+0.48*weapon_swap_direction*swap_arc)
	for child in weapon_aim_pivot.get_children():
		if child.has_meta("hold_rest"):
			var hand_rest: Vector3 = child.get_meta("hold_rest")
			child.position = hand_rest + Vector3(sin(anim_time*5.2)*0.035*loose_amount + weapon_visual_side_kick*0.65,-0.10*reload_arc+cos(anim_time*6.8)*0.025*loose_amount + weapon_visual_lift_kick*0.65,weapon_root.position.z+0.30+0.10*reload_arc)
			child.rotation = Vector3(one_hand_pitch*0.55-0.12*reload_arc,0.0,one_hand_roll*0.7 + weapon_visual_twist_kick*0.65+0.38*reload_arc)
	_pose_weapon_hands()
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
	if player_warrior_id == "aevilok" and head_style != null:
		var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
		AEVILOK_STYLE.animate_wings(
			head_style,
			delta,
			anim_time,
			walk_phase,
			horizontal_speed,
			player.velocity.y,
			player.is_on_floor()
		)
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
	help.text = "WASD move   SHIFT sprint   SPACE jump   RMB aim+magnet   LMB fire   R reload\nWHEEL weapon   H inspect   E warrior skill   G grenade   O comic   P pixels   Y Borderlands   M music\nKAR: RMB scope // NO magnet // near-still movement   TAB help   ESC cursor   F10 test rooms"
	help.position = Vector2(12, 28)
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.86, 0.86, 0.92))
	help_panel.add_child(help)

	status_label = Label.new()
	status_label.position = Vector2(12, 76)
	status_label.add_theme_font_size_override("font_size", 11)
	help_panel.add_child(status_label)
	_update_status()

	warrior_skill_label = Label.new()
	warrior_skill_label.name = "WarriorSkillStatus"
	warrior_skill_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warrior_skill_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	warrior_skill_label.offset_left = -220
	warrior_skill_label.offset_right = 220
	warrior_skill_label.offset_top = -60
	warrior_skill_label.offset_bottom = -32
	warrior_skill_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warrior_skill_label.add_theme_font_size_override("font_size", 12)
	help_panel.add_child(warrior_skill_label)

	warrior_skill_bar = ProgressBar.new()
	warrior_skill_bar.name = "WarriorSkillCooldown"
	warrior_skill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warrior_skill_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	warrior_skill_bar.offset_left = -170
	warrior_skill_bar.offset_right = 170
	warrior_skill_bar.offset_top = -29
	warrior_skill_bar.offset_bottom = -18
	warrior_skill_bar.min_value = 0.0
	warrior_skill_bar.max_value = 1.0
	warrior_skill_bar.value = 1.0
	warrior_skill_bar.show_percentage = false
	var skill_bg := StyleBoxFlat.new()
	skill_bg.bg_color = Color("171b25")
	skill_bg.border_color = Color("4a5264")
	skill_bg.set_border_width_all(1)
	var skill_fill := StyleBoxFlat.new()
	skill_fill.bg_color = WARRIOR_SKILL_RULES.color(player_warrior_id)
	skill_fill.corner_radius_top_left = 2
	skill_fill.corner_radius_top_right = 2
	skill_fill.corner_radius_bottom_left = 2
	skill_fill.corner_radius_bottom_right = 2
	warrior_skill_bar.add_theme_stylebox_override("background", skill_bg)
	warrior_skill_bar.add_theme_stylebox_override("fill", skill_fill)
	help_panel.add_child(warrior_skill_bar)
	_update_warrior_skill_hud(0.0, 0.0)

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
	var reload_tenth:=int(round(maxf(0.0,reload_remaining)*10.0)) if reload_remaining>0.0 else 0
	if ammo_hud_last_slot==weapon_slot and ammo_hud_last_ammo==ammo_in_mag and ammo_hud_last_maximum==maximum and ammo_hud_last_reload_tenth==reload_tenth:
		return
	ammo_hud_last_slot=weapon_slot
	ammo_hud_last_ammo=ammo_in_mag
	ammo_hud_last_maximum=maximum
	ammo_hud_last_reload_tenth=reload_tenth
	if reload_remaining>0.0:
		player_ammo_label.text="%s  %d / %d  //  RELOAD %.1f" % [str(profile.label),ammo_in_mag,maximum,float(reload_tenth)/10.0]
		player_ammo_label.modulate=Color("ffcf70")
	else:
		player_ammo_label.text="%s  %d / %d" % [str(profile.label),ammo_in_mag,maximum]
		player_ammo_label.modulate=Color("ff7b76") if ammo_in_mag<=maxi(1,int(ceil(maximum*0.20))) else Color("fff2c7")

func _tick_reload(delta: float) -> void:
	var changed:=false
	for slot in range(4):
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
	reload_remaining=float(profile.reload)*skill_reload_duration_multiplier()
	aim_recoil.reset()
	if play_fx:
		var audio:=ak_reload_audio if weapon_slot==0 else shotgun_reload_audio if weapon_slot==1 else kar_reload_audio if weapon_slot==2 else grenade_launcher_reload_audio
		if audio!=null:audio.play()
		if weapon_slot in [0,1]:_spawn_reload_magazine()
	_refresh_ammo_hud()
	return true

func _spawn_reload_magazine() -> void:
	if weapon_root==null:return
	reload_mag_serial+=1
	var mag:=_acquire_reload_magazine()
	mag.name="ReloadMag%02d"%reload_mag_serial
	mag.visible=true
	mag.scale=Vector3.ONE
	mag.global_transform=Transform3D(weapon_root.global_basis,weapon_root.to_global(Vector3(0.38,-0.20,0.0)))
	var start:=mag.global_position
	var side_dir:=weapon_root.global_basis.z.normalized()*0.18
	active_reload_mags.append({"node":mag,"age":0.0,"duration":0.55,"start":start,"end":start+Vector3.DOWN*1.15+side_dir,"start_rotation":mag.rotation,"end_rotation":mag.rotation+Vector3(1.6,0.8,-1.2)})

func _acquire_reload_magazine() -> MeshInstance3D:
	for mag in reload_mag_pool:
		if is_instance_valid(mag) and not bool(mag.get_meta("kw_reload_mag_active",false)):
			mag.set_meta("kw_reload_mag_active",true)
			return mag
	var mag:=MeshInstance3D.new()
	var box:=BoxMesh.new();box.size=Vector3(0.15,0.36,0.09);mag.mesh=box
	mag.material_override=_material(Color("24262d"),false,0.0)
	mag.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mag.visible=false;mag.set_meta("kw_reload_mag_active",true);add_child(mag);_add_scene_outline(mag,0.85)
	reload_mag_pool.append(mag)
	return mag

func _release_reload_magazine(mag: MeshInstance3D) -> void:
	if mag==null:return
	mag.visible=false;mag.scale=Vector3.ONE;mag.rotation=Vector3.ZERO;mag.set_meta("kw_reload_mag_active",false)

func _tick_reload_magazines(delta: float) -> void:
	for i in range(active_reload_mags.size()-1,-1,-1):
		var data: Dictionary=active_reload_mags[i]
		var mag:=data.node as MeshInstance3D
		if not is_instance_valid(mag):active_reload_mags.remove_at(i);continue
		data.age=float(data.age)+delta
		var p:=clampf(float(data.age)/float(data.duration),0.0,1.0)
		var eased:=p*p
		mag.global_position=(data.start as Vector3).lerp(data.end as Vector3,eased)
		mag.rotation=(data.start_rotation as Vector3).lerp(data.end_rotation as Vector3,eased)
		mag.scale=Vector3.ONE*lerpf(1.0,0.65,eased)
		if p>=1.0:_release_reload_magazine(mag);active_reload_mags.remove_at(i)

func _set_authoritative_weapon_state(state: Dictionary,force: bool=false) -> void:
	var server_slot:=clampi(int(state.get("weapon",weapon_slot)),0,3)
	var server_ammo: Array[int]=[
		clampi(int(state.get("ak_ammo",ammo_by_weapon[0])),0,int(WEAPON_RULES.AK.magazine)),
		clampi(int(state.get("sg_ammo",ammo_by_weapon[1])),0,int(WEAPON_RULES.SHOTGUN.magazine)),
		clampi(int(state.get("kar_ammo",ammo_by_weapon[2])),0,int(WEAPON_RULES.KAR.magazine)),
		clampi(int(state.get("gl_ammo",ammo_by_weapon[3])),0,int(WEAPON_RULES.GRENADE_LAUNCHER.magazine))]
	var server_reload: Array[float]=[
		clampf(float(state.get("ak_reload",reload_by_weapon[0])),0.0,float(WEAPON_RULES.AK.reload)),
		clampf(float(state.get("sg_reload",reload_by_weapon[1])),0.0,float(WEAPON_RULES.SHOTGUN.reload)),
		clampf(float(state.get("kar_reload",reload_by_weapon[2])),0.0,float(WEAPON_RULES.KAR.reload)),
		clampf(float(state.get("gl_reload",reload_by_weapon[3])),0.0,float(WEAPON_RULES.GRENADE_LAUNCHER.reload))]
	if force:
		ammo_by_weapon=server_ammo;reload_by_weapon=server_reload;_set_weapon_slot(server_slot,false)
	else:
		for slot in range(4):
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
	weapon_recoil=1.0 if weapon_slot==0 else 1.45 if weapon_slot==1 else 1.75 if weapon_slot==2 else 1.95
	var goofy:=1.75 if randf()<0.08 else 1.0
	var strength:=1.0 if weapon_slot==0 else 1.65 if weapon_slot==1 else 2.05 if weapon_slot==2 else 2.25
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
	ammo_in_mag-=1;_refresh_ammo_hud();shot_cooldown+=float(profile.fire_interval)*skill_fire_interval_multiplier()
	_update_weapon_pose(0.0);_kick_weapon_visuals();_play_weapon_fire_audio()
	var chest := _weapon_anchor()
	if weapon_slot==0:combat.fire(weapon_muzzle.global_position,aim_target,chest,WEAPON_RULES.AK,"ak")
	elif weapon_slot==1:combat.fire_shotgun(weapon_muzzle.global_position,aim_target,chest)
	elif weapon_slot==2:combat.fire(weapon_muzzle.global_position,aim_target,chest,WEAPON_RULES.KAR,"kar")
	else:
		var launch_direction := (aim_target-weapon_muzzle.global_position).normalized()
		grenade_skill.fire_launcher(weapon_muzzle.global_position,launch_direction,WEAPON_RULES.GRENADE_LAUNCHER)
		if combat.reticle!=null:combat.reticle.notify_shot()
	_apply_body_fire_recoil(yaw)
	var aim_kick: Vector2=aim_recoil.kick(aiming)
	if weapon_slot==1:aim_kick+=aim_recoil.kick(aiming)
	elif weapon_slot==2:
		aim_kick+=aim_recoil.kick(aiming)*1.55
	elif weapon_slot==3:
		aim_kick+=aim_recoil.kick(aiming)*1.25
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
	if weapon_slot==3:
		if grenade_launcher_fire_audio!=null and grenade_launcher_fire_audio.stream!=null:
			grenade_launcher_fire_audio.pitch_scale=randf_range(0.96,1.02);grenade_launcher_fire_audio.play()
		return
	if kar_fire_audio!=null and kar_fire_audio.stream!=null:
		kar_fire_audio.pitch_scale=randf_range(0.96,1.02);kar_fire_audio.play()


func skill_damage_multiplier() -> float:
	return float(warrior_skill.damage_multiplier()) if warrior_skill!=null else 1.0


func skill_fire_interval_multiplier() -> float:
	return float(warrior_skill.fire_interval_multiplier()) if warrior_skill!=null else 1.0


func skill_reload_duration_multiplier() -> float:
	return float(warrior_skill.reload_duration_multiplier()) if warrior_skill!=null else 1.0


func skill_is_immune() -> bool:
	return bool(warrior_skill.is_immune()) if warrior_skill!=null else false


func _update_warrior_skill_hud(cooldown_left: float, active_left: float) -> void:
	if warrior_skill_label==null:return
	var cfg:=WARRIOR_SKILL_RULES.config_ref(player_warrior_id)
	var label:=str(cfg.get("label","SKILL"))
	var color:=cfg.get("color",Color.WHITE) as Color
	var cooldown_max:=maxf(0.01,float(cfg.get("cooldown",10.0)))
	var duration_max:=maxf(0.01,float(cfg.get("duration",1.0)))
	if active_left>0.001:
		warrior_skill_label.text="E / LB  %s  //  ACTIVE %.1fs" % [label,active_left]
		warrior_skill_label.modulate=color
		if warrior_skill_bar!=null:warrior_skill_bar.value=clampf(active_left/duration_max,0.0,1.0)
	elif cooldown_left>0.001:
		warrior_skill_label.text="E / LB  %s  //  %.1fs" % [label,cooldown_left]
		warrior_skill_label.modulate=color.lerp(Color("8b919d"),0.52)
		if warrior_skill_bar!=null:warrior_skill_bar.value=clampf(1.0-cooldown_left/cooldown_max,0.0,1.0)
	else:
		warrior_skill_label.text="E / LB  %s  //  READY" % label
		warrior_skill_label.modulate=color
		if warrior_skill_bar!=null:warrior_skill_bar.value=1.0


func _spawn_warrior_skill_vfx(root: Node3D, warrior_id: String, duration: float) -> void:
	if root==null:return
	var old:=root.get_node_or_null("WarriorSkillGlow")
	if old!=null:
		old.name="WarriorSkillGlowRetired"
		old.queue_free()
	var fx:=Node3D.new();fx.name="WarriorSkillGlow";root.add_child(fx)
	var external_anchor: Node3D=null
	var skill_color:=WARRIOR_SKILL_RULES.color(warrior_id)
	var light:=OmniLight3D.new();light.light_color=skill_color;light.light_energy=2.6;light.omni_range=4.2;light.position=Vector3(0,0.75,0);fx.add_child(light)
	match warrior_id:
		"outrage":
			FLAME_PARTICLES.add_character_fire_aura(fx,Color("ff321a"),Color("fff27a"))
			_spawn_outage_damage_boost_flames(fx)
			light.light_energy=4.0
			light.light_color=Color("ff5a20")
		"aevilok":
			var head:=root.find_child("HeadRig",true,false) as Node3D
			var flame_parent:=fx
			if head!=null:
				var previous:=head.get_node_or_null("AevilokSkillFlameAnchor") as Node3D
				if previous!=null:
					previous.name="AevilokSkillFlameAnchorRetired"
					previous.queue_free()
				external_anchor=Node3D.new();external_anchor.name="AevilokSkillFlameAnchor";head.add_child(external_anchor)
				flame_parent=external_anchor
			FLAME_PARTICLES.add_flame_cone(flame_parent)
			_spawn_aevilok_flame_meshes(flame_parent)
			light.light_energy=4.6
			light.light_color=Color("ff5320")
		"erebus":
			_spawn_erebus_shield_vfx(fx,skill_color)
		"loker":
			FLAME_PARTICLES.add_character_fire_aura(fx,Color("20d856"),Color("d9ff77"))
			light.light_energy=3.4
		"kosas":
			light.light_energy=4.8
	var timer:=get_tree().create_timer(maxf(0.12,duration))
	timer.timeout.connect(_finish_warrior_skill_vfx.bind(weakref(fx),weakref(external_anchor) if external_anchor!=null else null))

func _finish_warrior_skill_vfx(fx_ref: WeakRef,anchor_ref: WeakRef) -> void:
	var fx_node:=fx_ref.get_ref() as Node if fx_ref!=null else null
	if is_instance_valid(fx_node):fx_node.queue_free()
	var anchor:=anchor_ref.get_ref() as Node if anchor_ref!=null else null
	if is_instance_valid(anchor):anchor.queue_free()


func _skill_emissive_material(color: Color, alpha: float = 1.0, energy: float = 4.0) -> ShaderMaterial:
	var mat:=_material(Color(color.r,color.g,color.b,1.0),true,energy)
	mat.set_shader_parameter("glow_energy",clampf(0.35+energy*0.10,0.35,1.25))
	return mat


func _spawn_outage_damage_boost_flames(parent: Node3D) -> void:
	var outer:=_skill_emissive_material(Color("ff3518"),0.88,5.0)
	var inner:=_skill_emissive_material(Color("ffe66a"),0.96,6.5)
	var positions: Array[Vector3]=[
		Vector3(-0.42,0.28,0.18),Vector3(0.42,0.34,-0.08),Vector3(-0.28,0.92,-0.16),
		Vector3(0.26,1.02,0.18),Vector3(-0.12,1.45,0.02),Vector3(0.38,1.55,-0.06)
	]
	for i in range(positions.size()):
		var flame:=MeshInstance3D.new();flame.name="DamageBoostFlame%02d"%i
		var mesh:=SphereMesh.new();mesh.radius=0.15 if i<4 else 0.12;mesh.height=0.55 if i<4 else 0.44;flame.mesh=mesh
		flame.material_override=inner if i%2==0 else outer
		flame.position=positions[i]
		flame.scale=Vector3(0.75,1.45,0.75)
		parent.add_child(flame)
		var tween:=flame.create_tween().set_loops()
		var delay:=0.05*float(i)
		if delay>0.0:tween.tween_interval(delay)
		tween.tween_property(flame,"scale",Vector3(0.52,2.15,0.52),0.16+0.025*float(i)).set_trans(Tween.TRANS_SINE)
		tween.tween_property(flame,"scale",Vector3(0.88,1.20,0.88),0.14+0.020*float(i)).set_trans(Tween.TRANS_SINE)


func _spawn_aevilok_flame_meshes(parent: Node3D) -> void:
	var hot:=_skill_emissive_material(Color("fff079"),0.92,7.0)
	var fire:=_skill_emissive_material(Color("ff4b18"),0.82,6.0)
	for i in range(7):
		var flame:=MeshInstance3D.new();flame.name="FlameConeChunk%02d"%i
		var sphere:=SphereMesh.new();sphere.radius=0.11+0.035*float(i);sphere.height=0.26+0.08*float(i);flame.mesh=sphere
		flame.material_override=hot if i<3 else fire
		var z:=-0.48-float(i)*0.48
		flame.position=Vector3(sin(float(i)*2.1)*0.07*float(i),cos(float(i)*1.7)*0.035*float(i),z)
		flame.scale=Vector3(0.75+0.10*float(i),0.75+0.05*float(i),1.0)
		parent.add_child(flame)
		var tween:=flame.create_tween().set_loops()
		tween.tween_property(flame,"scale",flame.scale*1.28,0.10+0.015*float(i)).set_trans(Tween.TRANS_SINE)
		tween.tween_property(flame,"scale",flame.scale*0.82,0.09+0.012*float(i)).set_trans(Tween.TRANS_SINE)


func _spawn_aevilok_flame_burst(origin: Vector3, direction: Vector3) -> void:
	var burst:=_acquire_aevilok_flame_burst()
	var root:=burst.root as Node3D
	var flames:=burst.flames as Array
	var base_scales:=burst.base_scales as Array
	var light:=burst.light as OmniLight3D
	root.visible=true
	var right:=direction.cross(Vector3.UP).normalized()
	if right.length_squared()<0.001:right=Vector3.RIGHT
	var up:=right.cross(direction).normalized()
	for i in range(9):
		var t: float=(float(i)+1.0)/9.0
		var flame:=flames[i] as MeshInstance3D
		var spread:=0.10+0.38*t
		var side:=sin(float(i)*2.35)*spread
		var vertical:=cos(float(i)*1.91)*spread*0.45
		flame.global_position=origin+direction*(0.55+5.7*t)+right*side+up*vertical
		flame.scale=base_scales[i] as Vector3
	light.light_energy=7.5;light.visible=true;light.global_position=origin+direction*2.4
	burst.age=0.0
	active_aevilok_bursts.append(burst)

func _ensure_aevilok_burst_resources() -> void:
	if aevilok_burst_materials.is_empty():
		aevilok_burst_materials=[
			_skill_emissive_material(Color("fff087"),0.96,8.0),
			_skill_emissive_material(Color("ff7a1d"),0.88,7.0),
			_skill_emissive_material(Color("ff3217"),0.78,6.0)]
	if aevilok_burst_meshes.is_empty():
		for i in range(9):
			var t:=(float(i)+1.0)/9.0
			var sphere:=SphereMesh.new();sphere.radius=0.10+0.15*t;sphere.height=0.24+0.42*t
			aevilok_burst_meshes.append(sphere)

func _create_aevilok_flame_burst() -> Dictionary:
	_ensure_aevilok_burst_resources()
	var root:=Node3D.new()
	root.name="AevilokWorldFlameBurst" if aevilok_burst_pool.is_empty() else "AevilokWorldFlameBurstPool%d"%aevilok_burst_pool.size()
	root.visible=false;add_child(root)
	var flames: Array=[];var base_scales: Array=[]
	for i in range(9):
		var t:=(float(i)+1.0)/9.0
		var flame:=MeshInstance3D.new();flame.name="WorldFlame%02d"%i;flame.mesh=aevilok_burst_meshes[i]
		flame.material_override=aevilok_burst_materials[0] if i<3 else aevilok_burst_materials[1] if i<7 else aevilok_burst_materials[2]
		flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;root.add_child(flame)
		var base:=Vector3(0.70+0.70*t,0.70+0.65*t,1.0);flame.scale=base;base_scales.append(base);flames.append(flame)
	var light:=OmniLight3D.new();light.light_color=Color("ff6a24");light.light_energy=7.5;light.omni_range=6.5;light.shadow_enabled=false;root.add_child(light)
	var burst:={"root":root,"flames":flames,"base_scales":base_scales,"light":light,"age":0.0}
	aevilok_burst_pool.append(burst)
	return burst

func _acquire_aevilok_flame_burst() -> Dictionary:
	for burst in aevilok_burst_pool:
		if not (burst.root as Node3D).visible:return burst
	if aevilok_burst_pool.size()<MAX_AEVILOK_BURSTS:return _create_aevilok_flame_burst()
	var oldest: Dictionary=active_aevilok_bursts.pop_front()
	_release_aevilok_flame_burst(oldest)
	return oldest

func _release_aevilok_flame_burst(burst: Dictionary) -> void:
	var root:=burst.root as Node3D
	if root!=null:root.visible=false
	var light:=burst.light as OmniLight3D
	if light!=null:light.visible=false;light.light_energy=0.0

func _tick_aevilok_flame_bursts(delta: float) -> void:
	for i in range(active_aevilok_bursts.size()-1,-1,-1):
		var burst: Dictionary=active_aevilok_bursts[i]
		burst.age=float(burst.age)+delta
		var p:=clampf(float(burst.age)/0.24,0.0,1.0)
		var eased:=1.0-pow(1.0-p,4.0)
		var flames:=burst.flames as Array;var base_scales:=burst.base_scales as Array
		for j in range(flames.size()):(flames[j] as MeshInstance3D).scale=(base_scales[j] as Vector3)*lerpf(1.0,1.75,eased)
		if float(burst.age)>=0.28:
			_release_aevilok_flame_burst(burst);active_aevilok_bursts.remove_at(i)


func _spawn_erebus_shield_vfx(parent: Node3D, color: Color) -> void:
	var shield:=Node3D.new();shield.name="ImmunityBubble";shield.position=Vector3(0,0.72,0);parent.add_child(shield)
	var mat:=_skill_emissive_material(color,1.0,5.0)
	for i in range(3):
		var ring_mesh:=TorusMesh.new();ring_mesh.inner_radius=1.20;ring_mesh.outer_radius=1.30;ring_mesh.rings=32;ring_mesh.ring_segments=8
		var ring:=MeshInstance3D.new();ring.name="ShieldRing%02d"%i;ring.mesh=ring_mesh;ring.material_override=mat;ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shield.add_child(ring)
		if i==1:ring.rotation_degrees.x=90.0
		elif i==2:ring.rotation_degrees.z=90.0
	var tween:=shield.create_tween().set_loops()
	tween.tween_property(shield,"scale",Vector3.ONE*1.08,0.34).set_trans(Tween.TRANS_SINE)
	tween.tween_property(shield,"scale",Vector3.ONE,0.34).set_trans(Tween.TRANS_SINE)


func _spawn_kosas_dash_vfx(start: Vector3, finish: Vector3) -> void:
	var trail:=Node3D.new();trail.name="KosasNoseRushTrail";add_child(trail);trail.global_position=start
	var direction:=finish-start
	var length:=direction.length()
	var material:=_skill_emissive_material(Color("ff43d5"),0.82,5.6)
	if length>0.05:
		var streak:=MeshInstance3D.new();streak.name="DashStreak"
		var box:=BoxMesh.new();box.size=Vector3(0.52,0.28,length);streak.mesh=box;streak.material_override=material
		trail.add_child(streak)
		streak.position=(finish-start)*0.5+Vector3.UP*0.85
		streak.look_at(trail.to_local(finish+Vector3.UP*0.85),Vector3.UP)
	var ghost_mesh:=SphereMesh.new();ghost_mesh.radius=0.21;ghost_mesh.height=0.42;ghost_mesh.material=material
	var ghost_mm:=MultiMesh.new();ghost_mm.transform_format=MultiMesh.TRANSFORM_3D;ghost_mm.mesh=ghost_mesh;ghost_mm.instance_count=11
	for i in range(11):
		var ghost_world:=start.lerp(finish,float(i)/10.0)+Vector3.UP*(0.70+0.07*sin(float(i)))
		ghost_mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,ghost_world-start))
	var ghost_batch:=MultiMeshInstance3D.new();ghost_batch.name="DashGhostBatch";ghost_batch.multimesh=ghost_mm;ghost_batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;trail.add_child(ghost_batch)
	var impact_ring:=MeshInstance3D.new();impact_ring.name="DashImpactRing"
	var torus:=TorusMesh.new();torus.inner_radius=0.65;torus.outer_radius=0.82;torus.rings=24;torus.ring_segments=8
	impact_ring.mesh=torus;impact_ring.material_override=material;impact_ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.add_child(impact_ring);impact_ring.position=finish-start+Vector3.UP*0.15
	var impact:=OmniLight3D.new();impact.light_color=Color("ff43d5");impact.light_energy=7.0;impact.omni_range=4.0;impact.shadow_enabled=false;trail.add_child(impact);impact.position=finish-start+Vector3.UP*0.8
	var tween:=trail.create_tween()
	tween.parallel().tween_property(impact_ring,"scale",Vector3.ONE*2.5,0.52).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(trail,"scale",Vector3.ONE*0.12,0.52).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_callback(trail.queue_free)

func _play_ak_fire_audio() -> void:
	if ak_fire_audio == null or ak_fire_audio.stream == null:return
	ak_fire_audio.pitch_scale = randf_range(0.975, 1.025);ak_fire_audio.play()

func _spawn_muzzle_flash() -> void:
	if weapon_muzzle == null:
		return
	if combat != null and combat.has_method("_spawn_world_muzzle_flash"):
		var direction := (aim_target-weapon_muzzle.global_position).normalized()
		if direction.length_squared()<0.0001:direction=-camera.global_basis.z if camera!=null else Vector3.FORWARD
		combat._spawn_world_muzzle_flash(weapon_muzzle.global_position,direction,true)

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
	body.set_meta("surface_color", color)
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color, false, 0.0)
	body.add_child(mesh)
	_add_scene_outline(mesh)
	if arena_static_batch_open:arena_static_visual_specs.append({"body":body,"mesh":mesh,"color":color})

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
	body.set_meta("surface_color", color)
	add_child(body)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = _material(color, false, 0.0)
	body.add_child(mesh)
	_add_scene_outline(mesh)
	if arena_static_batch_open:arena_static_visual_specs.append({"body":body,"mesh":mesh,"color":color})
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

func _finalize_static_arena_visuals() -> void:
	if arena_static_visual_specs.is_empty():return
	var fills: Dictionary={}
	var outlined: Array[Dictionary]=[]
	for spec in arena_static_visual_specs:
		var mesh:=spec.mesh as MeshInstance3D
		var body:=spec.body as Node3D
		if mesh==null or body==null or not mesh.mesh is BoxMesh:continue
		var key:=(spec.color as Color).to_html(true)
		if not fills.has(key):fills[key]=[]
		(fills[key] as Array).append(spec)
		var outline:=mesh.get_node_or_null("WorldInkOutline") as MeshInstance3D
		if outline!=null and outline.mesh!=null:outlined.append({"body":body,"mesh":mesh,"outline":outline})
	var fill_serial:=0
	for key in fills:
		var specs:=fills[key] as Array
		var first_mesh:=(specs[0] as Dictionary).mesh as MeshInstance3D
		var cube:=BoxMesh.new();cube.size=Vector3.ONE;cube.material=first_mesh.material_override
		var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=cube;mm.instance_count=specs.size()
		for index in range(specs.size()):
			var spec:=specs[index] as Dictionary
			var source:=spec.mesh as MeshInstance3D
			var source_body:=spec.body as Node3D
			var size: Vector3=(source.mesh as BoxMesh).size
			mm.set_instance_transform(index,source_body.transform*source.transform*Transform3D(Basis.from_scale(size),Vector3.ZERO))
			source.layers=0
		var batch:=MultiMeshInstance3D.new();batch.name="ArenaFillBatch_%02d"%fill_serial;fill_serial+=1
		batch.multimesh=mm;add_child(batch)
	if not outlined.is_empty():
		var first_pair:=outlined[0] as Dictionary
		var first_mesh:=first_pair.mesh as MeshInstance3D
		var first_outline:=first_pair.outline as MeshInstance3D
		var first_size: Vector3=(first_mesh.mesh as BoxMesh).size
		var outline_mm:=MultiMesh.new();outline_mm.transform_format=MultiMesh.TRANSFORM_3D;outline_mm.mesh=first_outline.mesh;outline_mm.instance_count=outlined.size()
		for index in range(outlined.size()):
			var pair:=outlined[index] as Dictionary
			var body:=pair.body as Node3D
			var source:=pair.mesh as MeshInstance3D
			var outline:=pair.outline as MeshInstance3D
			var size: Vector3=(source.mesh as BoxMesh).size
			var ratio:=Vector3(size.x/maxf(0.0001,first_size.x),size.y/maxf(0.0001,first_size.y),size.z/maxf(0.0001,first_size.z))
			outline_mm.set_instance_transform(index,body.transform*source.transform*outline.transform*Transform3D(Basis.from_scale(ratio),Vector3.ZERO))
			outline.layers=0
		var outline_batch:=MultiMeshInstance3D.new();outline_batch.name="ArenaInkBatch";outline_batch.multimesh=outline_mm
		outline_batch.material_override=first_outline.material_override;outline_batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		outline_batch.visible=comic_enabled;outline_batch.add_to_group("kw_world_ink");add_child(outline_batch)
	arena_static_visual_specs.clear()

func _add_neon_strip(pos: Vector3, color: Color) -> void:
	neon_strip_specs.append({"p":pos,"color":color})

func _finalize_neon_strips() -> void:
	if neon_strip_specs.is_empty():return
	var groups: Dictionary={}
	for spec in neon_strip_specs:
		var color:=spec.color as Color
		var key:=color.to_html(false)
		if not groups.has(key):groups[key]={"color":color,"items":[]}
		(groups[key].items as Array).append(spec)
	for key in groups:
		var group: Dictionary=groups[key]
		var items: Array=group.items
		var color:=group.color as Color
		var fill_mesh:=BoxMesh.new();fill_mesh.size=Vector3(2.6,0.04,0.12);fill_mesh.material=_material(color,true,4.0)
		var fill_mm:=MultiMesh.new();fill_mm.transform_format=MultiMesh.TRANSFORM_3D;fill_mm.mesh=fill_mesh;fill_mm.instance_count=items.size()
		var outline_mesh:=BoxMesh.new();outline_mesh.size=Vector3(2.72,0.055,0.135);outline_mesh.material=_material(Color("08070d"),false,0.0)
		var outline_mm:=MultiMesh.new();outline_mm.transform_format=MultiMesh.TRANSFORM_3D;outline_mm.mesh=outline_mesh;outline_mm.instance_count=items.size()
		for index in range(items.size()):
			var pos:=items[index].p as Vector3
			fill_mm.set_instance_transform(index,Transform3D(Basis.IDENTITY,pos))
			outline_mm.set_instance_transform(index,Transform3D(Basis.IDENTITY,pos+Vector3.DOWN*0.002))
		var outline_instance:=MultiMeshInstance3D.new();outline_instance.name="NeonStripOutlineBatch_"+str(key);outline_instance.multimesh=outline_mm;outline_instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(outline_instance);outline_instance.add_to_group("kw_world_ink");outline_instance.visible=comic_enabled
		var fill_instance:=MultiMeshInstance3D.new();fill_instance.name="NeonStripBatch_"+str(key);fill_instance.multimesh=fill_mm;fill_instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(fill_instance)
	neon_strip_specs.clear()

func _add_neon_light(pos: Vector3, color: Color, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = radius
	# The directional sun owns world shadows. Decorative neon omnis only provide
	# colored fill; disabling their eight shadow maps removes a large GPU cost.
	light.shadow_enabled = false
	add_child(light)

func _add_arena_fill_light(node_name: String, pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.name = node_name
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.15
	light.shadow_enabled = false
	add_child(light)

func _add_bounce_pad(pos: Vector3, color: Color) -> void:
	var pad := StaticBody3D.new()
	pad.position = pos
	pad.set_meta("surface_color", color)
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
		WARRIOR_RENDER_LOD.sync_batches(head_style)
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
	if head_style != null:
		head_style.set_enabled(value)
		WARRIOR_RENDER_LOD.sync_batches(head_style)
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
