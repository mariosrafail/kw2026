extends RefCounted
## Shared rules/catalog for the Overdrive Duel prototype.
const ROUND_TARGET := 5
const COUNTDOWN_SECONDS := 3.0
const CORE_DELAY := 20.0
const CORE_WINDOW := 5.0
const OVERLOAD_AT := 45.0
const CORE_RADIUS := 1.85
const OUTRAGE := "outrage"
const EREBUS := "erebus"

const CARDS := {
	"heavy_rounds":{"label":"HEAVY ROUNDS","desc":"+25% damage / slower shots"},
	"feather_trigger":{"label":"FEATHER TRIGGER","desc":"+28% fire rate / -15% damage"},
	"glass_cannon":{"label":"GLASS CANNON","desc":"+20% damage / 80 max HP"},
	"rubber_grenade":{"label":"RUBBER GRENADE","desc":"Less damage / huge blast push"},
	"double_trouble":{"label":"DOUBLE TROUBLE","desc":"Grenade echoes a second blast"},
	"air_control":{"label":"AIR CONTROL","desc":"+18% air movement"},
	"quick_feet":{"label":"QUICK FEET","desc":"Hit = short speed burst"},
	"second_charge":{"label":"SECOND CHARGE","desc":"Store 2 hero-skill charges"},
	"overclock":{"label":"OVERCLOCK","desc":"Stronger skill / slower recharge"},
	"grounded":{"label":"GROUNDED","desc":"Less knockback / slightly slower"},
	"vamp_shot":{"label":"VAMP SHOT","desc":"First hit / 8s heals 10 HP"},
	"last_stand":{"label":"LAST STAND","desc":"Low HP = speed + recharge"},
	"signature_one":{"label":"SIGNATURE I","desc":"Hero-specific upgrade."},
	"signature_two":{"label":"SIGNATURE II","desc":"Hero-specific upgrade."}
}
const CARD_ORDER := [
	"heavy_rounds","feather_trigger","glass_cannon","rubber_grenade",
	"double_trouble","air_control","quick_feet","second_charge",
	"overclock","grounded","vamp_shot","last_stand","signature_one","signature_two"
]

static func hero_for_index(index: int) -> String:
	return OUTRAGE if index == 0 else EREBUS

static func skill_name(hero: String) -> String:
	return "BLAST STEP" if hero == OUTRAGE else "VOID GUARD"

static func skill_base_cooldown(hero: String) -> float:
	return 7.0 if hero == OUTRAGE else 9.0

static func mapped_augment(card_id: String, hero: String) -> String:
	if card_id == "signature_one":
		return "afterimage" if hero == OUTRAGE else "phase_guard"
	if card_id == "signature_two":
		return "ram" if hero == OUTRAGE else "void_anchor"
	return card_id

static func card(card_id: String, hero: String) -> Dictionary:
	var data: Dictionary = CARDS.get(card_id,{"label":card_id.to_upper(),"desc":""}).duplicate()
	if card_id == "signature_one":
		if hero == OUTRAGE:
			data.label = "AFTERIMAGE"
			data.desc = "Hits recharge Blast Step faster"
		else:
			data.label = "PHASE GUARD"
			data.desc = "Longer Void Guard timing window"
	elif card_id == "signature_two":
		if hero == OUTRAGE:
			data.label = "RAM"
			data.desc = "Dash through rival = hard launch"
		else:
			data.label = "VOID ANCHOR"
			data.desc = "Void Guard gets a huge counter-push"
	data["id"] = card_id
	return data

static func count(augments: Dictionary, id: String) -> int:
	return int(augments.get(id,0))

static func has(augments: Dictionary, id: String) -> bool:
	return count(augments,id) > 0
