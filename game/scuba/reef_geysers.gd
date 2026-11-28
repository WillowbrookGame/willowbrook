extends Node3D
## Deep-floor bubble geysers that gently lift divers upward like natural elevators.
## Zero extra buttons; divers can steer freely or hold dive to leave any time.

const GEYSER_RADIUS := 2.15
const LIFT_SPEED := 4.2
const BUBBLES_PER_GEYSER := 10
const RATE := 22050

var placements: Node3D
var geysers: Array[Dictionary] = []
var _elapsed := 0.0
var _in_geyser := false
var _whoosh_cooldown := 0.0

static var _vent_mesh: CylinderMesh
static var _ring_mesh: TorusMesh
static var _bubble_mesh: SphereMesh
static var _vent_mat: StandardMaterial3D
static var _bubble_mat: StandardMaterial3D
static var _whoosh_stream: AudioStreamWAV


func _ready() -> void:
	_ensure_shared()
	var reef := get_parent() as Node3D
	for marker: Marker3D in placements.find_children("*", "Marker3D", false):
		var top := marker.get_node("Top") as Marker3D
		var base := reef.to_local(marker.global_position)
		var top_y := reef.to_local(top.global_position).y
		var root := Node3D.new()
		root.name = String(marker.name)
		root.position = base
		add_child(root)

		var vent := MeshInstance3D.new()
		vent.mesh = _vent_mesh
		vent.material_override = _vent_mat
		vent.position.y = 0.14
		vent.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(vent)

		var ring := MeshInstance3D.new()
		ring.mesh = _ring_mesh
		ring.material_override = _bubble_mat
		ring.position.y = 0.30
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)

		var bubbles: Array[MeshInstance3D] = []
		for i in BUBBLES_PER_GEYSER:
			var b := MeshInstance3D.new()
			b.mesh = _bubble_mesh
			b.material_override = _bubble_mat
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(b)
			bubbles.append(b)

		geysers.append({
			"id": String(marker.name),
			"base": base,
			"top_y": top_y,
			"height": maxf(2.0, top_y - base.y),
			"phase": float(geysers.size()) * 1.7,
			"bubbles": bubbles,
		})
	_update_bubbles()


func updraft_at(diver_pos: Vector3, holding_sink := false) -> float:
	if holding_sink:
		_in_geyser = false
		return 0.0
	var radius_sq := GEYSER_RADIUS * GEYSER_RADIUS
	var best_lift := 0.0
	for g: Dictionary in geysers:
		var base: Vector3 = g.base
		var top_y: float = float(g.top_y)
		if diver_pos.y < base.y - 0.5 or diver_pos.y > top_y:
			continue
		var dx := diver_pos.x - base.x
		var dz := diver_pos.z - base.z
		var dist_sq := dx * dx + dz * dz
		if dist_sq <= radius_sq:
			var radial := 1.0 - clampf(sqrt(dist_sq) / GEYSER_RADIUS, 0.0, 1.0) * 0.35
			var top_taper := clampf((top_y - diver_pos.y) / 2.2, 0.0, 1.0)
			best_lift = maxf(best_lift, LIFT_SPEED * radial * top_taper)
	var now_in := best_lift > 0.25
	if now_in and not _in_geyser and _whoosh_cooldown <= 0.0:
		_play_whoosh()
		_whoosh_cooldown = 1.2
	_in_geyser = now_in
	return best_lift


func _process(delta: float) -> void:
	_elapsed += delta
	_whoosh_cooldown = maxf(0.0, _whoosh_cooldown - delta)
	_update_bubbles()


func _update_bubbles() -> void:
	for g: Dictionary in geysers:
		var height: float = float(g.height)
		var phase: float = float(g.phase)
		var bubbles: Array = g.bubbles
		for i in bubbles.size():
			var b: MeshInstance3D = bubbles[i]
			var frac := fposmod(_elapsed * 0.28 + float(i) / float(bubbles.size()) + phase * 0.1, 1.0)
			var angle := _elapsed * 1.6 + float(i) * 1.3 + phase
			var sway := 0.45 + frac * 0.65
			b.position = Vector3(cos(angle) * sway, 0.35 + frac * height, sin(angle) * sway)
			var sz := lerpf(0.65, 1.45, sin(frac * PI))
			b.scale = Vector3.ONE * sz


static func _ensure_shared() -> void:
	if _vent_mesh != null:
		return
	_vent_mesh = CylinderMesh.new()
	_vent_mesh.top_radius = 0.72
	_vent_mesh.bottom_radius = 1.15
	_vent_mesh.height = 0.28
	_vent_mesh.radial_segments = 12

	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.52
	_ring_mesh.outer_radius = 0.72
	_ring_mesh.rings = 14
	_ring_mesh.ring_segments = 8

	_bubble_mesh = SphereMesh.new()
	_bubble_mesh.radius = 0.16
	_bubble_mesh.height = 0.32
	_bubble_mesh.radial_segments = 10
	_bubble_mesh.rings = 6

	_vent_mat = StandardMaterial3D.new()
	_vent_mat.albedo_color = Color("#4a5d63")
	_vent_mat.roughness = 0.85

	_bubble_mat = StandardMaterial3D.new()
	_bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bubble_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bubble_mat.albedo_color = Color(0.66, 0.96, 1.0, 0.48)


static func _build_whoosh() -> AudioStreamWAV:
	var count := int(RATE * 0.36)
	var data := PackedByteArray()
	data.resize(count * 2)
	var low := 0.0
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 211
	for i in count:
		var t := float(i) / float(RATE)
		var env := sin(minf(1.0, t / 0.36) * PI)
		low = lerpf(low, rng.randf_range(-1.0, 1.0), 0.14)
		var freq := lerpf(160.0, 420.0, t / 0.36)
		phase += TAU * freq / float(RATE)
		var wave := (low * 0.55 + sin(phase) * 0.30) * env * 0.35
		data.encode_s16(i * 2, clampi(roundi(wave * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _play_whoosh() -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	if _whoosh_stream == null:
		_whoosh_stream = _build_whoosh()
	var player := AudioStreamPlayer.new()
	player.stream = _whoosh_stream
	player.volume_db = -9.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
