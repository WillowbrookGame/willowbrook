extends Node3D
## Personal, optional flight goals. No collision, timers, save data, or networking.
const ROUTE_NAMES := ["Meadow rings", "Ridge rings"]
const NOTES := [523.25,587.33,659.25,698.46,783.99,880.0,987.77,1046.50]
const BULLSEYE_RADIUS := 4.0
const GREAT_RADIUS := 9.0
@onready var routes := [$MeadowTrail.get_children(), $RidgeTrail.get_children()]
var next := [0,0]
var _original_materials: Array[Material] = []
var _passed_material := StandardMaterial3D.new()
var _chime := AudioStreamPlayer.new()
var _tones: Array[AudioStreamWAV] = []
var landing_text := ""

func _ready() -> void:
	_passed_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_passed_material.albedo_color = Color("#547a88")
	for rings: Array in routes:
		var first: MeshInstance3D = rings[0]
		_original_materials.append(first.material_override)
	if DisplayServer.get_name() != "headless":
		for frequency in NOTES:
			_tones.append(_make_note(float(frequency)))
		_chime.volume_db = -15.0
	add_child(_chime)

func reset_flight() -> void:
	_chime.stop()
	landing_text = ""
	for i in routes.size():
		next[i] = 0
		for ring: MeshInstance3D in routes[i]:
			ring.material_override = _original_materials[i]

func progress_line() -> String:
	var parts: PackedStringArray = []
	for i in routes.size():
		if next[i] > 0:
			var count: int = routes[i].size()
			parts.append("%s: %s" % [ROUTE_NAMES[i], "complete!" if next[i] == count else "%d/%d" % [next[i],count]])
	return "  |  ".join(parts)

func step_segment(from: Vector3, to: Vector3) -> bool:
	var changed := false
	for i in routes.size():
		var low_t := 0.0
		while next[i] < routes[i].size():
			var ring: MeshInstance3D = routes[i][next[i]]
			var hit := segment_hit(ring.to_local(from),ring.to_local(to))
			if hit < low_t:
				break
			low_t = hit
			if next[i] < _tones.size():
				_chime.stream = _tones[next[i]]
				_chime.play()
			ring.material_override = _passed_material
			next[i] += 1
			changed = true
	return changed

# Rings lie in local XZ; normal is local Y. Accept either direction through the
# clear opening, not skimming the rim or flying alongside its plane.
static func segment_hit(from: Vector3, to: Vector3) -> float:
	if is_zero_approx(to.y-from.y) or is_zero_approx(from.y) or from.y*to.y > 0.0:
		return -1.0
	var fraction := from.y / (from.y-to.y)
	var at := from.lerp(to, fraction)
	return fraction if Vector2(at.x,at.z).length_squared() <= 1.0 else -1.0

func score_touchdown(at: Vector3, target: Vector3) -> void:
	var offset := Vector2(at.x-target.x,at.z-target.z).length()
	if offset <= BULLSEYE_RADIUS:
		landing_text = "Bullseye landing!"
	elif offset <= GREAT_RADIUS:
		landing_text = "Great landing!"
	else:
		landing_text = "Nice landing!"

func _make_note(frequency: float) -> AudioStreamWAV:
	const RATE := 22050
	var pcm := PackedByteArray()
	var samples := int(RATE * .17)
	pcm.resize(samples * 2)
	for i in samples:
		var t := float(i)/RATE
		var envelope := minf(1.0,t*170.0)*pow(1.0-float(i)/samples,2.2)
		var value := sin(TAU*frequency*t)*.65 + sin(TAU*frequency*t*2.0)*.18
		pcm.encode_s16(i*2,roundi(value*envelope*32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = pcm
	return wav
