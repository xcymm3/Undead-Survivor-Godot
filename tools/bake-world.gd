extends SceneTree
## Development-only conversion; the game loads the saved PackedScene directly.
func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var source = preload("res://tools/world_importer.gd").new()
	root.add_child(source)
	if not source.baked_ok:
		source.free()
		push_error("World bake aborted: invalid source or collision manifest")
		quit(1)
		return
	var buffers: Dictionary = source.instance_buffers
	source.name = "World"
	for child in source.find_children("*", "", true, false): child.owner = source
	source.set_script(null)
	var packed = PackedScene.new()
	var error = packed.pack(source)
	if error == OK: error = ResourceSaver.save(packed,"res://scenes/world.tscn")
	if error == OK:
		# Dummy RenderingServer cannot read back MultiMesh buffers in headless mode.
		# Serialize the native buffer from our CPU data, never from a GPU readback.
		var path = "res://scenes/world.tscn"
		var text = FileAccess.get_file_as_string(path)
		for id in buffers:
			var marker = '[sub_resource type="MultiMesh" id="%s"]' % id
			var start = text.find(marker)
			assert(start >= 0)
			var end = text.find("\n\n",start)
			text = text.insert(end,"\nbuffer = "+var_to_str(buffers[id]))
		var file = FileAccess.open(path,FileAccess.WRITE)
		if file: file.store_string(text)
		else: error = FileAccess.get_open_error()
	source.free()
	if error != OK: push_error("World bake failed: %s" % error)
	else: print("WORLD BAKE: PASS")
	quit(0 if error == OK else 1)
