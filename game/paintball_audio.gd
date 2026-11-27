extends RefCounted
## Lightweight procedural sound effects for Paintball.
## Zero external assets or licensing overhead; silent in headless test runs.

const RATE := 22050
static var _streams: Dictionary = {}


static func _enabled() -> bool:
	return DisplayServer.get_name() != "headless"


static func _make_wav(samples: PackedByteArray) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = samples
	return wav


static func _write_sample(buf: PackedByteArray, index: int, value: float) -> void:
	var clamped := clampi(roundi(value * 32767.0), -32768, 32767)
	buf.encode_s16(index * 2, clamped)


static func _build_pop() -> AudioStreamWAV:
	var count := int(RATE * 0.085)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	for i in count:
		var t := float(i) / float(RATE)
		var env := exp(-t * 42.0)
		var freq := lerpf(320.0, 95.0, minf(1.0, t / 0.05))
		phase += TAU * freq / float(RATE)
		var air := rng.randf_range(-1.0, 1.0) * exp(-t * 85.0) * 0.35
		_write_sample(data, i, (sin(phase) * 0.72 + air) * env * 0.65)
	return _make_wav(data)


static func _build_splat() -> AudioStreamWAV:
	var count := int(RATE * 0.11)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var low := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 73
	for i in count:
		var t := float(i) / float(RATE)
		var env := exp(-t * 30.0)
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.22)
		var freq := lerpf(190.0, 75.0, minf(1.0, t / 0.07))
		phase += TAU * freq / float(RATE)
		_write_sample(data, i, (low * 0.75 + sin(phase) * 0.35) * env * 0.55)
	return _make_wav(data)


static func _build_tag() -> AudioStreamWAV:
	var count := int(RATE * 0.22)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		var freq := 660.0 if t < 0.08 else 880.0
		var local_t := t if t < 0.08 else t - 0.08
		var env := exp(-local_t * 18.0)
		phase += TAU * freq / float(RATE)
		_write_sample(data, i, (sin(phase) + sin(phase * 2.0) * 0.2) * env * 0.45)
	return _make_wav(data)


static func _build_tagged() -> AudioStreamWAV:
	var count := int(RATE * 0.20)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		var freq := lerpf(310.0, 140.0, minf(1.0, t / 0.18))
		var env := exp(-t * 14.0)
		phase += TAU * freq / float(RATE)
		_write_sample(data, i, sin(phase) * env * 0.50)
	return _make_wav(data)


static func _build_tick(final_bell: bool) -> AudioStreamWAV:
	var duration := 0.32 if final_bell else 0.07
	var count := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var freq := 784.0 if final_bell else 520.0
	for i in count:
		var t := float(i) / float(RATE)
		var env := exp(-t * (9.0 if final_bell else 40.0))
		phase += TAU * freq / float(RATE)
		var tone := sin(phase)
		if final_bell:
			tone = (tone + sin(phase * 1.25) * 0.5 + sin(phase * 1.5) * 0.4) * 0.55
		_write_sample(data, i, tone * env * 0.42)
	return _make_wav(data)


static func _stream(kind: String) -> AudioStreamWAV:
	if not _streams.has(kind):
		match kind:
			"pop": _streams[kind] = _build_pop()
			"splat": _streams[kind] = _build_splat()
			"tag": _streams[kind] = _build_tag()
			"tagged": _streams[kind] = _build_tagged()
			"tick": _streams[kind] = _build_tick(false)
			"finish": _streams[kind] = _build_tick(true)
	return _streams[kind] as AudioStreamWAV


static func play(host: Node, kind: String, volume_db := -6.0, pitch := 1.0) -> void:
	if not _enabled() or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var player := AudioStreamPlayer.new()
	player.stream = _stream(kind)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	host.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
