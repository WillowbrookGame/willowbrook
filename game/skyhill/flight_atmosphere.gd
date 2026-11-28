extends Node3D
## Local presentation only. Never feeds back into the flight or network model.

const SOCK_SHADER := preload("res://game/skyhill/windsock_flutter.gdshader")
const RATE := 22050
const TRAIL_AGE := 0.56
const MAX_SAMPLES := 29
const SAMPLE_STEP := 0.025

@export var windsocks: Node3D
@export var left_tip: Marker3D
@export var right_tip: Marker3D

@onready var wind: AudioStreamPlayer = $Wind
@onready var cue: AudioStreamPlayer = $Cue
@onready var ribbons: MeshInstance3D = $WingtipTrails
var _mesh := ImmediateMesh.new()
var _streams := {}
var _cloth: Array[ShaderMaterial] = []
var _points: Array = [[], []]
var _sample_timer := 0.0
var _clock := 0.0
var _silenced := false

func _ready() -> void:
	ribbons.mesh = _mesh
	for sock in windsocks.get_children() if is_instance_valid(windsocks) else []:
		var art := sock.get_node("Art")
		var fabric := art as MeshInstance3D
		if fabric == null:
			var meshes := art.find_children("*", "MeshInstance3D", true, false)
			if meshes.is_empty():
				continue
			fabric = meshes[0] as MeshInstance3D
		var original := fabric.get_active_material(0) as BaseMaterial3D
		if original == null or original.albedo_texture == null:
			continue
		var material := ShaderMaterial.new()
		material.shader = SOCK_SHADER
		material.set_shader_parameter("palette", original.albedo_texture)
		fabric.material_override = material
		_cloth.append(material)
	for path in get_children():
		if path is Path3D:
			var follower := path.get_node("Follow") as PathFollow3D
			follower.progress_ratio = float(path.get_meta("phase")) / 7.0
			for part in path.find_children("*", "MeshInstance3D", true, false):
				part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if DisplayServer.get_name() == "headless":
		return
	wind.stream = _make_sound("wind", 2.4)
	for pair in [["launch", .54], ["touchdown", .64], ["crash", .39]]:
		_streams[pair[0]] = _make_sound(pair[0], pair[1])

func play_cue(event: String) -> void:
	if event != "launch":
		wind.stop()
	if _silenced or not _streams.has(event):
		return
	cue.stream = _streams[event]
	cue.play()

func reset_flight() -> void:
	wind.stop()
	cue.stop()
	clear_trails()

func set_suspended(value: bool) -> void:
	_silenced = value
	if value:
		reset_flight()

func tick(delta: float, flying: bool, speed: float, bank: float, lift: float) -> void:
	if _silenced:
		return
	_clock += delta
	for path in get_children():
		if path is Path3D:
			var follower := path.get_node("Follow") as PathFollow3D
			var bird := follower.get_node("Bird") as Node3D
			follower.progress += float(path.get_meta("speed")) * delta
			var phase := _clock + float(path.get_meta("phase"))
			var flap := sin(phase * TAU * 2.35) * smoothstep(.35, .86, sin(phase * .79))
			bird.get_node("WingLeft").rotation.z = -.06 + flap * .42
			bird.get_node("WingRight").rotation.z = .06 - flap * .42
	for i in _cloth.size():
		_cloth[i].set_shader_parameter("sock_phase", _clock * 5.0 + i * 1.3)
	if flying and wind.stream != null:
		if not wind.playing:
			wind.play()
		var rush := clampf(inverse_lerp(8.0, 22.0, speed), 0.0, 1.0)
		var target := lerpf(-29.0, -16.0, rush) + minf(absf(bank) * 5.0, 1.5)
		wind.volume_db = lerpf(wind.volume_db, target, 1.0 - exp(-5.0 * delta))
	elif wind.playing:
		wind.stop()
	_tick_trails(delta, flying, maxf(smoothstep(.08, .31, absf(bank)), smoothstep(.12, .85, lift)))

func clear_trails() -> void:
	for trail in _points:
		trail.clear()
	_mesh.clear_surfaces()
	_sample_timer = 0.0

func _tick_trails(delta: float, flying: bool, intensity: float) -> void:
	_sample_timer += delta
	if flying and is_instance_valid(left_tip) and is_instance_valid(right_tip) and intensity > .01 and _sample_timer >= SAMPLE_STEP:
		_sample_timer = fmod(_sample_timer, SAMPLE_STEP)
		for side in 2:
			var tip := left_tip if side == 0 else right_tip
			var trail: Array = _points[side]
			trail.append([to_local(tip.global_position), _clock, intensity])
			if trail.size() > MAX_SAMPLES:
				trail.pop_front()
	_mesh.clear_surfaces()
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return
	var eye := to_local(camera.global_position)
	for trail in _points:
		while not trail.is_empty() and _clock - float(trail[0][1]) >= TRAIL_AGE:
			trail.pop_front()
		if trail.size() < 2:
			continue
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in trail.size():
			var center: Vector3 = trail[i][0]
			var before: Vector3 = trail[maxi(0, i - 1)][0]
			var after: Vector3 = trail[mini(trail.size() - 1, i + 1)][0]
			var across := (after - before).cross(eye - center).normalized()
			var fade := 1.0 - clampf((_clock - float(trail[i][1])) / TRAIL_AGE, 0.0, 1.0)
			var width := .10 * fade
			var opacity := .28 * fade * float(trail[i][2])
			# Drop alpha at the oldest end as well as across activation gaps.
			if i > 0 and float(trail[i][1]) - float(trail[i-1][1]) > .085:
				opacity = 0.0
			_mesh.surface_set_color(Color(.80, .96, 1.0, opacity))
			_mesh.surface_add_vertex(center - across * width)
			_mesh.surface_add_vertex(center + across * width)
		_mesh.surface_end()

func _make_sound(kind: String, seconds: float) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7415 + kind.length()
	var waves := PackedByteArray()
	var count := int(seconds * RATE)
	waves.resize(count * 2)
	var slow := 0.0
	var soft := 0.0
	if kind == "wind":
		# Prime the filters with the end of the same noise sequence so the loop has no seam.
		for _i in count - 512:
			rng.randf_range(-1.0, 1.0)
		for _i in 512:
			var noise := rng.randf_range(-1.0, 1.0)
			slow = lerpf(slow, noise, .025)
			soft = lerpf(soft, noise, .18)
		rng.seed = 7415 + kind.length()
	for i in count:
		var t := float(i) / RATE
		var p := float(i) / count
		var noise := rng.randf_range(-1.0, 1.0)
		slow = lerpf(slow, noise, .025)
		soft = lerpf(soft, noise, .18)
		var sample := 0.0
		match kind:
			"wind":
				sample = slow * .75 + soft * .35
			"launch":
				sample = soft * .57 * pow(sin(PI * p), 1.6) + slow * .29 * sin(PI * p)
			"touchdown":
				sample = (soft * .47 + noise * .07) * smoothstep(0.0, .04, p) * pow(1.0 - p, 2.0)
			"crash":
				sample = (sin(TAU * (124.0 * t - 70.0 * t * t)) * .25 + soft * .36) * smoothstep(0.0, .035, p) * pow(1.0 - p, 3.0)
		waves.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = waves
	if kind == "wind":
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream
