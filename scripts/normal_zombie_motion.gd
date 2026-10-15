extends RefCounted
## Seven rigid toy joints; the same pose drives rendering and authoritative hits.
const Art = preload("res://scripts/normal_zombie_art.gd")
const HIT_DURATION = .18
const ATTACK_TIMES = [0.0,.16,.28,.86,1.0,1.18,1.5,2.0,2.6]
const ATTACK_ARMS = [.72,.72,-.85,-.85,.35,.35,.62,.72,.72]
const ATTACK_LEAN = [.025,.025,-.10,-.10,.16,.16,.08,.025,.025]
const ATTACK_HEAD = [0.0,0.0,-.08,-.08,.14,.14,.06,0.0,0.0]
const IDLE_TIMES = [0.0,.55,.62,1.15,1.22,1.75,1.82,2.4]
const IDLE_TICKS = [-1.0,-1.0,1.0,1.0,1.0,1.0,-1.0,-1.0]
const RECOIL_TIMES = [0.0,.025,.11,.18]
const RECOIL_WEIGHT = [0.0,1.0,1.0,0.0]
const SHOVE_TIMES = [0.0,.035,.16,.26,.65,2.65,2.98,3.12]
const SHOVE_WEIGHT = [0.0,1.0,1.0,.65,.55,.55,.15,0.0]
const STUN_TICKS = [-1.0,-1.0,.65,.65,.2,.2]
const DEATH_TIMES = [0.0,.08,.22,.30,.44,.58,.68,.75,.85]
const DEATH_FALL = [0.0,0.0,-.18,-.18,-1.05,-PI/2,-1.48,-PI/2,-PI/2]
const EMERGE_TIMES = [0.0,.18,.28,.46,.56,.70,.82,1.0]
const EMERGE_HEIGHT = [-2.5,-2.5,-1.35,-1.35,-.25,-.25,.02,0.0]

static func track(time: float, times: Array, values: Array) -> float:
	if time <= times[0]: return float(values[0])
	for index in range(1,times.size()):
		if time <= times[index]:
			return lerpf(values[index-1],values[index],smoothstep(times[index-1],times[index],time))
	return float(values[-1])

static func joint(pivot: Vector3, angles: Vector3) -> Transform3D:
	var rotation = Basis.from_euler(angles)
	return Transform3D(rotation,pivot-rotation*pivot)

