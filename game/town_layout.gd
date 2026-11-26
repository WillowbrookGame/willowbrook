extends Node3D
## Town's fixed map is authored in town_scenery.tscn. This script only binds
## the parts that change at runtime and retains the existing route contract.
const ROOT := "res://game/town_assets/"
const ROUTES = preload("res://game/town_routes.gd")
const WORLD_BOUNDS := ROUTES.WORLD_BOUNDS
const SPAWN := ROUTES.SPAWN
const ARENA_DOOR := ROUTES.ARENA_DOOR
const ARCADE_DOOR := ROUTES.ARCADE_DOOR
# Exact browser interaction points, separate from art and collision tolerances.
const BUSINESS_DOORS := {
	"bank": Vector3(-56.142857,0,-45), "vet": Vector3(-20.142857,0,-45),
	"salon": Vector3(15.857143,0,-45), "store": Vector3(-16,0,20.5),
	"cafe": Vector3(16,0,20.5), "library": Vector3(-16,0,-19),
	"arcade": ARCADE_DOOR,
}
const BUSINESS_RETURN_OFFSETS := {
	"bank": Vector3(0,0.04,2.2), "vet": Vector3(0,0.04,2.2), "salon": Vector3(0,0.04,2.2),
	"store": Vector3(0,0.04,-2.2), "cafe": Vector3(0,0.04,-2.2),
	"library": Vector3(0,0.04,2.2), "arcade": Vector3(0,0.04,2.2),
}
const HOME_DOORS := [
	Vector3(-51,0,-19),Vector3(-51,0,5),Vector3(-51,0,29),
	Vector3(51,0,-19),Vector3(51,0,5),Vector3(51,0,29),
]
const PLAYGROUND_ENTRIES := {
	"swing-0": Vector3(51,0,49.8), "slide": Vector3(43.15,0,45.1),
	"seesaw-0": Vector3(42.5,0,53.55), "seesaw-1": Vector3(42.5,0,56.45),
}
const OUTDOOR_ROLES := {
	"nursery": Vector3(-23,0,46.6), "park": Vector3(24,0,-26),
	"singing": Vector3(49,0,-47.5), "job_board": Vector3(10,0,4),
	"car_lot": Vector3(19,0,3), "scooter_bay": Vector3(-20,0,5),
}
const BEACH_DOOR := ROUTES.BEACH_DOOR
const BEACH_RETURN := ROUTES.BEACH_RETURN
const SCENERY := preload("res://game/town_scenery.tscn")
const FERRY := preload("res://game/ferry_landing.gd")
const NPC_SCRIPT := preload("res://game/town_npcs.gd")
const SUBURBAN := ROOT + "kenney-suburban/"
const SIDE_DRIVEWAYS := preload("res://game/vehicles/side_driveways.gd")
const DRIVEWAY_ROWS := [-24.0,0.0,24.0]

const HOME_FACADES := {
	"starter": [SUBURBAN + "building-type-a.glb", Vector3(7,6,7), PI],
	"cottage": [SUBURBAN + "building-type-h.glb", Vector3(9,7,8), PI],
	"family": [ROOT + "tiny-homely/house.gltf", Vector3(11,8,10), 0.0],
}
var _facades: Dictionary = {}

@onready var scenery: Node3D = get_node_or_null("TownScenery")
var _starter_facades: Array[Node3D] = []


func _ready() -> void:
	# SceneTree tests can still construct TownLayout directly.
	if scenery == null:
		scenery = SCENERY.instantiate()
		add_child(scenery)
	_apply_scenery_finish()
	for plot in HOME_DOORS.size():
		var starter := scenery.get_node("StarterHomes/HouseExterior_%d" % (plot+1)) as Node3D
		_starter_facades.append(starter)
		_facades[plot] = starter
	var ferry := FERRY.new()
	ferry.name = "FerryLanding"
	add_child(ferry)
	ferry.position = BEACH_DOOR + Vector3(0,.065,0)
	ferry.build("TOWN FERRY","To Willowbrook Island",false)
	var town_npcs := NPC_SCRIPT.new()
	town_npcs.name = "TownNpcs"
	add_child(town_npcs)


