extends RefCounted
## Shared engraved coin face and cut diamond icons, generated once.
static var coin_texture: Texture2D
static var diamond_texture: Texture2D

static func coin() -> Texture2D:
	if coin_texture: return coin_texture
	var image = Image.create(128,128,false,Image.FORMAT_RGBA8)
	var glyph = ["0011100","0101010","0101000","0011100","0001010","0101010","0011100"]
	for y in 128:
		for x in 128:
			var p = Vector2(x-63.5,y-63.5)
			var r = p.length()
			if r > 62: continue
			var gold = Color("d89a25").lerp(Color("ffe3a0"),clampf(.55-p.y/155-p.x/310,0,1))
			if r > 55: gold = Color("8f5817") if r > 60 else Color("ffe2a0")
			elif r > 50: gold = Color("995c14") if r < 52 else Color("f6ce65")
			if r > 56 and fmod(atan2(p.y,p.x)+PI,TAU/40) < .025: gold = Color("a6691c")
			var gx = floori((x-39)/7.0)
			var gy = floori((y-39)/7.0)
			if x >= 39 and y >= 39 and gx >= 0 and gx < 7 and gy >= 0 and gy < 7 and glyph[gy][gx] == "1": gold = Color("8c5417")
			image.set_pixel(x,y,gold)
	coin_texture = ImageTexture.create_from_image(image)
	return coin_texture

static func diamond() -> Texture2D:
	if diamond_texture: return diamond_texture
	var image = Image.create(96,96,false,Image.FORMAT_RGBA8)
	for y in 96:
		for x in 96:
			var p = Vector2((x-47.5)/43.0,(y-43.0)/43.0)
			if p.y < -.6 or p.y > 1 or absf(p.x) > (1.0 if p.y < 0 else 1-p.y): continue
			if p.y < 0 and absf(p.x) > 1.0+(p.y+.2)*.7: continue
			var color = Color("64d2ef")
			if p.y < 0: color = Color("c9f5ff") if p.x < 0 else Color("90e6fa")
			elif p.x < -p.y*.35: color = Color("30a3d0")
			elif p.x > p.y*.35: color = Color("4bbbdc")
			else: color = Color("a4edff")
			image.set_pixel(x,y,color)
	diamond_texture = ImageTexture.create_from_image(image)
	return diamond_texture

static func mesh() -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments = 48
	for i in segments:
		var a = i*TAU/segments
		var b = (i+1)*TAU/segments
		for side in [-1.0,1.0]:
			var ring = [Vector3.ZERO,Vector3(cos(a),0,sin(a))*.18,Vector3(cos(b),0,sin(b))*.18]
			if side > 0: ring.reverse()
			for vertex in ring:
				surface.set_normal(Vector3.UP*side)
				surface.set_uv(Vector2(vertex.x/.36+.5,vertex.z/.36+.5))
				surface.add_vertex(vertex+Vector3.UP*side*.026)
		var p0 = Vector3(cos(a),0,sin(a))*.18
		var p1 = Vector3(cos(b),0,sin(b))*.18
		for vertex in [p0+Vector3.UP*.026,p0-Vector3.UP*.026,p1+Vector3.UP*.026,p1+Vector3.UP*.026,p0-Vector3.UP*.026,p1-Vector3.UP*.026]:
			surface.set_normal(Vector3(vertex.x,0,vertex.z).normalized())
			surface.set_uv(Vector2(.5,.055))
			surface.add_vertex(vertex)
	return surface.commit()
