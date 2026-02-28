extends RefCounted

const SHOP_STATE_PATH := "user://test_menu_shop_state.json"

const HEADS_TEXTURE: Texture2D = preload("res://assets/warriors/allHeads.png")
const TORSO_TEXTURE: Texture2D = preload("res://assets/warriors/allTorso.png")
const LEGS_TEXTURE: Texture2D = preload("res://assets/warriors/allLegs.png")

const UZI_UI_TEXTURE: Texture2D = preload("res://assets/UI/uziUI.png")
const GRENADE_UI_TEXTURE: Texture2D = preload("res://assets/UI/grenadeUI.png")

const BULLET_TEXTURE: Texture2D = preload("res://assets/textures/bullet.png")

const WEAPON_UZI := "uzi"
const WEAPON_GRENADE := "grenade"

const WEAPON_IDS := [WEAPON_UZI, WEAPON_GRENADE]

const WEAPON_UI_TEXTURE_BY_ID := {
	WEAPON_UZI: UZI_UI_TEXTURE,
	WEAPON_GRENADE: GRENADE_UI_TEXTURE,
}

# Crop regions inside the 64x64 monochrome UI textures (keeps animations/scaling consistent).
const WEAPON_UI_REGION_BY_ID := {
	WEAPON_UZI: Rect2(21, 24, 25, 21),
	WEAPON_GRENADE: Rect2(12, 26, 39, 14),
}

const WEAPON_UI_OFFSET_BY_ID := {
	# Offsets align the "visual center" of each weapon, so transitions scale/move consistently.
	# Values are derived from an alpha-weighted centroid of the cropped region.
	WEAPON_UZI: Vector2(2.30, 3.84),
	WEAPON_GRENADE: Vector2(0.68, 2.35),
}

const WEAPON_BASE_COST_BY_ID := {
	WEAPON_UZI: 1800,
	WEAPON_GRENADE: 1600,
}

const WEAPON_SKINS_BY_ID := {
	WEAPON_UZI: [
		{"skin": 0, "name": "Classic", "tint": Color(0.92, 0.95, 0.98, 1), "cost": 0},
		{"skin": 1, "name": "Lime", "tint": Color(0.68, 1.0, 0.35, 1), "cost": 120},
		{"skin": 2, "name": "Orange", "tint": Color(1.0, 0.62, 0.22, 1), "cost": 140},
		{"skin": 3, "name": "Magenta", "tint": Color(1.0, 0.35, 0.85, 1), "cost": 160},
		{"skin": 4, "name": "Azure", "tint": Color(0.25, 0.72, 1.0, 1), "cost": 180},
		{"skin": 5, "name": "Red", "tint": Color(1.0, 0.28, 0.28, 1), "cost": 200},
		{"skin": 6, "name": "Aqua", "tint": Color(0.22, 1.0, 0.92, 1), "cost": 220},
		{"skin": 7, "name": "Yellow", "tint": Color(1.0, 0.98, 0.45, 1), "cost": 240},
		{"skin": 8, "name": "Pink", "tint": Color(1.0, 0.55, 0.72, 1), "cost": 260},
		{"skin": 9, "name": "Purple", "tint": Color(0.62, 0.38, 0.92, 1), "cost": 280},
		{"skin": 10, "name": "Steel", "tint": Color(0.72, 0.78, 0.9, 1), "cost": 300},
		{"skin": 11, "name": "Coal", "tint": Color(0.25, 0.27, 0.32, 1), "cost": 320},
		{"skin": 12, "name": "Sky", "tint": Color(0.48, 0.86, 1.0, 1), "cost": 340},
		{"skin": 13, "name": "Toxic", "tint": Color(0.65, 1.0, 0.2, 1), "cost": 360},
		{"skin": 14, "name": "Sand", "tint": Color(0.92, 0.84, 0.62, 1), "cost": 380},
		{"skin": 15, "name": "Lilac", "tint": Color(0.9, 0.74, 1.0, 1), "cost": 400},
		{"skin": 16, "name": "Teal", "tint": Color(0.18, 0.85, 0.78, 1), "cost": 420},
		{"skin": 17, "name": "Cherry", "tint": Color(0.98, 0.25, 0.4, 1), "cost": 440},
		{"skin": 18, "name": "Gold", "tint": Color(1.0, 0.9, 0.25, 1), "cost": 900},
		{"skin": 19, "name": "Neon", "tint": Color(0.25, 1.0, 0.85, 1), "cost": 1100},
		{"skin": 20, "name": "Rainbow", "tint": Color(1, 1, 1, 1), "cost": 0, "rainbow": true},
	],
	WEAPON_GRENADE: [
		{"skin": 0, "name": "Classic", "tint": Color(0.92, 0.95, 0.98, 1), "cost": 0},
		{"skin": 1, "name": "Lime", "tint": Color(0.68, 1.0, 0.35, 1), "cost": 120},
		{"skin": 2, "name": "Orange", "tint": Color(1.0, 0.62, 0.22, 1), "cost": 140},
		{"skin": 3, "name": "Magenta", "tint": Color(1.0, 0.35, 0.85, 1), "cost": 160},
		{"skin": 4, "name": "Azure", "tint": Color(0.25, 0.72, 1.0, 1), "cost": 180},
		{"skin": 5, "name": "Red", "tint": Color(1.0, 0.28, 0.28, 1), "cost": 200},
		{"skin": 6, "name": "Aqua", "tint": Color(0.22, 1.0, 0.92, 1), "cost": 220},
		{"skin": 7, "name": "Yellow", "tint": Color(1.0, 0.98, 0.45, 1), "cost": 240},
		{"skin": 8, "name": "Pink", "tint": Color(1.0, 0.55, 0.72, 1), "cost": 260},
		{"skin": 9, "name": "Purple", "tint": Color(0.62, 0.38, 0.92, 1), "cost": 280},
		{"skin": 10, "name": "Steel", "tint": Color(0.72, 0.78, 0.9, 1), "cost": 300},
		{"skin": 11, "name": "Coal", "tint": Color(0.25, 0.27, 0.32, 1), "cost": 320},
		{"skin": 12, "name": "Sky", "tint": Color(0.48, 0.86, 1.0, 1), "cost": 340},
		{"skin": 13, "name": "Toxic", "tint": Color(0.65, 1.0, 0.2, 1), "cost": 360},
		{"skin": 14, "name": "Sand", "tint": Color(0.92, 0.84, 0.62, 1), "cost": 380},
		{"skin": 15, "name": "Lilac", "tint": Color(0.9, 0.74, 1.0, 1), "cost": 400},
		{"skin": 16, "name": "Teal", "tint": Color(0.18, 0.85, 0.78, 1), "cost": 420},
		{"skin": 17, "name": "Cherry", "tint": Color(0.98, 0.25, 0.4, 1), "cost": 440},
		{"skin": 18, "name": "Gold", "tint": Color(1.0, 0.9, 0.25, 1), "cost": 900},
		{"skin": 19, "name": "Neon", "tint": Color(0.25, 1.0, 0.85, 1), "cost": 1100},
		{"skin": 20, "name": "Rainbow", "tint": Color(1, 1, 1, 1), "cost": 0, "rainbow": true},
	],
}
