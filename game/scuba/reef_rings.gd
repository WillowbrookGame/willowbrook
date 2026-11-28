extends Node3D
## Eight glowing Musical Bubble Rings winding through the reef and Coral Arch.
## Pure local swim-through fun: ascending C-major scale, no fin boost, no timer.

signal ring_passed(passed: int, total: int, completed: bool)

const OPENING_RADIUS := 1.55
const RESET_DELAY := 4.0
const RATE := 22050
# C5, D5, E5, F5, G5, A5, B5, C6
const SCALE_FREQS := [523.25, 587.33, 659.25, 698.46, 783.99, 880.00, 987.77, 1046.50]

var placements: Node3D
var rings: Array[Dictionary] = []
var passed_count := 0
var _elapsed := 0.0
var _reset_timer := 0.0
var _last_diver_pos := Vector3.ZERO
var _has_last_pos := false

static var _hoop_mesh: TorusMesh
static var _bead_mesh: SphereMesh
static var _active_mat: StandardMaterial3D
static var _passed_mat: StandardMaterial3D
static var _note_cache: Dictionary = {}


func _ready() -> void:
	_ensure_shared_meshes()
	var reef := get_parent() as Node3D
	for marker: Marker3D in placements.find_children("*", "Marker3D", false):
		var placement := reef.global_transform.affine_inverse() * marker.global_transform
		var node := _build_ring_node(placement.orthonormalized())
		add_child(node)
		rings.append({
			"base": node.position,
			"node": node,
			"hoop": node.get_node("Hoop") as MeshInstance3D,
			"phase": float(rings.size()) * 0.85,
			"passed": false,
		})


func total_count() -> int:
	return rings.size()


func check_diver(diver_pos: Vector3) -> void:
	if not _has_last_pos:
		_last_diver_pos = diver_pos
		_has_last_pos = true
		return
	var prev := _last_diver_pos
	_last_diver_pos = diver_pos
	if _reset_timer > 0.0:
		return
	for entry: Dictionary in rings:
		if bool(entry.passed):
			continue
		var node: Node3D = entry.node
		var local_prev := node.to_local(prev)
		var local_curr := node.to_local(diver_pos)
		var crossed := (local_prev.z < 0.0 and local_curr.z >= 0.0) or (local_prev.z > 0.0 and local_curr.z <= 0.0)
		if not crossed:
			continue
		var dz := local_curr.z - local_prev.z
		if absf(dz) < 0.00001:
			continue
		var t := -local_prev.z / dz
		var hit_xy := Vector2(lerpf(local_prev.x, local_curr.x, t), lerpf(local_prev.y, local_curr.y, t))
		if hit_xy.length() <= OPENING_RADIUS:
			entry.passed = true
			passed_count += 1
			var hoop: MeshInstance3D = entry.hoop
			hoop.material_override = _passed_mat
			_spawn_ring_bubbles(node.position)
			var done := passed_count >= rings.size()
			_play_note(passed_count, done)
			if done:
				_reset_timer = RESET_DELAY
			ring_passed.emit(passed_count, rings.size(), done)


func _reset_rings() -> void:
	passed_count = 0
	_reset_timer = 0.0
	_has_last_pos = false
	for entry: Dictionary in rings:
		entry.passed = false
		var hoop: MeshInstance3D = entry.hoop
		hoop.material_override = _active_mat


func _process(delta: float) -> void:
	_elapsed += delta
	if _reset_timer > 0.0:
		_reset_timer = maxf(0.0, _reset_timer - delta)
		if _reset_timer <= 0.0:
			_reset_rings()
	for entry: Dictionary in rings:
		var node: Node3D = entry.node
		var base: Vector3 = entry.base
		var phase: float = float(entry.phase)
		node.position = base + Vector3(0.0, sin(_elapsed * 1.6 + phase) * 0.16, 0.0)


static func _ensure_shared_meshes() -> void:
	if _hoop_mesh != null:
		return
	_hoop_mesh = TorusMesh.new()
	_hoop_mesh.inner_radius = 1.48
	_hoop_mesh.outer_radius = 1.66
	_hoop_mesh.rings = 24
	_hoop_mesh.ring_segments = 10

	_bead_mesh = SphereMesh.new()
	_bead_mesh.radius = 0.12
	_bead_mesh.height = 0.24
	_bead_mesh.radial_segments = 10
	_bead_mesh.rings = 6

	_active_mat = StandardMaterial3D.new()
	_active_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_active_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_active_mat.albedo_color = Color(0.54, 0.96, 1.0, 0.56)

	_passed_mat = StandardMaterial3D.new()
	_passed_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_passed_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_passed_mat.albedo_color = Color(1.0, 0.94, 0.62, 0.22)


func _build_ring_node(placement: Transform3D) -> Node3D:
	var root := Node3D.new()
	root.transform = placement

	var hoop := MeshInstance3D.new()
	hoop.name = "Hoop"
	hoop.mesh = _hoop_mesh
	hoop.material_override = _active_mat
	# Stand the torus vertically so divers swim cleanly through the open center.
	hoop.rotation.x = PI * 0.5
	hoop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hoop)

	for i in 6:
		var angle := (TAU / 6.0) * float(i)
		var bead := MeshInstance3D.new()
		bead.mesh = _bead_mesh
		bead.material_override = _active_mat
		bead.position = Vector3(cos(angle) * 1.58, sin(angle) * 1.58, 0.0)
		bead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(bead)
	return root


func _spawn_ring_bubbles(at: Vector3) -> void:
	if not is_inside_tree():
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.76, 0.98, 1.0, 0.78)
	for i in 8:
		var angle := (TAU / 8.0) * float(i)
		var bubble := MeshInstance3D.new()
		bubble.mesh = _bead_mesh
		bubble.material_override = mat
		bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bubble)
		var start := at + Vector3(cos(angle) * 1.4, sin(angle) * 1.4, 0.0)
		bubble.global_position = start
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(bubble, "global_position", start + Vector3(cos(angle) * 0.45, 1.35, sin(angle) * 0.35), 0.52).set_ease(Tween.EASE_OUT)
		tween.tween_property(bubble, "scale", Vector3.ONE * 0.08, 0.52).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(bubble.queue_free)


static func _build_note(index: int, final_chord: bool) -> AudioStreamWAV:
	var duration := 0.58 if final_chord else 0.30
	var samples := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var freq: float = SCALE_FREQS[clampi(index - 1, 0, SCALE_FREQS.size() - 1)]
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	for i in samples:
		var t := float(i) / float(RATE)
		var env := exp(-t * (5.0 if final_chord else 10.5))
		p1 += TAU * freq / float(RATE)
		var wave := sin(p1) * 0.70 + sin(p1 * 2.0) * 0.16
		if final_chord:
			p2 += TAU * (freq * 0.75) / float(RATE)
			p3 += TAU * (freq * 0.625) / float(RATE)
			if t > 0.05:
				wave += sin(p2) * 0.40
			if t > 0.10:
				wave += sin(p3) * 0.40
		var clamped := clampi(roundi(wave * env * 0.40 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, clamped)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _play_note(count: int, final_chord: bool) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var key := "%d_%s" % [count, final_chord]
	if not _note_cache.has(key):
		_note_cache[key] = _build_note(count, final_chord)
	var player := AudioStreamPlayer.new()
	player.stream = _note_cache[key]
	player.volume_db = -6.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
