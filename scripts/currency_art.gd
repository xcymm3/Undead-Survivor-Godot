extends RefCounted
## Chunky eight-sided tokens and flat faceted gem icons, generated once.
static var coin_texture: Texture2D
static var diamond_texture: Texture2D

static func coin() -> Texture2D:
	if coin_texture: return coin_texture
	var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><path d="M40 5 L88 5 L123 40 L123 88 L88 123 L40 123 L5 88 L5 40 Z" fill="#683c1f"/><path d="M42 11 L86 11 L117 42 L117 86 L86 117 L42 117 L11 86 L11 42 Z" fill="#f2ad32"/><path d="M42 11 L86 11 L117 42 L103 47 L81 25 L47 25 L25 47 L11 42 Z" fill="#ffe582"/><path d="M117 42 L117 86 L86 117 L42 117 L25 103 L47 103 L81 103 L103 81 L103 47 Z" fill="#bc701f"/><path d="M47 25 L81 25 L103 47 L103 81 L81 103 L47 103 L25 81 L25 47 Z" fill="#ffd04a"/><path d="M51 40 L79 40 L87 48 L75 55 L58 55 L58 61 L77 61 L87 71 L87 82 L76 90 L49 90 L41 81 L54 75 L70 75 L70 69 L51 69 L41 59 L41 48 Z" fill="#bc771f"/><path d="M60 33 L68 33 L68 96 L60 96 Z" fill="#bc771f"/></svg>'
	var image = Image.new()
	image.load_svg_from_string(svg,2.0)
	coin_texture = ImageTexture.create_from_image(image)
	return coin_texture

static func diamond() -> Texture2D:
	if diamond_texture: return diamond_texture
	var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><path d="M26 15 L100 15 L123 48 L64 121 L5 48 Z" fill="#183b5b"/><path d="M30 22 L96 22 L114 47 L64 111 L14 47 Z" fill="#29b6dc"/><path d="M30 22 L49 46 L14 47 Z" fill="#b3f6ff"/><path d="M30 22 L64 22 L49 46 Z" fill="#62d9f3"/><path d="M64 22 L96 22 L79 46 L49 46 Z" fill="#b3f6ff"/><path d="M96 22 L114 47 L79 46 Z" fill="#47bfe7"/><path d="M14 47 L49 46 L64 111 Z" fill="#1685b6"/><path d="M49 46 L79 46 L64 111 Z" fill="#65e0f4"/><path d="M79 46 L114 47 L64 111 Z" fill="#239ac6"/></svg>'
	var image = Image.new()
	image.load_svg_from_string(svg,2.0)
	diamond_texture = ImageTexture.create_from_image(image)
	return diamond_texture

static func mesh() -> ArrayMesh:
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments = 8
	for i in segments:
		var a = PI/8+i*TAU/segments
		var b = PI/8+(i+1)*TAU/segments
		for side in [-1.0,1.0]:
			var ring = [Vector3.ZERO,Vector3(cos(a),0,sin(a))*.18,Vector3(cos(b),0,sin(b))*.18]
			if side > 0: ring.reverse()
			for vertex in ring:
				surface.set_normal(Vector3.UP*side)
				surface.set_uv(Vector2(vertex.x/.36+.5,vertex.z/.36+.5))
				surface.add_vertex(vertex+Vector3.UP*side*.045)
		var p0 = Vector3(cos(a),0,sin(a))*.18
		var p1 = Vector3(cos(b),0,sin(b))*.18
		for vertex in [p0+Vector3.UP*.045,p0-Vector3.UP*.045,p1+Vector3.UP*.045,p1+Vector3.UP*.045,p0-Vector3.UP*.045,p1-Vector3.UP*.045]:
			surface.set_normal((p0+p1).normalized())
			surface.set_uv(Vector2(.5,.88))
			surface.add_vertex(vertex)
	return surface.commit()
