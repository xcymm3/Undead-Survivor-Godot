extends ColorRect
# Hallmark · pre-emit critique: P4 H4 E4 S5 R4 V4
const BACKGROUND = """
shader_type canvas_item;
void fragment() {
 vec2 p = UV*2.0-1.0;
 float angle = atan(p.y,p.x), radius = length(p);
 float flow = sin(angle*4.0+radius*11.0-TIME*.22+sin(p.x*7.0+p.y*5.0+TIME*.12)*2.0);
 float vein = pow(max(0.0,1.0-abs(flow)),10.0);
 vec3 dark = vec3(.025,.055,.048), rust = vec3(.24,.055,.038), teal = vec3(.06,.23,.22);
 vec3 color = mix(dark,rust,smoothstep(-.7,.8,flow)*.7);
 color = mix(color,teal,vein*.85);
 color += vein*vec3(.12,.15,.12);
 color *= .5+.5*smoothstep(.05,1.2,radius);
 COLOR = vec4(color,1.0);
}
"""
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader = Shader.new()
	shader.code = BACKGROUND
	var value = ShaderMaterial.new()
	value.shader = shader
	material = value
