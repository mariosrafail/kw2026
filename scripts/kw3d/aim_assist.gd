extends RefCounted
## Soft ADS magnetism. It only nudges aim when the player is already close to a visible target.
const CONE_DEG := 5.5
const MAX_RANGE := 52.0
const PULL_SPEED := 6.2
const MIN_STRENGTH := 0.16

static func forward(yaw: float,pitch: float) -> Vector3:
	return -(Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)).z

static func target_angles(origin: Vector3,target: Vector3) -> Vector2:
	var d: Vector3=(target-origin).normalized()
	if d.length_squared()<0.000001:return Vector2.ZERO
	return Vector2(atan2(-d.x,-d.z),asin(clampf(d.y,-1.0,1.0)))

static func angle_degrees(origin: Vector3,yaw: float,pitch: float,target: Vector3) -> float:
	var d:=target-origin
	if d.length_squared()<0.000001:return 0.0
	return rad_to_deg(acos(clampf(forward(yaw,pitch).dot(d.normalized()),-1.0,1.0)))

static func eligible(origin: Vector3,yaw: float,pitch: float,target: Vector3,cone_deg: float=CONE_DEG,max_range: float=MAX_RANGE) -> bool:
	var distance:=origin.distance_to(target)
	if distance<=0.01 or distance>max_range:return false
	return angle_degrees(origin,yaw,pitch,target)<=cone_deg

static func step(yaw: float,pitch: float,origin: Vector3,target: Vector3,dt: float,cone_deg: float=CONE_DEG) -> Vector2:
	var angle:=angle_degrees(origin,yaw,pitch,target)
	if angle>cone_deg:return Vector2(yaw,pitch)
	var wanted:=target_angles(origin,target)
	var closeness:=clampf(1.0-angle/maxf(0.001,cone_deg),0.0,1.0)
	var strength:=lerpf(MIN_STRENGTH,1.0,pow(closeness,0.65))
	var weight: float=(1.0-exp(-PULL_SPEED*maxf(0.0,dt)))*strength
	return Vector2(lerp_angle(yaw,wanted.x,weight),lerpf(pitch,wanted.y,weight))
