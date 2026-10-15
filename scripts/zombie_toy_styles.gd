extends RefCounted
## Per-kind toy art; no gameplay stats, extra nodes, textures or animation clocks.
const KINDS = ["normal","cone","bucket","imp","shield","berserker","giant","football","dancer"]
const PALETTES = {
	"imp":["9165bb","a882cc","52699a","48415d","a7be76"],
	"shield":["426b86","567c96","384e64","333e4a","8eae85"],
	"berserker":["b75848","ce7357","5c4853","493b39","9bb471"],
	"giant":["b99b66","c4ab7d","6c5845","493f33","a5b27a"],
	"football":["ce5147","eee0c3","e6ddc6","484d5c","98b67a"],
	"dancer":["7450a0","825dae","40375f","ceac68","9db68b"]}

static func size_for(part: Dictionary, kind: String) -> Vector3:
	var original = Vector3(part.size[0],part.size[1],part.size[2])
	if kind not in KINDS: return original
	if kind == "football" and part.get("kind","") == "football" and not part.get("head",false): return Vector3(1.02,.24,.52)
	if kind == "dancer" and part.get("kind","") == "dancer" and is_equal_approx(original.y,.17): return Vector3(.20,.09,.075)
	if part.get("shield",false):
		return Vector3(1.08,1.10,.14) if original.y > 1.3 else Vector3(.12,.90,.04) if original.y > 1 else original
	if part.get("head",false) or part.has("kind"): return original
	var limb = absf(float(part.get("limb",0.0)))
	if limb >= 1:
		if part.position[1] < .2: return Vector3(.32,.18,.49) if kind == "giant" else Vector3(.28,.16,.46)
		return Vector3(.27,.71,.34) if kind == "giant" else Vector3(.25,.71,.32)
	if limb > 0:
		if part.get("shirt",false): return Vector3(.27,.27,.50) if kind in ["giant","berserker"] else Vector3(.245,.245,.49)
		return Vector3(.31,.28,.34) if kind == "giant" else Vector3(.29,.26,.33) if kind == "berserker" else Vector3(.24,.24,.30)
	if part.get("shirt",false): return Vector3(.76,.7,.42) if kind == "giant" else Vector3(.68,.7,.38)
	return original

static func frame_for(part: Dictionary, kind: String) -> Transform3D:
	var center = Vector3(part.position[0],part.position[1],part.position[2])
	if kind == "shield" and part.get("shield",false): center.y = 1.05
	if kind == "football" and part.get("kind","") == "football" and not part.get("head",false): center.y = 1.42
	if kind == "bucket" and part.get("kind","") == "bucket":
		var tilt = Basis(Vector3.BACK,-.065)
		var pivot = Vector3(0,1.94,0)
		return Transform3D(tilt,pivot+tilt*(center-pivot))
	return Transform3D(Basis.IDENTITY,center)

static func color_for(part: Dictionary, index: int, kind: String, rage: bool) -> Color:
	var palette: Array = PALETTES.get(kind,PALETTES.imp)
	if part.get("shirt",false): return Color("d96f50" if part.has("limb") else "ca5a43") if kind == "berserker" and rage else Color(palette[1] if part.has("limb") else palette[0])
	if absf(float(part.get("limb",0.0))) >= 1: return Color(palette[3] if part.position[1] < .2 else palette[2])
	var equipment = {
		20:"c96a29",21:"ef8b30",22:"fff0cd",23:"ef8b30",24:"ffd18a",
		25:"667f8b",26:"abb9bd",27:"d7dfdd",28:"647d89",29:"e1e6dc",
		31:"ce9d5f",32:"385b78",33:"eee2bd",34:"eee2bd",
		35:"713f3e",36:"ead09b",37:"ead09b",38:"8e704b",39:"718071",
		40:"c94b43",41:"eee0c3",42:"dae0d8",43:"343343",44:"252a38",
		45:"d56c72",46:"e3c16b",47:"e3c16b",48:"d9b45c"}
	if equipment.has(index): return Color(equipment[index])
	return Color("b4b36f" if kind == "berserker" and rage else palette[4])

static func add(result: Array, at: Vector3, size: Vector3, color: String, bone := 0, armor := false) -> void:
	result.append({"position":at,"size":size,"color":Color(color),"bone":bone,"armor":armor})

