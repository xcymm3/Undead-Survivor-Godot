extends RefCounted
const IDS = ["graypine_defense"]
const Defense = preload("res://scripts/defense_layout.gd")

static func valid(id) -> bool:
	return id is String and id in IDS

static func definition(_id: String) -> Dictionary:
	return {"id":Defense.ID,"mode":"defense","title":"保卫水晶","subtitle":"过桥整备 · 修复水晶后开启十波防守","bounds":Defense.BOUNDS,"scene":"res://scenes/graypine_defense.tscn","spawn":Defense.SPAWN,"yaw":PI,"safe":[Defense.SPAWN],"spawn_region":Defense.ENEMY_SPAWN_REGION,"camera":Vector3(25,20,38),"look_at":Vector3(0,1,-37),"sky":Color("080d1c"),"fog":Color("101a2b"),"sun":Color("a8c5ef")}
