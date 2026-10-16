extends RefCounted
## Independently authored poses, informed by the rhythm of Kubold's public demo.
## Coordinates are local to the axe model; -X is the cutting edge, +Y the shaft.
const CUT_START = .22
const CUT_END = .66
const CUT_CENTRE = .46
const EDGE_POINT = Vector3(-.45,.565,0)
const TIMES = [0.0,.12,.22,.34,.46,.56,.66,.78,1.0]
const RIGHT_TIPS = [
	Vector3.ZERO,Vector3(.67,.47,-.36),Vector3(.74,.53,-.52),
	Vector3(.43,.29,-.91),Vector3(0,.02,-1.22),
	Vector3(-.47,-.22,-1.25),Vector3(-.83,-.36,-1.07),
	Vector3(-.94,-.43,-.93),Vector3(-.87,-.38,-.85)]
const LEFT_TIPS = [
	Vector3.ZERO,Vector3(-.65,.25,-.42),Vector3(-.73,.38,-.58),
	Vector3(-.41,.21,-.96),Vector3(.02,-.01,-1.24),
	Vector3(.46,-.16,-1.20),Vector3(.79,-.28,-1.01),
	Vector3(.90,-.36,-.86),Vector3(.84,-.31,-.79)]
const RIGHT_SHAFTS = [
	Vector3.UP,Vector3(.54,.81,.08),Vector3(.62,.77,-.12),
	Vector3(.39,.87,-.31),Vector3(.15,.87,-.47),
	Vector3(-.17,.75,-.64),Vector3(-.46,.57,-.68),
	Vector3(-.58,.46,-.67),Vector3(-.54,.53,-.65)]
const LEFT_SHAFTS = [
	Vector3.UP,Vector3(-.52,.83,.10),Vector3(-.57,.80,-.13),
	Vector3(-.32,.89,-.32),Vector3(-.10,.88,-.47),
	Vector3(.22,.77,-.60),Vector3(.48,.62,-.62),
	Vector3(.57,.51,-.64),Vector3(.52,.58,-.62)]

var current = ready_pose()
var start_pose = ready_pose()
var serial = -1
var last_phase = 0.0
var recovering = 0.0
var recovery_from = ready_pose()

static func ready_pose() -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(-.12,-.65,-.24)),Vector3(.08,-.10,-.46))

static func key_pose(index: int, direction: int) -> Transform3D:
	if index == 0: return ready_pose()
	var tips = RIGHT_TIPS if direction == 1 else LEFT_TIPS
	var shafts = RIGHT_SHAFTS if direction == 1 else LEFT_SHAFTS
	var y: Vector3 = shafts[index].normalized()
	# Roll the reverse stroke so the sharpened edge leads, rather than the pick.
	var edge = Vector3(-.82 if direction == 1 else .82,-.34,-.46)
	var x = -(edge-y*edge.dot(y)).normalized()
	var basis = Basis(x,y,x.cross(y).normalized())
	return Transform3D(basis,tips[index]-basis*EDGE_POINT)

static func pose(progress: float, direction: int) -> Transform3D:
	var t = clampf(progress,0,1)
	var i = 0
	while i < TIMES.size()-2 and t > TIMES[i+1]: i += 1
	var a = key_pose(i,direction)
	var b = key_pose(i+1,direction)
	var blend: float = (t-TIMES[i])/(TIMES[i+1]-TIMES[i])
	# Interpolate the cutting edge, then derive the grip, keeping the blade arc
	# monotone through the damage sector. Smooth recovery never rewinds the cut.
	var basis = Basis(a.basis.get_rotation_quaternion().slerp(b.basis.get_rotation_quaternion(),blend))
	var span: float = TIMES[i+1]-TIMES[i]
	var u2 = blend*blend
	var u3 = u2*blend
	var edge = (a*EDGE_POINT)*(2*u3-3*u2+1)+edge_tangent(i,direction)*span*(u3-2*u2+blend)+(b*EDGE_POINT)*(-2*u3+3*u2)+edge_tangent(i+1,direction)*span*(u3-u2)
	return Transform3D(basis,edge-basis*EDGE_POINT)

static func edge_tangent(index: int, direction: int) -> Vector3:
	if index == 0 or index == TIMES.size()-1: return Vector3.ZERO
	var previous = key_pose(index-1,direction)*EDGE_POINT
	var point = key_pose(index,direction)*EDGE_POINT
	var next = key_pose(index+1,direction)*EDGE_POINT
	var before: float = TIMES[index]-TIMES[index-1]
	var after: float = TIMES[index+1]-TIMES[index]
	var a = (point-previous)/before
	var b = (next-point)/after
	var result = Vector3.ZERO
	for axis in 3:
		if a[axis]*b[axis] <= 0: continue
		var w1 = 2*after+before
		var w2 = after+2*before
		result[axis] = (w1+w2)/(w1/a[axis]+w2/b[axis])
	return result

func reset() -> void:
	current = ready_pose()
	start_pose = current
	recovery_from = current
	serial = -1
	last_phase = 0.0
	recovering = 0.0

func sample(p: Dictionary, dt: float, duration: float) -> Transform3D:
	if p.get("hp",0) <= 0 or p.get("weapon",-1) != 6 or p.get("requested",6) != 6 or p.get("switch",0.0) > 0 or p.get("reloading",false):
		reset()
		return current
	if p.get("fire_anim",0.0) > 0:
		var phase = clampf(1.0-float(p.fire_anim)/maxf(.001,duration),0,1)
		var shot: int = int(p.get("shots",0))
		if serial != shot or phase < last_phase:
			start_pose = current
			serial = shot
		var target = pose(phase,int(p.get("axe_direction",1)))
		current = start_pose.interpolate_with(target,smoothstep(0,CUT_START,phase)) if phase < CUT_START else target
		last_phase = phase
		recovering = 0.0
		recovery_from = current
	else:
		# Keep the follow-through across the 40ms combo gap. A fresh stroke
		# starts from that displayed pose, even after a late buffered click.
		recovering += maxf(0,dt)
		current = recovery_from.interpolate_with(ready_pose(),smoothstep(.08,.26,recovering))
	return current
