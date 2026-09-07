shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size = 3.0;
void fragment() {
	vec2 resolution = vec2(textureSize(screen_texture, 0));
	vec2 uv = (floor(SCREEN_UV * resolution / pixel_size) + 0.5) * pixel_size / resolution;
	COLOR = texture(screen_texture, uv);
}