func _apply_scenery_finish() -> void:
	# Use Godot's bundled fallback font, not an embedded copy or an OS font.
	for label: Label3D in scenery.find_children("*","Label3D",true,false):
		if label.font is FontVariation:
			label.font.base_font = ThemeDB.fallback_font
	# Inherited meshes stay owned by the original assets. Reapply the
	# original low-cost foliage settings without embedding imported meshes.
	for area in ["Pond","NurseryAndGarden"]:
		for item: Node3D in scenery.get_node(area).find_children("*","Node3D",true,false):
			var file := item.scene_file_path.get_file()
			if file.begins_with("flower_") or file.begins_with("crops_") or file.begins_with("plant_bushSmall") or file.begins_with("lily_"):
				if item is GeometryInstance3D:
					item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				for mesh: GeometryInstance3D in item.find_children("*","GeometryInstance3D",true,false):
					mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var session := get_node_or_null("/root/WillowbrookBrowserSession")
	var uses_garden := OS.has_feature("web") and session != null and session.has_method("tend_garden")
	for name in ["Sign_CommunityGarden","GardenWateringMarker"]:
		scenery.get_node("NurseryAndGarden/"+name).visible = uses_garden


static func driveway_rect(side: int,row: float) -> Rect2:
	return SIDE_DRIVEWAYS.rect(side,row)


static func on_driveway(at: Vector3) -> bool:
	var point := Vector2(at.x,at.z)
	for side: int in [-1,1]:
		for row: float in DRIVEWAY_ROWS:
			if driveway_rect(side,row).has_point(point):
				return true
	return false


## Cosmetic tier comes from the server for all Town viewers, or the offline own plot.
## The road-side portal anchor never moves: upgrades grow into the lot, not the road.
func set_home_exteriors(rows: Array) -> void:
	var requested: Dictionary = {}
	for row in rows:
		if row is Dictionary:
			var plot := int(row.get("plot",-1))
			var variant := str(row.get("variant",""))
			if plot >= 0 and plot < HOME_DOORS.size() and HOME_FACADES.has(variant):
				requested[plot] = variant
	for plot in range(HOME_DOORS.size()):
		_set_home_facade(plot, str(requested.get(plot,"starter")))

func _set_home_facade(plot: int, variant: String) -> void:
	var old := _facades.get(plot) as Node3D
	if is_instance_valid(old) and old.get_meta("variant") == variant:
		return
	var starter := _starter_facades[plot]
	if old == starter:
		starter.hide()
		starter.process_mode = Node.PROCESS_MODE_DISABLED
	elif is_instance_valid(old):
		remove_child(old)
		old.queue_free()
	if variant == "starter":
		starter.process_mode = Node.PROCESS_MODE_INHERIT
		starter.show()
		_facades[plot] = starter
		return
	var info: Array = HOME_FACADES[variant]
	var desired: Vector3 = info[1]
	var model := (load(info[0]) as PackedScene).instantiate() as Node3D
	add_child(model)
	var raw := _measure(model)
	var orientation := Basis(Vector3.UP,float(info[2]))
	var footprint := Transform3D(orientation,Vector3.ZERO) * raw
	var scale_factor := desired / footprint.size
	var anchor: Vector3 = HOME_DOORS[plot]
	# The eaves end just behind the interaction, while a solid wall face starts
	# farther back. Keep the middle of the front approach free at all tiers.
	var front := anchor.z-0.35
	var shifted := Vector3(anchor.x,0,front-desired.z*0.5)
	var centered := Vector3(footprint.get_center().x,footprint.position.y,footprint.get_center().z)
	var shell := Node3D.new()
	shell.name = "HouseExterior_%d" % (plot+1)
	shell.set_meta("variant",variant)
	add_child(shell)
	model.reparent(shell,false)
	model.transform = Transform3D(orientation.scaled(scale_factor),shifted-centered*scale_factor)
	var solid := StaticBody3D.new()
	solid.name = "HouseWalls"
	shell.add_child(solid)
	solid.position = Vector3(anchor.x,1.6,shifted.z-0.27)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	# Exclude eaves and steps, but follow the tier footprint instead of keeping
	# a starter-sized invisible blocker inside a larger facade.
	shape.size = Vector3(desired.x*0.88,3.2,desired.z-1.0)
	shape_node.shape = shape
	solid.add_child(shape_node)
	_facades[plot] = shell

func _measure(model: Node3D) -> AABB:
	# Include actual imported root transforms and every mesh descendant.
	var to_local := global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	var meshes := model.find_children("*","MeshInstance3D",true,false)
	if model is MeshInstance3D:
		meshes.push_back(model)
	for mi: MeshInstance3D in meshes:
		var box := to_local * mi.global_transform * mi.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
