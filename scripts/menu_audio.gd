extends RefCounted
## A short glass/metal tick, without a long tail over neighbouring buttons.
static func hover() -> AudioStreamWAV:
	var rate = 22050
	var data = PackedByteArray()
	data.resize(int(rate*.085)*2)
	for i in data.size()/2:
		var t = float(i)/rate
		var envelope = minf(t/.002,1)*exp(-t*65)
		var value = (sin(TAU*1850*t)+sin(TAU*3100*t)*.3)*envelope*.35
		data.encode_s16(i*2,int(value*32767))
	var stream = AudioStreamWAV.new()
	stream.mix_rate = rate
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.data = data
	return stream
