extends RefCounted

class_name MainMenuOptionsController

var _host: Control
var _menu_sfx: RefCounted
var _intro_fx: RefCounted

func configure(host: Control, menu_sfx: RefCounted, intro_fx: RefCounted) -> void:
	_host = host
	_menu_sfx = menu_sfx
	_intro_fx = intro_fx

func bind_menu_sfx_button(btn: BaseButton) -> void:
	if _menu_sfx == null:
		return
	_menu_sfx.bind_button(btn)

func bind_menu_sfx_slider(slider: HSlider) -> void:
	if _menu_sfx == null:
		return
	_menu_sfx.bind_slider(slider)

func bind_menu_sfx_option(option: OptionButton) -> void:
	if _menu_sfx == null:
		return
	_menu_sfx.bind_option(option)

func on_music_slider_changed(value: float) -> void:
	if _intro_fx == null:
		return
	if _intro_fx.has_method("set_menu_music_volume_linear"):
		_intro_fx.call("set_menu_music_volume_linear", clampf(value, 0.0, 1.0))
	_host.call("_save_state")

func on_sfx_slider_changed(value: float) -> void:
	var clamped: float = clampf(value, 0.0, 1.0)
	set_sound_buses_volume_linear(clamped)
	if _menu_sfx != null and _menu_sfx.has_method("set_output_volume_linear"):
		_menu_sfx.call("set_output_volume_linear", clamped)
	if _intro_fx != null and _intro_fx.has_method("set_menu_sfx_volume_linear"):
		_intro_fx.call("set_menu_sfx_volume_linear", clamped)
	_host.call("_save_state")

func on_particles_toggle_pressed() -> void:
	var particles_toggle_button := _host.get("particles_toggle_button") as Button
	if particles_toggle_button == null:
		return
	set_particles_enabled(particles_toggle_button.button_pressed, true)

func set_particles_enabled(enabled: bool, save: bool) -> void:
	_host.set("particles_enabled", enabled)
	ProjectSettings.set_setting("kw/particles_enabled", bool(_host.get("particles_enabled")))
	var particles_toggle_button := _host.get("particles_toggle_button") as Button
	if particles_toggle_button != null:
		particles_toggle_button.set_pressed_no_signal(bool(_host.get("particles_enabled")))
		particles_toggle_button.text = "ON" if bool(_host.get("particles_enabled")) else "OFF"
		particles_toggle_button.modulate = Color(1.0, 1.0, 1.0, 1.0) if bool(_host.get("particles_enabled")) else Color(0.78, 0.78, 0.82, 1.0)
	if save:
		_host.call("_save_state")

func on_screen_shake_toggle_pressed() -> void:
	var screen_shake_toggle_button := _host.get("screen_shake_toggle_button") as Button
	if screen_shake_toggle_button == null:
		return
	set_screen_shake_enabled(screen_shake_toggle_button.button_pressed, true)

func set_screen_shake_enabled(enabled: bool, save: bool) -> void:
	_host.set("screen_shake_enabled", enabled)
	ProjectSettings.set_setting("kw/screen_shake_enabled", bool(_host.get("screen_shake_enabled")))
	var screen_shake_toggle_button := _host.get("screen_shake_toggle_button") as Button
	if screen_shake_toggle_button != null:
		screen_shake_toggle_button.set_pressed_no_signal(bool(_host.get("screen_shake_enabled")))
		screen_shake_toggle_button.text = "ON" if bool(_host.get("screen_shake_enabled")) else "OFF"
		screen_shake_toggle_button.modulate = Color(1.0, 1.0, 1.0, 1.0) if bool(_host.get("screen_shake_enabled")) else Color(0.78, 0.78, 0.82, 1.0)
	if save:
		_host.call("_save_state")

func set_sound_buses_volume_linear(value: float) -> void:
	var db: float = -80.0 if value <= 0.001 else linear_to_db(value)
	var sfx_idx: int = ensure_audio_bus("SFX", "Master")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, db)
	var target_names := {
		"sounds": true,
		"gamesfx": true,
		"game_sfx": true,
		"gameplay_sfx": true,
	}
	for i in range(AudioServer.get_bus_count()):
		var bus_name := AudioServer.get_bus_name(i).to_lower()
		if target_names.has(bus_name):
			AudioServer.set_bus_volume_db(i, db)

func ensure_audio_bus(bus_name: String, send_to: String = "Master") -> int:
	var wanted := bus_name.strip_edges()
	if wanted.is_empty():
		return -1
	for i in range(AudioServer.get_bus_count()):
		if AudioServer.get_bus_name(i).to_lower() == wanted.to_lower():
			return i
	AudioServer.add_bus(AudioServer.get_bus_count())
	var idx := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(idx, wanted)
	if not send_to.strip_edges().is_empty():
		AudioServer.set_bus_send(idx, send_to)
	return idx
