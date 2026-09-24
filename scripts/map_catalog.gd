extends RefCounted
const IDS = ["graypine_defense","graypine_night"]
const PLAYABLE = IDS
const Night = preload("res://scripts/night_layout.gd")
const Defense = preload("res://scripts/defense_layout.gd")

static func valid(id) -> bool:
	return id is String and id in IDS

static func definition(id: String) -> Dictionary:
	if id == Defense.ID:
		return {"id":Defense.ID,"mode":"defense","title":"保卫水晶","subtitle":"8 波防守 · 吊桥 / 缓坡 / 开阔高地 · 按 T 开战","bounds":Defense.BOUNDS,"scene":"res://scenes/graypine_defense.tscn","spawn":Defense.SPAWN,"yaw":0.0,"safe":[Defense.SPAWN],"spawns":Defense.ENTRIES,"camera":Vector3(25,20,38),"look_at":Vector3(0,1,-37),"sky":Color("1d3a45"),"fog":Color("345b62"),"sun":Color("ffd09a")}
	return {"id":"graypine_night","mode":"campaign","title":"灰松夜路","subtitle":"紧凑战役 · 堵车街口 / 暗店 / 林边安全屋 · 约 3 分钟目标","bounds":Night.BOUNDS,"scene":"res://scenes/graypine_night.tscn","spawn":Night.START,"yaw":0.0,"safe":[Night.START],"spawns":Night.ENTRIES,"camera":Vector3(25,18,65),"look_at":Vector3(0,1,35),"sky":Color("101d2b"),"fog":Color("1d2b35"),"sun":Color("95b3d1")}
