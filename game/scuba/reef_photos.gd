extends Node
## Scuba-owned Reef Photo Hunt catalog, viewfinder detection, and persistence.
## Keeps photographed reef species completely separate from Fishing catches.

const PROFILE := preload("res://game/progression/profile.gd")
const THUMB_PATH := "res://game/fish_thumbs/"
const MAX_PHOTO_DISTANCE := 14.0
const MIN_VIEW_DOT := 0.72
const RATE := 22050

const CATALOG: Array[Dictionary] = [
	{"id": "clownfish", "species": "Clownfish", "name": "Clownfish", "zone": "Sunbeam Shallows"},
	{"id": "bluetang", "species": "BlueTang", "name": "Blue Tang", "zone": "Sunbeam Shallows"},
	{"id": "butterflyfish", "species": "ButterflyFish", "name": "Butterflyfish", "zone": "Fan Garden"},
	{"id": "coralgrouper", "species": "CoralGrouper", "name": "Coral Grouper", "zone": "Fan Garden"},
	{"id": "parrotfish", "species": "ParrotFish", "name": "Parrotfish", "zone": "Coral Gate"},
	{"id": "tuna", "species": "Tuna", "name": "Tuna", "zone": "Bluewater Wreck"},
	{"id": "shark", "species": "Shark", "name": "Reef Shark", "zone": "Bluewater Wreck"},
	{"id": "sunfish", "species": "Sunfish", "name": "Ocean Sunfish", "zone": "Bluewater Overhang"},
]

static var _shutter_stream: AudioStreamWAV


static func entry_for_id(id: String) -> Dictionary:
	var key := id.to_lower()
	for row: Dictionary in CATALOG:
		if String(row.id) == key or String(row.species).to_lower() == key:
			return row
	return {}


static func resolve_profile(tree: SceneTree) -> RefCounted:
	if tree != null and tree.has_meta("willowbrook_profile"):
		var existing: Variant = tree.get_meta("willowbrook_profile")
		if existing is RefCounted:
			return existing
	var save_path := "user://willowbrook_profile.cfg"
	if tree != null and tree.has_meta("willowbrook_save_override"):
		save_path = str(tree.get_meta("willowbrook_save_override"))
	return PROFILE.new(save_path)


static func browser_session(tree: SceneTree) -> Node:
	if not OS.has_feature("web") or tree == null or tree.root == null:
		return null
	var session := tree.root.get_node_or_null("WillowbrookBrowserSession")
	if session != null and session.has_method("reef_photos_snapshot"):
		return session
	return null


static func dedupe_ids(raw: Variant) -> Array[String]:
	var clean: Array[String] = []
	if not raw is Array:
		return clean
	for item: Variant in raw:
		if item is String:
			var entry := entry_for_id(item)
			if not entry.is_empty():
				var id := String(entry.id)
				if not clean.has(id):
					clean.append(id)
	return clean


static func load_discovered(profile: RefCounted) -> Array[String]:
	if profile == null:
		return []
	var snap: Dictionary = profile.snapshot()
	return dedupe_ids(snap.get("reef_photos", []))


static func load_collection_fishing(profile: RefCounted, session: Node = null) -> Array:
	if session != null:
		if not bool(session.get("admitted")):
			return []
		if session.has_method("fishing_snapshot"):
			var snap: Dictionary = session.fishing_snapshot()
			var discovered: Variant = snap.get("discovered", [])
			if discovered is Array:
				return discovered.duplicate()
		return []
	if profile == null:
		return []
	var local_snap: Dictionary = profile.snapshot()
	var local_discovered: Variant = local_snap.get("fish_discovered", [])
	return local_discovered.duplicate() if local_discovered is Array else []


static func load_collection_reef(profile: RefCounted, session: Node = null) -> Array[String]:
	if session != null:
		if not bool(session.get("admitted")):
			return []
		if session.has_method("reef_photos_snapshot"):
			return dedupe_ids(session.reef_photos_snapshot())
		return []
	return load_discovered(profile)


