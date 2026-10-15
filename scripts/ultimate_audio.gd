extends RefCounted
static func make(music: bool) -> AudioStreamWAV:
	var rate = 22050
	var duration = 10.0 if music else .9
	var samples = PackedByteArray()
	samples.resize(roundi(rate*duration)*2)
	var random = RandomNumberGenerator.new()
	random.seed = 95172
	for i in samples.size()/2:
		var t = float(i)/rate
		var value: float
		if music:
			var beat = fmod(t,.4)
			var note = [220.0,261.63,329.63,392.0][int(t/.8)%4]
			value = (sin(TAU*note*t)+.25*sin(TAU*note*2*t))*.09
			value += .3*sin(TAU*(65*beat-30*beat*beat))*exp(-beat*24)
			value += random.randf_range(-1,1)*exp(-fmod(t,.2)*70)*.04
		else:
			value = random.randf_range(-1,1)*sin(PI*t/duration)*.18+sin(TAU*1800*t)*exp(-t*28)*.2
		value *= minf(1,t*40)*minf(1,(duration-t)*30)
		samples.encode_s16(i*2,int(clampf(value,-.95,.95)*32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = samples
	return stream
