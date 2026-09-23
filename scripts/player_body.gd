extends CharacterBody3D
## Authority-owned capsule. Explicit motion keeps simulation/test dt independent
## of the scene frame; Godot sweeps resolve floors, walls, ceilings and slopes.
const RADIUS = .3
const HEIGHT = 1.8
const CROUCH_HEIGHT = 1.2
const GRAVITY = 18.0
const JUMP_SPEED = 8.4
var grounded = false
var collider: CollisionShape3D

static func eye_height(p: Dictionary) -> float:
	return 1.7-.6*float(p.get("crouch",0.0))

func _init() -> void:
	collision_layer = 0
	# Layer 2 is reserved for player-only barriers; enemy authority and bullets use layer 1.
	collision_mask = 3
	safe_margin = .001
	floor_snap_length = .08
	collider = CollisionShape3D.new()
	var capsule = CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	collider.shape = capsule
	collider.position.y = HEIGHT/2
	add_child(collider)

func sync_from(p: Dictionary) -> void:
	set_height(lerpf(HEIGHT,CROUCH_HEIGHT,float(p.get("crouch",0.0))))
	position = Vector3(p.pos.x,p.height,p.pos.y)
	velocity.y = p.velocity
	grounded = false
	if velocity.y <= 0:
		var support = move_and_collide(Vector3.DOWN*floor_snap_length,true,safe_margin)
		grounded = support != null and support.get_normal().dot(Vector3.UP) >= cos(floor_max_angle)
		# A capsule already within the recovery margin can report a zero normal.
		# Verify nearby ground independently before preserving an old air input.
		if not grounded:
			var floor_hit = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(position+Vector3.UP*.05,position+Vector3.DOWN*.08,collision_mask))
			grounded = not floor_hit.is_empty() and floor_hit.normal.dot(Vector3.UP) >= cos(floor_max_angle)

func set_height(value: float) -> void:
	if is_equal_approx(collider.shape.height,value): return
	collider.shape.height = value
	collider.position.y = value/2

func update_stance(p: Dictionary, requested: bool, dt: float) -> void:
	var amount = float(p.get("crouch",0.0))
	var blocked = false
	if not requested and amount > 0:
		var shape = CapsuleShape3D.new()
		shape.radius = RADIUS-.005
		# Query only the extra volume above the crouched capsule. Rechecking
		# its already occupied feet can mistake floor recovery for a ceiling.
		shape.height = HEIGHT-CROUCH_HEIGHT+2*shape.radius
		var query = PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(Basis.IDENTITY,position+Vector3.UP*(HEIGHT-shape.height/2-.01))
		query.collision_mask = collision_mask
		query.exclude = [get_rid()]
		blocked = not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
	p.crouching = requested or blocked
	p.crouch = move_toward(amount,1.0 if p.crouching else 0.0,dt*6)
	set_height(lerpf(HEIGHT,CROUCH_HEIGHT,p.crouch))

func advance(horizontal: Vector2, dt: float) -> void:
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	var motion = velocity*dt+Vector3.DOWN*(GRAVITY*.5*dt*dt)
	velocity.y -= GRAVITY*dt
	grounded = false
	var margin = safe_margin
	for i in max_slides:
		if motion.length_squared() < .00000001: break
		var hit = move_and_collide(motion,false,margin)
		if hit == null: break
		var normal = hit.get_normal()
		if normal.dot(Vector3.UP) >= cos(floor_max_angle):
			grounded = true
			if velocity.y < 0: velocity.y = 0
		elif normal.dot(Vector3.DOWN) >= cos(floor_max_angle) and velocity.y > 0:
			velocity.y = 0
		motion = hit.get_remainder().slide(normal)
		# A floor contact inside the recovery margin can repeatedly report zero
		# travel even for a tangent motion. Retry that remaining sweep against
		# exact geometry; walls and ceilings still collide normally.
		if normal.dot(Vector3.UP) >= cos(floor_max_angle) and hit.get_travel().length_squared() < .00000001:
			margin = 0.0
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
