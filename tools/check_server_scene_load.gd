extends SceneTree

const REQUIRED_RESOURCES := [
	"res://scripts/app/runtime_shared.gd",
	"res://scripts/app/runtime_setup_logic.gd",
	"res://scripts/app/runtime_session_logic.gd",
	"res://scripts/app/runtime_rpc_logic.gd",
	"res://scripts/app/runtime_controller.gd",
	"res://scripts/ui/main_menu/lobby_rpc_bridge.gd",
	"res://scenes/server_boot.tscn",
	"res://scenes/ui/main_menu.tscn",
	"res://scenes/skull_ffa.tscn",
]

func _initialize() -> void:
	for resource_path in REQUIRED_RESOURCES:
		var resource := load(resource_path)
		if resource == null:
			push_error("Failed to load required server resource: %s" % resource_path)
			quit(1)
			return
	print("Server scene load validation OK.")
	quit(0)
