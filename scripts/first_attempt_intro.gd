extends RefCounted
## Shared timing for the authoritative interaction gate and the wave-style captions.
const LINE_SECONDS = 5.0
const LINES = [
	"病毒爆发了，小镇的大部分人都变成了僵尸",
	"作为镇上的消防员，你本来也难逃一劫",
	"幸运的是，你拥有一颗神秘的水晶，阻止了你被感染",
	"但是僵尸们不打算放过你",
	"又是一个晚上来临了，这次，你能生存下来吗..."
]
const DURATION = 25.0

static func active(state: Dictionary) -> bool:
	return float(state.get("intro_elapsed",DURATION)) < DURATION

static func caption(state: Dictionary) -> String:
	return LINES[clampi(int(float(state.get("intro_elapsed",0))/LINE_SECONDS),0,LINES.size()-1)]

static func alpha(state: Dictionary) -> float:
	if not active(state): return 0.0
	var age = fmod(float(state.get("intro_elapsed",0)),LINE_SECONDS)
	return minf(clampf(age/.6,0,1),clampf((LINE_SECONDS-age)/.7,0,1))
