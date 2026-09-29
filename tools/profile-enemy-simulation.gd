extends "res://scripts/simulation.gd"
var scopes: Array = []
var inclusive: Dictionary = {}
var exclusive: Dictionary = {}
var shot_calls = 0

func begin_scope(label: String) -> void:
	scopes.append({"label":label,"start":Time.get_ticks_usec(),"children":0})

func end_scope() -> void:
	var entry: Dictionary = scopes.pop_back()
	var duration: int = Time.get_ticks_usec()-entry.start
	inclusive[entry.label] = inclusive.get(entry.label,0)+duration
	exclusive[entry.label] = exclusive.get(entry.label,0)+duration-entry.children
	if not scopes.is_empty(): scopes[-1].children += duration

func step(dt: float) -> void:
	inclusive.clear()
	exclusive.clear()
	shot_calls = 0
	begin_scope("simulation")
	super.step(dt)
	end_scope()

func choose_zombie_target(z: Dictionary, living: Array) -> Dictionary:
	begin_scope("target_selection")
	var result = super.choose_zombie_target(z,living)
	end_scope()
	return result

func update_zombie(z: Dictionary, target: Dictionary, dt: float) -> void:
	begin_scope("enemy_logic")
	super.update_zombie(z,target,dt)
	end_scope()

func move_zombie(z: Dictionary, goal: Vector2, speed: float, dt: float, distance: float, contact: float, stop_at_waypoint := false) -> void:
	begin_scope("navigation_steering")
	super.move_zombie(z,goal,speed,dt,distance,contact,stop_at_waypoint)
	end_scope()

func physical_move(z: Dictionary, velocity: Vector2, dt: float, gravity := false) -> void:
	begin_scope("enemy_movement")
	super.physical_move(z,velocity,dt,gravity)
	end_scope()

func sync_enemy_bodies() -> void:
	begin_scope("enemy_sync")
	super.sync_enemy_bodies()
	end_scope()

func enemy_body(z: Dictionary):
	begin_scope("enemy_sync")
	var result = super.enemy_body(z)
	end_scope()
	return result

func attack_lane_clear(z: Dictionary, victim: Dictionary) -> bool:
	begin_scope("attack_occlusion")
	var result = super.attack_lane_clear(z,victim)
	end_scope()
	return result

func fire(p: Dictionary, w: Dictionary) -> void:
	begin_scope("shooting")
	shot_calls += 1
	super.fire(p,w)
	end_scope()
