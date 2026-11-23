extends RefCounted
const SPECIES := ["beaver","bee","bunny","cat","caterpillar","chick","cow","crab","deer","dog","elephant","fish","fox","giraffe","hog","koala","lion","monkey","panda","parrot","penguin","pig","polar","tiger"]
const COST := 8
const ROOT := "res://paintball_prototype/interiors/art/kenney-pets/"
static var _models: Dictionary = {}
static var _bounds: Dictionary = {}

static func display(species: String) -> String:
	return "Polar bear" if species=="polar" else species.capitalize()

static func state(profile: Dictionary) -> Dictionary:
	var current: Variant = profile.get("pets")
	if current is Dictionary and current.get("owned") is Array:
		return current.duplicate(true)
	var legacy: String = str(profile.get("pet",{}).get("kind",""))
	if legacy in SPECIES:
		return {"owned":[{"id":"legacy-pet","species":legacy}],"activeId":null}
	return {"owned":[],"activeId":null}

static func active_species(pets: Dictionary) -> String:
	for row: Dictionary in pets.get("owned",[]):
		if row.get("id")==pets.get("activeId") and row.get("species") in SPECIES:
			return String(row.species)
	return ""

static func make(species: String) -> Node3D:
	if species not in SPECIES: return null
	if not _models.has(species):
		_models[species] = load(ROOT+"animal-"+species+".glb")
	var scene: PackedScene = _models[species]
	if scene == null: return null
	var wrapper := Node3D.new()
	var model := scene.instantiate() as Node3D
	wrapper.add_child(model)
	if not _bounds.has(species):
		_bounds[species] = _measure(model,Transform3D.IDENTITY)
	var bounds: AABB = _bounds[species]
	var width := maxf(.01,maxf(bounds.size.x,bounds.size.z))
	var ratio := minf(.63/width,.69/maxf(.01,bounds.size.y))
	model.scale *= ratio
	model.position -= Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*ratio
	return wrapper

static func _measure(node: Node3D,parent_tf: Transform3D) -> AABB:
	var tf := parent_tf*node.transform
	var result := (tf*(node as MeshInstance3D).get_aabb()) if node is MeshInstance3D else AABB()
	for child in node.get_children():
		if child is Node3D:
			var next := _measure(child,tf)
			if next.has_surface():
				result = result.merge(next) if result.has_surface() else next
	return result