static func record_photo(species_id: String, profile: RefCounted) -> Dictionary:
	var entry := entry_for_id(species_id)
	if entry.is_empty():
		return {"ok": false, "text": "Unknown reef wildlife."}
	var id := String(entry.id)
	var discovered := load_discovered(profile)
	var is_new := not discovered.has(id)
	if is_new:
		discovered.append(id)
		if profile != null:
			var next: Dictionary = profile.snapshot()
			next.reef_photos = discovered.duplicate()
			if not profile.commit(next):
				return {"ok": false, "text": "Couldn't save your reef photo."}
	return {
		"ok": true,
		"new_discovery": is_new,
		"entry": entry.duplicate(),
		"discovered": discovered,
		"count": discovered.size(),
		"total": CATALOG.size(),
	}


static func capture_in_view(camera: Camera3D, art: Node3D, discovered: Array[String] = []) -> Dictionary:
	if camera == null or art == null:
		return {}
	var forward := -camera.global_basis.z.normalized()
	var origin := camera.global_position
	var best_entry: Dictionary = {}
	var best_score := -INF
	var candidates: Array = []
	candidates.append_array(art._fish)
	candidates.append_array(art._visitors)
	for item: Variant in candidates:
		if not item is Dictionary:
			continue
		var node := item.get("node") as Node3D
		if not is_instance_valid(node):
			continue
		var species_name := String(item.get("species", ""))
		var entry := entry_for_id(species_name)
		if entry.is_empty():
			continue
		var pos := node.global_position
		var offset := pos - origin
		var dist := offset.length()
		if dist < 0.25 or dist > MAX_PHOTO_DISTANCE:
			continue
		var dot := forward.dot(offset / dist)
		if dot < MIN_VIEW_DOT:
			continue
		var is_new := not discovered.has(String(entry.id))
		# Prefer centered, nearby subjects, with a gentle tie-breaker for undiscovered species.
		var score := dot * 2.0 - (dist / MAX_PHOTO_DISTANCE) * 0.65 + (0.12 if is_new else 0.0)
		if score > best_score:
			best_score = score
			best_entry = entry.duplicate()
	return best_entry


static func book_tab(discovered_ids: Array) -> Dictionary:
	var seen := {}
	for raw: Variant in discovered_ids:
		if raw is String:
			seen[raw.to_lower()] = true
	var entries: Array[Dictionary] = []
	for row: Dictionary in CATALOG:
		var id := String(row.id)
		entries.append({
			"id": id,
			"name": String(row.name),
			"thumb": THUMB_PATH + id + ".png",
			"discovered": seen.has(id),
		})
	return {
		"id": "reef",
		"label": "Reef",
		"title": "Reef Photo Book",
		"entries": entries,
	}


static func _build_shutter() -> AudioStreamWAV:
	var count := int(RATE * 0.14)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 409
	var phase := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		var click1 := exp(-t * 95.0) * rng.randf_range(-1.0, 1.0)
		var t2 := maxf(0.0, t - 0.055)
		var click2 := (exp(-t2 * 110.0) * rng.randf_range(-1.0, 1.0)) if t >= 0.055 else 0.0
		phase += TAU * 1320.0 / float(RATE)
		var chime := sin(phase) * exp(-t * 28.0) * 0.18
		var wave := (click1 * 0.48 + click2 * 0.36 + chime) * 0.55
		data.encode_s16(i * 2, clampi(roundi(wave * 32767.0), -32768, 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


static func play_shutter(host: Node) -> void:
	if DisplayServer.get_name() == "headless" or host == null or not host.is_inside_tree():
		return
	if _shutter_stream == null:
		_shutter_stream = _build_shutter()
	var player := AudioStreamPlayer.new()
	player.stream = _shutter_stream
	player.volume_db = -7.0
	host.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
