extends SceneTree
## Run in a separate headless project containing the imported reference Arms.fbx.
## --script <absolute path to this script> -- --output=<absolute destination JSON>
const SOURCE = "https://github.com/BigAndCrispy/Unity-First-Person-Melee"
const COMMIT = "592b08e2e1fe81a51f712fa65d806fa3621e2032"
const FBX_SHA256 = "8f1afd249569249a3420ee4e9f8b48611893ce7987e5a644a634593700452f93"
const SIZE = .56
func _initialize() -> void: call_deferred("bake")

func bake() -> void:
	var output = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): output = argument.trim_prefix("--output=")
	if output.is_empty(): push_error("Missing --output"); quit(1); return
	if FileAccess.get_sha256("res://Arms.fbx") != FBX_SHA256:
		push_error("Reference FBX does not match the pinned source version"); quit(1); return
	var packed: PackedScene = load("res://Arms.fbx")
	var actor = packed.instantiate()
	root.add_child(actor)
	var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
	var skeleton: Skeleton3D = actor.find_children("*","Skeleton3D",true,false)[0]
	var wrist = skeleton.find_bone("Wrist.R")
	var camera_axis = Basis(Vector3.UP,PI)
	var y = Vector3(.64,.56,-.53).normalized()
	var x = y.cross(Vector3.BACK).normalized()
	var resting = Basis(x,y,x.cross(y))
	var result = {"source":SOURCE,"commit":COMMIT,"license":"CC0-1.0","fbx_sha256":FileAccess.get_sha256("res://Arms.fbx"),"bone":"Wrist.R","samples_per_clip":121,"clips":[]}
	for clip_name in ["CharacterArmature|Sword_Slash1","CharacterArmature|Sword_Slash2"]:
		var clip: Animation = player.get_animation(clip_name)
		player.play(clip_name)
		player.pause()
		player.seek(0,true)
		skeleton.force_update_all_bone_transforms()
		var initial: Transform3D = actor.global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_pose(wrist)
		var samples = []
		for index in 121:
			var progress = float(index)/120
			# Keep the authored wind-up/cut/follow-through, omit its return-to-idle.
			var phase = lerpf(.13,.30,progress/.22) if progress < .22 else lerpf(.30,.52,(progress-.22)/.44) if progress < .66 else lerpf(.52,.62,(progress-.66)/.34)
			player.seek(clip.length*phase,true)
			skeleton.force_update_all_bone_transforms()
			var frame: Transform3D = actor.global_transform.affine_inverse()*skeleton.global_transform*skeleton.get_bone_global_pose(wrist)
			var rotation = camera_axis*frame.basis*initial.basis.inverse()*camera_axis.inverse()*resting
			var position = Vector3(.34,-.24,-1.04)+camera_axis*(frame.origin-initial.origin)*.85
			var pose = fit_in_view(Transform3D(rotation.scaled(Vector3.ONE*SIZE),position))
			var q = pose.basis.orthonormalized().get_rotation_quaternion()
			samples.append([pose.origin.x,pose.origin.y,pose.origin.z,q.x,q.y,q.z,q.w])
		result.clips.append({"name":clip_name,"source_seconds":clip.length,"source_phase":[.13,.30,.52,.62],"samples":samples})
	var file = FileAccess.open(output,FileAccess.WRITE)
	if not file: push_error("Cannot write output"); quit(1); return
	file.store_string(JSON.stringify(result))
	file.close()
	print("Baked two CC0 sword clips, 121 camera-space keys each, without skeletons or hands")
	quit()

func fit_in_view(pose: Transform3D) -> Transform3D:
	# A development-only framing pass for the current longer blade, 61° vertical FOV.
	var retreat = 0.0
	var tangent = tan(deg_to_rad(61.0)*.5)
	for x in [-.125,.125]:
		for y in [-.35,1.11]:
			for z in [-.05,.05]:
				var vertex: Vector3 = pose*Vector3(x,y,z)
				retreat = maxf(retreat,maxf(vertex.z+absf(vertex.x)/(tangent*(4.0/3.0)*.88),vertex.z+absf(vertex.y)/(tangent*.88)))
	pose.origin.z -= retreat
	return pose
