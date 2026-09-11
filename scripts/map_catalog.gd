extends RefCounted
const IDS = ["outpost","dust"]
const Dust = preload("res://scripts/dust_layout.gd")

static func valid(id) -> bool:
	return id is String and id in IDS

static func definition(id: String) -> Dictionary:
	if id == "dust":
		return {"id":"dust","title":"沙漠之城","subtitle":"DUST · 中央通道 / 地下通路 / 双庭院", "bounds":Rect2(-50,-44,102,88),
			"scene":"res://scenes/dust.tscn","spawn":Dust.point(704,301),"yaw":PI/2,
			"safe":[Dust.point(704,301),Dust.point(672,294),Dust.point(442,70),Dust.point(126,198)],
			"spawns":[Dust.point(126,112),Dust.point(120,308),Dust.point(110,427),Dust.point(443,65),Dust.point(449,182),Dust.point(568,280)],
			"camera":Vector3(67,57,73),"look_at":Vector3(0,0,0),"sky":Color("b5c9d2"),"fog":Color("d9bc90"),"sun":Color("ffdfae")}
	return {"id":"outpost","title":"灰松哨站","subtitle":"松林河谷 · 桥梁 / 缓坡 / 浅滩", "bounds":Rect2(-22,-48,44,62),
		"scene":"res://scenes/world.tscn","spawn":Vector2(0,9),"yaw":0.0,
		"safe":[Vector2(0,9),Vector2(-3,9),Vector2(3,9),Vector2(0,5)],
		"spawns":[Vector2(-13,-45),Vector2(1,-45),Vector2(12,-45),Vector2(19,-36),Vector2(19,-20),Vector2(19,-4)],
		"camera":Vector3(14,10,11),"look_at":Vector3(-3,1,-21),"sky":Color("b1c7bd"),"fog":Color("b1c7bd"),"sun":Color("ffe0b3")}
