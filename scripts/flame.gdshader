shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
uniform float flame_time = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

void fragment() {
	// Soft faceted volumes retain the game's low-poly style without opaque cubes.
	float edge = pow(clamp(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.0, 1.0), 1.2);
	vec2 flow = UV*vec2(9.0,5.0)-vec2(0.0,flame_time*5.0);
	float density = noise(flow)*0.65+noise(flow*2.1)*0.35;
	ALBEDO = COLOR.rgb*vec3(1.0,0.45+0.55*density,0.25+0.75*density);
	ALPHA = COLOR.a * edge * smoothstep(0.18,0.7,density);
}
