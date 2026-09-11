shader_type spatial;
render_mode cull_back;
uniform vec4 stone_color : source_color = vec4(0.70,0.52,0.32,1.0);
varying vec3 local_world;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
void vertex() { local_world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec3 p = local_world;
	float grain = hash(floor(p*42.0));
	float course = floor(p.y/0.48);
	float vertical_joint = step(0.965,fract((p.x+p.z)/1.35+mod(course,2.0)*0.5));
	float horizontal_joint = step(0.95,fract(p.y/0.48));
	float mortar = max(vertical_joint,horizontal_joint)*0.15;
	float weather = hash(floor(p/0.35))*0.06;
	ALBEDO = stone_color.rgb*(0.93+grain*0.1-weather-mortar);
	ROUGHNESS = 0.94;
}
