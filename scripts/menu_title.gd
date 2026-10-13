extends TextureRect
# Hallmark · pre-emit critique: P4 H5 E4 S5 R4 V4
## Native font artwork with extruded edges, projected away at the top.
var display_font: Font
class Ink extends Control:
	const IVORY = Color("aaa99f")
	const EDGE = Color("ddd9c9")
	const SIDE = Color("494943")
	const OUTLINE = Color("101619")
	var display_font: Font
	const GLYPHS = {
		"U":[17,17,17,17,17,17,14], "N":[17,25,25,21,19,19,17],
		"D":[30,17,17,17,17,17,30], "E":[31,16,16,30,16,16,31],
		"A":[14,17,17,31,17,17,17], "S":[15,16,16,14,1,1,30],
		"R":[30,17,17,30,20,18,17], "V":[17,17,17,17,17,10,4],
		"I":[31,4,4,4,4,4,31], "O":[14,17,17,17,17,17,14]}
	func stamp(word: String, height: float, baseline: float, offset: Vector2, color: Color, margin: float) -> void:
		var cell = height/7.0
		var origin = Vector2((1200-(word.length()*6-1)*cell)/2,baseline-height)+offset
		for index in word.length():
			var rows: Array = GLYPHS[word[index]]
			for y in 7:
				for x in 5:
					if int(rows[y]) & (1 << (4-x)):
						draw_rect(Rect2(origin+Vector2(index*6+x,y)*cell-Vector2.ONE*margin,Vector2.ONE*(cell+margin*2)),color)
	func _draw() -> void:
		for row in [["UNDEAD",96,148],["SURVIVOR",124,316]]:
			for depth in range(18,-1,-1):
				stamp(row[0],row[1],row[2],Vector2(depth*.45,depth),OUTLINE if depth == 18 else SIDE,2)
			stamp(row[0],row[1],row[2],Vector2.ZERO,EDGE,1)
			stamp(row[0],row[1],row[2],Vector2.ZERO,IVORY,0)
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
 float grain = fract(sin(dot(floor(uv*vec2(1200.0,370.0)),vec2(12.9898,78.233)))*43758.5453);
 float tile = fract(sin(dot(floor(uv*vec2(220.0,90.0)),vec2(41.13,27.17)))*15437.4);
 float chips = step(.95,tile)*.23;
 ink.rgb *= mix(1.05,.83,uv.y)*(0.85+grain*.23-chips);
 COLOR = (uv.x < 0.0 || uv.x > 1.0) ? vec4(0.0) : ink;
}
"""
	var effect = ShaderMaterial.new()
	effect.shader = shader
	material = effect
