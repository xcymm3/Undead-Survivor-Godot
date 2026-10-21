extends Node3D
## A local, deterministic flowing shell: no world lights or exposure changes.
var finish: ShaderMaterial

func setup(blade_mesh: Mesh) -> void:
	var shader = Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float flow_clock = 0.0;
uniform float halo = 0.0;
varying vec3 blade_point;
void vertex() { blade_point = VERTEX; }
void fragment() {
 float travel = blade_point.y * 11.0 - flow_clock * 8.0;
 float band = pow(0.5 + 0.5 * sin(travel), 7.0);
 float filament = pow(0.5 + 0.5 * sin(blade_point.y * 29.0 + flow_clock * 12.0), 16.0);
 float end_fade = smoothstep(0.02, 0.15, blade_point.y);
 ALBEDO = mix(vec3(0.015,0.25,1.0),vec3(0.48,0.94,1.0),band);
 ALPHA = end_fade * mix(0.30 + band*0.55 + filament*0.15,0.055 + band*0.08,halo);
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
