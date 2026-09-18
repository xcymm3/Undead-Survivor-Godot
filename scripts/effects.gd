extends Node3D
var particles: Array = []
var multi: MultiMesh
var material: StandardMaterial3D
var flame_particles: Array = []
var flame_mesh: MultiMesh
var fire_material: ShaderMaterial
var flame_light: OmniLight3D
var collision_query: Callable
var flame_clock = 0.0
var flame_light_time = 0.0
var flame_light_strength = 1.0
const FLAME_LIMIT = 640

func clear() -> void:
	particles.clear()
	flame_particles.clear()
	flame_mesh.visible_instance_count = 0
	flame_light_time = 0
	step(0)

func _ready() -> void:
	multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = BoxMesh.new()
	multi.instance_count = 384
	multi.visible_instance_count = 0
	var view = MultiMeshInstance3D.new()
	view.multimesh = multi
	view.custom_aabb = AABB(Vector3(-90,-10,-150),Vector3(180,50,300))
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .85
	view.material_override = material
	add_child(view)
	flame_mesh = MultiMesh.new()
	flame_mesh.transform_format = MultiMesh.TRANSFORM_3D
	flame_mesh.use_colors = true
	var shape = SphereMesh.new()
	shape.radial_segments = 8
	shape.rings = 4
	flame_mesh.mesh = shape
	flame_mesh.instance_count = FLAME_LIMIT
	flame_mesh.visible_instance_count = 0
	var plume = MultiMeshInstance3D.new()
	plume.multimesh = flame_mesh
	plume.custom_aabb = view.custom_aabb
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fire_material = ShaderMaterial.new()
	fire_material.shader = preload("res://scripts/flame.gdshader")
	plume.material_override = fire_material
	add_child(plume)
	flame_light = OmniLight3D.new()
	flame_light.light_color = Color("ff993d")
	flame_light.omni_range = 5.0
	flame_light.shadow_enabled = false
	flame_light.light_energy = 0
	flame_light.visible = false
	add_child(flame_light)

func burst(pos: Vector3, armor := false, broken := false) -> void:
	for i in ([4,8,12][int(Data.settings.effects)] if broken else [2,4,6][int(Data.settings.effects)]):
		if particles.size() >= [96,192,384][int(Data.settings.effects)]: particles.pop_front()
		particles.append({"pos":pos,"velocity":Vector3(randf_range(-2,2),randf_range(1,3),randf_range(-2,2)),"life":randf_range(.25,.65),"color":Color("a7b3a2") if armor else Color("8a342c"),"size":.08 if broken else .035})

func flame(from: Vector3, to: Vector3) -> void:
	var reach = from.distance_to(to)
	# A blocked cosmetic barrel falls back to the camera-side authority origin.
	# Do not fill that tiny camera/wall gap with translucent fire or a hot light.
	if reach < .5:
		flame_light_time = 0
		return
	var dir = (to-from)/reach
	var right = dir.cross(Vector3.UP).normalized()
	if right.length_squared() < .01: right = Vector3.RIGHT
	var up = right.cross(dir).normalized()
	# Each 80 ms shot emits a spatially continuous packet, not four isolated beads.
	# Particles remain in world space when the player turns or stops firing.
	for i in 20:
		var delay = float(i)/20*.08
		var angle = randf()*TAU
		var drift = right*cos(angle)+up*sin(angle)
		var start = from
		if flame_particles.size() >= FLAME_LIMIT: flame_particles.pop_front()
		flame_particles.append({"pos":start,"origin":from,"dir":dir,"drift":drift,
			"age":-delay,"life":.76,"travel":0.0,"reach":minf(reach,12.0),
			"seed":randf()*TAU,"smoke":i%7 == 0})
	flame_light.position = from+dir*minf(.5,reach*.5)
	flame_light_strength = clampf(pow(reach/2.0,2),.02,1.0)
	flame_light_time = .12

