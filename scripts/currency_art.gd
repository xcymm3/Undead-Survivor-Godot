extends RefCounted
## Shared engraved coin face and cut diamond icons, generated once.
static var coin_texture: Texture2D
static var diamond_texture: Texture2D

static func coin() -> Texture2D:
	if coin_texture: return coin_texture
	var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><defs><linearGradient id="gold" x1="0" y1="0" x2="1" y2="1"><stop stop-color="#ffe9aa"/><stop offset="0.48" stop-color="#e4b14f"/><stop offset="1" stop-color="#aa6b1e"/></linearGradient></defs><circle cx="64" cy="64" r="62" fill="#89551b"/><circle cx="64" cy="64" r="60" fill="url(#gold)" stroke="#ffe3a1" stroke-width="2"/><circle cx="64" cy="64" r="52" fill="none" stroke="#9c671d" stroke-width="2"/><circle cx="64" cy="64" r="49" fill="none" stroke="#ffe3a1" stroke-width="1"/>'
	for i in 40:
		var a = i*TAU/40
		var p0 = Vector2(64,64)+Vector2(cos(a),sin(a))*55
		var p1 = Vector2(64,64)+Vector2(cos(a),sin(a))*58
		svg += '<path d="M%.2f %.2f L%.2f %.2f" stroke="#8f5b18" stroke-width="1.4"/>' % [p0.x,p0.y,p1.x,p1.y]
	svg += '<path d="M82 44 C75 32 49 33 45 47 C39 66 84 61 82 78 C79 96 52 96 43 83 M63 27 L63 102" fill="none" stroke="#ffe2a0" stroke-width="8" stroke-linecap="round" transform="translate(-1 -1)"/><path d="M82 44 C75 32 49 33 45 47 C39 66 84 61 82 78 C79 96 52 96 43 83 M63 27 L63 102" fill="none" stroke="#95611d" stroke-width="6" stroke-linecap="round"/></svg>'
	var image = Image.new()
	image.load_svg_from_string(svg,2.0)
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
