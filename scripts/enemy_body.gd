extends CharacterBody3D
## Authority capsules, independent of animated hit boxes. Dead bodies never collide.
var collider: CollisionShape3D
var profile_key = ""
var blocked_by_enemy = false
var blocked_by_world = false
var grounded = false
var physics_usec = 0
var overlap_queries: Dictionary = {}
var peer_rid = RID()
var next_crowd_probe = 0.0
var last_move_at = 0.0
var move_attempts = 0

func _ready() -> void:
	# Godot queues kinematic peer transforms until its next physics step.
	# A native static capsule in the same space publishes the resolved pose
	# immediately for subsequent character sweeps. Both use the same shape;
	# this is engine collision detection, never a distance-based substitute.
	peer_rid = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(peer_rid,PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_attach_object_instance_id(peer_rid,get_instance_id())
	PhysicsServer3D.body_add_shape(peer_rid,collider.shape.get_rid(),collider.transform)
	PhysicsServer3D.body_set_collision_layer(peer_rid,8)
	PhysicsServer3D.body_set_collision_mask(peer_rid,0)
	PhysicsServer3D.body_set_space(peer_rid,get_world_3d().space)
	PhysicsServer3D.body_add_collision_exception(get_rid(),peer_rid)
	commit_transform()

func _exit_tree() -> void:
	if peer_rid.is_valid():
		PhysicsServer3D.free_rid(peer_rid)
		peer_rid = RID()

static func profile(kind: String) -> Dictionary:
	if kind == "giant": return {"key":"giant","radius":.72,"height":3.6,"clearance":.75}
	if kind == "imp": return {"key":"imp","radius":.25,"height":1.3,"clearance":.28}
	if kind == "crawler": return {"key":"crawler","radius":.34,"height":1.6,"clearance":.93}
	return {"key":"normal","radius":.4,"height":2.0,"clearance":.43}

func _init(kind := "normal") -> void:
	collision_layer = 2
	collision_mask = 13 # World, resolved enemy capsules, players.
	safe_margin = .001
	max_slides = 6
	collider = CollisionShape3D.new()
	configure(kind)
	add_child(collider)

func configure(kind: String) -> void:
	overlap_queries.clear()
	var data = profile(kind)
	profile_key = data.key
	var shape = CapsuleShape3D.new()
	shape.radius = data.radius
	shape.height = data.height
	collider.shape = shape
	collider.rotation.x = PI/2 if kind == "crawler" else 0.0
	collider.position.y = data.radius+.02 if kind == "crawler" else data.height/2
	collider.position.z = .1 if kind == "crawler" else 0.0
	if peer_rid.is_valid():
		PhysicsServer3D.body_clear_shapes(peer_rid)
		PhysicsServer3D.body_add_shape(peer_rid,collider.shape.get_rid(),collider.transform)

func sync_from(z: Dictionary) -> void:
	if profile_key != profile(z.kind).key: configure(z.kind)
	position = Vector3(z.pos.x,z.get("height",Data.enemy_ground_height(z.pos,z.map_id)),z.pos.y)
	if z.kind == "crawler" and not is_equal_approx(rotation.y,z.heading):
		var old_heading = rotation.y
		rotation.y = z.heading
		commit_transform()
		if overlaps(13):
			rotation.y = old_heading
			commit_transform()
			z.heading = old_heading
	velocity.y = z.get("vertical_velocity",0.0)
	collider.disabled = z.hp <= 0
	collision_layer = 2 if z.hp > 0 else 0
	collision_mask = 13 if z.hp > 0 else 0
	if peer_rid.is_valid(): PhysicsServer3D.body_set_collision_layer(peer_rid,8 if z.hp > 0 else 0)
	commit_transform()

func commit_transform() -> void:
	# Enemies advance sequentially inside one authority tick. Publish each
	# transform immediately so the next sweep sees this tick's position,
	# rather than the scene tree's deferred transform from the previous tick.
	force_update_transform()
	collider.force_update_transform()
	PhysicsServer3D.body_set_state(get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,global_transform)
	if peer_rid.is_valid():
		PhysicsServer3D.body_set_state(peer_rid,PhysicsServer3D.BODY_STATE_TRANSFORM,global_transform)

func retire() -> void:
	collision_layer = 0
	collision_mask = 0
	collider.disabled = true
	if peer_rid.is_valid(): PhysicsServer3D.body_set_collision_layer(peer_rid,0)
	velocity = Vector3.ZERO

func advance(horizontal: Vector2, dt: float, gravity := false, allow_step := true) -> void:
	var start = Time.get_ticks_usec()
	if horizontal.length_squared() > .001: move_attempts += 1
	blocked_by_enemy = false
	blocked_by_world = false
	grounded = false
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	var original = global_transform
	var mask_before = collision_mask
	if gravity: collision_mask = 1
	var motion = Vector3(horizontal.x,0,horizontal.y)*dt
	if gravity:
		motion.y = velocity.y*dt-9*dt*dt
		velocity.y -= 18*dt
	var margin = safe_margin
	var actor_contacts = 0
	for i in max_slides:
		if motion.length_squared() < .00000001: break
		var hit = move_and_collide(motion,false,margin)
		commit_transform()
		if hit == null: break
		var normal = hit.get_normal()
		var actor = hit.get_collider()
		if actor is CharacterBody3D:
			actor_contacts += 1
			blocked_by_enemy = true
			# Two peer slides suffice for a crowd corner. More bounces in one
			# tick waste sweeps without creating usable space for this actor.
			if actor_contacts >= 2: break
		if normal.length_squared() < .01:
			if actor is CharacterBody3D: blocked_by_enemy = true
			else: blocked_by_world = true
			# A floor inside the recovery margin may return no usable normal.
			# Retry its remaining motion against exact geometry, retaining the
			# final capsule overlap check instead of freezing at that contact.
			motion = hit.get_remainder()
			margin = 0.0
			continue
		if actor is CharacterBody3D:
			# Rounded capsules must not turn a crowd into a staircase. Actor
			# contacts slide horizontally; only world geometry supports feet.
			blocked_by_enemy = actor.collision_layer == 2
			normal.y = 0
			normal = normal.normalized()
		elif normal.dot(Vector3.UP) >= cos(floor_max_angle):
			grounded = true
			velocity.y = 0
		else: blocked_by_world = true
		motion = hit.get_remainder().slide(normal)
		if grounded and hit.get_travel().length_squared() < .00000001: margin = 0.0
	if velocity.y <= 0:
		# Snap against scenery only, never onto another enemy's head.
		var mask = collision_mask
		collision_mask = 1
		var support = move_and_collide(Vector3.DOWN*.12,true,safe_margin)
		if support != null and support.get_normal().dot(Vector3.UP) >= cos(floor_max_angle):
			# Apply the tested sweep's safe travel. Repeating the cast after
			# an immediate transform update can recover against the old pose.
			position += support.get_travel()
			commit_transform()
			velocity.y = 0
			grounded = true
		collision_mask = mask
		# At tangent capsule/floor contacts Godot's sweep can report travel a
		# few centimetres below the support plane. Correct only the foot height
		# against real world geometry before validating the entire capsule.
		var foot_offset = .02 if profile_key == "crawler" else 0.0
		var probes = [Vector3.ZERO]
		if profile_key == "crawler":
			# Its horizontal cylindrical section needs support at both ends
			# when crossing the ramp crest or turning sideways on the slope.
			var half_axis: float = collider.shape.height/2-collider.shape.radius
			probes = [basis*Vector3(0,0,.1-half_axis),basis*Vector3(0,0,.1+half_axis)]
		for offset in probes:
			var point: Vector3 = position+offset
			var floor_ray = PhysicsRayQueryParameters3D.create(point+Vector3.UP*.18,point+Vector3.DOWN*.18,1)
			var floor_hit = get_world_3d().direct_space_state.intersect_ray(floor_ray)
			if not floor_hit.is_empty() and floor_hit.normal.dot(Vector3.UP) >= cos(floor_max_angle):
				position.y = maxf(position.y,floor_hit.position.y-foot_offset+.001)
				if position.y+foot_offset-floor_hit.position.y < .01:
					velocity.y = 0
					grounded = true
		commit_transform()
	collision_mask = mask_before
	# Rounded capsules in a dense slope can produce a recovery displacement
	# into a second contact. Reject an invalid final volume, keeping the last
	# valid position; there is no forward teleport or crowd stacking.
	if overlaps(13):
		var actor_overlap = overlaps(12)
		blocked_by_world = blocked_by_world or overlaps(1)
		global_transform = original
		commit_transform()
		# The rotated ramp slab has a small raised lip at its crest. Try a
		# swept 12-cm step, never a height teleport or stepping on an actor.
		if allow_step and not gravity and not actor_overlap and blocked_by_world and horizontal.length_squared() > .01:
			var ceiling = move_and_collide(Vector3.UP*.12,true,safe_margin)
			if ceiling == null:
				move_and_collide(Vector3.UP*.12,false,safe_margin)
				commit_transform()
				advance(horizontal,dt,false,false)
				if Vector2(position.x,position.z).distance_to(Vector2(original.origin.x,original.origin.z)) > .001:
					physics_usec = Time.get_ticks_usec()-start
					return
				global_transform = original
				commit_transform()
		if gravity: velocity.y = 0
		else: blocked_by_enemy = blocked_by_enemy or actor_overlap
	physics_usec = Time.get_ticks_usec()-start

func sync_to(z: Dictionary) -> void:
	z.pos = Vector2(position.x,position.z)
	z.height = position.y
	z.vertical_velocity = velocity.y
	z.grounded = grounded
	z.crowd_blocked = blocked_by_enemy
	z.world_blocked = blocked_by_world

func overlaps_world() -> bool:
	return overlaps(1,.025)

func overlaps(mask: int, tolerance := .005) -> bool:
	if not overlap_queries.has(tolerance):
		var shape = collider.shape.duplicate()
		shape.radius -= tolerance
		shape.height -= tolerance*2
		var value = PhysicsShapeQueryParameters3D.new()
		value.shape = shape
		value.exclude = [get_rid(),peer_rid]
		overlap_queries[tolerance] = value
	var query: PhysicsShapeQueryParameters3D = overlap_queries[tolerance]
	query.transform = collider.global_transform
	query.collision_mask = mask
	return not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()
