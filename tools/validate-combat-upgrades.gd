extends SceneTree
const Ultimate = preload("res://scripts/ultimate.gd")
const Store = preload("res://scripts/progression_store.gd")
const Fixture = preload("res://tools/preparation-fixture.gd")
const Catalog = preload("res://scripts/preparation_catalog.gd")
var failures = 0
var checks = 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func validate_blade_motion(game) -> void:
	var motion_type = load("res://scripts/blade_motion.gd")
	var blade_type = load("res://scripts/long_blade.gd")
	var tip: float = blade_type.TIP
	var model = blade_type.new()
	var blade_mesh: Mesh = model.get_node("Blade").mesh
	var vertices: PackedVector3Array = blade_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	check(blade_mesh.get_aabb().end.y > 1.5 and vertices.has(Vector3(0,tip,0)),"Longer blade has a geometric pointed tip rather than a box end")
	check(Array(vertices).all(func(v): return v.y < tip-.001 or (absf(v.x) < .001 and absf(v.z) < .001)),"Both blade edges converge to the same sharp tip")
	var normals: PackedVector3Array = blade_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	check(normals[0].dot(Vector3(vertices[0].x,0,vertices[0].z)) > 0,"Blade bevel faces point outward for correct lighting and backface culling")
	check(blade_type.SHEATH_LENGTH > tip,"Scabbard encloses the full new blade length")
	model.free()
	var sheath: Transform3D = motion_type.sheath_pose()
	var inserted: Transform3D = motion_type.inserted_pose()
	check((inserted*Vector3(0,tip,0)).distance_to(sheath*Vector3(0,-tip,0)) < .00001,"Inserted blade points into the sheath, with guard at its mouth")
	var pulled: Transform3D = motion_type.extracted_pose()
	check((pulled*Vector3(0,tip,0)-motion_type.MOUTH).dot(motion_type.PULL) > 0,"Draw pulls the entire blade clear of the scabbard mouth toward the left")
	for step in 9:
		var extracting: Transform3D = motion_type.draw_pose(lerpf(.16,.74,float(step)/8))
		var travel: Vector3 = extracting.origin-motion_type.MOUTH
		check(travel.cross(motion_type.PULL).length() < .00001 and extracting.basis.is_equal_approx(inserted.basis),"Blade stays aligned with the scabbard during extraction, before rotating: "+str(step))
	check(motion_type.draw_pose(1).is_equal_approx(motion_type.ready_pose()),"Draw ends at the exact idle pose without a transition snap")
	for step in 31:
		var t = float(step)/30
		for direction in [-1,1]:
			var pose: Transform3D = motion_type.swing_pose(t,direction)
			var bounds_valid = true
			for vertex in [Vector3(-.05,0,-.02),Vector3(.06,tip,.02),Vector3(0,-.38,0)]:
				var point: Vector3 = pose*vertex
				for aspect in [4.0/3.0,1.6,16.0/9.0]:
					var half_height = -point.z*tan(deg_to_rad(61.0)*.5)
					bounds_valid = bounds_valid and point.z < -.04 and absf(point.x) < half_height*aspect*.95 and absf(point.y) < half_height*.95
					if is_equal_approx(aspect,1.6): bounds_valid = bounds_valid and point.x < half_height*aspect*.62
			check(bounds_valid,"Wide slash keeps blade tip and grip within desktop camera bounds: "+str(step)+" / "+str(direction))
	check(motion_type.slash_data.clips.size() == 2 and motion_type.slash_data.clips[0].name.ends_with("Sword_Slash1") and motion_type.slash_data.clips[1].name.ends_with("Sword_Slash2"),"Both distinct authored CC0 slash clips are present")
	check(motion_type.slash_data.clips.all(func(clip): return clip.samples.size() == 121 and is_equal_approx(clip.source_seconds,5.0/6.0)),"Reference animations preserve their source timing and dense baked wrist samples")
	var motion = motion_type.new()
	var combo = {"ultimate_remaining":5.0,"ultimate_age":2.0,"ultimate_sheathe":0.0,"fire_anim":.00001,"axe_direction":1}
	var combo_end: Transform3D = motion.sample(combo,.016,.28).blade
	combo.fire_anim = .28
	combo.axe_direction = -1
	var combo_start: Transform3D = motion.sample(combo,0,.28).blade
	check(combo_end.is_equal_approx(combo_start),"Opposite authored clip starts from the previous displayed follow-through without an idle snap")
	motion.reset()
	var pawn = {"ultimate_remaining":5.0,"ultimate_age":2.0,"ultimate_sheathe":0.0,"fire_anim":.14,"axe_direction":1}
	motion.sample(pawn,1.0/60,.28)
	var before: Transform3D = motion.current
	pawn.ultimate_remaining = 0.0
	pawn.ultimate_sheathe = Ultimate.SHEATHE_TIME
	pawn.fire_anim = 0.0
	var after: Dictionary = motion.sample(pawn,0,.28)
	check(before.is_equal_approx(after.blade),"Mid-slash cancellation starts sheathing at the last displayed blade pose without snapping")
	pawn.ultimate_sheathe -= .01
	after = motion.sample(pawn,.01,.28)
	check(before.origin.distance_to(after.blade.origin) < .02,"First sheathing step smoothly aligns from the interrupted swing")
	var p: Dictionary = game.local_pawn()
	var restore = p.duplicate(true)
	p.weapon = 6
	p.ultimate_remaining = 5.0
	p.ultimate_age = 2.0
	p.ultimate_sheathe = 0.0
	p.fire_anim = .14
	game.weapon.reset_motion()
	game.weapon.sync(p,.016,0)
	check(game.weapon.blade.visible and not game.weapon.scabbard.visible,"Scabbard is hidden throughout active slashes")
	p.fire_anim = 0
	game.weapon.sync(p,.016,0)
	check(not game.weapon.scabbard.visible,"Scabbard remains hidden while holding the blade idle")
	p.ultimate_age = Ultimate.DRAW_TIME*.5
	game.weapon.sync(p,.016,0)
	check(game.weapon.scabbard.visible,"Scabbard is visible while the blade is being drawn")
	p.ultimate_remaining = 0
	p.ultimate_sheathe = Ultimate.SHEATHE_TIME
	game.weapon.sync(p,0,0)
	check(game.weapon.scabbard.visible,"Scabbard returns for sheathing")
	var root_inverse: Transform3D = game.weapon.transform.affine_inverse()
	var raised: Transform3D = motion_type.sheath_pose()
	raised.origin += Vector3(.10,-.65,.08)
	check(game.weapon.scabbard.transform.is_equal_approx(root_inverse*raised),"Gun-root motion cannot move the independent entering scabbard")
	p.clear()
	p.merge(restore,true)
	game.weapon.reset_motion()

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.start_solo("defense",47)
	var sim = game.sim
	var p: Dictionary = sim.pawns.solo
	var data = root.get_node("Data")
	for kind in {"normal":100,"cone":200,"bucket":400,"imp":400,"shield":1200,"berserker":3000,"giant":6000,"football":9000,"dancer":90000}:
		var original = {"normal":100,"cone":200,"bucket":400,"imp":400,"shield":1200,"berserker":3000,"giant":6000,"football":9000,"dancer":90000}
		check(data.enemies[kind].health == original[kind]*2,"Doubled health: "+kind)
	for kind in {"cone":100,"bucket":300,"shield":1000,"giant":2000,"football":6000}:
		var original = {"cone":100,"bucket":300,"shield":1000,"giant":2000,"football":6000}
		check(data.enemies[kind].armor == original[kind]*2,"Doubled armor: "+kind)
	check(p.slot_ammo == [30,15] and p.slot_reserves == [255,128],"Full magazines with halved initial reserve")
	p.slot = 2
	sim.equipment.select_weapon_slot(p,2)
	check(is_equal_approx(p.switch,1.5),"Fixed-loadout pistol uses the longer real switch duration")
	p.switch = .55
	game.weapon.sync(p,0,sim.elapsed)
	check(absf(game.weapon.rotation.x) > .5,"Pistol spin has a visible intermediate pose")
	p.slot = 1
	sim.equipment.select_weapon_slot(p,1)
	p.switch = .45
	game.weapon.sync(p,0,sim.elapsed)
	check(game.weapon.models[0].rack_hand.visible and game.weapon.models[0].bolt.position.z > .08,"Rifle charging handle and racking glove visibly travel together")
	p.switch = 0
	game.weapon.sync(p,0,sim.elapsed)
	check(not game.weapon.models[0].rack_hand.visible and is_equal_approx(game.weapon.models[0].bolt.position.z,-.11),"Rifle rack returns home and withdraws the racking hand")
	var world = game.arena.scenery
	for item in sim.defense.structures:
		if item.kind == "mine": continue
		var actor: Dictionary = world.structure_view.actors[item.id]
		check(actor.root.visible and actor.get("ghost",false) and actor.body.collision_layer == 0,"Unbuilt prep structure is a nonblocking ghost: "+item.id)
		for mesh in actor.root.find_children("*","MeshInstance3D",true,false):
			check(mesh.material_override.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,"Ghost uses transparent override")
	sim.progression.data.coins = 100000
	for id in ["rifle","pistol","axe","rifle_magazine","pistol_magazine"]:
		Fixture.face(sim,p,id)
		check(Catalog.focus(sim,p).get("id","") == id,"Shared stand resolves held weapon: "+id)
		check(Catalog.description(sim,id).contains(Catalog.NAMES[id]),"Description identifies the upgraded weapon: "+id)
		check(sim.purchase_upgrade(id,p),"Shared stand buys correct upgrade: "+id)
	check(world.preparation.stations.size() == 9,"Shared stands remove redundant weapon desks")
	Fixture.face(sim,p,"ultimate")
	check(sim.purchase_upgrade("ultimate",p) and sim.progression.level("ultimate") == 1,"Learning the ultimate uses its physical stand")
	for price in [450,650,1000]:
		check(sim.progression.cost("ultimate") == price and sim.progression.purchase("ultimate"),"Ultimate next price: "+str(price))
	check(sim.progression.cost("ultimate") == -1 and Store.valid(sim.progression.data),"Ultimate caps at four and its save is valid")
	p.slot = 1
	p.weapon = 0
	p.requested = 0
	p.switch = 0
	p.reloading = true
	p.reload = .8
	p.ammo[0] = 1
	p.reserves[0] = 40
	check(sim.try_shove(p),"Shove can start during a magazine reload")
	sim.update_arsenal(p,{},.1)
	check(p.reloading and is_equal_approx(p.reload,.7),"Reload advances while shove is active")
	p.shove_anim = .22 # Pose sampled 0.1 seconds after shove begins.
	game.weapon.sync(p,0,sim.elapsed)
	check(absf(game.weapon.models[0].rotation.z) > .01 and game.weapon.position.z < -.5,"Model reload tilt and root shove coexist")
	p.reloading = false
	p.shove_anim = 0
	p.slot = 3
	p.weapon = 6
	p.requested = 6
	p.axe_next_direction = 1
	sim.fire(p,data.weapons[6])
	check(p.axe_direction == 1,"First axe swing goes right to left")
	sim.fire(p,data.weapons[6])
	check(p.axe_direction == -1,"Held next axe swing reverses")
	sim.advance_arsenal(p,{"fire":false},.01)
	sim.fire(p,data.weapons[6])
	check(p.axe_direction == 1,"Releasing fire resets axe direction")
	var pivot = Node3D.new()
	var view = load("res://scripts/weapon_view.gd")
	view.sample_axe(pivot,1.0,1)
	var resting: Transform3D = pivot.transform
	view.sample_axe(pivot,1.0,-1)
	check(resting.is_equal_approx(pivot.transform),"Both axe directions recover to the same resting pose")
	view.sample_axe(pivot,.5,1)
	var right_pose: Vector3 = pivot.position
	view.sample_axe(pivot,.5,-1)
	check(right_pose.distance_to(pivot.position) > .5,"Opposite axe strokes visibly cross opposite sides")
	pivot.free()
	p.slot = 1
	p.weapon = 0
	p.requested = 0
	p.fire_anim = 0
	sim.defense.started = true
	p.input = {"ultimate":true}
	check(Ultimate.tick(sim,p,p.input,.01) and Ultimate.active(p),"Q activates learned ultimate")
	var sword: Dictionary = sim.combat_weapon(p)
	check(is_equal_approx(sword.damage,300*pow(1.2,3)) and is_equal_approx(sword.fireDuration,data.weapons[6].fireDuration*.5),"Long blade damage scales and attack animation runs twice as fast")
	check(p.ultimate_cd == 0 and p.weapon == 6 and not p.reloading,"Active ultimate locks blade and has no cooldown yet")
	p.input = {"slot":2,"weapon":2}
	Ultimate.tick(sim,p,p.input,1)
	check(p.slot == 3 and p.weapon == 6 and p.input.slot == 3,"Ultimate ignores weapon switch requests")
	p.input = {"x":0.0,"y":-1.0,"fire":true}
	p.input_age = 0
	sim.update_pawn(p,.01)
	check(p.sprinting,"Ultimate keeps sprint speed while attacking without Shift")
	game.weapon.sync(p,0,sim.elapsed)
	check(game.weapon.blade.visible and not game.weapon.models[6].visible,"Ultimate replaces axe with long blade")
	p.input = {"ultimate":true}
	Ultimate.tick(sim,p,p.input,.01)
	check(not Ultimate.active(p) and p.ultimate_cd == 60 and p.ultimate_sheathe > 0,"Q early finish starts sixty-second cooldown and sheath animation")
	p.input = {}
	Ultimate.tick(sim,p,p.input,1)
	check(not Ultimate.locked(p) and p.slot == 1,"Sheathing restores previous equipment slot")
	validate_blade_motion(game)
	p.input = {"ultimate":true}
	Ultimate.tick(sim,p,p.input,.01)
	check(not Ultimate.active(p) and p.ultimate_notice == "大招冷却中","Q during cooldown reports unavailability")
	p.ultimate_cd = 0
	p.input = {"ultimate":true}
	Ultimate.tick(sim,p,p.input,.01)
	p.input = {}
	Ultimate.tick(sim,p,p.input,10.01)
	check(not Ultimate.active(p) and p.ultimate_cd == 60,"Natural ten-second expiration starts full cooldown")
	var disk_path = OS.get_cache_dir().path_join("undead-ultimate-qa-"+str(Time.get_ticks_usec())+".json")
	var persisted = Store.new(disk_path)
	persisted.data = sim.progression.data.duplicate(true)
	persisted.dirty = true
	check(persisted.save() and Store.new(disk_path).level("ultimate") == 4,"Ultimate rank survives an actual disk reload")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(disk_path+suffix): DirAccess.remove_absolute(disk_path+suffix)
	var key = InputEventKey.new()
	key.physical_keycode = KEY_Q
	key.pressed = true
	game._unhandled_input(key)
	check(game.input_state().ultimate and not game.input_state().ultimate,"Physical Q submits one input edge")
	game.ui.native_hud.sync()
	check(game.ui.native_hud.ultimate_ring.caption == "0%","Ultimate ring shows charge percentage after ending")
	sim.damage_crystal({},1)
	game.ui.native_hud.sync()
	check(game.ui.native_hud.crystal_alert.visible,"Crystal damage shows top-of-screen alert")
	# Compare uncapped armor damage at an identical blast position.
	sim.zombies.clear()
	var blast = Vector3(8,4.0,27)
	sim.spawn(Vector2(8,27),"giant")
	var victim: Dictionary = sim.zombies[0]
	var hp: float = victim.hp
	sim.equipment.explode({"id":-1,"owner":p.id,"pos":blast,"damage_scale":.5})
	var mine_damage: float = hp-victim.hp
	victim.body = 8000.0
	victim.armor = 4000.0
	victim.hp = 12000.0
	victim.pos = Vector2(8,27)
	sim.equipment.explode({"id":-1,"owner":p.id,"pos":blast})
	check(is_equal_approx(hp-victim.hp,mine_damage*2),"Hand grenade deals twice mine damage at the same distance")
	# Real disk deletion under a unique temporary directory, never the user's saves.
	var folder = OS.get_cache_dir().path_join("undead-delete-qa-"+str(Time.get_ticks_usec()))
	DirAccess.make_dir_recursive_absolute(folder)
	var manager = load("res://scripts/progression.gd").new()
	manager.configure(folder)
	manager.slots[0].data.coins = 123
	manager.slots[0].dirty = true
	check(manager.slots[0].save(),"Deletion fixture creates a real save")
	var filename: String = manager.slots[0].path
	DirAccess.copy_absolute(filename,filename+".bak")
	DirAccess.copy_absolute(filename,filename+".corrupt-test")
	manager.slots[1].data.coins = 99
	manager.slots[1].dirty = true
	manager.slots[1].save()
	check(manager.delete_slot(0) and not FileAccess.file_exists(filename) and not FileAccess.file_exists(filename+".bak") and not FileAccess.file_exists(filename+".corrupt-test"),"Confirmed deletion removes primary and recoverable copies")
	check(manager.store.data.coins == 0 and manager.slots[1].data.coins == 99,"Deleted current slot resets while another slot is preserved")
	var directory = DirAccess.open(folder)
	for file in directory.get_files(): directory.remove(file)
	DirAccess.remove_absolute(folder)
	manager.free()
	game.free()
	print("COMBAT UPGRADES: %d checks; %d failures" % [checks,failures])
	quit(1 if failures else 0)
