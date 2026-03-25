extends RefCounted

const HOVER_SFX := preload("res://assets/sounds/sfx/menu_placeholders/menu_hover.wav")
const CLICK_SFX := preload("res://assets/sounds/sfx/menu_placeholders/menu_click.wav")
const CHANGE_SFX := preload("res://assets/sounds/sfx/menu_placeholders/menu_change.wav")

const META_BOUND_BUTTON := "kw_menu_sfx_button_bound"
const META_BOUND_SLIDER := "kw_menu_sfx_slider_bound"
const META_BOUND_OPTION := "kw_menu_sfx_option_bound"
const BASE_HOVER_DB := -12.0
const BASE_CLICK_DB := -10.0
const BASE_CHANGE_DB := -11.0

var _host: Node
var _hover_player: AudioStreamPlayer
var _click_player: AudioStreamPlayer
var _change_player: AudioStreamPlayer
var _last_slider_tick_msec := 0
var _volume_linear := 1.0

func configure(host: Node) -> void:
	_host = host
	_hover_player = _ensure_player("MenuSfxHover", HOVER_SFX, BASE_HOVER_DB)
	_click_player = _ensure_player("MenuSfxClick", CLICK_SFX, BASE_CLICK_DB)
	_change_player = _ensure_player("MenuSfxChange", CHANGE_SFX, BASE_CHANGE_DB)
	set_output_volume_linear(_volume_linear)

func bind_button(btn: BaseButton) -> void:
	if btn == null:
		return
	if bool(btn.get_meta(META_BOUND_BUTTON, false)):
		return
	btn.set_meta(META_BOUND_BUTTON, true)
	var hover_cb := Callable(self, "_on_control_hovered")
	if not btn.mouse_entered.is_connected(hover_cb):
		btn.mouse_entered.connect(hover_cb)
	var click_cb := Callable(self, "_on_button_pressed")
	if not btn.pressed.is_connected(click_cb):
		btn.pressed.connect(click_cb)
	if btn is CheckBox or btn is CheckButton:
		var toggle_cb := Callable(self, "_on_button_toggled")
		if not btn.toggled.is_connected(toggle_cb):
			btn.toggled.connect(toggle_cb)

func bind_slider(slider: HSlider) -> void:
	if slider == null:
		return
	if bool(slider.get_meta(META_BOUND_SLIDER, false)):
		return
	slider.set_meta(META_BOUND_SLIDER, true)
	var hover_cb := Callable(self, "_on_control_hovered")
	if not slider.mouse_entered.is_connected(hover_cb):
		slider.mouse_entered.connect(hover_cb)
	if slider.has_signal("drag_started"):
		var drag_start_cb := Callable(self, "_on_slider_drag_started")
		if not slider.drag_started.is_connected(drag_start_cb):
			slider.drag_started.connect(drag_start_cb)
	if slider.has_signal("drag_ended"):
		var drag_end_cb := Callable(self, "_on_slider_drag_ended")
		if not slider.drag_ended.is_connected(drag_end_cb):
			slider.drag_ended.connect(drag_end_cb)
	var value_cb := Callable(self, "_on_slider_value_changed")
	if not slider.value_changed.is_connected(value_cb):
		slider.value_changed.connect(value_cb)

func bind_option(option: OptionButton) -> void:
	if option == null:
		return
	if bool(option.get_meta(META_BOUND_OPTION, false)):
		return
	option.set_meta(META_BOUND_OPTION, true)
	bind_button(option)
	var select_cb := Callable(self, "_on_option_item_selected")
	if not option.item_selected.is_connected(select_cb):
		option.item_selected.connect(select_cb)

func play_hover() -> void:
	_play(_hover_player)

func play_click() -> void:
	_play(_click_player)

func play_change() -> void:
	_play(_change_player)

func _ensure_player(name: String, stream: AudioStream, volume_db: float) -> AudioStreamPlayer:
	if _host == null:
		return null
	var existing := _host.get_node_or_null(name) as AudioStreamPlayer
	if existing != null:
		if stream != null:
			existing.stream = stream
		existing.volume_db = _scaled_db(volume_db)
		existing.set_meta("kw_base_db", volume_db)
		existing.max_polyphony = 8
		existing.bus = "SFX"
		return existing
	var p := AudioStreamPlayer.new()
	p.name = name
	p.stream = stream
	p.volume_db = _scaled_db(volume_db)
	p.set_meta("kw_base_db", volume_db)
	p.max_polyphony = 8
	p.bus = "SFX"
	_host.add_child(p)
	return p

func set_output_volume_linear(value: float) -> void:
	_volume_linear = clampf(value, 0.0, 1.0)
	_apply_scaled_volume(_hover_player)
	_apply_scaled_volume(_click_player)
	_apply_scaled_volume(_change_player)

func _apply_scaled_volume(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player):
		return
	var base_db := float(player.get_meta("kw_base_db", 0.0))
	player.volume_db = _scaled_db(base_db)

func _scaled_db(base_db: float) -> float:
	if _volume_linear <= 0.001:
		return -80.0
	return clampf(base_db + linear_to_db(_volume_linear), -80.0, 12.0)

func _play(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.play()

func _on_control_hovered() -> void:
	play_hover()

func _on_button_pressed() -> void:
	play_click()

func _on_button_toggled(_toggled_on: bool) -> void:
	play_change()

func _on_slider_drag_started() -> void:
	play_click()

func _on_slider_drag_ended(_value_changed: bool) -> void:
	play_change()

func _on_slider_value_changed(_value: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_slider_tick_msec < 55:
		return
	_last_slider_tick_msec = now
	play_hover()

func _on_option_item_selected(_index: int) -> void:
	play_change()
