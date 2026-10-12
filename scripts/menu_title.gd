extends TextureRect
# Hallmark · pre-emit critique: P4 H5 E4 S5 R4 V4
## Native font artwork with extruded edges, projected away at the top.
var display_font: Font
class Ink extends Control:
	const IVORY = Color("f8edc3")
	const EDGE = Color("d8a65a")
	const SIDE = Color("72512e")
	const OUTLINE = Color("101713")
	var display_font: Font
	func _draw() -> void:
		for row in [["UNDEAD",112,148],["SURVIVOR",144,316]]:
			var word: String = row[0]
			var height: int = row[1]
			var origin = Vector2((1200-display_font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,height).x)/2,row[2])
			for depth in range(18,-1,-1):
				var offset = Vector2(depth*.45,depth)
				display_font.draw_string_outline(get_canvas_item(),origin+offset,word,HORIZONTAL_ALIGNMENT_LEFT,-1,height,8,OUTLINE if depth == 18 else SIDE)
			display_font.draw_string_outline(get_canvas_item(),origin,word,HORIZONTAL_ALIGNMENT_LEFT,-1,height,4,EDGE)
			display_font.draw_string(get_canvas_item(),origin,word,HORIZONTAL_ALIGNMENT_LEFT,-1,height,IVORY)
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	var viewport = SubViewport.new()
	viewport.size = Vector2i(1200,370)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var ink = Ink.new()
	ink.display_font = display_font
	viewport.add_child(ink)
	texture = viewport.get_texture()
	var shader = Shader.new()
	shader.code = """
shader_type canvas_item;
void fragment() {
 vec2 uv = UV;
 float width = mix(.68,1.0,uv.y);
 uv.x = (uv.x-.5)/width+.5;
 vec4 ink = texture(TEXTURE,uv);
 ink.rgb *= mix(1.05,.83,uv.y);
 COLOR = (uv.x < 0.0 || uv.x > 1.0) ? vec4(0.0) : ink;
}
"""
	var effect = ShaderMaterial.new()
	effect.shader = shader
	material = effect
