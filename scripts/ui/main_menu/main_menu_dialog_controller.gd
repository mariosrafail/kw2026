extends RefCounted

class_name MainMenuDialogController

var _host: Control
var _confirm_overlay_script
var _cursor_manager_name := ""
var _enable_menu_loading_overlay := false

func configure(host: Control, confirm_overlay_script, cursor_manager_name: String, enable_menu_loading_overlay: bool) -> void:
	_host = host
	_confirm_overlay_script = confirm_overlay_script
	_cursor_manager_name = cursor_manager_name
	_enable_menu_loading_overlay = enable_menu_loading_overlay

func init_confirm_dialog() -> void:
	if _confirm_overlay_script == null or _host == null:
		return
	var overlay: Variant = _confirm_overlay_script.new()
	overlay.name = "ConfirmOverlay"
	overlay.configure(
		Callable(_host, "_make_shop_button"),
		Callable(_host, "_set_weapon_icon_sprite"),
		Callable(_host, "_apply_weapon_skin_visual"),
		Callable(_host, "_center_pivot"),
		Callable(_host, "_add_hover_pop")
	)
	_host.add_child(overlay)
	_host.set("_confirm_overlay_ui", overlay)

func ask_confirm(title: String, text: String, on_confirm: Callable, weapon_id: String = "", skin_index: int = 0) -> void:
	var confirm_overlay_ui: Variant = _host.get("_confirm_overlay_ui")
	if confirm_overlay_ui == null:
		return
	confirm_overlay_ui.call("ask", title, text, on_confirm, weapon_id, skin_index)

func show_menu_loading_overlay(message: String = "LOADING...") -> void:
	if not _enable_menu_loading_overlay:
		return
	set_menu_cursor_hover_blocked(true)
	var menu_loading_overlay: Variant = _host.get("_menu_loading_overlay")
	if menu_loading_overlay != null and menu_loading_overlay.has_method("show"):
		menu_loading_overlay.call("show", message)

func hide_menu_loading_overlay() -> void:
	if not _enable_menu_loading_overlay:
		return
	var menu_loading_overlay: Variant = _host.get("_menu_loading_overlay")
	if menu_loading_overlay != null and menu_loading_overlay.has_method("hide"):
		menu_loading_overlay.call("hide")

func on_menu_loading_overlay_shown() -> void:
	set_menu_cursor_hover_blocked(true)

func on_menu_loading_overlay_hidden() -> void:
	set_menu_cursor_hover_blocked(false)

func set_menu_cursor_hover_blocked(blocked: bool) -> void:
	var tree := _host.get_tree()
	if tree == null:
		return
	var root := tree.get_root()
	if root == null:
		return
	var cm := root.get_node_or_null(_cursor_manager_name)
	if cm != null and cm.has_method("set_menu_hover_blocked"):
		cm.call("set_menu_hover_blocked", blocked)
