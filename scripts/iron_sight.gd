extends Node3D
## Small sight-only fittings, measured in the original imported model coordinates.
const PROFILES = {
	"pistol": {"rear":Vector3(0,.050,.038),"front":Vector3(0,.050,-.315),"width":.056,"gap":.014,"notch":.013,"blade":.008,"mount":Vector2(.024,.022)},
	"p90": {"rear":Vector3(0,.125,-.232),"front":Vector3(0,.125,-.329),"width":.065,"gap":.020,"notch":.016,"blade":.012,"mount":Vector2(.094,.081)},
	"heavy-machine-gun": {"rear":Vector3(.04,.215,-.16),"front":Vector3(.04,.215,-1.02),"width":.112,"gap":.025,"notch":.025,"blade":.015,"mount":Vector2(.12,.105)}
}
var line: Vector3

func _init(id: String) -> void:
	name = "TopIronSight"
	var p: Dictionary = PROFILES[id]
	line = p.rear
	var finish: String = {"pistol":"303638","p90":"343e38","heavy-machine-gun":"51594f"}[id]
	add_notch(self,p.rear,p.width,p.gap,p.notch,.022,finish)
	var floor_y: float = p.rear.y-p.notch-.006
	box(self,"RearSightFoot",Vector3(p.rear.x,(floor_y+p.mount.x)*.5,p.rear.z),Vector3(p.width,floor_y-p.mount.x,.028),finish)
	box(self,"FrontSightFoot",Vector3(p.front.x,(p.front.y-.020+p.mount.y)*.5,p.front.z),Vector3(p.blade*2,p.front.y-.020-p.mount.y,.032),finish)
	box(self,"FrontBlade",p.front-Vector3(0,.011,0),Vector3(p.blade,.022,.018),"6d7568")
	box(self,"FrontInlay",p.front+Vector3(0,-.007,.0095),Vector3(p.blade*.5,.004,.001),"c1b99a")
	for entry in [["RearAim",p.rear],["FrontAim",p.front]]:
		var marker = Marker3D.new()
		marker.name = entry[0]
		marker.position = entry[1]
		add_child(marker)

static func part(parent: Node3D, title: String, shape: Mesh, at: Vector3, color: String) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.name = title
	node.mesh = shape
	node.position = at
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = .8
	node.material_override = material
	parent.add_child(node)
	return node

static func box(parent: Node3D, title: String, at: Vector3, size: Vector3, color: String) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = size
	return part(parent,title,shape,at,color)

static func add_notch(parent: Node3D, at: Vector3, width: float, gap: float, height: float, depth: float, color := "606966") -> MeshInstance3D:
	var r = gap*.5
	var bevel = minf(.004,width*.08)
	var outline = PackedVector2Array([
		Vector2(-width*.5,-height-.006),Vector2(width*.5,-height-.006),
		Vector2(width*.5,-bevel),Vector2(width*.5-bevel,0),Vector2(r,0)])
	for i in 9:
		var angle = -PI*float(i)/8
		outline.append(Vector2(cos(angle)*r,-height+r+sin(angle)*r))
	outline.append_array(PackedVector2Array([Vector2(-r,0),Vector2(-width*.5+bevel,0),Vector2(-width*.5,-bevel)]))
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices = Geometry2D.triangulate_polygon(outline)
	# Clockwise winding on outward faces, with flat normals on the machined edges.
	for side in [-1.0,1.0]:
		for i in range(0,indices.size(),3):
			for corner in ([0,1,2] if side < 0 else [2,1,0]):
				var point = outline[indices[i+corner]]
				surface.set_normal(Vector3(0,0,side))
				surface.add_vertex(Vector3(point.x,point.y,side*depth*.5))
	for i in outline.size():
		var a = outline[i]
		var b = outline[(i+1)%outline.size()]
		var normal = Vector3(b.y-a.y,a.x-b.x,0).normalized()
		for point in [Vector3(b.x,b.y,depth*.5),Vector3(b.x,b.y,-depth*.5),Vector3(a.x,a.y,-depth*.5),Vector3(a.x,a.y,depth*.5),Vector3(b.x,b.y,depth*.5),Vector3(a.x,a.y,-depth*.5)]:
			surface.set_normal(normal)
			surface.add_vertex(point)
	return part(parent,"RearNotch",surface.commit(),at,color)
