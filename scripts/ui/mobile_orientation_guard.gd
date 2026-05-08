extends RefCounted
class_name MobileOrientationGuard

const POLL_INTERVAL_SEC := 0.5

var _host: Control
var _overlay: Control
var _info_label: Label
var _button: Button
var _poll_timer: Timer
var _is_mobile := false
var _last_orientation := ""
var _last_overlay_visible := false

func configure(host: Control) -> void:
	_host = host
	if _host == null:
		return
	if not OS.has_feature("web"):
		_log_mobile(false, "desktop")
		return
	_is_mobile = _detect_mobile_or_tablet()
	_log_mobile(_is_mobile, _read_orientation())
	if not _is_mobile:
		return
	_create_overlay()
	_connect_orientation_signals()
	_refresh_overlay_state()

func _detect_mobile_or_tablet() -> bool:
	var ua: String = str(JavaScriptBridge.eval("navigator.userAgent || ''")).to_lower()
	var touch_points: int = int(JavaScriptBridge.eval("navigator.maxTouchPoints || 0"))
	var width: int = int(JavaScriptBridge.eval("window.innerWidth || 0"))
	var height: int = int(JavaScriptBridge.eval("window.innerHeight || 0"))
	var smallest_edge: int = mini(width, height)
	var mobile_ua: bool = ua.find("android") >= 0 or ua.find("iphone") >= 0 or ua.find("ipad") >= 0 or ua.find("mobile") >= 0 or ua.find("tablet") >= 0
	var touch_device: bool = touch_points >= 2
	var likely_handheld: bool = smallest_edge > 0 and smallest_edge <= 1024
	return mobile_ua or (touch_device and likely_handheld)

func _create_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "MobileOrientationOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 4000
	_host.add_child(_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.08, 0.82)
	_overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 220)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-240, -110)
	_overlay.add_child(panel)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.15, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.95, 0.5, 0.75, 1.0)
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var title := Label.new()
	title.text = "Rotate your device to landscape to play"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	_info_label = Label.new()
	_info_label.text = "Portrait mode is blocked."
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 14)
	box.add_child(_info_label)

	_button = Button.new()
	_button.text = "Enter fullscreen landscape"
	_button.custom_minimum_size = Vector2(0, 52)
	_button.pressed.connect(_on_fullscreen_landscape_pressed)
	box.add_child(_button)

func _connect_orientation_signals() -> void:
	var viewport := _host.get_viewport()
	if viewport != null:
		viewport.size_changed.connect(_refresh_overlay_state)
	_poll_timer = Timer.new()
	_poll_timer.name = "MobileOrientationPollTimer"
	_poll_timer.wait_time = POLL_INTERVAL_SEC
	_poll_timer.one_shot = false
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_refresh_overlay_state)
	_host.add_child(_poll_timer)

func _read_orientation() -> String:
	var width := int(JavaScriptBridge.eval("window.innerWidth || 0"))
	var height := int(JavaScriptBridge.eval("window.innerHeight || 0"))
	if width <= 0 or height <= 0:
		return "unknown"
	return "landscape" if width > height else "portrait"

func _refresh_overlay_state() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var orientation := _read_orientation()
	if orientation != _last_orientation:
		_last_orientation = orientation
		print("[MOBILE] orientation = %s" % orientation)
	var show_overlay := orientation != "landscape"
	if show_overlay != _last_overlay_visible:
		_last_overlay_visible = show_overlay
		print("[MOBILE] overlay visible = %s" % str(show_overlay))
	_overlay.visible = show_overlay
	if _info_label != null:
		if show_overlay:
			_info_label.text = "Portrait mode is blocked."
		else:
			_info_label.text = "Landscape detected."

func _on_fullscreen_landscape_pressed() -> void:
	var fullscreen_result := str(JavaScriptBridge.eval("(function(){try{var root=document.documentElement;if(document.fullscreenElement){return 'already-fullscreen';}if(root.requestFullscreen){root.requestFullscreen();return 'requested';}return 'unsupported';}catch(e){return 'error:' + String(e);}})();"))
	print("[MOBILE] request fullscreen result = %s" % fullscreen_result)
	var lock_result := str(JavaScriptBridge.eval("(function(){try{if(screen.orientation && screen.orientation.lock){screen.orientation.lock('landscape').then(function(){window.KW_ORIENTATION_LOCK_RESULT='locked';}).catch(function(e){window.KW_ORIENTATION_LOCK_RESULT='error:' + String(e);});return 'requested';}window.KW_ORIENTATION_LOCK_RESULT='unsupported';return 'unsupported';}catch(e){window.KW_ORIENTATION_LOCK_RESULT='error:' + String(e);return 'error:' + String(e);}})();"))
	print("[MOBILE] orientation lock result = %s" % lock_result)
	_host.call_deferred("_kw_log_mobile_orientation_lock_result")
	_refresh_overlay_state()

func _log_mobile(is_mobile: bool, orientation: String) -> void:
	print("[MOBILE] is_mobile = %s" % str(is_mobile))
	print("[MOBILE] orientation = %s" % orientation)
