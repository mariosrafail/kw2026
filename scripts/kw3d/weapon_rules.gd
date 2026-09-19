extends RefCounted
## Shared 3D weapon rules. Damage is authoritative; visuals may predict but never decide hits.
const HEADSHOT_MULTIPLIER := 1.5

const AK := {
	"id":"ak","label":"AK","base_damage":5.0,"magazine":25,"reload":1.0,
	"fire_interval":0.10,"pellets":1,"spread_deg":0.0,"range":120.0,
	"body_recoil":1.25,"muzzle_x":1.34
}
const SHOTGUN := {
	"id":"shotgun","label":"SHOTGUN","base_damage":5.0,"magazine":2,"reload":1.2,
	"fire_interval":0.20,"pellets":10,"spread_deg":11.0,"range":62.0,
	"body_recoil":2.7,"muzzle_x":1.52
}
const ORDER := ["ak","shotgun"]

static func by_slot(slot: int) -> Dictionary:
	return AK if clampi(slot,0,1)==0 else SHOTGUN

static func slot_for_id(id: String) -> int:
	return 1 if id=="shotgun" else 0

static func damage(profile: Dictionary, headshot: bool) -> float:
	var base := float(profile.get("base_damage",5.0))
	return base * (HEADSHOT_MULTIPLIER if headshot else 1.0)
