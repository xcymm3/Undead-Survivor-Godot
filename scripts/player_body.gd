extends CharacterBody3D
## Authority-owned capsule. Explicit motion keeps simulation/test dt independent
## of the scene frame; Godot sweeps resolve floors, walls, ceilings and slopes.
const RADIUS = .3
const HEIGHT = 1.8
const GRAVITY = 18.0
const JUMP_SPEED = 8.4
var grounded = false

func _init() -> void:
	collision_layer = 0
	collision_mask = 1
	safe_margin = .001
	floor_snap_length = .08
	var collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	collider.shape = capsule
	collider.position.y = HEIGHT/2
	add_child(collider)

func sync_from(p: Dictionary) -> void:
	position = Vector3(p.pos.x,p.height,p.pos.y)
	velocity.y = p.velocity
	grounded = false
	if velocity.y <= 0:
		var support = move_and_collide(Vector3.DOWN*floor_snap_length,true,safe_margin)
		grounded = support != null and support.get_normal().dot(Vector3.UP) >= cos(floor_max_angle)

func advance(horizontal: Vector2, dt: float) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	var motion = velocity*dt+Vector3.DOWN*(GRAVITY*.5*dt*dt)
	velocity.y -= GRAVITY*dt
	grounded = false
	for i in max_slides:
		if motion.length_squared() < .00000001: break
		var hit = move_and_collide(motion,false,safe_margin)
		if hit == null: break
		var normal = hit.get_normal()
		if normal.dot(Vector3.UP) >= cos(floor_max_angle):
			grounded = true
			if velocity.y < 0: velocity.y = 0
		elif normal.dot(Vector3.DOWN) >= cos(floor_max_angle) and velocity.y > 0:
			velocity.y = 0
		motion = hit.get_remainder().slide(normal)
	if velocity.y <= 0:
		var support = move_and_collide(Vector3.DOWN*floor_snap_length,true,safe_margin)
		if support != null and support.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
			move_and_collide(Vector3.DOWN*floor_snap_length,false,safe_margin)
			grounded = true
			velocity.y = 0

func sync_to(p: Dictionary) -> void:
	p.pos = Vector2(position.x,position.z)
	p.height = position.y
	p.velocity = velocity.y
	p.grounded = grounded
