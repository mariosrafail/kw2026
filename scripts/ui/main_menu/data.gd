extends RefCounted

const SHOP_STATE_PATH := "user://main_menu_shop_state.json"

const UZI_UI_TEXTURE: Texture2D = preload("res://assets/ui/uziUI.png")
const GRENADE_UI_TEXTURE: Texture2D = preload("res://assets/ui/grenadeUI.png")
const AK_UI_TEXTURE: Texture2D = preload("res://assets/ui/akUI.png")
const KAR_UI_TEXTURE: Texture2D = preload("res://assets/ui/karUI.png")
const SHOTGUN_UI_TEXTURE: Texture2D = preload("res://assets/ui/shotgunUI.png")

const AK_SKIN1_UI_TEXTURE: Texture2D = preload("res://assets/ui/akSkin1UI.png")

const BULLET_TEXTURE: Texture2D = preload("res://assets/textures/bullet.png")

const WEAPON_UZI := "uzi"
const WEAPON_GRENADE := "grenade"
const WEAPON_AK47 := "ak47"
const WEAPON_KAR := "kar"
const WEAPON_SHOTGUN := "shotgun"

const WEAPON_IDS := [WEAPON_UZI, WEAPON_GRENADE, WEAPON_AK47, WEAPON_KAR, WEAPON_SHOTGUN]

const WEAPON_UI_TEXTURE_BY_ID := {
	WEAPON_UZI: UZI_UI_TEXTURE,
	WEAPON_GRENADE: GRENADE_UI_TEXTURE,
	WEAPON_AK47: AK_UI_TEXTURE,
	WEAPON_KAR: KAR_UI_TEXTURE,
	WEAPON_SHOTGUN: SHOTGUN_UI_TEXTURE,
}

# Crop regions inside the 64x64 monochrome UI textures (keeps animations/scaling consistent).
const WEAPON_UI_REGION_BY_ID := {
	WEAPON_UZI: Rect2(21, 24, 25, 21),
	WEAPON_GRENADE: Rect2(12, 26, 39, 14),
	WEAPON_AK47: Rect2(8, 27, 50, 12),
	WEAPON_KAR: Rect2(5, 34, 76, 16),
	WEAPON_SHOTGUN: Rect2(6, 28, 54, 12),
}

const WEAPON_UI_OFFSET_BY_ID := {
	# Offsets align the "visual center" of each weapon, so transitions scale/move consistently.
	# Values are derived from an alpha-weighted centroid of the cropped region.
	WEAPON_UZI: Vector2(2.30, 3.84),
	WEAPON_GRENADE: Vector2(0.68, 2.35),
	WEAPON_AK47: Vector2(2.83, 2.75),
	WEAPON_KAR: Vector2(7.88, 0.60),
	WEAPON_SHOTGUN: Vector2(2.32, 2.40),
}

const WEAPON_BASE_COST_BY_ID := {
	WEAPON_UZI: 1800,
	WEAPON_GRENADE: 1600,
	WEAPON_AK47: 2200,
	WEAPON_KAR: 2600,
	WEAPON_SHOTGUN: 2000,
}

const COMMON_WEAPON_SKINS := [
	{"skin": 0, "name": "Classic", "category": "colors", "kind": "tint", "tint": Color(0.92, 0.95, 0.98, 1), "cost": 0},
	{"skin": 1, "name": "Lime", "category": "colors", "kind": "tint", "tint": Color(0.68, 1.0, 0.35, 1), "cost": 120},
	{"skin": 2, "name": "Orange", "category": "colors", "kind": "tint", "tint": Color(1.0, 0.62, 0.22, 1), "cost": 140},
	{"skin": 3, "name": "Magenta", "category": "colors", "kind": "tint", "tint": Color(1.0, 0.35, 0.85, 1), "cost": 160},
	{"skin": 4, "name": "Azure", "category": "colors", "kind": "tint", "tint": Color(0.25, 0.72, 1.0, 1), "cost": 180},
	{"skin": 5, "name": "Red", "category": "colors", "kind": "tint", "tint": Color(1.0, 0.28, 0.28, 1), "cost": 200},
	{"skin": 6, "name": "Aqua", "category": "colors", "kind": "tint", "tint": Color(0.22, 1.0, 0.92, 1), "cost": 220},
	{"skin": 7, "name": "Yellow", "category": "colors", "kind": "tint", "tint": Color(1.0, 0.98, 0.45, 1), "cost": 240},
	{"skin": 8, "name": "Pink", "category": "colors", "kind": "tint", "tint": Color(1.0, 0.55, 0.72, 1), "cost": 260},
	{"skin": 9, "name": "Purple", "category": "colors", "kind": "tint", "tint": Color(0.62, 0.38, 0.92, 1), "cost": 280},
	{"skin": 10, "name": "Steel", "category": "colors", "kind": "tint", "tint": Color(0.72, 0.78, 0.9, 1), "cost": 300},
	{"skin": 11, "name": "Coal", "category": "colors", "kind": "tint", "tint": Color(0.25, 0.27, 0.32, 1), "cost": 320},
	{"skin": 12, "name": "Sky", "category": "colors", "kind": "tint", "tint": Color(0.48, 0.86, 1.0, 1), "cost": 340},
	{"skin": 13, "name": "Toxic", "category": "colors", "kind": "tint", "tint": Color(0.65, 1.0, 0.2, 1), "cost": 360},
	{"skin": 14, "name": "Sand", "category": "colors", "kind": "tint", "tint": Color(0.92, 0.84, 0.62, 1), "cost": 380},
	{"skin": 15, "name": "Lilac", "category": "colors", "kind": "tint", "tint": Color(0.9, 0.74, 1.0, 1), "cost": 400},
	{"skin": 16, "name": "Teal", "category": "colors", "kind": "tint", "tint": Color(0.18, 0.85, 0.78, 1), "cost": 420},
	{"skin": 17, "name": "Cherry", "category": "colors", "kind": "tint", "tint": Color(0.98, 0.25, 0.4, 1), "cost": 440},
	{"skin": 18, "name": "Gold", "category": "colors", "kind": "tint", "tint": Color(1.0, 0.9, 0.25, 1), "cost": 900},
	{"skin": 19, "name": "Neon", "category": "colors", "kind": "tint", "tint": Color(0.25, 1.0, 0.85, 1), "cost": 1100},
	{"skin": 20, "name": "Rainbow", "category": "colors", "kind": "tint", "tint": Color(1, 1, 1, 1), "cost": 0, "rainbow": true},
	{"skin": 21, "name": "total black", "category": "colors", "kind": "tint", "tint": Color(0, 0, 0, 1), "cost": 500},
]

const WEAPON_SKINS_BY_ID := {
	WEAPON_UZI: COMMON_WEAPON_SKINS,
	WEAPON_GRENADE: COMMON_WEAPON_SKINS,
	WEAPON_AK47: COMMON_WEAPON_SKINS,
	WEAPON_KAR: COMMON_WEAPON_SKINS,
	WEAPON_SHOTGUN: COMMON_WEAPON_SKINS,
}

const WEAPON_SPECIAL_SKINS_BY_ID := {
	WEAPON_AK47: [
		{"skin": 100, "name": "Mech", "category": "skins", "kind": "ui", "ui_texture": AK_SKIN1_UI_TEXTURE, "auto_crop": true, "cost": 800},
	],
}
