extends RefCounted
## Glass resonances, a small pickup chime and a rising preparation cue.
static func make(cue: String) -> AudioStreamWAV:
	var rate = 22050
	var duration = 3.0 if cue == "purchase" else .52 if cue == "crystal-hit" else .24
	var samples = PackedByteArray()
	samples.resize(int(rate*duration)*2)
	for i in samples.size()/2:
		var t = float(i)/rate
		var value = 0.0
		if cue == "purchase":
			var progress = t/duration
			var phase = TAU*(440*t+110*t*t)
			var pulse = .65+.35*sin(TAU*(4*t+t*t))
			value = (sin(phase)+.25*sin(phase*1.5))*pulse*(.06+.18*progress)*minf(1,t*40)*minf(1,(duration-t)*30)
		else:
			var base = 2300.0 if cue == "crystal-hit" else 1250.0
			value = (sin(TAU*base*t)*exp(-t*13)+.45*sin(TAU*base*1.43*t)*exp(-t*20)+.23*sin(TAU*base*1.91*t)*exp(-t*31))*.35*minf(1,t*1000)
		samples.encode_s16(i*2,int(clampf(value,-.95,.95)*32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = samples
	return stream
