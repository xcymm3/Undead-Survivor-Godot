extends RefCounted
## Camera-space choreography; the scabbard axis and the blade insertion axis oppose.
const SIZE = .56
const HORIZONTAL = 1.25
const VERTICAL = .72
const FORWARD_LEAN = .32
const LENGTH = preload("res://scripts/long_blade.gd").TIP*SIZE
const MOUTH = Vector3(.36,-.28,-1.42)
const PULL = Vector3(-.82,.43,-.37)
var current = ready_pose()
var sheath_from = ready_pose()
var sheathing = false
var chop = preload("res://scripts/axe_motion.gd").new()

func _init() -> void:
	chop.horizontal_scale = HORIZONTAL
	chop.vertical_scale = VERTICAL
	chop.forward_lean = FORWARD_LEAN
	chop.reset()

static func pose(grip: Vector3, axis: Vector3) -> Transform3D:
	var y = axis.normalized()
	var x = y.cross(Vector3.BACK).normalized()
	return Transform3D(Basis(x,y,x.cross(y)).scaled(Vector3.ONE*SIZE),grip)

static func carry_frame() -> Transform3D:
	# The same .5-scale first-person weapon root and melee carry position as the axe.
	return Transform3D(Basis().scaled(Vector3.ONE*.5),Vector3(.19,-.10,-.46))

static func model_alignment() -> Transform3D:
	# Keep the existing long-blade size; this fixed model scale never alters the grip path.
	return Transform3D(Basis().scaled(Vector3.ONE*(SIZE/.5)),Vector3.ZERO)

static func ready_pose() -> Transform3D:
	return carry_frame()*preload("res://scripts/axe_motion.gd").ready_pose(HORIZONTAL,VERTICAL,FORWARD_LEAN)*model_alignment()

static func sheath_pose() -> Transform3D:
	return pose(MOUTH,PULL)

static func inserted_pose() -> Transform3D:
	return pose(MOUTH,-PULL)

static func extracted_pose() -> Transform3D:
	return pose(MOUTH+PULL.normalized()*(LENGTH+.12),-PULL)

static func draw_pose(progress: float, held := ready_pose()) -> Transform3D:
	if progress < .16: return inserted_pose()
	if progress < .74:
		return inserted_pose().interpolate_with(extracted_pose(),smoothstep(.16,.74,progress))
	return extracted_pose().interpolate_with(held,smoothstep(.74,1.0,progress))

static func swing_pose(progress: float, direction: int) -> Transform3D:
	return carry_frame()*preload("res://scripts/axe_motion.gd").pose(progress,direction,HORIZONTAL,VERTICAL,FORWARD_LEAN)*model_alignment()

func reset() -> void:
	current = ready_pose()
	sheathing = false
	chop.reset()

func sample(p: Dictionary, dt: float, fire_duration: float, carry := carry_frame()) -> Dictionary:
	var ultimate = preload("res://scripts/ultimate.gd")
	var remaining: float = p.get("ultimate_sheathe",0.0)
	var drawing: bool = ultimate.active(p) and p.get("ultimate_age",0.0) < ultimate.DRAW_TIME
	var sheath = sheath_pose()
	if remaining > 0:
		if not sheathing: sheath_from = current
		sheathing = true
		var t = clampf(1.0-remaining/ultimate.SHEATHE_TIME,0,1)
		if t < .38:
			current = sheath_from.interpolate_with(extracted_pose(),smoothstep(0,.38,t))
		else:
			current = extracted_pose().interpolate_with(inserted_pose(),smoothstep(.38,.83,t))
		var lower = Vector3(.10,-.48,.08)*smoothstep(.83,1,t)
		current.origin += lower
		sheath.origin += lower
		# Bring the empty scabbard up while the blade aligns, before insertion.
		sheath.origin += Vector3(.10,-.65,.08)*(1.0-smoothstep(0,.30,t))
	elif drawing:
		var t = clampf(float(p.ultimate_age)/ultimate.DRAW_TIME,0,1)
		current = draw_pose(t,carry*chop.ready_pose(HORIZONTAL,VERTICAL,FORWARD_LEAN)*model_alignment())
		var lift = Vector3(.10,-.48,.08)*(1.0-smoothstep(0,.16,t))
		current.origin += lift
		sheath.origin += lift
		# Once the tip is clear, lower the empty scabbard out of view.
		sheath.origin += Vector3(.10,-.65,.08)*smoothstep(.74,1,t)
		sheathing = false
		chop.reset()
	else:
		# Share the entire axe state machine: wind-up, shot serials, combo gap and recovery.
		# Only the geometry attached at its grip is different; no camera-space remapping.
		current = carry*chop.sample(p,dt,fire_duration)*model_alignment()
	return {"blade":current,"sheath":sheath}
