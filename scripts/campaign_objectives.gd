extends RefCounted
## Ordered, authority-checked objectives shared by scenery, guidance and QA.
const NODES = [
	{"id":"loading_release","pos":Vector2(-65,205),"requires":["shop_key"],"label":"卸货区 · 复位货梯断电开关","seconds":3.0},
	{"id":"loading_power","pos":Vector2(-25,145),"requires":["loading_release"],"label":"配电间 · 恢复商铺出口供电","seconds":2.0},
	{"id":"pump_fault_a","pos":Vector2(-65,-200),"requires":["gate_open","leak_closed"],"label":"西维修工位 · 隔离损坏水泵","seconds":3.0},
	{"id":"pump_fault_b","pos":Vector2(-15,-180),"requires":["pump_fault_a"],"label":"东维修工位 · 接通备用回路","seconds":3.0},
	{"id":"exit_relay","pos":Vector2(65,-220),"requires":["power_ready"],"label":"维修通道 · 恢复门控继电器","seconds":3.0},
	{"id":"exit_control","pos":Vector2(20,-200),"requires":["exit_relay"],"label":"门控台 · 解锁安全屋入口","seconds":3.0}]

static func available(node: Dictionary, state: Dictionary) -> bool:
	return not state.get(node.id,false) and node.requires.all(func(key): return state.get(key,false))

static func at(point: Vector2) -> String:
	for node in NODES:
		if node.pos == point: return node.id
	return ""
