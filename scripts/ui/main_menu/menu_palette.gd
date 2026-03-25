extends RefCounted
class_name MenuPalette

# Core palette (edit these hex values to recolor menu/lobby/intro globally).
const HEX_BASE := "#FAF7F1"
const HEX_ACCENT := "#47429D"
const HEX_HOT := "#20ACF3"
const HEX_HIGHLIGHT := "#E27393"

# Supporting palette for better balance/readability.
const HEX_TEXT_PRIMARY := "#FAF7F1"
const HEX_TEXT_DARK := "#0F0D14"

static func color_from_hex(hex: String, alpha: float = 1.0) -> Color:
	var clean := hex.strip_edges()
	if clean.begins_with("#"):
		clean = clean.substr(1)
	if clean.length() != 6 and clean.length() != 8:
		return Color(1, 1, 1, clampf(alpha, 0.0, 1.0))
	var r := float(clean.substr(0, 2).hex_to_int()) / 255.0
	var g := float(clean.substr(2, 2).hex_to_int()) / 255.0
	var b := float(clean.substr(4, 2).hex_to_int()) / 255.0
	var a := clampf(alpha, 0.0, 1.0)
	if clean.length() == 8:
		a = clampf((float(clean.substr(6, 2).hex_to_int()) / 255.0) * a, 0.0, 1.0)
	return Color(r, g, b, a)

static func with_alpha(c: Color, alpha: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(alpha, 0.0, 1.0))

static func base(alpha: float = 1.0) -> Color:
	return color_from_hex(HEX_BASE, alpha)

static func accent(alpha: float = 1.0) -> Color:
	return color_from_hex(HEX_ACCENT, alpha)

static func hot(alpha: float = 1.0) -> Color:
	return color_from_hex(HEX_HOT, alpha)

static func highlight(alpha: float = 1.0) -> Color:
	return color_from_hex(HEX_HIGHLIGHT, alpha)

static func text_primary(alpha: float = 1.0) -> Color:
	return color_from_hex(HEX_TEXT_PRIMARY, alpha)

static func text_dark(alpha: float = 1.0) -> Color:
	return color_from_hex(HEX_TEXT_DARK, alpha)
