extends SceneTree
## Loads scripts after autoload registration; never instantiates gameplay or starts a match.
func _initialize() -> void:
	call_deferred("check_scripts")

func check_scripts() -> void:
	var path = "res://scripts/main.gd"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--parse-script="): path = arg.trim_prefix("--parse-script=")
	var script = load(path) as GDScript
	if script == null or not script.can_instantiate():
		push_error("SCRIPT PARSE FAILED: "+path)
		quit(1)
		return
	print("SCRIPT PARSE COMPLETE: "+path+" (no scene instantiated)")
	quit(0)
