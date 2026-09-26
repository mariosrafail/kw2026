extends RefCounted
## Shared 3D weapon rules. Damage and spread are authoritative.
const HEADSHOT_MULTIPLIER := 1.5

const AK := {
	"id":"ak","label":"AK","base_damage":5.0,"magazine":25,"reload":1.0,
	"fire_interval":0.10,"pellets":1,"spread_deg":0.0,"hip_spread_deg":0.0,"ads_spread_deg":0.0,"range":120.0,
	"body_recoil":1.25,"muzzle_x":1.34
}
const SHOTGUN := {
	"id":"shotgun","label":"SHOTGUN","base_damage":6.0,"magazine":2,"reload":1.2,
	"fire_interval":0.20,"pellets":10,"spread_deg":11.0,"hip_spread_deg":13.5,"ads_spread_deg":9.0,"range":62.0,
	"body_recoil":2.7,"muzzle_x":1.52
}
const KAR := {
	"id":"kar","label":"KAR","base_damage":50.0,"headshot_damage":1000.0,"magazine":1,"reload":1.4,
	"fire_interval":0.95,"pellets":1,"spread_deg":0.0,"hip_spread_deg":0.0,"ads_spread_deg":0.0,"range":220.0,
	"body_recoil":3.25,"muzzle_x":1.82
}
const GRENADE_LAUNCHER := {
	"id":"grenade_launcher","label":"GRENADE","base_damage":70.0,"magazine":1,"reload":1.65,
	"fire_interval":0.90,"pellets":1,"spread_deg":0.0,"hip_spread_deg":0.0,"ads_spread_deg":0.0,"range":80.0,
	"body_recoil":3.0,"muzzle_x":1.62,"projectile_speed":22.0,"gravity":16.0,
	"fuse":2.4,"blast_radius":4.8,"min_damage":22.0,"max_damage":72.0
}
const ORDER := ["ak","shotgun","kar","grenade_launcher"]
static var spread_rng:=RandomNumberGenerator.new()

static func by_slot(slot: int) -> Dictionary:
	match clampi(slot,0,3):
		1:return SHOTGUN
		2:return KAR
		3:return GRENADE_LAUNCHER
		_:return AK

static func slot_for_id(id: String) -> int:
	if id=="shotgun":return 1
	if id=="kar":return 2
	if id in ["grenade_launcher","launcher","gl"]:return 3
	return 0

static func damage(profile: Dictionary,headshot: bool) -> float:
	if headshot and profile.has("headshot_damage"):return float(profile.headshot_damage)
	var base:=float(profile.get("base_damage",5.0))
	return base*(HEADSHOT_MULTIPLIER if headshot else 1.0)

static func spread_for(profile: Dictionary,aiming: bool) -> float:
	return float(profile.get("ads_spread_deg",0.0) if aiming else profile.get("hip_spread_deg",0.0))

static func spread_direction(base_direction: Vector3,profile: Dictionary,aiming: bool,seed: int) -> Vector3:
	var base:=base_direction.normalized()
	var spread_deg:=spread_for(profile,aiming)
	if spread_deg<=0.0001:return base
	spread_rng.seed=seed
	var right:=base.cross(Vector3.UP).normalized()
	if right.length_squared()<0.01:right=Vector3.RIGHT
	var up:=right.cross(base).normalized()
	var angle:=spread_rng.randf_range(0.0,TAU)
	var radius:=sqrt(spread_rng.randf())*tan(deg_to_rad(spread_deg))
	return (base+right*cos(angle)*radius+up*sin(angle)*radius).normalized()
