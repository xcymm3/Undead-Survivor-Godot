extends RefCounted
## Short deterministic mechanical key click; respects the normal master volume.
static func make() -> AudioStreamWAV:
	var rate = 22050
	var bytes = PackedByteArray()
	bytes.resize(int(rate*.035)*2)
	var noise = RandomNumberGenerator.new()
	noise.seed = 8129
	for index in bytes.size()/2:
		var time = float(index)/rate
		var signal_value = (noise.randf_range(-1,1)*.45+sin(TAU*1600*time)*.3)*exp(-time*160)*minf(1,time*3000)
		bytes.encode_s16(index*2,int(signal_value*18000))
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
