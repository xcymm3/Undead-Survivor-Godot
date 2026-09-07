shader_type spatial;
render_mode cull_back;
uniform int kind = 0;
varying vec4 instance_flags;
varying vec4 part_color;
void vertex() {
	instance_flags = INSTANCE_CUSTOM;
	part_color = COLOR;
	float limb = UV2.x;
	float stride = INSTANCE_CUSTOM.r;
	float lunge = INSTANCE_CUSTOM.g;
	float flags = floor(INSTANCE_CUSTOM.a + 0.1);
	bool exposed = flags >= 8.0;
	bool armor = INSTANCE_CUSTOM.b > 0.5;
	float angle = 0.0;
	if (abs(limb) >= 1.0) angle = stride * limb * 0.27;
	else if (abs(limb) > 0.0) angle = -stride * sign(limb) * 0.16;
	vec2 rel = VERTEX.yz - UV;
	VERTEX.yz = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle))) * rel + UV;
	NORMAL.yz = mat2(vec2(cos(angle),sin(angle)),vec2(-sin(angle),cos(angle))) * NORMAL.yz;
	if (abs(limb) >= 1.0) {
		VERTEX.z += stride * limb * 0.20;
		VERTEX.y += max(0.0,stride*sign(limb))*0.075;
	} else if (abs(limb) > 0.0) {
		VERTEX.z += -stride*sign(limb)*0.07+lunge*0.28;
		VERTEX.y += sin(lunge*3.14159265)*0.16;
	}
	if (UV2.y == 2.0 && exposed) { VERTEX.y -= 0.85; VERTEX.z -= 0.18; }
	if ((UV2.y == 1.0 || UV2.y == 2.0) && !armor) VERTEX = vec3(0.0,-100.0,0.0);
}
void fragment() {
	vec3 color = part_color.rgb;
	if (UV2.y == 3.0) {
		int flags = int(floor(instance_flags.a+0.1));
		int palette = flags % 4;
		bool rage = (flags % 8) >= 4;
		color = palette == 0 ? vec3(0.349,0.392,0.314) : palette == 1 ? vec3(0.424,0.345,0.353) : palette == 2 ? vec3(0.329,0.408,0.467) : vec3(0.510,0.443,0.341);
		if (kind == 3) color = vec3(0.341,0.251,0.373);
		if (kind == 4) color = vec3(0.275,0.365,0.396);
		if (kind == 5) color = rage ? vec3(0.714,0.231,0.173) : vec3(0.494,0.220,0.184);
		if (kind == 6) color = vec3(0.443,0.349,0.263);
		if (kind == 7) color = vec3(0.561,0.157,0.188);
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
}
