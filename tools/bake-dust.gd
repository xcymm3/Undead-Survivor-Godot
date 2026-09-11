extends SceneTree
func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var source = load("res://tools/dust_builder.gd").new()
	root.add_child(source)
	for child in source.find_children("*","",true,false): child.owner = source
	source.set_script(null)
	var scene = PackedScene.new()
	var result = scene.pack(source)
	if result == OK: result = ResourceSaver.save(scene,"res://scenes/dust.tscn")
	source.free()
	if result != OK: push_error("Dust scene bake failed")
	else: print("DUST BAKE: PASS")
	quit(0 if result == OK else 1)
