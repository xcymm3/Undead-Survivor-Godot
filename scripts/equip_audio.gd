extends RefCounted
const Motion = preload("res://scripts/equip_motion.gd")

static func make(weapon: int) -> AudioStreamWAV:
	var duration = Motion.window(weapon,.9).y
	var rate = 22050
	var samples = PackedByteArray()
	samples.resize(roundi(rate*duration)*2)
	var random = RandomNumberGenerator.new()
	random.seed = 53091+weapon
	var filtered = 0.0
	for index in samples.size()/2:
		var time = float(index)/rate
		var progress = time/duration
		var noise = random.randf_range(-1,1)
		var value = 0.0
		if weapon == 0:
			# Pull latch, metal scrape, then the return spring's closing click.
			for impact in [0.0,duration*.5,duration*.93]:
				var age: float = time-impact
				if age >= 0: value += (noise*.55+sin(TAU*1700*age)*.3+sin(TAU*3100*age)*.15)*exp(-age*110)*.5
			value += noise*.085*sin(PI*progress)
		else:
			# Smoothstep rotation's angular speed peaks halfway through the spin.
			filtered = lerpf(filtered,noise,.22)
			value = filtered*(6*progress*(1-progress))*.55
		value *= minf(1.0,(duration-time)*160)
		samples.encode_s16(index*2,int(clampf(value,-.95,.95)*32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = samples
	return stream
