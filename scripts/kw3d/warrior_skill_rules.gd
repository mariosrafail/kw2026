extends RefCounted
## Shared 3D warrior-skill balance. Offline and authority code read the same table.

const DATA := {
	"outrage": {
		"id": "damage_boost", "label": "DAMAGE BOOST", "cooldown": 12.0, "duration": 5.0,
		"color": Color("ff3f57"), "description": "x2 damage for 5 seconds"
	},
	"erebus": {
		"id": "immunity_surge", "label": "IMMUNITY SURGE", "cooldown": 14.0, "duration": 5.0,
		"color": Color("7188ff"), "description": "Ignore incoming damage for 5 seconds"
	},
	"kosas": {
		"id": "nose_rush", "label": "NOSE RUSH", "cooldown": 8.0, "duration": 0.35,
		"color": Color("ff43d5"), "description": "Dash forward and ram nearby enemies"
	},
	"aevilok": {
		"id": "flamethrower", "label": "FLAMETHROWER", "cooldown": 12.0, "duration": 3.5,
		"color": Color("ff6239"), "description": "Channel a damaging flame cone for 3.5 seconds"
	},
	"loker": {
		"id": "overclock", "label": "OVERCLOCK", "cooldown": 11.0, "duration": 5.0,
		"color": Color("39d143"), "description": "Faster fire rate and reload speed for 5 seconds"
	}
}


static func config(warrior_id: String) -> Dictionary:
	return config_ref(warrior_id).duplicate(true)

static func config_ref(warrior_id: String) -> Dictionary:
	var id := warrior_id.strip_edges().to_lower()
	return DATA.get(id,DATA.outrage) as Dictionary


static func valid(warrior_id: String) -> bool:
	return DATA.has(warrior_id.strip_edges().to_lower())


static func label(warrior_id: String) -> String:
	return str(config_ref(warrior_id).get("label", "SKILL"))


static func color(warrior_id: String) -> Color:
	return config_ref(warrior_id).get("color", Color.WHITE) as Color


static func cooldown(warrior_id: String) -> float:
	return float(config_ref(warrior_id).get("cooldown", 10.0))


static func duration(warrior_id: String) -> float:
	return float(config_ref(warrior_id).get("duration", 0.0))

static func skill_id(warrior_id: String) -> String:
	return str(config_ref(warrior_id).get("id","skill"))
