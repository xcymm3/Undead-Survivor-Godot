extends RefCounted
## The unmodified healing chime is outside the CC0 combat replacement scope.
static func heal() -> AudioStreamWAV:
	var rate = 22050
	var duration = .65
	var samples = PackedByteArray()
	samples.resize(int(rate*duration)*2)
	for i in samples.size()/2:
		var t = float(i)/rate
		var value = (sin(TAU*440*t)+sin(TAU*660*t)*.35)*sin(PI*t/duration)*exp(-t*4)*.14
		samples.encode_s16(i*2,int(clampf(value,-.95,.95)*32767))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = samples
	return stream
