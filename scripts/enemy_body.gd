extends CharacterBody3D
class_name EnemyPhysicsBody
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
var seen_epoch = 0
var pose_revision = 0
var wake_anchor = Vector3.INF
var wake_heading = 0.0
var wait_revision = -1
var wait_goal = Vector2.INF
var enemy_id = -1
var blocker_a = -1
var blocker_b = -1
var blocker_revision_a = -1
var blocker_revision_b = -1
var sync_writes = 0
var query_count = 0
var published_pose = Transform3D(Basis.IDENTITY,Vector3.INF)
var shape_dirty = true
var live_collision = true
var valid_pose = false
var flat_region = Rect2()
var flat_height = 0.0
var floor_source = 0
var space: PhysicsDirectSpaceState3D
var floor_query = PhysicsRayQueryParameters3D.new()
const PROFILES = {
	"normal":{"key":"normal","radius":.4,"height":2.0,"clearance":.43},
	"giant":{"key":"giant","radius":.72,"height":3.6,"clearance":.75},
	"imp":{"key":"imp","radius":.25,"height":1.3,"clearance":.28},
	"crawler":{"key":"crawler","radius":.34,"height":1.6,"clearance":.93}}

func _ready() -> void:
	space = get_world_3d().direct_space_state
	floor_query.collision_mask = 1
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
	return PROFILES.get(kind,PROFILES.normal)

func _init(kind := "normal") -> void:
	collision_layer = 2
	collision_mask = 13 # World, resolved enemy capsules, players.
	safe_margin = .001
	max_slides = 6
	collider = CollisionShape3D.new()
	configure(kind)
	add_child(collider)

func configure(kind: String) -> void:
	shape_dirty = true
	valid_pose = false
	flat_region = Rect2()
	floor_source = 0
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
	var key: String = z.kind if z.kind in ["giant","imp","crawler"] else "normal"
	if profile_key != key: configure(z.kind)
	var pose = Vector3(z.pos.x,z.get("height",Data.enemy_ground_height(z.pos,z.map_id)),z.pos.y)
	if position != pose:
		position = pose
		valid_pose = false
	if z.kind == "crawler" and not is_equal_approx(rotation.y,z.heading):
		var old_heading = rotation.y
		rotation.y = z.heading
		commit_transform()
		if overlaps(13):
			rotation.y = old_heading
			commit_transform()
			z.heading = old_heading
	velocity.y = z.get("vertical_velocity",0.0)
	if live_collision != (z.hp > 0):
		live_collision = z.hp > 0
		collider.disabled = not live_collision
		collision_layer = 2 if live_collision else 0
		collision_mask = 13 if live_collision else 0
		if peer_rid.is_valid(): PhysicsServer3D.body_set_collision_layer(peer_rid,8 if live_collision else 0)
	commit_transform()

func commit_transform() -> void:
	var pose = global_transform
	if pose == published_pose and not shape_dirty: return
	# Enemies advance sequentially inside one authority tick. Publish each
	# transform immediately so the next sweep sees this tick's position,
	# rather than the scene tree's deferred transform from the previous tick.
	force_update_transform()
	if shape_dirty: collider.force_update_transform()
	# CollisionObject3D publishes its own RID during force_update_transform.
	# Only the separately owned peer requires an explicit server submission.
	if peer_rid.is_valid():
		PhysicsServer3D.body_set_state(peer_rid,PhysicsServer3D.BODY_STATE_TRANSFORM,global_transform)
	published_pose = global_transform
	shape_dirty = false
	sync_writes += 1

func retire() -> void:
	if not live_collision: return
	live_collision = false
	pose_revision += 1
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
	var was_grounded = grounded
	grounded = false
	if not gravity:
		blocker_a = -1
		blocker_b = -1
	velocity.x = horizontal.x
	velocity.z = horizontal.y
	var original = global_transform
	var end_point = Vector2(position.x,position.z)+horizontal*dt
	var flat_support = not gravity and was_grounded and velocity.y <= 0 and flat_region.has_point(Vector2(position.x,position.z)) and flat_region.has_point(end_point) and absf(position.y-flat_height+(.02 if profile_key == "crawler" else 0.0)) < .01
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
		query_count += 1
		var hit = move_and_collide(motion,false,margin)
		commit_transform()
		if hit == null: break
		var normal = hit.get_normal()
		var actor = hit.get_collider()
		if actor is CharacterBody3D:
			if actor is EnemyPhysicsBody:
				if blocker_a < 0:
					blocker_a = actor.enemy_id
					blocker_revision_a = actor.pose_revision
				elif blocker_a != actor.enemy_id:
					blocker_b = actor.enemy_id
					blocker_revision_b = actor.pose_revision
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
	flat_support = flat_support and absf(position.y-original.origin.y) < .005 and flat_region.has_point(Vector2(position.x,position.z))
	if flat_support:
		grounded = true
		velocity.y = 0
	elif velocity.y <= 0:
		# Snap against scenery only, never onto another enemy's head.
		var mask = collision_mask
		collision_mask = 1
		var support = move_and_collide(Vector3.DOWN*.12,true,safe_margin)
		query_count += 1
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
			floor_query.from = point+Vector3.UP*.18
			floor_query.to = point+Vector3.DOWN*.18
			query_count += 1
			var floor_hit = space.intersect_ray(floor_query)
			if not floor_hit.is_empty() and floor_hit.normal.dot(Vector3.UP) >= cos(floor_max_angle):
				cache_flat_support(floor_hit)
				position.y = maxf(position.y,floor_hit.position.y-foot_offset+.001)
				if position.y+foot_offset-floor_hit.position.y < .01:
					velocity.y = 0
					grounded = true
		commit_transform()
	collision_mask = mask_before
	# Rounded capsules in a dense slope can produce a recovery displacement
	# into a second contact. Reject an invalid final volume, keeping the last
	# valid position; there is no forward teleport or crowd stacking.
	var unchanged = global_transform == original and valid_pose
	if not unchanged and overlaps(13):
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
	else: valid_pose = true
	physics_usec = Time.get_ticks_usec()-start

func cache_flat_support(hit: Dictionary) -> void:
	# Cache only an actual immutable horizontal box support, inside its full
	# footprint. Slopes, crests, edges and unsupported motion still query.
	if hit.normal.y < .9999: return
	var actor = hit.collider
	if not actor is StaticBody3D or actor.get_instance_id() == floor_source: return
	for child in actor.get_children():
		if not child is CollisionShape3D or not child.shape is BoxShape3D: continue
		var pose: Transform3D = child.global_transform
		if not pose.basis.is_equal_approx(Basis.IDENTITY): continue
		var size: Vector3 = child.shape.size
		flat_region = Rect2(Vector2(pose.origin.x-size.x/2,pose.origin.z-size.z/2),Vector2(size.x,size.z)).grow(-PROFILES[profile_key].clearance-.03)
		flat_height = hit.position.y
		floor_source = actor.get_instance_id()
		return

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
	query_count += 1
	return not space.intersect_shape(query,1).is_empty()
