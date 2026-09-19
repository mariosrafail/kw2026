extends RefCounted
## Resolves the exact CollisionShape3D hit by a physics ray.
const BODY := "body"
const HEAD := "head"

static func region_from_hit(hit: Dictionary) -> String:
	if hit.is_empty():
		return BODY
	var collider := hit.get("collider") as CollisionObject3D
	if collider == null:
		return BODY
	var shape_index := int(hit.get("shape",-1))
	if shape_index < 0:
		return BODY
	var owner_id := collider.shape_find_owner(shape_index)
	if owner_id < 0:
		return BODY
	var owner := collider.shape_owner_get_owner(owner_id) as Node
	if owner != null and owner.has_meta("hit_region"):
		return str(owner.get_meta("hit_region"))
	return BODY

static func is_headshot(hit: Dictionary) -> bool:
	return region_from_hit(hit)==HEAD
