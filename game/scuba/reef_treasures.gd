extends Node3D
## Six Sunken Reef Treasures chosen per dive from 18 hand-placed spots across all 5 zones.
## Pure local per-diver discovery: no timer, no Stars, no extra buttons.

signal treasure_found(title: String, found: int, total: int)

const PICKUP_RADIUS := 2.2
const RATE := 22050
const CHIME_FREQS := [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5]
const TOTAL_TREASURES := 6

var placements: Node3D
var items: Array[Dictionary] = []
var found_count := 0
var _elapsed := 0.0
var _rng := RandomNumberGenerator.new()

static var _pearl_mesh: SphereMesh
static var _shell_mesh: CylinderMesh
static var _ring_mesh: TorusMesh
static var _bubble_mesh: SphereMesh
static var _shell_mat: StandardMaterial3D
static var _chime_cache: Dictionary = {}


func _ready() -> void:
	_ensure_shared_meshes()
	_rng.randomize()
	var chosen := _select_dive_spots()
	for i in chosen.size():
		var spec: Dictionary = chosen[i]
		var node := _build_treasure_node(spec)
		add_child(node)
		items.append({
			"id": String(spec.id),
			"title": String(spec.title),
			"base": spec.pos as Vector3,
			"color": spec.color as Color,
			"node": node,
			"phase": float(i) * 1.1,
			"found": false,
		})


func candidate_pools() -> Array[Dictionary]:
	var reef := get_parent() as Node3D
	var pools: Array[Dictionary] = []
	for pool in placements.get_children():
		var spots: Array[Dictionary] = []
		for marker: Marker3D in pool.find_children("*", "Marker3D", false):
			spots.append({
				"id": String(marker.name),
				"title": String(marker.get_meta("title", marker.name)),
				"pos": reef.to_local(marker.global_position),
				"color": marker.get_meta("color", Color.WHITE),
			})
		pools.append({"pick": int(pool.get_meta("pick", 1)), "spots": spots})
	return pools


func _select_dive_spots() -> Array[Dictionary]:
	var selected: Array[Dictionary] = []
	for pool_entry: Dictionary in candidate_pools():
		var candidates: Array = pool_entry.spots
		for i in range(candidates.size() - 1, 0, -1):
			var j := _rng.randi_range(0, i)
			var swap: Variant = candidates[i]
			candidates[i] = candidates[j]
			candidates[j] = swap
		var take := mini(int(pool_entry.pick), candidates.size())
		for i in take:
			selected.append(candidates[i] as Dictionary)
	return selected


func total_count() -> int:
	return items.size()


func check_diver(diver_pos: Vector3) -> void:
	var radius_sq := PICKUP_RADIUS * PICKUP_RADIUS
	for entry: Dictionary in items:
		if bool(entry.found):
			continue
		var node: Node3D = entry.node
		if diver_pos.distance_squared_to(node.position) <= radius_sq:
			entry.found = true
			found_count += 1
			node.hide()
			_spawn_bubble_burst(node.position, entry.color as Color)
			_play_chime(found_count)
			treasure_found.emit(String(entry.title), found_count, items.size())


func _process(delta: float) -> void:
	_elapsed += delta
	for entry: Dictionary in items:
		if bool(entry.found):
			continue
		var node: Node3D = entry.node
		var base: Vector3 = entry.base
		var phase: float = float(entry.phase)
		node.position = base + Vector3(0.0, sin(_elapsed * 2.1 + phase) * 0.22, 0.0)
		node.rotation.y = _elapsed * 0.85 + phase