func step_flame(dt: float) -> void:
	flame_clock += dt
	fire_material.set_shader_parameter("flame_time",flame_clock)
	flame_light_time = maxf(0,flame_light_time-dt)
	# An inactive light must not occupy a Compatibility per-object light slot.
	flame_light.visible = flame_light_time > 0
	flame_light.light_energy = flame_light_strength*minf(1,flame_light_time/.08)*(1.2+.18*sin(flame_clock*31))
	for p in flame_particles:
		var prior_age: float = p.age
		p.age += dt
		if p.age < 0: continue
		var active_dt: float = minf(dt,p.age) if prior_age < 0 else dt
		var speed = lerpf(18.0,12.0,clampf(p.age/.76,0,1))
		p.travel += speed*active_dt
		var width = .045+p.travel*.045
		var target: Vector3 = p.origin+p.dir*p.travel+p.drift*width*sin(p.age*13+p.seed)
		# Only the cooling tail rises; the pressurized core keeps forward momentum.
		target.y += maxf(0,p.age-.3)*maxf(0,p.age-.3)*1.1
		var wall: Dictionary = collision_query.call(p.pos,target) if collision_query.is_valid() else {}
		if not wall.is_empty() or p.travel >= p.reach: p.age = p.life
		else: p.pos = target
	flame_particles = flame_particles.filter(func(p): return p.age < p.life)
	flame_mesh.visible_instance_count = flame_particles.size()
	for i in flame_particles.size():
		var p: Dictionary = flame_particles[i]
		var t: float = maxf(0,p.age/p.life)
		var radius: float = .045+p.travel*.04
		var color = Color("fff0ab").lerp(Color("ffbc35"),minf(1,t*3))
		color = color.lerp(Color("e74712"),clampf((t-.3)/.5,0,1))
		color.a = .38*(1-smoothstep(.58,1.0,t)) if p.age >= 0 else 0.0
		if p.smoke and t > .62:
			color = Color(.19,.17,.15,.16*(1-smoothstep(.7,1.0,t)))
			radius *= 1.35
		var basis = Basis(Quaternion(Vector3.UP,p.dir))
		basis = basis*Basis.from_scale(Vector3(radius*2,radius*4.0,radius*2))
		# Let the renderer encode instance colors/transforms for its backend.
		# Reusing a raw float buffer after pool resets corrupts Web GL instances.
		flame_mesh.set_instance_transform(i,Transform3D(basis,p.pos))
		flame_mesh.set_instance_color(i,color)

func tracer(from: Vector3, to: Vector3, shell := true) -> void:
	if particles.size() > 380: particles = particles.slice(-370)
	var length = from.distance_to(to)
	if length > .001:
		particles.append({"pos":(from+to)*.5,"velocity":Vector3.ZERO,"life":.045,"color":Color("ffe6ad"),"size":.015,"scale":Vector3(.015,.015,length),"basis":Basis(Quaternion(Vector3.BACK,(to-from).normalized())),"gravity":false})
	if shell:
		var right = (to-from).normalized().cross(Vector3.UP)
		particles.append({"pos":from,"velocity":right*1.8+Vector3.UP*1.2,"life":.85,"color":Color("bb9751"),"size":.03,"scale":Vector3(.03,.025,.085)})

func shotgun(from: Vector3, ends: Array) -> void:
	# Brief moving streaks follow actual pellet hits instead of a single long laser beam.
	if particles.size() > 360: particles = particles.slice(-350)
	for end: Vector3 in ends:
		var distance = from.distance_to(end)
		if distance <= .001: continue
		var direction = (end-from).normalized()
		var streak = minf(.35,distance)
		particles.append({"pos":from+direction*streak*.5,"velocity":direction*350,
			"life":minf(.07,(distance-streak*.5)/350),"color":Color("b9b5a0"),"size":.004,
			"scale":Vector3(.004,.004,streak),"basis":Basis(Quaternion(Vector3.BACK,direction)),"gravity":false})
	# One cartridge per shot, regardless of pellet count.
	if not ends.is_empty():
		var right = (ends[0]-from).normalized().cross(Vector3.UP)
		particles.append({"pos":from,"velocity":right*1.8+Vector3.UP*1.2,"life":.85,
			"color":Color("ad4833"),"size":.035,"scale":Vector3(.035,.035,.08)})

func step(dt: float) -> void:
	step_flame(dt)
	for p in particles:
		p.life -= dt
		p.pos += p.velocity*dt
		if p.get("gravity",true): p.velocity.y -= 7*dt
	particles = particles.filter(func(p): return p.life > 0)
	multi.visible_instance_count = particles.size()
	for i in particles.size():
		var p: Dictionary = particles[i]
		multi.set_instance_transform(i,particle_transform(p))
		multi.set_instance_color(i,p.color)

static func particle_transform(p: Dictionary) -> Transform3D:
	return Transform3D(p.get("basis",Basis.IDENTITY) * Basis.from_scale(p.get("scale",Vector3.ONE*p.size)),p.pos)

func explosion(pos: Vector3) -> void:
	for i in 48:
		if particles.size() >= 384: particles.pop_front()
		var direction = Vector3(randf_range(-1,1),randf_range(-.2,1),randf_range(-1,1)).normalized()
		particles.append({"pos":pos,"velocity":direction*randf_range(3,12),"life":randf_range(.35,.8),"color":Color("f0b24b") if i < 20 else Color("55534a"),"size":.15 if i < 20 else .3})
