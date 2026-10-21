extends Node3D
## A local, deterministic flowing shell: no world lights or exposure changes.
const FLOW_PERIOD = 16.0
var finish: ShaderMaterial

func setup(blade_mesh: Mesh) -> void:
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float flow_clock = 0.0;
uniform float halo = 0.0;
varying vec3 blade_point;
void vertex() { blade_point = VERTEX; }
// Periodic spatial noise, advected continuously. Wrapping the lattice preserves
// both value and slope; no fade-in/out envelope or animation restart is involved.
float flow_hash(vec2 cell) {
 cell = mod(cell,64.0);
 return fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
}
float flow_noise(vec2 point) {
 vec2 cell = floor(point);
 vec2 f = fract(point);
 vec2 u = f*f*f*(f*(f*6.0-15.0)+10.0);
 return mix(mix(flow_hash(cell),flow_hash(cell+vec2(1.0,0.0)),u.x),
            mix(flow_hash(cell+vec2(0.0,1.0)),flow_hash(cell+vec2(1.0,1.0)),u.x),u.y);
}
void fragment() {
 float across = blade_point.x*32.0 + blade_point.z*17.0;
 float stream = flow_noise(vec2(blade_point.y*6.0-flow_clock*4.0,across));
 float detail = flow_noise(vec2(blade_point.y*12.0-flow_clock*8.0,across*1.7+19.4));
 float silk = smoothstep(0.30,0.85,stream*0.72+detail*0.28);
 float glint = pow(smoothstep(0.55,0.92,detail),2.0);
 float end_fade = smoothstep(0.02,0.15,blade_point.y);
 ALBEDO = mix(vec3(0.015,0.23,0.95),vec3(0.30,0.84,1.0),silk);
 ALPHA = end_fade * mix(0.34+silk*0.36+glint*0.14,0.06+silk*0.09,halo);
}
"""
	finish = ShaderMaterial.new()
	finish.shader = shader
	for halo in [false,true]:
		var shell = MeshInstance3D.new()
		shell.name = "BlueHalo" if halo else "FlowingBlueEdge"
		shell.mesh = blade_mesh
		shell.layers = 2
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.scale = Vector3(2.8,1.0,2.8) if halo else Vector3(1.06,1.001,1.06)
		var material = finish.duplicate() as ShaderMaterial if halo else finish
		material.set_shader_parameter("halo",1.0 if halo else 0.0)
		shell.material_override = material
		add_child(shell)
	hide()

func sync(active: bool, clock: float) -> void:
	visible = active
	if not active: return
	for shell in get_children(): shell.material_override.set_shader_parameter("flow_clock",clock)
