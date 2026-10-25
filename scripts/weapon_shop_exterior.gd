extends "res://scripts/world_geometry.gd"
## Weathered roadside gun shop: gable silhouette, timber storefront, lit displays.
const Layout = preload("res://scripts/defense_layout.gd")
const TIMBER = "584430"
const TRIM = "c0a576"
const ROOF = "775044"
const IRON = "35453e"
const BRASS = "cfab64"
const GLASS = "9d7947"

func _ready() -> void:
	build_roof()
	build_facade()
	build_porch()
	build_stock()

func part(parent: Node3D, title: String, pos: Vector3, size: Vector3, color: String) -> Node3D:
	var item = block(title,Vector3.ZERO,size,color,false)
	item.reparent(parent,false)
	item.position = pos
	return item

func beam(title: String, a: Vector3, b: Vector3, width: float, depth: float, color: String) -> void:
	var item = block(title,(a+b)*.5,Vector3(width,a.distance_to(b),depth),color,false)
	item.basis = Basis(Quaternion(Vector3.UP,(b-a).normalized()))

func gable(z: float, front: bool) -> void:
	var body = StaticBody3D.new()
	body.name = "FrontGable" if front else "RearGable"
	var points = PackedVector3Array([Vector3(-13.3,7.5,z),Vector3(13.3,7.5,z),Vector3(0,10.9,z)])
	var builder = SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in ([0,1,2] if front else [2,1,0]): builder.add_vertex(points[index])
	builder.generate_normals()
	var view = MeshInstance3D.new()
	view.mesh = builder.commit()
	view.material_override = material("89866a")
	body.add_child(view)
	var collision = CollisionShape3D.new()
	var shape = ConvexPolygonShape3D.new()
	var hull = PackedVector3Array()
	for point in points:
		hull.append(point+Vector3(0,0,-.14))
		hull.append(point+Vector3(0,0,.14))
	shape.points = hull
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	var offset = -.19 if front else .19
	beam("GableBargeboard",Vector3(-13.55,7.48,z+offset),Vector3(0,11.0,z+offset),.2,.2,TRIM)
	beam("GableBargeboard",Vector3(0,11.0,z+offset),Vector3(13.55,7.48,z+offset),.2,.2,TRIM)
	beam("GableTie",Vector3(-13.3,7.54,z+offset),Vector3(13.3,7.54,z+offset),.23,.22,TIMBER)
	beam("KingPost",Vector3(0,7.5,z+offset),Vector3(0,10.8,z+offset),.2,.18,TIMBER)

func build_roof() -> void:
	var front: float = Layout.SHOP_FRONT_Z
	var middle: float = Layout.SHOP_AREA.get_center().y
	var slope = atan2(3.4,13.3)
	var length = Vector2(13.8,3.53).length()
	for side in [-1.0,1.0]:
		var panel = block("SlopedShopRoof",Vector3(side*6.9,9.13,middle),Vector3(length,.24,Layout.SHOP_AREA.size.y+2.0),ROOF,true,false)
		panel.rotation.z = -side*slope
		block("EaveFascia",Vector3(side*13.8,7.37,middle),Vector3(.18,.4,Layout.SHOP_AREA.size.y+2.2),TIMBER,false)
		for offset in range(-12,13,2):
			var seam = block("RoofStandingSeam",Vector3(side*6.9,9.28,middle+offset),Vector3(length,.055,.07),"ac8061",false)
			seam.rotation.z = -side*slope
	block("RoofRidgeCap",Vector3(0,10.99,middle),Vector3(.4,.2,Layout.SHOP_AREA.size.y+2.3),IRON,false)
	gable(front-.08,true)
	gable(Layout.SHOP_AREA.end.y+.08,false)
	# A brick chimney breaks the long roof ridge and reads at battlefield distance.
	var chimney = Vector3(-8,9.8,Layout.SHOP_AREA.end.y-4)
	block("BrickChimney",chimney,Vector3(1.45,4.5,1.4),"765747",true,false)
	for level in 9:
		block("ChimneyMortar",Vector3(chimney.x,7.9+level*.48,chimney.z),Vector3(1.48,.045,1.43),"a18a6a",false)
	block("ChimneyCrown",chimney+Vector3(0,2.27,0),Vector3(1.8,.22,1.75),IRON,false)
	block("ChimneyMouth",chimney+Vector3(0,2.4,0),Vector3(1.2,.045,1.15),"19221e",false)

