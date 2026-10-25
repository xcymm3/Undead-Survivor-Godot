extends Node3D
## Render-only batches. Original named bodies/colliders stay in their hierarchy.
const Layout = preload("res://scripts/defense_layout.gd")
const CHUNK = 8.0
var camera: Camera3D
var regions: Dictionary = {}
var labels: Dictionary = {}
var material_keys: Dictionary = {}
var stats = {"original_meshes":0,"batch_draws":0,"multimeshes":0,"merged_surfaces":0}
var unit_box: BoxMesh
var visibility_state: Dictionary = {}
var exterior_visuals: Array[GeometryInstance3D] = []
var door: Array[Vector3] = []
var passage: Array[Vector3] = []
var frustum: Array[Plane] = []

func setup(world: Node3D) -> void:
	name = "StaticScenery"
	process_priority = 150
	unit_box = BoxMesh.new()
	unit_box.size = Vector3.ONE
	for region in ["shell","shop","bedroom","exterior"]:
		var group = Node3D.new()
		group.name = region
		add_child(group)
		regions[region] = group
		labels[region] = []
	var buckets: Dictionary = {}
	var shop = world.shop
	for mesh in shop.find_children("*","MeshInstance3D",true,false):
		if not is_instance_valid(mesh) or mesh.get_child_count() > 0: continue
		if shop.owner_model.is_ancestor_of(mesh) or not mesh.is_visible_in_tree() or mesh.skin or not mesh.mesh: continue
		if mesh.mesh.get_surface_count() != 1: continue
		var finish = mesh.material_override if mesh.material_override else mesh.mesh.surface_get_material(0)
		if not finish is StandardMaterial3D or finish.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
		var region = region_for(mesh,shop)
		var point: Vector3 = mesh.global_position
		var key = "%s/%d/%d/%s" % [region,floori(point.x/CHUNK),floori(point.z/CHUNK),material_key(finish)]
		if not buckets.has(key): buckets[key] = {"region":region,"material":finish,"boxes":[],"others":[]}
		var pose: Transform3D = global_transform.affine_inverse()*mesh.global_transform
		if mesh.mesh is BoxMesh and finish.albedo_texture == null:
			pose.basis *= Basis.from_scale(mesh.mesh.size)
			buckets[key].boxes.append(pose)
		else: buckets[key].others.append({"mesh":mesh.mesh,"pose":pose})
		stats.original_meshes += 1
		# Preserve child indices and names used by collision/interaction inspections.
		var parent = mesh.get_parent()
		var placeholder = Node3D.new()
		placeholder.name = mesh.name
		placeholder.transform = mesh.transform
		var index: int = mesh.get_index()
		parent.remove_child(mesh)
		parent.add_child(placeholder)
		parent.move_child(placeholder,index)
		mesh.free()
	for bucket in buckets.values():
		var group: Node3D = regions[bucket.region]
		if not bucket.boxes.is_empty():
			var view = MultiMeshInstance3D.new()
			view.name = "BoxInstances"
			view.multimesh = MultiMesh.new()
			view.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			view.multimesh.mesh = unit_box
			view.multimesh.instance_count = bucket.boxes.size()
			for index in bucket.boxes.size(): view.multimesh.set_instance_transform(index,bucket.boxes[index])
			view.material_override = bucket.material
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.add_child(view)
			stats.multimeshes += 1
			stats.batch_draws += 1
		if not bucket.others.is_empty():
			var surface = SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for item in bucket.others: surface.append_from(item.mesh,0,item.pose)
			var view = MeshInstance3D.new()
			view.name = "MergedDecoration"
			view.mesh = surface.commit()
			view.material_override = bucket.material
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.add_child(view)
			stats.merged_surfaces += 1
			stats.batch_draws += 1
	for label in shop.find_children("*","Label3D",true,false):
		if not shop.owner_model.is_ancestor_of(label): labels[region_for(label,shop)].append(label)
	# Static outdoor geometry only: moving crystal, stations and defenses retain
	# their own visibility/state ownership. Hiding meshes never hides colliders.
	for view in world.find_children("*","GeometryInstance3D",true,false):
		if not (view is MeshInstance3D or view is MultiMeshInstance3D) or not view.visible: continue
		if shop.is_ancestor_of(view) or world.crystal.is_ancestor_of(view) or world.preparation.is_ancestor_of(view) or world.structure_view.is_ancestor_of(view): continue
		if view.get_parent().name == "SafeZoneFloor": continue
		exterior_visuals.append(view)
	for y in [3.0,6.5]:
		for z in [Layout.SHOP_DOOR_Z-2.1,Layout.SHOP_DOOR_Z+2.1]: door.append(Vector3(13,y,z))
	for x in [Layout.SHOP_PASSAGE_X-2.1,Layout.SHOP_PASSAGE_X+2.1]:
		for y in [3.0,6.6]: passage.append(Vector3(x,y,Layout.SHOP_PARTITION_Z))

func material_key(finish: StandardMaterial3D) -> String:
	var identity = finish.get_instance_id()
	if material_keys.has(identity): return material_keys[identity]
	var properties: Array = []
	for property in finish.get_property_list():
		if property.usage & PROPERTY_USAGE_STORAGE and not str(property.name).begins_with("resource_"):
			properties.append([property.name,finish.get(property.name)])
	var key = var_to_bytes(properties).hex_encode().sha256_text()
	material_keys[identity] = key
	return key

func region_for(node: Node3D, shop: Node3D) -> String:
	var bedroom = shop.get_node("Bedroom")
	if node == bedroom or bedroom.is_ancestor_of(node):
		return "shell" if str(node.get_parent().name) == "BedroomEastWall" else "bedroom"
	var exterior = shop.get_node("Storefront")
	if exterior.is_ancestor_of(node): return "exterior"
	var ancestor = node
	while ancestor.get_parent() != shop and ancestor.get_parent() != null: ancestor = ancestor.get_parent()
	if str(ancestor.name).begins_with("Shop") or str(ancestor.name).begins_with("BackroomDivider") or ancestor.name == "BackroomLintel": return "shell"
	return "shop"

func portal_visible(points: Array[Vector3]) -> bool:
	# Conservative convex-frustum intersection: partial/near-plane views stay open.
	for plane in frustum:
		var outside = true
		for point in points:
			if plane.distance_to(point) <= .05: outside = false; break
		if outside: return false
	return true

func _process(_dt: float) -> void:
	update_visibility()

func update_visibility() -> void:
	if not is_instance_valid(camera): return
	var p = camera.global_position
	var room = Layout.SHOP_AREA.grow(.5).has_point(Vector2(p.x,p.z))
	var bedroom = room and p.z > Layout.SHOP_PARTITION_Z and p.x < -1.35
	var high = p.y > Layout.SHOP_CEILING_Y-.1
	frustum = camera.get_frustum()
	var see_door = portal_visible(door)
	var see_passage = portal_visible(passage)
	if absf(p.x-13) < 1.0 and absf(p.z-Layout.SHOP_DOOR_Z) < 2.8: see_door = true
	visibility_state = {"shell":true,"shop":high or (room and (not bedroom or see_passage)) or (not room and p.x > 12.5 and see_door),
		"bedroom":high or bedroom or (room and see_passage) or (not room and p.x > 12.5 and see_door and see_passage),
		"exterior":high or not room or (see_door and (not bedroom or see_passage))}
	for region in regions:
		if regions[region].visible != visibility_state[region]:
			regions[region].visible = visibility_state[region]
			for label in labels[region]: label.visible = visibility_state[region]
			if region == "exterior":
				for view in exterior_visuals: view.visible = visibility_state.exterior
