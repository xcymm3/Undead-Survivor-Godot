extends RefCounted
const IDS = ["graypine_night"]
const PLAYABLE = IDS
const Night = preload("res://scripts/night_layout.gd")

static func valid(id) -> bool:
	return id is String and id in IDS

static func definition(_id: String) -> Dictionary:
	return {"id":"graypine_night","title":"灰松夜路","subtitle":"紧凑战役 · 堵车街口 / 暗店 / 林边安全屋 · 约 3 分钟目标","bounds":Night.BOUNDS,"scene":"res://scenes/graypine_night.tscn","spawn":Night.START,"yaw":0.0,"safe":[Night.START],"spawns":Night.ENTRIES,"camera":Vector3(25,18,65),"look_at":Vector3(0,1,35),"sky":Color("101d2b"),"fog":Color("1d2b35"),"sun":Color("95b3d1")}
