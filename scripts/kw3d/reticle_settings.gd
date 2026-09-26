extends RefCounted
## Persistent local reticle preferences shared by the menu and all 3D clients.

const CONFIG_PATH := "user://kw3d_reticle.cfg"
const CUSTOM_COPY_PATH := "user://kw3d_custom_reticle.png"

const PRESET_BLOCKS := "blocks"
const PRESET_DOT := "dot"
const PRESET_CLASSIC := "classic"
const PRESET_CUSTOM := "custom"
const PRESETS := [PRESET_BLOCKS, PRESET_DOT, PRESET_CLASSIC, PRESET_CUSTOM]


static func defaults() -> Dictionary:
	return {
		"preset": PRESET_BLOCKS,
		"size_scale": 0.72,
		"custom_png": "",
	}


static func load_settings() -> Dictionary:
	var result := defaults()
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) == OK:
		result["preset"] = str(config.get_value("reticle", "preset", result.preset)).strip_edges().to_lower()
		result["size_scale"] = float(config.get_value("reticle", "size_scale", result.size_scale))
		result["custom_png"] = str(config.get_value("reticle", "custom_png", result.custom_png)).strip_edges()
	if str(result.preset) not in PRESETS:
		result["preset"] = PRESET_BLOCKS
	result["size_scale"] = clampf(float(result.size_scale), 0.45, 1.60)
	return result


static func save_settings(preset: String, size_scale: float, custom_png: String = "") -> Error:
	var normalized := preset.strip_edges().to_lower()
	if normalized not in PRESETS:
		normalized = PRESET_BLOCKS
	var config := ConfigFile.new()
	config.set_value("reticle", "preset", normalized)
	config.set_value("reticle", "size_scale", clampf(size_scale, 0.45, 1.60))
	config.set_value("reticle", "custom_png", custom_png.strip_edges())
	return config.save(CONFIG_PATH)


static func import_custom_png(source_path: String) -> Dictionary:
	var image := Image.new()
	var load_error := image.load(source_path)
	if load_error != OK or image.is_empty():
		return {"ok": false, "error": load_error, "path": ""}
	var save_error := image.save_png(CUSTOM_COPY_PATH)
	if save_error != OK:
		return {"ok": false, "error": save_error, "path": ""}
	return {"ok": true, "error": OK, "path": CUSTOM_COPY_PATH}


static func load_custom_texture(path: String) -> Texture2D:
	var wanted := path.strip_edges()
	if wanted.is_empty():
		return null
	var image := Image.new()
	if image.load(wanted) != OK or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