static func _ensure_shared_meshes() -> void:
	if _pearl_mesh != null:
		return
	_pearl_mesh = SphereMesh.new()
	_pearl_mesh.radius = 0.28
	_pearl_mesh.height = 0.56
	_pearl_mesh.radial_segments = 14
	_pearl_mesh.rings = 8

	_shell_mesh = CylinderMesh.new()
	_shell_mesh.top_radius = 0.44
	_shell_mesh.bottom_radius = 0.36
	_shell_mesh.height = 0.14
	_shell_mesh.radial_segments = 12

	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.56
	_ring_mesh.outer_radius = 0.64
	_ring_mesh.rings = 14
	_ring_mesh.ring_segments = 8

	_bubble_mesh = SphereMesh.new()
	_bubble_mesh.radius = 0.11
	_bubble_mesh.height = 0.22
	_bubble_mesh.radial_segments = 10
	_bubble_mesh.rings = 6

	_shell_mat = StandardMaterial3D.new()
	_shell_mat.albedo_color = Color("#f4dfd0")
	_shell_mat.roughness = 0.55


func _build_treasure_node(spec: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = String(spec.id)
	root.position = spec.pos as Vector3
	var tint: Color = spec.color

	var lower := MeshInstance3D.new()
	lower.mesh = _shell_mesh
	lower.material_override = _shell_mat
	lower.position = Vector3(0.0, -0.22, 0.0)
	lower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lower)

	var lid := MeshInstance3D.new()
	lid.mesh = _shell_mesh
	lid.material_override = _shell_mat
	lid.position = Vector3(0.0, 0.14, -0.24)
	lid.rotation.x = -0.95
	lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(lid)

	var orb_mat := StandardMaterial3D.new()
	orb_mat.albedo_color = tint
	orb_mat.emission_enabled = true
	orb_mat.emission = tint
	orb_mat.emission_energy_multiplier = 1.45
	orb_mat.roughness = 0.2

	var orb := MeshInstance3D.new()
	orb.mesh = _pearl_mesh
	orb.material_override = orb_mat
	orb.position = Vector3(0.0, 0.04, 0.02)
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(orb)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.42)

	var ring := MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	return root


func _spawn_bubble_burst(at: Vector3, tint: Color) -> void:
	if not is_inside_tree():
		return
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(tint.r, tint.g, tint.b, 0.78)
	var offsets := [
		Vector3(0.55, 0.9, 0.35), Vector3(-0.55, 1.0, 0.30),
		Vector3(0.30, 1.2, -0.50), Vector3(-0.35, 1.1, -0.45),
		Vector3(0.05, 1.45, 0.10), Vector3(-0.12, 0.8, 0.55),
		Vector3(0.45, 1.35, -0.10), Vector3(-0.48, 1.3, 0.05),
	]
	for offset: Vector3 in offsets:
		var bubble := MeshInstance3D.new()
		bubble.mesh = _bubble_mesh
		bubble.material_override = mat
		bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bubble)
		bubble.global_position = at
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(bubble, "global_position", at + offset, 0.55).set_ease(Tween.EASE_OUT)
		tween.tween_property(bubble, "scale", Vector3.ONE * 0.08, 0.55).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(bubble.queue_free)


static func _build_chime(count: int) -> AudioStreamWAV:
	var final := count >= TOTAL_TREASURES
	var duration := 0.52 if final else 0.28
	var samples := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(samples * 2)
	var base_freq: float = CHIME_FREQS[clampi(count - 1, 0, CHIME_FREQS.size() - 1)]
	var p1 := 0.0
	var p2 := 0.0
	var p3 := 0.0
	for i in samples:
		var t := float(i) / float(RATE)
		var env := exp(-t * (5.5 if final else 11.0))
		p1 += TAU * base_freq / float(RATE)
		p2 += TAU * (base_freq * 1.25) / float(RATE)
		p3 += TAU * (base_freq * 1.5) / float(RATE)
		var wave := sin(p1) * 0.65 + sin(p1 * 2.0) * 0.18
		if final and t > 0.08:
			wave += sin(p2) * 0.45 + sin(p3) * 0.40
		elif t > 0.07:
			wave += sin(p3) * 0.35
		var clamped := clampi(roundi(wave * env * 0.42 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, clamped)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


func _play_chime(count: int) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	if not _chime_cache.has(count):
		_chime_cache[count] = _build_chime(count)
	var player := AudioStreamPlayer.new()
	player.stream = _chime_cache[count]
	player.volume_db = -6.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
