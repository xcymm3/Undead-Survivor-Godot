extends RefCounted
## Deterministic mechanical cues; no shared generic reload report.
static func make(index: int, healing := false) -> AudioStreamWAV:
	var rate = 22050
	var duration = .65 if healing else .65 if index in [4,8] else 1.65 if index == 3 else 2.2 if index == 9 else 1.3
	var samples = PackedByteArray()
	samples.resize(int(rate*duration)*2)
	var random = RandomNumberGenerator.new()
	random.seed = 771+index*293
	var timings = [.04,.42,.92] if index != 3 else [.03,.22,.36,.48,.63,1.22,1.43]
	if index == 1: timings = [.02,.33,.81,1.02] # Top-mounted P90 magazine latch.
	if index == 2: timings = [.03,.28,.76] # Pistol magazine and slide.
	if index == 5: timings = [.04,.31,.59,.92,1.14] # Rifle bolt and magazine.
	if index == 7: timings = [.05,.44,.78,1.05] # Fuel canister clamp and valve.
	if index in [4,8]: timings = [.03,.25,.46]
	if index == 9: timings = [.03,.35,.62,1.12,1.56,1.95]
	for i in samples.size()/2:
		var t = float(i)/rate
		var value = 0.0
		if healing: value = (sin(TAU*440*t)+sin(TAU*660*t)*.35)*sin(PI*t/duration)*exp(-t*4)*.14
		else:
			for j in timings.size():
				var age: float = t-timings[j]
				if age < 0 or age > .13: continue
				var pitch = 350+index*91+j*113
				value += (random.randf_range(-1,1)*.7+sin(TAU*pitch*age)*.3)*exp(-age*(48 if j%2 == 0 else 29))*.45
		samples.encode_s16(i*2,int(clampf(value,-.95,.95)*32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = samples
	return stream
