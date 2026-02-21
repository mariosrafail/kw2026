extends Control

const DEFAULT_PORT := 8080
const MAX_CLIENTS := 8
const DEFAULT_HOST := "127.0.0.1"
const SNAPSHOT_RATE := 45.0
const INPUT_SEND_RATE := 90.0
const PING_INTERVAL := 0.75
const PLAYER_HISTORY_MS := 800
const MAX_INPUT_PACKETS_PER_SEC := 120
const MAX_REPORTED_RTT_MS := 300
const MAX_INPUT_STALE_MS := 120
const LOCAL_RECONCILE_SNAP_DISTANCE := 96.0
const LOCAL_RECONCILE_VERTICAL_SNAP_DISTANCE := 6.0
const LOCAL_RECONCILE_POS_BLEND := 0.08
const LOCAL_RECONCILE_VEL_BLEND := 0.12

const ARG_MODE_PREFIX := "--mode="
const ARG_HOST_PREFIX := "--host="
const ARG_PORT_PREFIX := "--port="
const ARG_NO_AUTOSTART := "--no-autostart"

const MAP_ID_CLASSIC := "classic"
const WEAPON_ID_AK47 := "ak47"
const WEAPON_ID_UZI := "uzi"
const CHARACTER_ID_OUTRAGE := "outrage"
const CHARACTER_ID_EREBUS := "erebus"

const PLAYER_SCENE := preload("res://scenes/entities/player.tscn")
const PROJECTILE_SCENE := preload("res://scenes/entities/bullet.tscn")
const AK47_SCRIPT := preload("res://scripts/weapons/ak47.gd")
const UZI_SCRIPT := preload("res://scripts/weapons/uzi.gd")
const MAP_CATALOG_SCRIPT := preload("res://scripts/world/map_catalog.gd")
const MAP_FLOW_SERVICE_SCRIPT := preload("res://scripts/world/map_flow_service.gd")
const SPAWN_FLOW_SERVICE_SCRIPT := preload("res://scripts/world/spawn_flow_service.gd")
const LOBBY_CONFIG_SCRIPT := preload("res://scripts/lobby/lobby_config.gd")
const LOBBY_SERVICE_SCRIPT := preload("res://scripts/lobby/lobby_service.gd")
const LOBBY_FLOW_CONTROLLER_SCRIPT := preload("res://scripts/lobby/lobby_flow_controller.gd")
const SESSION_CONTROLLER_SCRIPT := preload("res://scripts/network/session_controller.gd")
const CONNECT_RETRY_SCRIPT := preload("res://scripts/network/connect_retry.gd")
const UI_CONTROLLER_SCRIPT := preload("res://scripts/ui/ui_controller.gd")
const SPAWN_IDENTITY_SCRIPT := preload("res://scripts/entities/spawn_identity.gd")
const PLAYER_REPLICATION_SCRIPT := preload("res://scripts/network/player_replication.gd")
const PROJECTILE_SYSTEM_SCRIPT := preload("res://scripts/combat/projectile_system.gd")
const HIT_DAMAGE_RESOLVER_SCRIPT := preload("res://scripts/combat/hit_damage_resolver.gd")
const COMBAT_FLOW_SERVICE_SCRIPT := preload("res://scripts/combat/combat_flow_service.gd")
const CLIENT_RPC_FLOW_SERVICE_SCRIPT := preload("res://scripts/network/client_rpc_flow_service.gd")
const CLIENT_INPUT_CONTROLLER_SCRIPT := preload("res://scripts/input/client_input_controller.gd")
const COMBAT_EFFECTS_SCRIPT := preload("res://scripts/effects/combat_effects.gd")
const CAMERA_SHAKE_SCRIPT := preload("res://scripts/effects/camera_shake.gd")

const AK47_SHOT_SFX := preload("res://assets/sounds/sfx/guns/ak47/ak_shoot.wav")
const AK47_RELOAD_SFX := preload("res://assets/sounds/sfx/guns/ak47/ak_reload.wav")
const UZI_SHOT_SFX := preload("res://assets/sounds/sfx/guns/uzi/uzi_shoot.wav")
const UZI_RELOAD_SFX := preload("res://assets/sounds/sfx/guns/uzi/uzi_reload.wav")
const SPLASH_HIT_SFX := preload("res://assets/sounds/sfx/splash.MP3")
const DEATH_HIT_SFX := preload("res://assets/sounds/sfx/general/death.wav")
const BULLET_TOUCH_SFX := preload("res://assets/sounds/sfx/guns/shared/bullet_touch.wav")
const GUNS_SPRITESHEET := preload("res://assets/warriors/guns.png")

enum Role { NONE, SERVER, CLIENT }

