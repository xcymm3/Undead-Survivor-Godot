extends MeshInstance3D
## Camera-space afterimage of the actual blade, with a bounded 180 ms history.
const LIFE = .18
const MAX_SAMPLES = 24
var history: Array[Dictionary] = []
var clock = 0.0

func _init() -> void:
	name = "BlueBladeAfterimage"
	layers = 2
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
varying vec4 trail_color;
void vertex() { trail_color = COLOR; }
void fragment() {
 ALBEDO = trail_color.rgb * 3.0;
 ALPHA = trail_color.a;
}
"""
	var finish = ShaderMaterial.new()
	finish.shader = shader
	material_override = finish
	hide()

func clear() -> void:
	history.clear()
	clock = 0.0
	mesh = null
	hide()

func sample(p: Dictionary, dt: float, blade_pose: Transform3D, duration: float) -> void:
	var ultimate = preload("res://scripts/ultimate.gd")
	if not ultimate.active(p) or p.get("hp",0) <= 0 or p.get("ultimate_age",0.0) < ultimate.DRAW_TIME:
		clear()
		return
	clock += maxf(0,dt)
	while not history.is_empty() and clock-float(history[0].time) > LIFE: history.pop_front()
	var phase = 1.0-float(p.get("fire_anim",0.0))/maxf(.001,duration)
	var cutting = p.get("fire_anim",0.0) > 0 and phase >= .16 and phase <= .78
	var shot = int(p.get("shots",0))
	if cutting and dt > 0:
		var tip = preload("res://scripts/long_blade.gd").TIP_POINT
		history.append({"time":clock,"shot":shot,"base":blade_pose*Vector3(0,.26,0),"tip":blade_pose*tip})
		if history.size() > MAX_SAMPLES: history.pop_front()
	rebuild()

static func vertex(surface: SurfaceTool, point: Vector3, color: Color) -> void:
	surface.set_color(color)
	surface.add_vertex(point)

static func quad(surface: SurfaceTool, points: Array, colors: Array) -> void:
	for index in [0,1,2,0,2,3]: vertex(surface,points[index],colors[index])

func fade(item: Dictionary) -> float:
	return pow(clampf(1.0-(clock-float(item.time))/LIFE,0,1),1.5)

func rebuild() -> void:
	if history.size() < 2:
		mesh = null
		hide()
		return
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles = false
	for i in range(1,history.size()):
		var a = history[i-1]
		var b = history[i]
		# Never connect separate swings or draw a bright idle blob.
		if a.shot != b.shot or a.tip.distance_squared_to(b.tip) < .00001: continue
		triangles = true
		var fa = fade(a)
		var fb = fade(b)
		for band in [[.0,.65,.015,.18],[.65,.96,.18,.50],[.96,1.0,.50,.85],[1.0,1.035,.22,.0]]:
			quad(surface,[a.base.lerp(a.tip,band[0]),b.base.lerp(b.tip,band[0]),b.base.lerp(b.tip,band[1]),a.base.lerp(a.tip,band[1])],
				[Color(.03,.38,1,band[2]*fa),Color(.03,.38,1,band[2]*fb),Color(.36,.88,1,band[3]*fb),Color(.36,.88,1,band[3]*fa)])
		if i%2 == 0:
			var point: Vector3 = a.base.lerp(a.tip,.72+.24*sin(float(i)*2.4))
			point += Vector3(sin(float(i)*3.1),cos(float(i)*2.7),0)*.025*(1.0-fa)
			var size = .010+.012*fa
			var color = Color(.62,.96,1,.8*fa)
			for axes in [Vector2(size*2.6,size*.32),Vector2(size*.32,size*2.6)]:
				quad(surface,[point+Vector3(-axes.x,0,0),point+Vector3(0,axes.y,0),point+Vector3(axes.x,0,0),point+Vector3(0,-axes.y,0)], [color,color,color,color])
	if triangles:
		mesh = surface.commit()
		show()
	else:
		mesh = null
		hide()
