extends "res://tools/campaign-input-driver.gd"
## Explicit synthetic limitations, not a validated model of human performance.
var error_angle = deg_to_rad(.35)
var observation = 1.5
var observed_task = -1
var pause_left = 0.0
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
	var yaw = desired
	var pitch = float(result.pitch)+cos(clock_time*1.3)*error_angle
	result.shove = result.get("shove",false) and absf(angle_difference(yaw,requested_yaw)) < .5
	result.yaw = yaw
	result.pitch = pitch
	result.x = move_world.x*cos(yaw)-move_world.y*sin(yaw)
	result.y = move_world.x*sin(yaw)+move_world.y*cos(yaw)
	if game.sim.zombies.any(func(z): return z.hp > 0 and z.pos.distance_to(p.pos) < 10): pause_left = 0.0
	if pause_left > 0:
		pause_left -= dt
		result.x = 0.0
		result.y = 0.0
		result.interact = false
		result.fire = false
	if result.get("slot",1) == 4 and result.has("use_self"): result.use_self = result.fire
	return result
