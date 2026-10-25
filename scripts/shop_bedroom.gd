extends "res://scripts/world_geometry.gd"
## A compact lived-in sleeping room, with a clear central route for four spawns.
const Layout = preload("res://scripts/defense_layout.gd")

func _ready() -> void:
	var rear: float = Layout.SHOP_AREA.end.y
	var front: float = Layout.SHOP_PARTITION_Z
	block("BedroomEastWall",Vector3(-1.5,5.25,(front+rear)/2),Vector3(.22,4.5,rear-front),"555c4a")
	# Skirting, wood flooring and a faded rug warm up the bare shell.
	for i in 14:
		block("Floorboard",Vector3(-12.45+i*.79,3.063,(front+rear)/2),Vector3(.77,.025,rear-front-.35),"66513a" if i%3 else "715b41",false)
	for x in [-12.65,-1.65]:
		block("Skirting",Vector3(x,3.16,(front+rear)/2),Vector3(.09,.26,rear-front-.25),"8d714b",false)
	block("WovenRug",Vector3(-6.7,3.085,rear-4.8),Vector3(4.6,.018,3.3),"756b4e",false)
	for x in [-8.85,-4.55]:
		block("RugBorder",Vector3(x,3.10,rear-4.8),Vector3(.12,.008,3.1),"b3a176",false)
	# Full bed frame and layered bedding, placed to the west of the walkway.
	var bed = Vector3(-10.6,3,rear-3.0)
	for x in [-.82,.82]:
		for z in [-1.75,1.75]: block("BedLeg",bed+Vector3(x,.28,z),Vector3(.15,.56,.15),"4d3829")
	block("BedFrame",bed+Vector3(0,.42,0),Vector3(1.95,.32,3.9),"795636")
	block("BedHeadboard",bed+Vector3(0,.93,1.86),Vector3(2.08,1.45,.15),"795636")
	for x in [-.64,0,.64]: block("HeadboardInset",bed+Vector3(x,1.03,1.765),Vector3(.52,.83,.035),"5b432f",false)
	block("Mattress",bed+Vector3(0,.69,0),Vector3(1.85,.30,3.65),"c7bd9c")
	block("OliveBlanket",bed+Vector3(0,.86,-.55),Vector3(1.9,.11,2.45),"57644d",false)
	block("FoldedBlanketEdge",bed+Vector3(0,.94,.55),Vector3(1.91,.10,.25),"748064",false)
	block("BedPillow",bed+Vector3(0,.93,1.2),Vector3(1.22,.24,.65),"e0d1aa",false)
	# Bedside drawer, a book, a mug and an actual warm lamp.
	var table = Vector3(-8.9,3,rear-.6)
	block("Nightstand",table+Vector3(0,.44,0),Vector3(.85,.88,.78),"725137")
	for y in [.27,.62]:
		block("NightstandDrawer",table+Vector3(0,y,-.405),Vector3(.7,.28,.04),"94714c",false)
		block("DrawerPull",table+Vector3(0,y,-.45),Vector3(.2,.045,.07),"c0a36a",false)
	lamp(table+Vector3(0,.9,0))
	block("BedsideBook",table+Vector3(.23,.92,-.2),Vector3(.25,.06,.33),"8c6043",false)
	# Wardrobe and a small writing desk occupy the east edge, away from spawns.
	block("Wardrobe",Vector3(-2.7,4.24,rear-1.0),Vector3(1.9,2.48,1.15),"5a432f")
	block("WardrobeCornice",Vector3(-2.7,5.52,rear-1.0),Vector3(2.06,.15,1.25),"93734b",true,false)
	for x in [-3.15,-2.25]:
		block("WardrobeDoor",Vector3(x,4.25,rear-1.61),Vector3(.81,2.22,.07),"80613f",false)
		block("WardrobePanel",Vector3(x,4.25,rear-1.66),Vector3(.59,1.83,.03),"6d5037",false)
		block("WardrobeHandle",Vector3(x+(.26 if x < -2.7 else -.26),4.2,rear-1.71),Vector3(.05,.24,.06),"c0a36a",false)
	var desk = Vector3(-2.9,3,rear-6.2)
	block("WritingDesk",desk+Vector3(0,.97,0),Vector3(1.8,.16,1.15),"a08254")
	for x in [-.73,.73]:
		for z in [-.4,.4]: block("DeskLeg",desk+Vector3(x,.46,z),Vector3(.12,.92,.12),"61472f",false)
	solid_core("WritingDeskCore",desk+Vector3(0,.50,0),Vector3(1.8,1.0,1.15))
	block("PaperSheet",desk+Vector3(-.16,1.061,0),Vector3(.47,.015,.57),"d4c7a4",false)
	block("Notebook",desk+Vector3(.47,1.09,.15),Vector3(.38,.07,.45),"3e594f",false)
	var mug = cylinder(desk+Vector3(-.6,1.17,.27),.095,.22,"ad9870")
	mug.name = "DeskMug"
	block("StoolSeat",desk+Vector3(-1.0,.57,-.1),Vector3(.55,.13,.55),"8e6b46")
	solid_core("StoolCore",desk+Vector3(-1.0,.30,-.1),Vector3(.55,.60,.55))
	for x in [-.20,.20]:
		for z in [-.20,.20]: block("StoolLeg",desk+Vector3(-1.0+x,.27,-.1+z),Vector3(.08,.54,.08),"61472f",false)
	# Personal items and shelves imply a firefighter sleeping here between nights.
	block("WallShelf",Vector3(-12.45,4.85,rear-6.5),Vector3(.7,.12,2.0),"99774e",true,false)
	for i in 4:
		block("SupplyBook",Vector3(-12.45,5.10,rear-7.1+i*.25),Vector3(.40,.4,.16),["66583d","47584b","805641","b0a17a"][i],false)
	block("CoatPeg",Vector3(-1.72,5.14,rear-4.1),Vector3(.18,.14,.14),"b0945c",false)
	block("HangingWorkCoat",Vector3(-1.87,4.70,rear-4.1),Vector3(.20,.85,.62),"674c35",true,false)
	block("CoatReflectiveStripe",Vector3(-1.98,4.55,rear-4.1),Vector3(.025,.10,.64),"c1ac64",false)
	# A warm ceiling fixture supports navigation even when facing away from the bed.
	var ceiling = OmniLight3D.new()
	ceiling.name = "BedroomCeilingLight"
	ceiling.position = Vector3(-6.7,6.8,rear-4.2)
	ceiling.light_color = Color("ffda9f")
	ceiling.light_energy = 1.5
	ceiling.omni_range = 9
	ceiling.shadow_enabled = false
	add_child(ceiling)

func solid_core(title: String, center: Vector3, size: Vector3) -> void:
	var body = block(title,center,size,"61472f")
	body.get_child(0).hide()

func lamp(base: Vector3) -> void:
	cylinder(base+Vector3(0,.04,0),.20,.07,"635038")
	cylinder(base+Vector3(0,.27,0),.035,.45,"ad8b50")
	var shade = cylinder(base+Vector3(0,.57,0),.31,.37,"e6bf79")
	shade.name = "BedsideLampshade"
	solid_core("BedsideLampCore",base+Vector3(0,.57,0),Vector3(.58,.37,.58))
	shade.mesh.top_radius = .17
	var glow = material("e6bf79").duplicate()
	glow.emission_enabled = true
	glow.emission = Color("ffc778")
	glow.emission_energy_multiplier = .7
	shade.material_override = glow
	var light = OmniLight3D.new()
	light.name = "BedsideLight"
	light.position = base+Vector3(0,.55,0)
	light.light_color = Color("ffc885")
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.shadow_enabled = false
	add_child(light)
