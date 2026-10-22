extends RefCounted
## Shared timing for the authoritative interaction gate and the wave-style captions.
const LINE_SECONDS = 3.0
const LINES = [
	"太阳落下，夜幕降临",
	"黑暗中的亡灵又开始蠢蠢欲动",
	"你必须保卫水晶，不惜一切代价..."
]
const DURATION = 9.0

static func active(state: Dictionary) -> bool:
	return float(state.get("intro_elapsed",DURATION)) < DURATION

static func caption(state: Dictionary) -> String:
	var count = clampi(floori(float(state.get("intro_elapsed",0))/LINE_SECONDS)+1,1,LINES.size())
	return "\n".join(LINES.slice(0,count))

static func alpha(state: Dictionary) -> float:
	return clampf((DURATION-float(state.get("intro_elapsed",0)))/.7,0,1) if active(state) else 0.0

static func line_alpha(state: Dictionary, index: int) -> float:
	if not active(state): return 0.0
	return clampf((float(state.get("intro_elapsed",0))-index*LINE_SECONDS)/.6,0,1)