static func details(kind: String) -> Array:
	var result: Array = []
	match kind:
		"imp":
			add(result,Vector3(0,1.03,.200),Vector3(.66,.07,.012),"65507f")
			add(result,Vector3(0,1.03,.211),Vector3(.12,.10,.010),"e7bc70")
			for x in [-.20,.20]: add(result,Vector3(x,1.30,.199),Vector3(.055,.28,.012),"d6badd")
		"shield":
			add(result,Vector3(0,1.05,.819),Vector3(.26,.26,.012),"dc9b50",5)
			for x in [-.065,.065]: add(result,Vector3(x,1.05,.829),Vector3(.026,.16,.006),"385b78",5)
			for x in [-.23,.23]: add(result,Vector3(x,1.37,.201),Vector3(.07,.07,.012),"dfc28b")
		"berserker":
			add(result,Vector3(0,.91,.199),Vector3(.65,.09,.012),"743d3e")
			add(result,Vector3(0,.91,.208),Vector3(.13,.11,.012),"d8b473")
		"giant":
			for x in [-.23,.23]:
				add(result,Vector3(x,1.31,.219),Vector3(.07,.35,.012),"725740")
				add(result,Vector3(x,1.16,.229),Vector3(.05,.05,.010),"e2d3ac")
			add(result,Vector3(0,1.07,.219),Vector3(.27,.18,.012),"917348")
			for x in [-.09,0,.09]: add(result,Vector3(x,1.09,.228),Vector3(.018,.10,.007),"e1d1a2")
		"football":
			# A large jersey number 08, drawn as coarse seven-segment printing.
			for digit in 2:
				var center = -.09 if digit == 0 else .09
				for y in [.995,1.205]: add(result,Vector3(center,y,.200),Vector3(.10,.028,.012),"fff0d0")
				for x in [-.05,.05]: add(result,Vector3(center+x,1.10,.200),Vector3(.026,.21,.012),"fff0d0")
				if digit == 1: add(result,Vector3(center,1.10,.200),Vector3(.10,.026,.012),"fff0d0")
			add(result,Vector3(0,2.08,.316),Vector3(.075,.38,.012),"f4dda7",6,true)
			for x in [-.19,.19]: add(result,Vector3(x,.47,.174 if x < 0 else .194),Vector3(.05,.61,.012),"b85046",1 if x < 0 else 2)
		"dancer":
			add(result,Vector3(0,1.53,.274),Vector3(.052,.065,.010),"f3a394")
			for x in [-.15,.15]: add(result,Vector3(x,1.875,.311),Vector3(.082,.014,.006),"7288a0",6)
			add(result,Vector3(0,1.854,.312),Vector3(.055,.035,.008),"d9b45c",6)
			for y in [1.04,1.20]: add(result,Vector3(0,y,.201),Vector3(.035,.035,.012),"e7c778")
	return result

static func face_profile(kind: String) -> Dictionary:
	var basic = ["0000111000","0011111100","0011222110","0112222210","1122222211","1121111211","1110000111"]
	var profile = {"eye_width":.120,"eye_height":.055,"eye_y":1.825,"eye_gap":.104,"mouth":basic,"mouth_width":.024,"mouth_y":1.745,"inside":"854e4c"}
	match kind:
		"imp":
			profile.eye_width = .130
			profile.mouth = ["0000000110","0011111110","0112222210","1122222211","1112222111","0111111110"]
			profile.inside = "9b6066"
		"shield":
			profile.eye_height = .032
			profile.mouth = ["0000000000","0000000000","0111111110","1122222211","1111111111"]
			profile.inside = "77544f"
		"berserker":
			profile.eye_height = .036
			profile.mouth = ["0011111100","0112222110","1122222211","1122222211","1122222211","0111111110"]
			profile.inside = "9c4c4c"
		"giant":
			profile.eye_height = .044
			profile.eye_gap = .100
			profile.mouth_width = .026
			profile.inside = "85634f"
		"football":
			profile.eye_y = 1.770
			profile.mouth_y = 1.725
			profile.eye_height = .045
		"dancer":
			profile.mouth = ["0000000011","0000001111","0111112211","1122222210","0111111100"]
			profile.mouth_y = 1.735
			profile.inside = "995c6b"
	return profile