static func pose(z: Dictionary, elapsed: float, stationary: bool) -> Dictionary:
	var bones: Array[Transform3D] = []
	bones.resize(7)
	bones.fill(Transform3D.IDENTITY)
	var scale: float = Data.enemy_scale("normal")
	var ground: float = Data.enemy_ground_height(z.pos,z.get("map_id","graypine_defense"))
	var root = Transform3D(Basis(Vector3.UP,z.heading).scaled(Vector3.ONE*scale),Vector3(z.pos.x,ground,z.pos.y))
	var legs = Vector2.ZERO
	var arms = Vector2(.72,.72)
	var arm_roll = Vector2.ZERO
	var head = Vector3.ZERO
	var lean = .025
	var roll = 0.0
	var height = 0.0
	var animation = "idle"
	var hit_age: float = elapsed-float(z.get("toy_hit_at",-100.0))
	var shove_age: float = elapsed-float(z.get("toy_shove_at",-100.0))
	if z.hp <= 0:
		animation = "death"
		var age = clampf(.85-float(z.down),0,.85)
		lean = track(age,DEATH_TIMES,DEATH_FALL)
		var power_off = smoothstep(.08,.22,age)
		arms = Vector2(.72,.72).lerp(Vector2(.12,.28),power_off)
		arm_roll = Vector2(-.24,.24)*power_off
		legs = Vector2(.12,-.08)*power_off
		head.x = .12*power_off
	elif z.get("emerge_remaining",0.0) > 0:
		animation = "emerge"
		var progress = clampf(1.0-float(z.emerge_remaining)/1.4,0,1)
		height = track(progress,EMERGE_TIMES,EMERGE_HEIGHT)*scale
		var spring = 1.0-smoothstep(.7,1,progress)
		arms = Vector2(-.65,-.65).lerp(Vector2(.72,.72),1-spring)
		head.x = -.12*spring
		roll = .055*spring*(1.0 if progress < .46 else -1.0)
	elif z.get("state","") == "stunned" and shove_age >= 0 and elapsed < z.get("toy_shove_until",-1.0):
		animation = "shove"
		var weight = track(shove_age,SHOVE_TIMES,SHOVE_WEIGHT)
		lean = -.30*weight
		roll = .045*weight*STUN_TICKS[floori(shove_age*7)%STUN_TICKS.size()]
		arms = Vector2(.72,.72).lerp(Vector2(-.35,-.2),weight)
		arm_roll = Vector2(-.12,.12)*weight
		legs = Vector2(.16,-.12)*weight
		head = Vector3(.20*weight,.05*weight,0)
	elif hit_age >= 0 and hit_age < HIT_DURATION:
		animation = "hit"
		var weight = track(hit_age,RECOIL_TIMES,RECOIL_WEIGHT)
		var side: float = float(z.get("toy_hit_side",0.0))
		lean = -.22*weight
		roll = -.10*side*weight
		arms = Vector2(.72,.72).lerp(Vector2(.2,.45),weight)
		head = Vector3(.16*weight,.12*side*weight,0)
	elif z.get("state","") == "stunned":
		animation = "stunned"
		var strength = clampf(float(z.get("state_time",0.0))/.16,0,1)
		var tick: float = STUN_TICKS[posmod(floori(elapsed*9)+int(z.id),STUN_TICKS.size())]
		lean = -.08*strength
		roll = tick*.075*strength
		arms = Vector2(.72,.72).lerp(Vector2(.2,.9),strength)
		head = Vector3(.12,tick*.14,-tick*.08)*strength
	elif z.attack_time > 0:
		animation = "attack"
		var progress: float = z.attack_time/Data.attack("normal").x
		var arm = track(progress,ATTACK_TIMES,ATTACK_ARMS)
		arms = Vector2(arm,arm)
		lean = track(progress,ATTACK_TIMES,ATTACK_LEAN)
		head.x = track(progress,ATTACK_TIMES,ATTACK_HEAD)
		legs = Vector2(.08,-.06)
	elif not stationary and z.get("move_speed",0.0) > .05 and z.get("rage_pause",0.0) <= 0:
		animation = "walk"
		var phase: float = float(z.get("gait",(elapsed-z.born)*5+z.id*2))
		var sample = Art.walk_sample(phase)
		legs = Vector2(sample.x,sample.y)
		arms = Vector2(.72-sample.x*.25,.72-sample.y*.25)
		roll = sample.z*.085
		lean = .12 if z.move_speed > 3.5 else .04
		root.origin += root.basis*Vector3.RIGHT*sample.z*.035
	else:
		var tick = track(fposmod(elapsed+z.id*.137,2.4),IDLE_TIMES,IDLE_TICKS)
		roll = tick*.025
		head = Vector3(.02,tick*.075,-tick*.015)
		arms = Vector2(.68+tick*.025,.68-tick*.025)
	root.basis *= Basis.from_euler(Vector3(lean,0,roll))
	for index in 2:
		var side = 1.0 if index == 0 else -1.0
		bones[index+1] = joint(Vector3(-side*.19,.83,0),Vector3(legs[index],0,0))
		bones[index+3] = joint(Vector3(-side*.43,1.35,-.045),Vector3(arms[index],0,arm_roll[index]))
	bones[6] = joint(Vector3(0,1.79,0),head)
	if animation == "death": root = plant_body(root,bones,ground)
	else: root = Art.plant_feet(root,bones,Data.parts,ground)
	root.origin.y += height
	return {"root":root,"bones":bones,"animation":animation}

static func plant_body(root: Transform3D, bones: Array, ground: float) -> Transform3D:
	# Keep a rigid fallen toy above the floor, including its head and forearms.
	var low = INF
	for index in 20:
		if not Art.part_visible(index,"normal"): continue
		var part: Dictionary = Data.parts[index]
		var limb: float = float(part.get("limb",0.0))
		var bone = 0
		if part.get("head",false): bone = 6
		elif absf(limb) >= 1: bone = 1 if limb > 0 else 2
		elif limb != 0: bone = 3 if limb > 0 else 4
		var pose: Transform3D = root*bones[bone]
		var center: Vector3 = pose*Data.v3(part.position)
		var half_size = Art.part_size(part,"normal")*.5
		var radius = absf(pose.basis.x.y)*half_size.x+absf(pose.basis.y.y)*half_size.y+absf(pose.basis.z.y)*half_size.z
		low = minf(low,center.y-radius)
	root.origin.y += ground+.015-low
	return root
