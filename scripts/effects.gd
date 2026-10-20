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
const TRACER_HOLD = .04
const TRACER_RETRACT = .06
const TRACER_LIMIT = 192
const FLASH_LIMIT = 64
var tracers: Array = []
var flashes: Array = []
var gun_mesh: MultiMesh

func clear() -> void:
	particles.clear()
	tracers.clear()
	flashes.clear()
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
	gun_mesh = MultiMesh.new()
	gun_mesh.transform_format = MultiMesh.TRANSFORM_3D
	gun_mesh.use_colors = true
	gun_mesh.mesh = BoxMesh.new()
	gun_mesh.mesh.size = Vector3.ONE
	gun_mesh.instance_count = TRACER_LIMIT+FLASH_LIMIT*3
	gun_mesh.visible_instance_count = 0
	var gun_view = MultiMeshInstance3D.new()
	gun_view.multimesh = gun_mesh
	gun_view.custom_aabb = AABB(Vector3(-260,-80,-260),Vector3(520,200,520))
	gun_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gun_material = StandardMaterial3D.new()
	gun_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gun_material.vertex_color_use_as_albedo = true
	gun_view.material_override = gun_material
	add_child(gun_view)
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

func eject_shell(from: Vector3, direction: Vector3, shotgun := false) -> void:
	if particles.size() >= 384: particles.pop_front()
	var right = direction.normalized().cross(Vector3.UP)
	if right.length_squared() < .01: right = Vector3.RIGHT
	particles.append({"kind":"casing","pos":from,"velocity":right*1.8+Vector3.UP*1.2,"life":.85,
		"basis":Basis.IDENTITY,"spin":Vector3(9,13,5),
		"color":Color("ad4833") if shotgun else Color("bb9751"),"size":.03,
		"scale":Vector3(.035,.035,.08) if shotgun else Vector3(.03,.025,.085)})

func gunshot(from: Vector3, to: Vector3, pellet_ends: Array = [], surface_hits: Array = [], shotgun := false, eject := true, muzzle_source := Callable()) -> void:
	var direction = (to-from).normalized()
	if direction.length_squared() < .01: direction = Vector3.FORWARD
	if from.distance_to(to) >= .2:
		if flashes.size() >= FLASH_LIMIT: flashes.pop_front()
		flashes.append({"pos":from+direction*.06,"direction":direction,"age":0.0,"muzzle_source":muzzle_source,"target":to})
	for endpoint in ([to] if pellet_ends.is_empty() else pellet_ends):
		if from.distance_to(endpoint) < .01: continue
		# Cosmetic muzzle positions also respect geometry, independently of damage.
		var wall: Dictionary = collision_query.call(from,endpoint) if collision_query.is_valid() else {}
		var clipped: Vector3 = wall.position if not wall.is_empty() else endpoint
		if from.distance_to(clipped) < .01: continue
		if tracers.size() >= TRACER_LIMIT: tracers.pop_front()
		tracers.append({"from":from,"to":clipped,"target":clipped,"age":0.0,"muzzle_source":muzzle_source})
	if eject:
		var right = direction.cross(Vector3.UP).normalized()
		eject_shell(from-direction*.16+right*.04,direction,shotgun)
	for hit in surface_hits: surface_impact(hit.position,hit.normal)
	update_gun_visuals()

func surface_impact(pos: Vector3, normal: Vector3) -> void:
	for i in [3,5,7][int(Data.settings.effects)]:
		if particles.size() >= 384: particles.pop_front()
		var scatter = Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))
		var direction = (normal+scatter*.65).normalized()
		particles.append({"kind":"surface","pos":pos+normal*.015,"velocity":direction*randf_range(.8,2.4),"life":randf_range(.12,.28),"color":Color("ffe4a1") if i < 2 else Color("9a9485"),"size":.025 if i < 2 else .045})

static func tracer_start(tracer: Dictionary) -> Vector3:
	var progress = clampf((float(tracer.age)-TRACER_HOLD)/TRACER_RETRACT,0,1)
	return tracer.from.lerp(tracer.to,progress)

static func tracer_transform(tracer: Dictionary) -> Transform3D:
	var start = tracer_start(tracer)
	var delta: Vector3 = tracer.to-start
	var basis = Basis(Quaternion(Vector3.UP,delta.normalized()))*Basis.from_scale(Vector3(.014,delta.length(),.014))
	return Transform3D(basis,(start+tracer.to)*.5)

func update_gun_visuals() -> void:
	var index = 0
	for tracer in tracers:
		var source: Callable = tracer.get("muzzle_source",Callable())
		if tracer.age <= TRACER_HOLD and source.is_valid():
			tracer.from = source.call()
			var wall: Dictionary = collision_query.call(tracer.from,tracer.target) if collision_query.is_valid() else {}
			tracer.to = wall.position if not wall.is_empty() else tracer.target
		var start = tracer_start(tracer)
		var delta: Vector3 = tracer.to-start
		var length = delta.length()
		if length < .001: continue
		gun_mesh.set_instance_transform(index,tracer_transform(tracer))
		gun_mesh.set_instance_color(index,Color("ffe4a1"))
		index += 1
	for flash in flashes:
		var source: Callable = flash.get("muzzle_source",Callable())
		if source.is_valid():
			var origin: Vector3 = source.call()
			flash.direction = (flash.target-origin).normalized()
			flash.pos = origin+flash.direction*.06
		var basis = Basis(Quaternion(Vector3.FORWARD,flash.direction))
		var scale = 1.0-float(flash.age)/.035
		for size in [Vector3(.07,.07,.25),Vector3(.27,.025,.07),Vector3(.025,.22,.07)]:
			gun_mesh.set_instance_transform(index,Transform3D(basis*Basis.from_scale(size*maxf(.1,scale)),flash.pos))
			gun_mesh.set_instance_color(index,Color("fff0bc") if index%3 == 0 else Color("ffb447"))
			index += 1
	gun_mesh.visible_instance_count = index

func step(dt: float) -> void:
	step_flame(dt)
	for tracer in tracers: tracer.age += dt
	for flash in flashes: flash.age += dt
	tracers = tracers.filter(func(tracer): return tracer.age < TRACER_HOLD+TRACER_RETRACT)
	flashes = flashes.filter(func(flash): return flash.age < .035)
	update_gun_visuals()
	for p in particles:
		p.life -= dt
		p.pos += p.velocity*dt
		if p.get("gravity",true): p.velocity.y -= 7*dt
		if p.has("spin"):
			var spin: Vector3 = p.spin
			p.basis = (Basis.from_euler(spin*dt)*p.basis).orthonormalized()
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
