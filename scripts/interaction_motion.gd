extends Node3D
## Snapshot-driven prop animation; no local timers or inventory authority.
var views: Dictionary = {}
const Props = preload("res://scripts/campaign_props.gd")
const Weapons = preload("res://scripts/weapon_view.gd")
const World = preload("res://scripts/campaign_world.gd")

func make_model(weapon: int, slot: int) -> Node3D:
	var root = Node3D.new()
	add_child(root)
	var model = Weapons.create_model(Data.weapons[weapon].id) if weapon >= 0 else Props.model(slot)
	root.add_child(model)
	if weapon >= 0:
		var bounds = World.posed_bounds(model)
		var factor = .95/maxf(.01,maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z)))
		model.scale *= factor
		model.position -= bounds.get_center()*factor
	return root

func sync(state: Dictionary) -> void:
	var live: Array = []
	for motion in state.get("pickup_motion",[]):
		live.append(motion.id)
		var t: float = maxf(0,state.get("prop_clock",0.0)-motion.at)
		if not views.has(motion.id):
			var fresh = make_model(motion.weapon,motion.slot)
			var old: Node3D = make_model(motion.old,0) if motion.old >= 0 else null
			views[motion.id] = {"fresh":fresh,"old":old,"drop":motion.drop}
		var entry: Dictionary = views[motion.id]
		var duration = .57 if motion.weapon >= 0 else .65
		var progress = smoothstep(0,duration,t)
		entry.fresh.visible = t < duration
		entry.fresh.position = motion.from.lerp(motion.to,progress)+Vector3.UP*sin(progress*PI)*.18
		entry.fresh.rotation = Vector3(motion.pitch*progress,lerp_angle(PI/2,motion.yaw,progress),0)
		entry.fresh.scale = Vector3.ONE*lerpf(1,.6,progress)
		if entry.old:
			entry.old.scale = Vector3.ONE*.65
			var fall = minf(t,.58)
			var side = Vector3(cos(motion.yaw),0,-sin(motion.yaw))
			entry.old.position = entry.drop+side*fall*.95+Vector3(0,-4*fall*fall,0)
			entry.old.position.y = maxf(.15,entry.old.position.y)
			entry.old.rotation = Vector3(0,motion.yaw,minf(t/.58,1)*PI/2)
			if t > .58: entry.old.position.y = .15+maxf(0,.10-(t-.58)*.5)*absf(sin((t-.58)*16))
	for id in views.keys():
		if id in live: continue
		views[id].fresh.queue_free()
		if views[id].old: views[id].old.queue_free()
		views.erase(id)
