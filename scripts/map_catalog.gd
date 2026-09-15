extends RefCounted
const IDS = ["outpost","dust","graypine_ferry","graypine_night"]
const PLAYABLE = ["graypine_night","outpost","dust"]
const Night = preload("res://scripts/night_layout.gd")
const Ferry = preload("res://scripts/campaign_layout.gd")
const Dust = preload("res://scripts/dust_layout.gd")

static func valid(id) -> bool:
	return id is String and id in IDS

static func definition(id: String) -> Dictionary:
	if id == "graypine_night":
		return {"id":id,"title":"灰松夜路","subtitle":"紧凑战役 · 堵车街口 / 暗店 / 林边安全屋 · 约 3 分钟目标","bounds":Night.BOUNDS,"scene":"res://scenes/graypine_night.tscn","spawn":Night.START,"yaw":0.0,"safe":[Night.START],"spawns":Night.ENTRIES,"camera":Vector3(25,18,65),"look_at":Vector3(0,1,35),"sky":Color("101d2b"),"fog":Color("1d2b35"),"sun":Color("95b3d1")}
	if id == "graypine_ferry":
		return {"id":id,"title":"灰松渡口","subtitle":"战役 · 街道 / 河桥尸潮 / 泵站安全屋","bounds":Ferry.BOUNDS,"scene":"res://scenes/graypine_ferry.tscn","spawn":Ferry.START,"yaw":0.0,"safe":[Ferry.START],"spawns":Ferry.BRIDGE_POINTS,"camera":Vector3(48,38,20),"look_at":Vector3(0,0,-35),"sky":Color("a3b9ae"),"fog":Color("a3b9ae"),"sun":Color("ffe0b3")}
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
