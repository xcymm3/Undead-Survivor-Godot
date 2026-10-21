extends Node
## Shared world, separate depth target. Weapon transforms and hit rays stay unchanged.
var game
var viewport: SubViewport
var camera: Camera3D
var overlay: CanvasLayer
var image: TextureRect
var source_environment: Environment

func setup(owner_game) -> void:
	game = owner_game
	process_priority = 100
	viewport = SubViewport.new()
	viewport.name = "FirstPersonDepth"
	viewport.transparent_bg = true
	viewport.world_3d = game.camera.get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	camera = Camera3D.new()
	camera.name = "FirstPersonCamera"
	camera.cull_mask = 2
	viewport.add_child(camera)
	camera.current = true
	overlay = CanvasLayer.new()
	overlay.name = "FirstPersonComposite"
	overlay.layer = 0
	add_child(overlay)
	image = TextureRect.new()
	image.name = "FirstPersonImage"
	image.texture = viewport.get_texture()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	RenderingServer.frame_pre_draw.connect(sync_view)
	sync_view()

func _process(_dt: float) -> void:
	sync_view()

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(sync_view): RenderingServer.frame_pre_draw.disconnect(sync_view)

func sync_view() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.camera): return
	var world_camera: Camera3D = game.camera
	# Existing tools may temporarily change camera masks; layer two remains exclusive.
	world_camera.cull_mask &= ~2
	viewport.world_3d = world_camera.get_world_3d()
	viewport.size = Vector2i(game.get_viewport().get_visible_rect().size)
	viewport.msaa_3d = game.get_viewport().msaa_3d
	viewport.scaling_3d_scale = game.get_viewport().scaling_3d_scale
	camera.global_transform = world_camera.global_transform
	camera.force_update_transform()
	camera.fov = world_camera.fov
	camera.keep_aspect = world_camera.keep_aspect
	camera.near = world_camera.near
	camera.far = world_camera.far
	var environment: Environment = viewport.world_3d.environment
	if environment != source_environment:
		source_environment = environment
		camera.environment = environment.duplicate() if environment else Environment.new()
		camera.environment.background_mode = Environment.BG_CLEAR_COLOR
		camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	if environment:
		camera.environment.ambient_light_color = environment.ambient_light_color
		camera.environment.ambient_light_energy = environment.ambient_light_energy
	image.visible = game.weapon.visible or (is_instance_valid(game.equipment_prop) and game.equipment_prop.visible)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if image.visible else SubViewport.UPDATE_DISABLED
