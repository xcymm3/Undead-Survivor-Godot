extends RefCounted
## Check actual presentation consumers, including procedural geometry and world layers.

static func geometry_matches(reference: Node3D, candidate: Node3D) -> bool:
	for mesh in reference.find_children("*","MeshInstance3D",true,false):
		# Repeated procedural part names receive instance-specific generated names.
		var indices: Array[int] = []
		var part: Node = mesh
		while part != reference:
			indices.push_front(part.get_index())
			part = part.get_parent()
		var other: Node = candidate
		for index in indices:
			if index >= other.get_child_count(): return false
			other = other.get_child(index)
		if not other is MeshInstance3D or mesh.mesh.get_surface_count() != other.mesh.get_surface_count(): return false
		for surface in mesh.mesh.get_surface_count():
			if mesh.mesh.surface_get_arrays(surface) != other.mesh.surface_get_arrays(surface): return false
			var a: Material = mesh.material_override if mesh.material_override else mesh.mesh.surface_get_material(surface)
			var b: Material = other.material_override if other.material_override else other.mesh.surface_get_material(surface)
			if a is StandardMaterial3D and b is StandardMaterial3D:
				if a.albedo_color != b.albedo_color or a.metallic != b.metallic or a.roughness != b.roughness: return false
			elif a != b: return false
	return true

static func validate(game, check: Callable) -> void:
	var data = game.get_node("/root/Data")
	var factory = load("res://scripts/weapon_models.gd")
	var partner = load("res://scripts/partner_view.gd").new()
	game.add_child(partner)
	var p: Dictionary = game.local_pawn().duplicate(true)
	p.hp = 100
	p.aim = false
	p.reloading = false
	p.fire_anim = 0.0
	p.switch = 0.0
	p.pickup_remaining = 0.0
	partner.setup(p)
	var pickup = load("res://scripts/interaction_motion.gd").new()
	game.add_child(pickup)
	var displays = game.arena.scenery.find_children("WeaponDisplay*","Node3D",true,false)
	for index in data.weapons.size():
		var id: String = data.weapons[index].id
		var reference: Node3D = factory.create(id)
		game.add_child(reference)
		p.weapon = index
		p.requested = index
		game.weapon.sync(p,1.0,0.0)
		partner.update_weapon(index)
		var moving_prop: Node3D = pickup.make_model(index,0)
		check.call(geometry_matches(reference,game.weapon.models[index]),id+": first person uses the shared geometry and materials")
		check.call(geometry_matches(reference,partner.gun_model),id+": partner uses the same gun and sights")
		check.call(geometry_matches(reference,moving_prop.get_child(0)),id+": pickup and dropped prop use the same gun and sights")
		for display in displays:
			if display.get_meta("weapon_display_index") == index:
				check.call(geometry_matches(reference,display),id+": mounted wall display uses the same gun and sights")
		if id in ["p90","pistol","heavy-machine-gun"]:
			check.call(reference.find_children("TopIronSight","Node3D",true,false).size() == 1,id+": world model contains exactly one shared sight")
		if id == "revolver":
			check.call(reference.find_child("SwingOutCylinder",true,false) != null and not reference.loader.visible and not reference.shells.visible,"Displayed revolver is closed and has no loose reload props")
			check.call(reference.find_children("*","MeshInstance3D",true,false).all(func(mesh): return mesh.layers == 1 and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON),"World revolver has world visibility and casts shadows")
			check.call(game.weapon.models[index].find_children("*","MeshInstance3D",true,false).all(func(mesh): return mesh.layers == 2 and mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF),"First-person revolver alone uses the view layer and no shadows")
			p.reloading = true
			p.reload = data.weapons[index].reloadDuration*.5
			partner.sync(p,.016)
			check.call(partner.gun_model.cylinder_open > .9 and reference.cylinder_open == 0,"Partner reload opens its own cylinder without changing world display")
			var expected_muzzle: Vector3 = partner.gun_model.gun.to_global(load("res://scripts/revolver_model.gd").MUZZLE)
			check.call(partner.muzzle_position().is_equal_approx(expected_muzzle),"Partner revolver muzzle follows the animated gun")
			p.reloading = false
			partner.sync(p,.016)
			check.call(partner.gun_model.cylinder_open == 0 and not partner.gun_model.loader.visible,"Partner reload finishes with closed cylinder and hidden speedloader")
		reference.free()
		moving_prop.free()
	partner.free()
	pickup.free()
	game.weapon.sync(game.local_pawn(),1.0,0.0)