func signboard(title: String, pos: Vector3, width: float, height: float, yaw: float) -> Node3D:
	var root = Node3D.new()
	root.name = title
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	part(root,"CarvedSignBacking",Vector3.ZERO,Vector3(width,height,.2),TIMBER)
	for y in [-height*.5,height*.5]: part(root,"SignBrassEdge",Vector3(0,y,.12),Vector3(width+.12,.09,.05),BRASS)
	for x in [-width*.5,width*.5]: part(root,"SignBrassEdge",Vector3(x,0,.12),Vector3(.09,height,.05),BRASS)
	if title in ["BattlefieldShopSign","PorchShopSign"]:
		var lettering = Label3D.new()
		lettering.name = "ShopLettering"
		lettering.text = "SHOP"
		lettering.font = preload("res://assets/fonts/ZCOOLQingKeHuangYou-Regular.ttf")
		lettering.font_size = 160
		lettering.pixel_size = minf(width/430.0,height/190.0)
		lettering.position.z = .14
		lettering.modulate = Color("f6d99b")
		lettering.outline_size = 10
		root.add_child(lettering)
	return root

func window_display(center: Vector3, yaw: float, weapon := false) -> void:
	var root = Node3D.new()
	root.name = "LitDisplayWindow"
	root.position = center
	root.rotation.y = yaw
	add_child(root)
	part(root,"WindowShadowBox",Vector3.ZERO,Vector3(5.5,2.1,.22),TIMBER)
	var pane = part(root,"OpaqueAmberGlass",Vector3(0,0,.13),Vector3(5.12,1.8,.03),GLASS)
	var glass = material(GLASS)
	glass.emission_enabled = true
	glass.emission = Color("956b32")
	glass.emission_energy_multiplier = .55
	pane.get_child(0).material_override = glass
	for x in [-2.65,2.65]: part(root,"WindowFrame",Vector3(x,0,.22),Vector3(.16,2.2,.2),TRIM)
	for y in [-1.02,1.02]: part(root,"WindowFrame",Vector3(0,y,.22),Vector3(5.5,.16,.2),TRIM)
	part(root,"WindowSill",Vector3(0,-1.12,.3),Vector3(5.8,.15,.65),TIMBER)
	for x in [-1.72,1.72]: part(root,"WindowIronGrille",Vector3(x,0,.28),Vector3(.055,1.85,.05),IRON)
	if weapon:
		var gun = preload("res://scripts/weapon_view.gd").create_model("rifle")
		root.add_child(gun)
		gun.rotation.y = PI/2
		var bounds = preload("res://scripts/world_geometry.gd").posed_bounds(gun)
		var center_local = root.to_local(bounds.get_center())
		var factor = 3.6/maxf(.01,bounds.size.length())
		gun.scale *= factor
		gun.position = Vector3(0,.06,.36)-center_local*factor
	else:
		for x in [-1.15,0,1.15]:
			part(root,"WindowAmmoBox",Vector3(x,-.36,.3),Vector3(.68,.7,.18),"59694a")
			part(root,"AmmoBoxStrap",Vector3(x,-.36,.41),Vector3(.12,.72,.035),BRASS)

func lamp(pos: Vector3, energy := 1.8) -> void:
	block("ExteriorLampBracket",pos+Vector3(0,.2,0),Vector3(.45,.12,.4),IRON,false)
	var glass = block("ExteriorLanternGlass",pos,Vector3(.28,.38,.28),"ffe0a1",false)
	var glow = material("ffe0a1")
	glow.emission_enabled = true
	glow.emission = Color("ffc37a")
	glass.get_child(0).material_override = glow
	var light = OmniLight3D.new()
	light.name = "StorefrontWarmLight"
	light.position = pos
	light.light_color = Color("ffcc87")
	light.light_energy = energy
	light.omni_range = 9
	light.shadow_enabled = false
	add_child(light)