@export var enable_lobby_scene_flow := false
@export var damage_boost_enabled := false
@export var default_selected_weapon_id := WEAPON_ID_AK47
@export var default_selected_map_id := MAP_ID_CLASSIC
@export var default_selected_character_id := CHARACTER_ID_OUTRAGE

@onready var port_spin: SpinBox = %PortSpin
@onready var host_input: LineEdit = %HostInput
@onready var start_server_button: Button = %StartServerButton
@onready var stop_button: Button = %StopButton
@onready var connect_button: Button = %ConnectButton
@onready var disconnect_button: Button = %DisconnectButton
@onready var status_label: Label = %StatusLabel
@onready var peers_label: Label = %PeersLabel
@onready var log_label: RichTextLabel = %LogLabel
@onready var local_ip_label: Label = %LocalIpLabel
@onready var ping_label: Label = %PingLabel
@onready var kd_label: Label = %KdLabel
@onready var scoreboard_label: Label = %ScoreboardLabel
@onready var ui_panel: PanelContainer = get_node_or_null("UiPanel") as PanelContainer
@onready var world_root: Node2D = get_node_or_null("World") as Node2D
@onready var map_front_sprite: Sprite2D = get_node_or_null("World/MapFront") as Sprite2D
@onready var main_camera: Camera2D = %MainCamera
@onready var players_root: Node2D = %Players
@onready var projectiles_root: Node2D = %Projectiles
@onready var map_controller: MapController = get_node_or_null("World/MapController") as MapController

@onready var border_top: StaticBody2D = get_node_or_null("World/BorderTop") as StaticBody2D
@onready var border_bottom: StaticBody2D = get_node_or_null("World/BorderBottom") as StaticBody2D
@onready var border_left: StaticBody2D = get_node_or_null("World/BorderLeft") as StaticBody2D
@onready var border_right: StaticBody2D = get_node_or_null("World/BorderRight") as StaticBody2D
@onready var border_top_shape: CollisionShape2D = get_node_or_null("World/BorderTop/CollisionShape2D") as CollisionShape2D
@onready var border_bottom_shape: CollisionShape2D = get_node_or_null("World/BorderBottom/CollisionShape2D") as CollisionShape2D
@onready var border_left_shape: CollisionShape2D = get_node_or_null("World/BorderLeft/CollisionShape2D") as CollisionShape2D
@onready var border_right_shape: CollisionShape2D = get_node_or_null("World/BorderRight/CollisionShape2D") as CollisionShape2D

@onready var lobby_name_input: LineEdit = get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyNameRow/LobbyNameInput") as LineEdit
@onready var lobby_list: ItemList = get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyList") as ItemList
@onready var lobby_status_label: Label = get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyStatusLabel") as Label
@onready var lobby_create_button: Button = get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyNameRow/LobbyCreateButton") as Button
@onready var lobby_join_button: Button = get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyActionsRow/LobbyJoinButton") as Button
@onready var lobby_refresh_button: Button = get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyActionsRow/LobbyRefreshButton") as Button
@onready var lobby_leave_button: Button = get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LobbyActionsRow/LobbyLeaveButton") as Button
@onready var lobby_weapon_option: OptionButton = get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LoadoutRow/LobbyWeaponOption") as OptionButton
@onready var lobby_character_option: OptionButton = get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/LoadoutRow/LobbyCharacterOption") as OptionButton
@onready var lobby_map_option: OptionButton = get_node_or_null("LobbyUi/LobbyPanel/Margin/VBox/MapRow/LobbyMapOption") as OptionButton
@onready var lobby_panel: PanelContainer = get_node_or_null("LobbyUi/LobbyPanel") as PanelContainer
@onready var lobby_room_bg: ColorRect = get_node_or_null("LobbyUi/LobbyRoomBg") as ColorRect
@onready var lobby_room_title: Label = get_node_or_null("LobbyUi/LobbyRoomTitle") as Label

var role: int = Role.NONE
var startup_mode: int = Role.CLIENT
var scoreboard_visible := false

var players: Dictionary = {}
var input_states: Dictionary = {}
var fire_cooldowns: Dictionary = {}
var player_history: Dictionary = {}
var input_rate_window_start_ms: Dictionary = {}
var input_rate_counts: Dictionary = {}
var spawn_slots: Dictionary = {}
var player_stats: Dictionary = {}
var player_display_names: Dictionary = {}
var ammo_by_peer: Dictionary = {}
var reload_remaining_by_peer: Dictionary = {}
var peer_weapon_ids: Dictionary = {}
var peer_character_ids: Dictionary = {}

var snapshot_accumulator := 0.0
var ping_accumulator := 0.0
var last_ping_ms := -1
var spawn_request_sent := false

