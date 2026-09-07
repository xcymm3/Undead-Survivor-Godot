extends Node3D
var particles: Array = []
var multi: MultiMesh
var material: StandardMaterial3D

func _ready() -> void:
	multi = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = BoxMesh.new()
	multi.instance_count = 384
	multi.visible_instance_count = 0
	var view = MultiMeshInstance3D.new()
	view.multimesh = multi
	view.custom_aabb = AABB(Vector3(-30,-3,-55),Vector3(60,20,75))
	material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .85
	view.material_override = material
	add_child(view)

func burst(pos: Vector3, armor := false, broken := false) -> void:
	for i in ([4,8,12][int(Data.settings.effects)] if broken else [2,4,6][int(Data.settings.effects)]):
		if particles.size() >= [96,192,384][int(Data.settings.effects)]: particles.pop_front()
		particles.append({"pos":pos,"velocity":Vector3(randf_range(-2,2),randf_range(1,3),randf_range(-2,2)),"life":randf_range(.25,.65),"color":Color("a7b3a2") if armor else Color("8a342c"),"size":.08 if broken else .035})

func flame(from: Vector3, to: Vector3) -> void:
	var dir = (to-from).normalized()
	for i in 4:
		if particles.size() >= 384: particles.pop_front()
		particles.append({"pos":from+dir*i*.3,"velocity":dir*14+Vector3(randf_range(-.7,.7),randf_range(-.4,.4),randf_range(-.7,.7)),"life":.6,"color":Color("e8a343"),"size":.13})

func tracer(from: Vector3, to: Vector3, shell := true) -> void:
	if particles.size() > 380: particles = particles.slice(-370)
	var length = from.distance_to(to)
	if length > .001:
		particles.append({"pos":(from+to)*.5,"velocity":Vector3.ZERO,"life":.045,"color":Color("ffe6ad"),"size":.015,"scale":Vector3(.015,.015,length),"basis":Basis(Quaternion(Vector3.BACK,(to-from).normalized())),"gravity":false})
	if shell:
		var right = (to-from).normalized().cross(Vector3.UP)
		particles.append({"pos":from,"velocity":right*1.8+Vector3.UP*1.2,"life":.85,"color":Color("bb9751"),"size":.03,"scale":Vector3(.03,.025,.085)})

func step(dt: float) -> void:
	for p in particles:
		p.life -= dt
		p.pos += p.velocity*dt
		if p.get("gravity",true): p.velocity.y -= 7*dt
	particles = particles.filter(func(p): return p.life > 0)
	multi.visible_instance_count = particles.size()
	for i in particles.size():
		var p: Dictionary = particles[i]
		multi.set_instance_transform(i,Transform3D(p.get("basis",Basis.IDENTITY).scaled(p.get("scale",Vector3.ONE*p.size)),p.pos))
		multi.set_instance_color(i,p.color)