func build_facade() -> void:
	var front: float = Layout.SHOP_FRONT_Z
	var rear: float = Layout.SHOP_AREA.end.y
	# Stone footing, repeated timber bays and pale plaster replace blank dark walls.
	for z in [front-.28,rear+.28]:
		for x in range(-12,13,2):
			block("StoneFoundation",Vector3(x,3.5,z),Vector3(1.96,1,.25),"666b5b" if x%4 == 0 else "797965",false)
		for x in [-12.7,-4,4,12.7]:
			block("FacadeTimberPost",Vector3(x,5.2,z),Vector3(.21,4.4,.24),TIMBER,false)
		for y in [4.1,7.18]: block("FacadeTimberRail",Vector3(0,y,z),Vector3(26,.18,.24),TIMBER,false)
	for x in [-13.28,13.28]:
		for z in [front+.5,front+8.5,front+15,rear-.5]:
			# The east-side entrance stays open; decorative trim cannot cross it.
			if x > 0 and absf(z-Layout.SHOP_DOOR_Z) < Layout.SHOP_DOOR_WIDTH*.5: continue
			block("SideTimberPost",Vector3(x,5.2,z),Vector3(.24,4.4,.22),TIMBER,false)
		# Rear side trim never bridges across the open doorway.
		block("SideTimberRail",Vector3(x,4.05,front+18),Vector3(.24,.18,11.5),TIMBER,false)
	window_display(Vector3(-8,5.42,front-.45),PI,true)
	window_display(Vector3(8,5.42,front-.45),PI,true)
	window_display(Vector3(13.4,5.35,front+18),PI/2,false)
	signboard("BattlefieldShopSign",Vector3(0,8.92,front-.48),10.4,1.65,PI)
	signboard("ServicesSign",Vector3(0,5.45,front-.46),6.6,.84,PI)
	# A crossed weapon crest can be recognized before the Chinese letters resolve.
	var crest = Vector3(0,6.65,front-.62)
	beam("CrossedRifleEmblem",crest+Vector3(-.8,-.32,0),crest+Vector3(.8,.32,0),.14,.12,BRASS)
	beam("CrossedRifleEmblem",crest+Vector3(-.8,.32,0),crest+Vector3(.8,-.32,0),.14,.12,BRASS)
	for x in [-8,0,8]: lamp(Vector3(x,6.8,front-1.0),2.4)
	lamp(Vector3(0,10.0,front-1.0),2.5)

func build_porch() -> void:
	var door: float = Layout.SHOP_DOOR_Z
	# The deep striped canopy and two slim posts identify the side-facing entrance.
	var slope = atan2(.85,4.7)
	for i in 18:
		var cloth = block("StripedShopAwning",Vector3(15.5,6.57,door-4.25+i*.5),Vector3(4.9,.12,.5),"825746" if i%2 == 0 else "c3b185",true,false)
		cloth.rotation.z = -slope
		block("AwningValance",Vector3(17.94,6.02,door-4.25+i*.5),Vector3(.1,.35,.5),"825746" if i%2 == 0 else "c3b185",false)
	for z in [door-4.35,door+4.35]:
		block("PorchPost",Vector3(17.65,4.5,z),Vector3(.22,3,.22),TIMBER)
		block("PorchPostFoot",Vector3(17.65,3.18,z),Vector3(.4,.36,.4),IRON,false)
		beam("PorchDiagonalBrace",Vector3(17.65,5.3,z),Vector3(16.65,6.15,z),.13,.13,TRIM)
	signboard("PorchShopSign",Vector3(18.03,6.44,door),3.8,.9,PI/2)
	# A hanging blade sign faces the approaching player, above the canopy line.
	beam("HangingSignBracket",Vector3(13.4,8.4,door+3.0),Vector3(17.2,8.4,door+3.0),.12,.12,IRON)
	for x in [15.3,16.7]: beam("SignChain",Vector3(x,8.4,door+3),Vector3(x,7.8,door+3),.035,.035,IRON)
	signboard("HangingArmorySign",Vector3(16,7.2,door+3),2.0,1.5,PI)
	for z in [door-2.35,door+2.35]: lamp(Vector3(14.0,5.75,z),2.2)

func build_stock() -> void:
	var front: float = Layout.SHOP_FRONT_Z
	# Physical stock piles stay outside the existing spawn-to-crystal walking route.
	for item in [[-11.4,front-1.35],[14.4,front+15.6]]:
		var p = Vector3(item[0],3.45,item[1])
		block("ExteriorSupplyCrate",p,Vector3(1.35,.9,1.1),"756044")
		for offset in [-.48,.48]: block("CrateIronBand",p+Vector3(offset,0,0),Vector3(.075,.94,1.14),IRON,false)
		var upper = block("ExteriorAmmoChest",p+Vector3(.12,.7,0),Vector3(.95,.5,.75),"58674c",true)
		upper.set_meta("shop_prop",true)
