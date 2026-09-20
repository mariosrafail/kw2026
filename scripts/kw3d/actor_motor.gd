extends RefCounted
## Identical fixed-step motor for authority and local prediction. No input or camera dependencies.
const DT := 1.0/60.0
const WALK_SPEED := 7.5
const SPRINT_SPEED := 11.0
const SNIPER_AIM_SPEED := 0.6

static func speed_for(command: Dictionary) -> float:
	var sniper_scoped:=bool(command.get("aim",false)) and int(command.get("weapon",0))==2
	if sniper_scoped:return SNIPER_AIM_SPEED
	return SPRINT_SPEED if bool(command.get("sprint",false)) else WALK_SPEED

static func step(body: CharacterBody3D, command: Dictionary, dt: float=DT) -> void:
	var move: Vector2=command.get("move",Vector2.ZERO)
	var yaw: float=command.get("yaw",0.0)
	var basis =Basis(Vector3.UP,yaw)
	var direction: Vector3=(basis.x*move.x-basis.z*move.y).limit_length(1.0)
	var speed: float=speed_for(command)
	body.velocity.x=move_toward(body.velocity.x,direction.x*speed,28.0*dt)
	body.velocity.z=move_toward(body.velocity.z,direction.z*speed,28.0*dt)
	var grounded: bool=body.get_meta("motor_grounded",body.is_on_floor())
	if body.has_meta("motor_grounded"):body.remove_meta("motor_grounded")
	if grounded:
		body.velocity.y=8.8 if command.get("jump",false) else -0.5
	else:
		body.velocity.y-=19.5*dt
	body.move_and_slide()
static func empty(yaw: float=0.0,pitch: float=-0.174533) -> Dictionary:
	return {"move":Vector2.ZERO,"yaw":yaw,"pitch":pitch,"fire":false,"aim":false,"sprint":false,"jump":false,"grenade":false,"reload":false,"side":1.0,"weapon":0}
