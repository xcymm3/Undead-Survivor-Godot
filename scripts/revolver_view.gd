extends "res://scripts/revolver_model.gd"
## First-person motion adapter; all geometry and mechanical poses come from the shared model.
var last_reload = false
var cancel_time = 0.0
var cancel_phase = 0.0
var previous_phase = 0.0
var motion = 0.0
var stride = 0.0
var sway = Vector2.ZERO
var previous_pos = Vector2.ZERO
var previous_angles = Vector2.ZERO
var tracked_id = ""
var preview_speed = -1.0
var preview_stride = 0.0
var state_name = "idle"

func reset_motion() -> void:
	tracked_id = ""
	last_reload = false
	cancel_time = 0.0
	previous_phase = 0.0
	motion = 0.0
	sway = Vector2.ZERO

func sync_pose(p: Dictionary, dt: float, elapsed: float, aim: float) -> void:
	var angles = Vector2(float(p.get("yaw",0)),float(p.get("pitch",0)))
	var pos: Vector2 = p.pos
	if tracked_id != str(p.id):
		tracked_id = str(p.id)
		previous_pos = pos
		previous_angles = angles
	var speed = minf(5.0,pos.distance_to(previous_pos)/maxf(dt,.001))
	if preview_speed >= 0: speed = preview_speed
	motion = lerpf(motion,speed,1-exp(-dt*12))
	stride += motion*dt*3.1
	if preview_speed >= 0: stride = preview_stride
	var turn = Vector2(angle_difference(previous_angles.x,angles.x),angles.y-previous_angles.y)/maxf(dt,.001)
	sway = sway.lerp(turn.limit_length(3.0),1-exp(-dt*10))
	previous_pos = pos
	previous_angles = angles
	var phase = clampf(1-float(p.reload)/Data.weapons[3].reloadDuration,0,1) if p.reloading else 0.0
	if last_reload and not p.reloading and previous_phase < .97:
		cancel_time = .13
		cancel_phase = previous_phase
	var cancellation = cancel_time > 0 and not p.reloading
	if cancellation:
		phase = lerpf(cancel_phase,1.0,1-cancel_time/.13)
		cancel_time = maxf(0,cancel_time-dt)
	var fire = clampf(1-float(p.fire_anim)/Data.weapons[3].fireDuration,0.001,1) if p.fire_anim > 0 else 0.0
	sample_pose(phase,p.reloading or cancellation,fire,aim,int(p.get("shots",0)))
	state_name = "reload" if p.reloading or cancellation else "fire" if fire > 0 else "aim" if aim > .5 else "walk" if motion > .1 else "idle"
	var strength = minf(motion/4.2,1.0)*(1-aim*.88)*(0.2 if p.reloading else 1.0)
	position = Vector3(sin(stride)*.014,absf(cos(stride))*.013,-absf(sin(stride))*.008)*strength
	position.y += sin(elapsed*1.7)*.002*(1-aim*.8)
	rotation = Vector3(-sway.y*.012,-sway.x*.013,sin(stride)*.013*strength+sway.x*.006)*(1-aim*.75)
	if p.switch > 0:
		rotation.z -= sin((1-p.switch/.4)*PI)*.3
		state_name = "switch"
	if cancellation: state_name = "cancel"
	if p.hp <= 0: visible = false
	last_reload = p.reloading
	previous_phase = phase
