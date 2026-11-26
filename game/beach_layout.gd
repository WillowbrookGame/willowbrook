extends Node3D
## Willowbrook Island preserves the original beach activity coordinates.
const FERRY = preload("res://game/ferry_landing.gd")
const BASE := preload("res://game/beach_base.tscn")
const SCENERY := preload("res://game/beach_scenery.tscn")
const SPAWN := Vector3(0, 0.05, 34)
const TOWN_DOOR := Vector3(0, 0, 38)
const WORLD_BOUNDS := Rect2(-57, -55, 114, 98)
const POLE := Vector3(2.8, 0, 2)
# Interaction happens in the customer aisle, not at the clerk's position inside.
const SHOP_NPC := Vector3(-19, 0, 28.5)
const MARINA_POSITION := Vector3(-19, .48, 32.65)
const FISHER_NPC := Vector3(1.7, 0.55, -31)
const SLIDE_ENTRY := Vector3(-46.05, 0, 3.5)
const SLIDE_SECONDS := 4.35
const SLIDE_CREST_TIME := 2.10
const SLIDE_GLIDE_END := 4.03
# Exact centerline at the top surface of the imported yellow straight chute,
# transformed by the Beach model's .35 scale. x=-46.05 throughout.
const SLIDE_CHUTE := [
	Vector2(7.203,3.521),Vector2(7.553,3.518),Vector2(7.903,3.468),
	Vector2(8.253,3.344),Vector2(8.603,3.156),Vector2(8.953,2.920),
	Vector2(9.303,2.641),Vector2(9.653,2.336),Vector2(10.003,2.014),
	Vector2(10.353,1.688),Vector2(10.703,1.370),Vector2(11.053,1.071),
	Vector2(11.403,.802),Vector2(11.753,.575),Vector2(12.103,.405),
	Vector2(12.453,.298),Vector2(12.803,.267),Vector2(13.503,.266)
]
const ART := "res://game/beach_art/"
const ROD := ART + "beach-fishing/FishingRod_Lvl1.glb"

# Conservative waterline footprints for the two existing moored models;
# these fixed XZ bounds remain valid while the meshes bob in Y.
const MOORING_HULLS := [
	Rect2(20.15,-9.25,2.7,4.5),
	Rect2(41.40,-9.80,3.2,5.6),
]

var departure_only := false
var _boats: Array[Node3D] = []
var _boat_anchors: Array[Vector2] = []

static func is_water(at: Vector3) -> bool:
	if absf(at.x) >= 57.0 or at.z < -55.0 or at.z >= 1.0:
		return false
	var main_dock := (absf(at.x) <= 2.2 and at.z >= -23.0) or (absf(at.x) <= 3.25 and at.z >= -35.0 and at.z <= -23.0)
	var rental_dock := (absf(at.x - 32.0) <= 2.2 and at.z >= -11.0) or (absf(at.x - 32.0) <= 7.0 and at.z >= -11.45 and at.z <= -6.0)
	return not main_dock and not rental_dock and not is_boat_water(at)


static func is_boat_water(at: Vector3) -> bool:
	for hull: Rect2 in MOORING_HULLS:
		if hull.has_point(Vector2(at.x,at.z)):
			return true
	return false


static func slide_is_seated(elapsed: float) -> bool:
	return elapsed >= SLIDE_CREST_TIME and elapsed <= SLIDE_GLIDE_END


static func _slide_surface(z: float) -> float:
	for i in range(1,SLIDE_CHUTE.size()):
		var a: Vector2 = SLIDE_CHUTE[i-1]
		var b: Vector2 = SLIDE_CHUTE[i]
		if z <= b.x:
			return lerpf(a.y,b.y,clampf(inverse_lerp(a.x,b.x,z),0.0,1.0))
	return SLIDE_CHUTE.back().y


static func slide_pitch(elapsed: float) -> float:
	if not slide_is_seated(elapsed):
		return 0.0
	var z := slide_pose(elapsed).z
	return clampf(atan2(_slide_surface(z-.13)-_slide_surface(z+.13),.26)*.77,0.0,.67)


