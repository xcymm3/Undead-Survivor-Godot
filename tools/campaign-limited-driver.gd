extends "res://tools/campaign-input-driver.gd"
## Explicit synthetic limitations, not a validated model of human performance.
var turn_rate = deg_to_rad(120.0)
var error_angle = deg_to_rad(.7)
var reaction = .25
var observation = 1.5
var observed_task = -1
var pause_left = 0.0
var steady = 0.0
var clock_time = 0.0
var last_heading = 0.0
func command(dt: float) -> Dictionary:
	var p: Dictionary = game.local_pawn()
	var result: Dictionary = super.command(dt)
	if result.is_empty(): return {"yaw":p.get("yaw",0.0),"pitch":p.get("pitch",0.0),"weapon":p.get("primary",0)}
	clock_time += dt
	var requested_yaw: float = result.yaw
	var move_world = Vector2(result.x*cos(requested_yaw)+result.y*sin(requested_yaw),-result.x*sin(requested_yaw)+result.y*cos(requested_yaw))
	if index != observed_task:
		observed_task = index
		var heading = move_world.angle()
		# Observe at interactions or meaningful route turns, not every frame.
		if index < tasks.size() and (tasks[index][1] != "" or absf(angle_difference(last_heading,heading)) > .9): pause_left = observation
		last_heading = heading
	var desired = requested_yaw+sin(clock_time*1.7)*error_angle
	var yaw = p.yaw+clampf(angle_difference(p.yaw,desired),-turn_rate*dt,turn_rate*dt)
	var pitch = move_toward(float(p.pitch),float(result.pitch)+cos(clock_time*1.3)*error_angle,turn_rate*dt)
	steady = steady+dt if absf(angle_difference(yaw,requested_yaw)) < .08 else 0.0
	result.shove = result.get("shove",false) and absf(angle_difference(yaw,requested_yaw)) < .5
	result.yaw = yaw
	result.pitch = pitch
	result.x = move_world.x*cos(yaw)-move_world.y*sin(yaw)
	result.y = move_world.x*sin(yaw)+move_world.y*cos(yaw)
	result.fire = result.fire and (steady >= reaction or (game.sim.map_id == "graypine_night" and result.get("slot",1) == 3 and absf(angle_difference(yaw,requested_yaw)) < .6))
	if game.sim.zombies.any(func(z): return z.hp > 0 and z.pos.distance_to(p.pos) < 10): pause_left = 0.0
	if pause_left > 0:
		pause_left -= dt
		result.x = 0.0
		result.y = 0.0
		result.interact = false
		result.fire = false
	if result.get("slot",1) == 4 and result.has("use_self"): result.use_self = result.fire
	return result
