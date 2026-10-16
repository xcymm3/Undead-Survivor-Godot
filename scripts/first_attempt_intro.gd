extends RefCounted
## Shared timing for the authoritative interaction gate and the wave-style captions.
const LINE_SECONDS = 5.0
const LINES = [
	"第491次尝试，又失败了...",
	"看样子，只有击败那个戴着墨镜，穿黄金苦茶子的家伙，才能离开这个轮回",
	"再次点亮水晶吧",
	"这一次，我不会再失败...",
]
const DURATION = 20.0

static func active(state: Dictionary) -> bool:
	return float(state.get("intro_elapsed",DURATION)) < DURATION

static func caption(state: Dictionary) -> String:
	return LINES[clampi(int(float(state.get("intro_elapsed",0))/LINE_SECONDS),0,LINES.size()-1)]

static func alpha(state: Dictionary) -> float:
	if not active(state): return 0.0
	var age = fmod(float(state.get("intro_elapsed",0)),LINE_SECONDS)
	return minf(clampf(age/.6,0,1),clampf((LINE_SECONDS-age)/.7,0,1))