static func slide_pose(elapsed: float) -> Vector3:
	var t := clampf(elapsed,0.0,SLIDE_SECONDS)
	if t < .29:
		return Vector3(SLIDE_ENTRY.x,0.0,lerpf(3.5,5.1,t/.29))
	if t < 1.63:
		var u := inverse_lerp(.29,1.63,t)
		return Vector3(SLIDE_ENTRY.x,lerpf(0.0,3.521,u),lerpf(5.1,6.12,u))
	if t < SLIDE_CREST_TIME:
		return Vector3(SLIDE_ENTRY.x,3.521,lerpf(6.12,7.203,inverse_lerp(1.63,SLIDE_CREST_TIME,t)))
	if t <= SLIDE_GLIDE_END:
		var u := pow(inverse_lerp(SLIDE_CREST_TIME,SLIDE_GLIDE_END,t),1.20)
		var z := lerpf(7.203,13.503,u)
		return Vector3(SLIDE_ENTRY.x,_slide_surface(z),z)
	var u := inverse_lerp(SLIDE_GLIDE_END,SLIDE_SECONDS,t)
	return Vector3(SLIDE_ENTRY.x,lerpf(.266,.04,u),lerpf(13.503,14.35,u))


func _ready() -> void:
	if departure_only:
		add_child(BASE.instantiate())
		return
	var scenery := SCENERY.instantiate() as Node3D
	add_child(scenery)
	var ferry := FERRY.new()
	ferry.name = "FerryLanding"
	add_child(ferry)
	var pier := scenery.get_node("FerryPier") as Node3D
	ferry.global_transform = pier.global_transform
	ferry.build("ISLAND FERRY","To Willowbrook Town",false)
	for boat: Node3D in scenery.get_node("MooredBoats").get_children():
		_boats.append(boat)
		_boat_anchors.append(Vector2(boat.position.y,boat.rotation.z))
	_play_animation(scenery.get_node("Shops/Marina"),"idle")
	var fisher := scenery.get_node("FishingPier/FinnDisplay") as Node3D
	_play_animation(fisher.get_node("Finn"),"holding-right")
	_build_fishing_line(fisher)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _boats.size():
		_boats[i].position.y = _boat_anchors[i].x + sin(t * .7 + i * 2.0) * .035
		_boats[i].rotation.z = _boat_anchors[i].y + sin(t * .5 + i) * .012


func _play_animation(model: Node3D, clip: String) -> void:
	for item in model.find_children("*", "AnimationPlayer", true, false):
		var animation := item as AnimationPlayer
		if animation.has_animation(clip):
			animation.play(clip)
			break


func _build_fishing_line(display: Node3D) -> void:
	var rod := display.get_node("FishingRod") as Node3D
	var bobber := display.get_node("Bobber") as Node3D
	var line := ImmediateMesh.new()
	var white := StandardMaterial3D.new()
	white.albedo_color = Color("#fff4d6")
	white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, white)
	line.surface_add_vertex(rod.transform * Vector3(0,3.4,0))
	line.surface_add_vertex(Vector3(3.9,-.20,0))
	line.surface_add_vertex(bobber.position)
	line.surface_end()
	var item := MeshInstance3D.new()
	item.name = "FishingLine"
	item.mesh = line
	display.add_child(item)


func make_rod(length: float = 2.4) -> Node3D:
	var root := Node3D.new()
	var visual := _new_asset(ROD)
	if visual == null:
		return root
	var bounds := _model_bounds(visual)
	var s := length / maxf(.001, bounds.size.y)
	visual.scale *= s
	visual.position = -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * s
	root.add_child(visual)
	return root


func _new_asset(path: String) -> Node3D:
	var source := load(path) as PackedScene
	return source.instantiate() as Node3D if source != null else null


func _model_bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var found := false
	var candidates := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		candidates.push_front(root)
	for node in candidates:
		var piece := node as MeshInstance3D
		if piece.mesh == null:
			continue
		var t := piece.transform
		var ancestor := piece.get_parent_node_3d()
		while ancestor != null:
			t = ancestor.transform * t
			if ancestor == root:
				break
			ancestor = ancestor.get_parent_node_3d()
		var box := t * piece.get_aabb()
		bounds = bounds.merge(box) if found else box
		found = true
	return bounds
