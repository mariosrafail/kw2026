extends CanvasLayer

const POLL_INTERVAL_SEC := 0.25

var _overlay: Control
var _info_label: Label
var _button: Button
var _poll_timer: Timer
var _is_mobile := false
var _last_orientation := ""
var _last_blocked := false
var _last_event_tick := -1

func _ready() -> void:
	layer = 200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_mobile = _detect_mobile_or_tablet()
	_create_overlay()
	_connect_signals()
	_install_browser_event_hooks()
	print("[MOBILE] orientation guard initialized globally")
	print("[MOBILE] is_mobile = %s" % str(_is_mobile))
	_refresh_overlay_state()

func _create_overlay() -> void:
	_overlay = Control.new()
	_overlay.name = "MobileOrientationOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.z_index = 4000
	_overlay.visible = false
	add_child(_overlay)

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

func _connect_signals() -> void:
	var viewport := get_viewport()
	if viewport != null:
		var cb := Callable(self, "_refresh_overlay_state")
		if not viewport.size_changed.is_connected(cb):
			viewport.size_changed.connect(cb)
	_poll_timer = Timer.new()
	_poll_timer.name = "GlobalMobileOrientationPollTimer"
	_poll_timer.wait_time = POLL_INTERVAL_SEC
	_poll_timer.one_shot = false
	_poll_timer.autostart = true
	_poll_timer.timeout.connect(_on_poll_tick)
	add_child(_poll_timer)

func _install_browser_event_hooks() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("(function(){try{window.KW_ORIENTATION_EVENT_TICK = window.KW_ORIENTATION_EVENT_TICK || 0; if(window.KW_ORIENTATION_HOOKS_INSTALLED){return;} var bump=function(){window.KW_ORIENTATION_EVENT_TICK=(window.KW_ORIENTATION_EVENT_TICK||0)+1;}; window.addEventListener('resize', bump, {passive:true}); window.addEventListener('orientationchange', bump, {passive:true}); document.addEventListener('fullscreenchange', bump, {passive:true}); window.KW_ORIENTATION_HOOKS_INSTALLED=true;}catch(e){}})();")

func _on_poll_tick() -> void:
	if OS.has_feature("web"):
		var tick := int(JavaScriptBridge.eval("window.KW_ORIENTATION_EVENT_TICK || 0"))
		if tick != _last_event_tick:
			_last_event_tick = tick
	_refresh_overlay_state()

func _detect_mobile_or_tablet() -> bool:
	if not OS.has_feature("web"):
		return false
	var ua: String = str(JavaScriptBridge.eval("navigator.userAgent || ''")).to_lower()
	var touch_points: int = int(JavaScriptBridge.eval("navigator.maxTouchPoints || 0"))
	var width := int(JavaScriptBridge.eval("window.innerWidth || 0"))
	var height := int(JavaScriptBridge.eval("window.innerHeight || 0"))
	var smallest_edge := mini(width, height)
	var mobile_ua := ua.find("android") >= 0 or ua.find("iphone") >= 0 or ua.find("ipad") >= 0 or ua.find("mobile") >= 0 or ua.find("tablet") >= 0
	var touch_device := touch_points >= 2
	var likely_handheld := smallest_edge > 0 and smallest_edge <= 1366
	return mobile_ua or (touch_device and likely_handheld)

func _read_orientation() -> String:
	var viewport := get_viewport()
	if viewport == null:
		return "desktop"
	var size := viewport.get_visible_rect().size
	var width := int(size.x)
	var height := int(size.y)
	if width <= 0 or height <= 0:
		return "desktop"
	if not _is_mobile:
		return "desktop"
	if height > width:
		return "portrait"
	return "landscape"

func _refresh_overlay_state() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var orientation := _read_orientation()
	if orientation != _last_orientation:
		_last_orientation = orientation
		print("[MOBILE] orientation = %s" % orientation)
	var blocked := _is_mobile and orientation == "portrait"
	if blocked != _last_blocked:
		_last_blocked = blocked
		print("[MOBILE] portrait blocked = %s" % str(blocked))
		print("[MOBILE] orientation overlay %s" % ("shown" if blocked else "hidden"))
	_overlay.visible = blocked
	if _info_label != null:
		_info_label.text = "Portrait mode is blocked." if blocked else "Landscape detected."

func _unhandled_input(_event: InputEvent) -> void:
	if _overlay != null and _overlay.visible:
		get_viewport().set_input_as_handled()

func _on_fullscreen_landscape_pressed() -> void:
	if not OS.has_feature("web"):
		return
	var fullscreen_result := str(JavaScriptBridge.eval("(function(){try{var root=document.documentElement;if(document.fullscreenElement){return 'already-fullscreen';}if(root.requestFullscreen){root.requestFullscreen();return 'requested';}return 'unsupported';}catch(e){return 'error:' + String(e);}})();"))
	print("[MOBILE] request fullscreen result = %s" % fullscreen_result)
	var lock_result := str(JavaScriptBridge.eval("(function(){try{if(screen.orientation && screen.orientation.lock){screen.orientation.lock('landscape').then(function(){window.KW_ORIENTATION_LOCK_RESULT='locked';window.KW_ORIENTATION_EVENT_TICK=(window.KW_ORIENTATION_EVENT_TICK||0)+1;}).catch(function(e){window.KW_ORIENTATION_LOCK_RESULT='error:' + String(e);});return 'requested';}window.KW_ORIENTATION_LOCK_RESULT='unsupported';return 'unsupported';}catch(e){window.KW_ORIENTATION_LOCK_RESULT='error:' + String(e);return 'error:' + String(e);}})();"))
	print("[MOBILE] orientation lock result = %s" % lock_result)
	_refresh_overlay_state()
