extends RefCounted
const IDS = ["graypine_defense"]
const Defense = preload("res://scripts/defense_layout.gd")

static func valid(id) -> bool:
	return id is String and id in IDS

static func definition(_id: String) -> Dictionary:
	return {"id":Defense.ID,"mode":"defense","title":"保卫水晶","subtitle":"8 波防守 · 吊桥 / 缓坡 / 开阔高地 · 按 T 开战","bounds":Defense.BOUNDS,"scene":"res://scenes/graypine_defense.tscn","spawn":Defense.SPAWN,"yaw":0.0,"safe":[Defense.SPAWN],"spawns":Defense.ENTRIES,"camera":Vector3(25,20,38),"look_at":Vector3(0,1,-37),"sky":Color("1d3a45"),"fog":Color("345b62"),"sun":Color("ffd09a")}
