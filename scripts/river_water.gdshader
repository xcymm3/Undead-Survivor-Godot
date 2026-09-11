shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

void fragment() {
	float flow = UV.x - TIME * 0.45;
	float wave = sin(flow * 7.0 + sin(UV.y * 19.0 + TIME * 0.6));
	float ripple = smoothstep(0.86, 1.0, wave);
	float shore = smoothstep(0.88, 1.0, abs(UV.y * 2.0 - 1.0));
	ALBEDO = mix(vec3(0.10, 0.28, 0.27), vec3(0.32, 0.48, 0.40), UV.y);
	ALBEDO += vec3(0.12, 0.17, 0.15) * ripple * 0.45;
	ALBEDO = mix(ALBEDO, vec3(0.62, 0.70, 0.58), shore * (0.25 + ripple * 0.35));
	ROUGHNESS = 0.28;
	SPECULAR = 0.45;
	ALPHA = 0.57 + shore * 0.12;
}
