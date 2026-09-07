extends Node
## Opt-in playtest aim assistance. Only camera orientation changes; no combat state writes.
const EnemyView = preload("res://scripts/enemy_view.gd")
var game
var target_id = -1
var timer = 0.0

func _ready() -> void:
	process_priority = -50
	if not Data.automation or "--qa-autoaim" not in OS.get_cmdline_user_args(): queue_free()

func _process(dt: float) -> void:
	timer += dt
	if timer < .05: return
	timer = 0.0
	var previous_target = target_id
	target_id = -1
	if not game.running or game.paused or game.finished or not game.sim: return
	var p: Dictionary = game.local_pawn()
	if p.is_empty() or p.hp <= 0: return
	var origin = Vector3(p.pos.x,p.height+1.7,p.pos.y)
	var best_score = INF
	var best = Vector3.ZERO
	for z in game.sim.zombies:
		if z.hp <= 0: continue
		var poses: Array = EnemyView.transforms(z,game.sim.elapsed,game.sim.mode == "practice")
		var target_part = 0
		if p.weapon != 7:
			for i in Data.parts.size():
				if Data.parts[i].get("head",false):
					target_part = i
					break
		var point: Vector3 = poses[target_part].origin
		var offset = point-origin
		var distance = offset.length()
		if distance < .01: continue
		var wall: Dictionary = game.arena.surface_hit(origin,point)
		if not wall.is_empty() and origin.distance_to(wall.position) < distance-.1: continue
		var hit = EnemyView.hit(z,origin,offset/distance,distance+.5,game.sim.elapsed,game.sim.mode == "practice")
		if hit.is_empty(): continue
		# Clear fast close attackers before spending a magazine on a slow tank.
		var priority: float = {"imp":.55,"berserker":.4 if z.rage else .7,"giant":2.5,"football":1.3}.get(z.kind,1.0)
		var score = distance*priority
		if z.id == previous_target: score *= .8
		if score >= best_score: continue
		best_score = score
		best = offset
		target_id = z.id
	if target_id >= 0:
		game.yaw = atan2(-best.x,-best.z)
		game.pitch = clampf(atan2(best.y,Vector2(best.x,best.z).length()),-deg_to_rad(85),deg_to_rad(85))
	elif game.sim.rest <= 0:
		# Look around when no target is visible, as a player would between spawns.
		game.yaw = wrapf(game.yaw+.035,-PI,PI)