var selected_weapon_id := WEAPON_ID_AK47
var selected_map_id := MAP_ID_CLASSIC
var selected_character_id := CHARACTER_ID_OUTRAGE
var client_target_map_id := MAP_ID_CLASSIC
var client_lobby_id := 0
var lobby_auto_action_inflight := false
var lobby_entries: Array = []
var lobby_map_by_id: Dictionary = {}
var pending_scene_switch := ""
var escape_return_pending := false
var escape_return_nonce := 0

var spawn_points: Array = []
var map_catalog: MapCatalog
var map_flow_service: MapFlowService
var spawn_flow_service: SpawnFlowService
var lobby_service: LobbyService
var lobby_flow_controller: LobbyFlowController
var session_controller: SessionController
var connect_retry: ConnectRetry
var ui_controller: UiController
var spawn_identity: SpawnIdentity
var player_replication: PlayerReplication
var projectile_system: ProjectileSystem
var hit_damage_resolver: HitDamageResolver
var combat_flow_service: CombatFlowService
var client_rpc_flow_service: ClientRpcFlowService
var client_input_controller: ClientInputController
var combat_effects: CombatEffects
var camera_shake: CameraShake

var weapon_profiles: Dictionary = {}
var weapon_shot_sfx_by_id: Dictionary = {}
var weapon_reload_sfx_by_id: Dictionary = {}

func _rpc_request_spawn() -> void:
	pass

func _rpc_spawn_player(_peer_id: int, _spawn_position: Vector2, _display_name: String = "", _weapon_id: String = "", _character_id: String = "") -> void:
	pass

func _rpc_despawn_player(_peer_id: int) -> void:
	pass

func _rpc_sync_player_state(_peer_id: int, _new_position: Vector2, _new_velocity: Vector2, _aim_angle: float, _health: int) -> void:
	pass

func _rpc_sync_player_stats(_peer_id: int, _kills: int, _deaths: int) -> void:
	pass

func _rpc_submit_input(_axis: float, _jump_pressed: bool, _jump_held: bool, _aim_world: Vector2, _shoot_held: bool, _boost_damage: bool, _reported_rtt_ms: int) -> void:
	pass

func _rpc_ping_request(_client_sent_msec: int) -> void:
	pass

func _rpc_ping_response(_client_sent_msec: int) -> void:
	pass

func _rpc_spawn_projectile(_projectile_id: int, _owner_peer_id: int, _spawn_position: Vector2, _velocity: Vector2, _lag_comp_ms: int, _trail_origin: Vector2, _weapon_id: String) -> void:
	pass

func _rpc_despawn_projectile(_projectile_id: int) -> void:
	pass

func _rpc_projectile_impact(_projectile_id: int, _impact_position: Vector2) -> void:
	pass

func _rpc_spawn_blood_particles(_impact_position: Vector2, _incoming_velocity: Vector2) -> void:
	pass

func _rpc_spawn_surface_particles(_impact_position: Vector2, _incoming_velocity: Vector2, _particle_color: Color) -> void:
	pass

func _rpc_play_reload_sfx(_peer_id: int, _weapon_id: String) -> void:
	pass

func _rpc_sync_player_ammo(_peer_id: int, _ammo: int, _is_reloading: bool) -> void:
	pass

func _rpc_sync_player_weapon(_peer_id: int, _weapon_id: String) -> void:
	pass

func _rpc_sync_player_character(_peer_id: int, _character_id: String) -> void:
	pass

func _rpc_play_death_sfx(_impact_position: Vector2) -> void:
	pass

func _rpc_request_lobby_list() -> void:
	pass

func _rpc_lobby_create(_requested_name: String, _payload: String) -> void:
	pass

func _rpc_lobby_join(_lobby_id: int, _weapon_id: String, _character_id: String = "") -> void:
	pass

func _rpc_lobby_leave(_legacy_a: Variant = null, _legacy_b: Variant = null) -> void:
	pass

func _rpc_lobby_set_weapon(_weapon_id: String) -> void:
	pass

func _rpc_lobby_set_character(_character_id: String) -> void:
	pass

func _rpc_lobby_list(_entries: Array, _active_lobby_id: int) -> void:
	pass

func _rpc_lobby_action_result(_success: bool, _message: String, _active_lobby_id: int, _map_id: String, _lobby_scene_mode: bool) -> void:
	pass

func _rpc_scene_switch_to_map(_map_id: String) -> void:
	pass

func _rpc_cast_skill1(_target_world: Vector2) -> void:
	pass

func _rpc_cast_skill2(_target_world: Vector2) -> void:
	pass

func _rpc_spawn_outrage_bomb(_caster_peer_id: int, _world_position: Vector2, _fuse_sec: float) -> void:
	pass

func _rpc_spawn_erebus_immunity(_caster_peer_id: int, _duration_sec: float) -> void:
	pass
