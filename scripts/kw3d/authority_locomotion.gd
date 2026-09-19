extends "res://scripts/prototypes/kw_goofy_locomotion.gd"
## Same foot planting and torso springs, supplied by data instead of render meshes.
func setup(p: CharacterBody3D,v: Node3D,h: Node3D,t: Node3D,left: Node3D,right: Node3D,seed_value: int=137) -> void:
	actor=p;visual=v;head=h;torso=t
	torso_rest=t.position;head_rest=h.position
	rng.seed=seed_value
	noise_phase=rng.randf_range(0.0,TAU)
	for n in [left,right]:
		var f =FootState.new()
		f.node=n;f.rest=n.position
		var data: Dictionary=n.get_meta("sole_geometry")
		for a in data.corners: f.corners.append(Vector3(a[0],a[1],a[2]))
		var c: Array=data.center
		f.sole_center=Vector3(c[0],c[1],c[2])
		assert(f.corners.size()==8)
		feet.append(f)
	reset()
