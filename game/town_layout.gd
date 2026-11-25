extends Node3D
## Willowbrook's walkable town uses original web-world coordinates, in meters.
## The host owns interaction, character, and camera; this node owns scenery.
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
const FERRY = preload("res://game/ferry_landing.gd")
const BEACH_DOOR := ROUTES.BEACH_DOOR
const BEACH_RETURN := ROUTES.BEACH_RETURN
const GRASS := Color("#94ba77")
const SAND := Color("#d9b887")
const STONE := Color("#d0c8ad")
const ROAD_ROOT := ROOT + "kenney-roads/"
const SUBURBAN := ROOT + "kenney-suburban/"
const COMMERCIAL := ROOT + "kenney-commercial/"
const TILE := 12
const SIDE_DRIVEWAYS = preload("res://game/vehicles/side_driveways.gd")
const DRIVEWAY_ROWS := [-24.0,0.0,24.0]
const NPC_SCRIPT := preload("res://game/town_npcs.gd")
const SIGN_ART = preload("res://game/landmark_sign_art.gd")
const BUILDING_SIGNS := Color("#374a52")

# Raw asset-local front faces measured from the commercial GLB triangles.
# The decal/plate follows the exact building transform and keeps a tiny
# outward clearance; no portal, collider, facade scale or material is changed.
const COMMERCIAL_FASCIA := {
	"bank":[Vector3(0.0,.353,-.407),Vector2(.72,.083),true,Color("#0d2b1e")],
	"cafe":[Vector3(.065,.353,-.461),Vector2(.72,.083),true,Color.BLACK],
	"store":[Vector3(.022,.351,-.350),Vector2(.68,.083),false,Color("#797347")],
	"vet":[Vector3(0.0,.351,-.410),Vector2(.68,.083),false,Color("#537d68")],
	"salon":[Vector3(-.178,.351,-.275),Vector2(.36,.083),false,Color("#7d476a")],
	"library":[Vector3(-.075,.351,-.356),Vector2(.64,.083),false,Color("#436d71")],
}
const PARK_BENCH_TREE_START := Vector3(21,0,-19.5)
const PARK_BENCH_TREE_SIDE := Vector3(27.4,0,-20.4)
const HOUSE_2_TREE_START := Vector3(-47,0,6.6)
# West of the planned x=-62.65 side fence and x=-62.05 driveway edge.
const HOUSE_2_TREE_SIDE := Vector3(-65.8,0,-2.4)

var materials: Dictionary = {}
var scenes: Dictionary = {}
var dimensions: Dictionary = {}
const HOME_FACADES := {
	"starter": [SUBURBAN + "building-type-a.glb", Vector3(7,6,7), PI],
	"cottage": [SUBURBAN + "building-type-h.glb", Vector3(9,7,8), PI],
	"family": [ROOT + "tiny-homely/house.gltf", Vector3(11,8,10), 0.0],
}
var _facades: Dictionary = {}


func _ready() -> void:
	_box(Vector3(0,-0.25,-35.1), Vector3(300,0.5,189.8), GRASS, true)
	_roads()
	_build_arena_exterior()
	_build_shops()
	_build_park()
	_build_pond()
	_build_beach_approach()
	_build_trees()
	_build_nursery_and_garden()
	_build_recreation()
	_build_concert()
	_build_street_landmarks()
	_build_bays()
	_build_hills()
	var town_npcs := NPC_SCRIPT.new()
	town_npcs.name = "TownNpcs"
	add_child(town_npcs)

func _roads() -> void:
	# Same loops, dimensions and model rotations as public/town-layout.js.
	var cells: Dictionary = {}
	for z in [-3, -1, 1, 3]:
		for x in range(-6, 7):
			cells[Vector2i(x,z)] = true
	for x in [-6, -3, 0, 3, 6]:
		for z in range(-3, 4):
			cells[Vector2i(x,z)] = true
	for cell: Vector2i in cells:
		var n := cells.has(cell + Vector2i(0,-1))
		var s := cells.has(cell + Vector2i(0,1))
		var e := cells.has(cell + Vector2i(1,0))
		var w := cells.has(cell + Vector2i(-1,0))
		var count := int(n) + int(s) + int(e) + int(w)
		var file := "road-straight"
		var yaw := 0.0
		if count == 4:
			file = "road-crossroad"
		elif count == 3:
			file = "road-intersection"
			yaw = 0.0 if not n else PI if not s else PI/2.0 if not w else -PI/2.0
		elif n and s:
			yaw = PI/2.0
		elif not (e and w):
			file = "road-bend-square"
			yaw = PI/2.0 if (e and s) else 0.0 if (s and w) else -PI/2.0 if (w and n) else PI
		var tile := _instance(ROAD_ROOT + file + ".glb")
		tile.name = "Road_%s_%s" % [cell.x,cell.y]
		tile.position = Vector3(cell.x*TILE,0.015,cell.y*TILE)
		# Like the web town, the grid is 12 m wide and curbs only 8 cm high.
		tile.scale = Vector3(TILE, 4, TILE)
		tile.rotation.y = yaw

func _build_arena_exterior() -> void:
	var file := ROOT + "paintball-warehouse/warehouse-exterior.glb"
	var model := _instance(file)
	for node_name in ["RollUpDoor_East","RollUpDoor_West"]:
		var shutter := model.find_child(node_name, true, false) as Node3D
		if shutter != null:
			shutter.position.y = 1
			shutter.scale.y *= 3.0
	for node_name in ["SideDoor_North","SideDoor_South"]:
		var door := model.find_child(node_name, true, false) as Node3D
		if door != null:
			door.rotation = Vector3(0,0 if node_name == "SideDoor_North" else PI,0)
	# The asset has large native dimensions. Restore the web asset's uniform
	# scale and orient it by the same quarter turn, not a 3-axis size target.
	var ratio := 0.32
	var yaw := -PI/2.0
	var raw := _measure(model)
	var rotated := Transform3D(Basis(Vector3.UP,yaw),Vector3.ZERO) * raw
	var center := Vector3(ARENA_DOOR.x,0,ARENA_DOOR.z-0.32-rotated.size.z*ratio*0.5)
	var warehouse := _place(model,raw,center,ratio,yaw)
	warehouse.name = "PaintballWarehouseExterior"
	var size := rotated.size * ratio
	_box(center + Vector3.DOWN * 0.015,Vector3(size.x+1.3,0.05,size.z+1.2),STONE)
	_collider(center + Vector3.UP * (size.y*0.36),Vector3(size.x-0.5,size.y*0.72,size.z-0.12))
	_box(ARENA_DOOR + Vector3(0,0.055,2.95),Vector3(3.4,0.07,5.75),SAND)
	_box(ARENA_DOOR + Vector3(0,1.47,-0.265),Vector3(2.0,2.94,0.14),BUILDING_SIGNS)
	_box(ARENA_DOOR + Vector3(0.67,1.22,-0.163),Vector3(0.13,0.18,0.08),Color("#d8b76b"))
	var board := _sign("PAINTBALL ARENA",ARENA_DOOR + Vector3(0,4.6,-0.30),5.7,0.72,0.0,BUILDING_SIGNS)
	_mount_board(board,Vector2(-2.15,2.15),Vector2(.13,.13))

static func driveway_rect(side: int,row: float) -> Rect2:
	return SIDE_DRIVEWAYS.rect(side,row)


static func on_driveway(at: Vector3) -> bool:
	var point := Vector2(at.x,at.z)
	for side: int in [-1,1]:
		for row: float in DRIVEWAY_ROWS:
			if driveway_rect(side,row).has_point(point):
				return true
	return false


func _build_shops() -> void:
	_build_arcade()
	_business("library","WILLOW LIBRARY","building-e",Vector3(-16,0,-24),6.65,PI,Vector2(0.20,-0.356))
	_business("cafe","SUNNY CAFE","building-g",Vector3(16,0,24),6.9,0.0,Vector2(-0.135,-0.399))
	_business("store","TOWN STORE","building-a",Vector3(-16,0,24),7.25,0.0,Vector2(0.0,-0.42))
	_business("bank","WILLOW BANK","building-f",Vector3(-54,0,-49),6.95,PI,Vector2(0.20,-0.42))
	_business("vet","PET VET","building-d",Vector3(-18,0,-49),8.0,PI,Vector2(0.20,-0.42))
	_business("salon","BEAUTY SALON","building-c",Vector3(18,0,-49),8.0,PI,Vector2(0.20,-0.42))
	for side: int in [-1,1]:
		for i in range(3):
			var at := Vector3(51*side,0,DRIVEWAY_ROWS[i])
			var plot := HOME_DOORS.find(at + Vector3(0,0,5))
			_set_home_facade(plot, "starter")
			var paved := driveway_rect(side,at.z)
			var lane := paved.get_center()
			_box(Vector3(lane.x,0.105,lane.y),Vector3(paved.size.x,0.05,paved.size.y),STONE).name = "Driveway_%d_%d" % [side,i]
			var stop := SIDE_DRIVEWAYS.park(side,at.z)
			for offset: float in [-1.60,1.60]:
				_box(Vector3(lane.x+offset,0.135,stop.y),Vector3(.10,.012,4.25),Color("#faf4dd"))
			_box(Vector3(lane.x,0.135,stop.y-2.125),Vector3(3.2,.012,.10),Color("#faf4dd"))
			_box(Vector3(at.x,0.039,at.z+5.2),Vector3(2.4,0.072,3),STONE)
			# The model’s operable door faces +Z, toward the nearest road at row + 12.
			# Preserve Plot 2's existing numbered mailbox and clear front walk.
			var mailbox_offset := 2.45 if side == -1 and i == 1 else 3.6
			var mailbox := _fit_width(ROOT + "tiny-homely/mailbox.gltf",at + Vector3(mailbox_offset,0,5.75),0.72,0.0)
			mailbox.name = "RoadFacingMailbox_%d_%d" % [side,i]
			_number_mailbox(mailbox,HOME_DOORS.find(Vector3(at.x,0,at.z+5.0)))
			for x in [-3.8,3.8]:
				_fit_width(SUBURBAN + "planter.glb",at + Vector3(x,0,3.7),1.19,0.0)

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
	if is_instance_valid(old):
		remove_child(old)
		old.queue_free()
	var info: Array = HOME_FACADES[variant]
	var desired: Vector3 = info[1]
	var model := _instance(info[0])
	var raw := _asset_bounds(info[0], model)
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

func _number_mailbox(mailbox: Node3D, plot_index: int) -> void:
	if plot_index < 0:
		return
	# Tiny Homely's fixed mailbox door is +Z-facing in both rows. Its flat
	# face is at local z=.15; the plaque overlaps the face, not the flag/handle.
	var door := mailbox.find_child("mailbox_door",true,false) as Node3D
	if not is_instance_valid(door):
		return
	var plate := _box(Vector3.ZERO,Vector3(.43,.23,.018),Color("#344753"))
	plate.name = "HouseNumberPlate"
	plate.reparent(door,false)
	plate.position = Vector3(0,.255,.155)
	var label := Label3D.new()
	label.name = "HouseNumber"
	label.text = str(plot_index+1)
	label.font_size = 54
	label.outline_size = 3
	label.pixel_size = .0028
	label.modulate = Color("#fff2ca")
	label.position.z = .011
	plate.add_child(label)


func _build_arcade() -> void:
	var at := Vector3(0,0,-51)
	var navy := Color("#293e63")
	var arcade := Node3D.new()
	arcade.name = "WillowArcade"
	add_child(arcade)
	var pack := ROOT + "kenney-mini-arcade/"
	for x: int in [-4,-2,0,2,4]:
		_fit_panel(pack + "wall.glb", at + Vector3(x,0,-4),2.0,3.2,0.0).reparent(arcade,true)
		_fit_panel(pack + ("wall-door-rotate.glb" if x == 0 else "wall-window.glb"),
			at + Vector3(x,0,4),2.0,3.2,0.0).reparent(arcade,true)
	for z: int in [-3,-1,1,3]:
		_fit_panel(pack + "wall-window.glb",at + Vector3(-5,0,z),2.0,3.2,PI/2.0).reparent(arcade,true)
		_fit_panel(pack + "wall-window.glb",at + Vector3(5,0,z),2.0,3.2,PI/2.0).reparent(arcade,true)
	_box(at + Vector3(0,3.3,0),Vector3(10.1,0.22,8.1),navy)
	_box(at + Vector3(0,0.028,0),Vector3(9.7,0.05,7.7),Color("#526180"))
	_box(ARCADE_DOOR + Vector3(0,0.026,2.5),Vector3(2.5,0.05,5.3),STONE)
	var board := _sign("WILLOW ARCADE",at + Vector3(0,2.75,4.27),5.4,0.52,0.0,navy)
	_mount_board(board,Vector2(-1.53,1.53),Vector2(.15,.15))
	_collider(at + Vector3(0,1.5,-0.10),Vector3(9.88,3,7.34))
	for entry in [["arcade-machine.glb",-3.4],["claw-machine.glb",-1.6],["vending-machine.glb",2.8]]:
		_fit_height(pack + String(entry[0]),at + Vector3(entry[1],0.05,2.7),1.52,0.0).reparent(arcade,true)

# The original arcade composed independent wall modules on a 2 m seam grid.
# Fit both dimensions with an intentional panel-only conversion, not a building stretch.
func _fit_panel(file: String, at: Vector3, width: float, height: float, yaw: float) -> Node3D:
	var model := _instance(file)
	var bounds := _asset_bounds(file,model)
	var wrapper := Node3D.new()
	add_child(wrapper)
	model.reparent(wrapper,false)
	var anchor := bounds.get_center()
	anchor.y = bounds.position.y
	var factor := Vector3(width/maxf(bounds.size.x,0.01),height/maxf(bounds.size.y,0.01),1.0)
	var turned := Basis(Vector3.UP,yaw)
	var corrected := turned * Basis.from_scale(factor)
	wrapper.transform = Transform3D(corrected,at - corrected*anchor)
	return wrapper

func _business(id: String, title: String, file: String, at: Vector3, ratio: float, yaw: float, native_door: Vector2) -> void:
	var asset := COMMERCIAL + file + ".glb"
	var model := _instance(asset)
	var raw := _asset_bounds(asset,model)
	var anchor := raw.get_center()
	var rotated := Basis(Vector3.UP,yaw)
	var door: Vector3 = BUSINESS_DOORS[id]
	var normal := rotated * Vector3.FORWARD
	var modeled_door := rotated * Vector3(native_door.x-anchor.x,0,native_door.y-anchor.z) * ratio
	# Preserve the model's proportions and align its native doorway with the
	# published portal. Move the decorative shell back slightly so overhanging
	# awnings never become invisible movement blockers at the approach.
	var center := door - modeled_door - normal * 0.47
	center.y = at.y
	var building := _place(model,raw,center,ratio,yaw)
	building.name = title.to_pascal_case()
	var size: Vector3 = building.get_meta("layout_size")
	var wall_face := door - normal * 0.48
	var back := center - normal * (size.z*0.5-0.18)
	var collider_center := (wall_face+back)*0.5
	var depth := absf(wall_face.z-back.z)
	var collider_height := minf(size.y,3.4)
	collider_center.x = center.x
	collider_center.y = collider_height*0.5
	_collider(collider_center,Vector3(size.x*0.91,collider_height,depth))
	_commercial_sign(building,id,title)
	_box(door + normal * 1.12 + Vector3.UP*0.033,Vector3(2.8,0.06,2.75),STONE)

func _commercial_sign(building: Node3D, id: String, title: String) -> void:
	var art: Array = COMMERCIAL_FASCIA[id]
	var face: Vector3 = art[0]
	var extent: Vector2 = art[1]
	var direct: bool = art[2]
	var color: Color = art[3]
	var label := Label3D.new()
	label.name = "DirectFasciaLettering" if direct else "PlateLettering"
	label.text = title
	label.font_size = 64
	label.outline_size = 0
	label.modulate = color if direct else Color("#fff2ca")
	label.double_sided = false
	var font := FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.variation_embolden = .45
	label.font = font
	var glyph_width := font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size).x
	var glyph_height := font.get_height(label.font_size)
	label.pixel_size = minf(extent.x*.94/(glyph_width+5.0),extent.y*.91/(glyph_height+5.0))
	if direct:
		building.add_child(label)
		label.position = face - Vector3(0,0,.0024)
		label.rotation.y = PI
	else:
		# The thin plaque's back penetrates the solid fascia by .001 local
		# units. The shallow face and decal cannot float away at oblique angles.
		var thickness := .009
		var board := _box(Vector3.ZERO,Vector3(extent.x,extent.y,thickness),color)
		board.name = "FlushFasciaPlate"
		board.reparent(building,false)
		board.position = face - Vector3(0,0,thickness*.5-.001)
		board.rotation.y = PI
		board.add_child(label)
		label.position.z = thickness*.5+.0018


func _build_park() -> void:
	var at := Vector3(16,0,-24)
	_box(at + Vector3.UP*0.048,Vector3(20,0.095,12),Color("#a6c583"))
	_box(at + Vector3.UP*0.054,Vector3(3,0.11,12),Color("#e6d9b8"))
	_box(at + Vector3.UP*0.057,Vector3(20,0.11,3),Color("#e6d9b8"))
	var fountain := _fit_width(ROOT + "tiny-park/fountain.gltf",at + Vector3.UP * 0.11,4.8,0.0)
	fountain.name = "VillageGreenFountain"
	_collider(at + Vector3.UP*0.35,Vector3(3.1,0.7,3.1))
	for item in [[10,-28,0],[22,-28,0],[10,-20,PI],[22,-20,PI]]:
		var p := Vector3(item[0],0.1,item[1])
		_fit_width(ROOT + "tiny-park/bench.gltf",p,2.6,item[2])
		_collider(p + Vector3.UP*0.42,Vector3(2.18,0.64,0.78))
	for p in [Vector3(7.5,0.10,-29),Vector3(24.5,0.10,-19)]:
		_fit_width(ROOT + "tiny-park/street_lantern.gltf",p,0.8,0.0)

func _build_pond() -> void:
	var at := Vector3(-13,0,50.5)
	_disk(at + Vector3.UP * 0.024,Vector2(7.15,5.0),Color("#d7c494"))
	_disk(at + Vector3.UP * 0.038,Vector2(6.65,4.5),Color("#629a9a"))
	_disk(at + Vector3(-0.22,0.042,0.27),Vector2(5.8,3.7),Color("#559195"))
	_collider(at + Vector3.UP * 0.57,Vector3(9.6,1.14,5.35))
	_collider(at + Vector3.UP * 0.57,Vector3(5.2,1.14,7.75))
	for offset in [Vector3(-1.9,0.055,-0.9),Vector3(0.9,0.055,1.3),Vector3(2,0.055,0.72)]:
		_fit_width(ROOT + "kenney-nature/lily_large.glb",at + offset,1.05,offset.x)
	for offset in [Vector3(3.4,0,-3.45),Vector3(-6.0,0,1.7),Vector3(5.0,0,2.7)]:
		_fit_width(ROOT + "kenney-nature/stone_smallA.glb",at + offset,1.22,offset.x)

func _build_beach_approach() -> void:
	# Same pond approach, but the land ends at the bay. Only the pier can extend
	# the player's walkable floor beyond the shore.
	_box(Vector3(-5,.036,51.45),Vector3(3.25,.045,12.9),SAND)
	_box(Vector3(-5,.03,58.1),Vector3(11,.045,3.7),Color("#e7c58f"))
	_box(Vector3(-5,-.165,61.3),Vector3(5.60,.45,7.6),Color("#ab7856"),true)
	_collider(Vector3(-5,1.39,62.9),Vector3(5.6,3.6,.65))
	_collider(Vector3(-7.78,1.2,61.04),Vector3(.18,3.2,4.0))
	_collider(Vector3(-2.22,1.2,61.04),Vector3(.18,3.2,4.0))
	# Shore rails stop players from falling below Town's normal floor. They
	# stop at the pier mouth and cannot hide the pier signage.
	_collider(Vector3(-79,1.7,59.75),Vector3(142.4,4,.36))
	_collider(Vector3(72.65,1.7,59.75),Vector3(150.1,4,.36))
	var ferry := FERRY.new()
	ferry.name = "FerryLanding"
	add_child(ferry)
	ferry.position = BEACH_DOOR + Vector3(0,.065,0)
	ferry.build("TOWN FERRY","To Willowbrook Island")
	_build_bay_water()
	var snapshot := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(145,25)
	snapshot.mesh = mesh
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded,cull_disabled,shadows_disabled;
uniform sampler2D snapshot : source_color, filter_linear_mipmap;
void fragment() {
	vec4 image = texture(snapshot,vec2(UV.x,0.80-((1.0-UV.y)*0.42)));
	float edges = smoothstep(0.0,0.12,UV.x)*(1.0-smoothstep(0.88,1.0,UV.x));
	float top_bottom = smoothstep(0.0,0.12,UV.y)*(1.0-smoothstep(0.72,1.0,UV.y));
	ALBEDO = mix(image.rgb,vec3(0.44,0.62,0.67),0.18);
	ALPHA = image.a*edges*top_bottom;
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("snapshot",load(ROOT + "beach-snapshot-backdrop/beach-from-town.png"))
	snapshot.material_override = material
	snapshot.name = "DistantBeachSnapshot"
	snapshot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(snapshot)
	snapshot.position = Vector3(-5,7,132)
	snapshot.rotation.y = PI

func _build_bay_water() -> void:
	var water := MeshInstance3D.new()
	water.name = "TownBayWater"
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(500,270)
	water.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = """
shader_type spatial;
render_mode unshaded,shadows_disabled;
varying vec3 at;
void vertex() { at = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	float depth = smoothstep(60.0,116.0,at.z);
	vec3 sea = mix(vec3(.31,.67,.67),vec3(.13,.45,.58),depth);
	float crest = sin(at.z*2.15+sin(at.x*.46-TIME*.45)*1.08-TIME*1.85);
	float strips = smoothstep(.71,.99,crest)*smoothstep(-.55,.30,sin(at.x*.7+at.z*.97+TIME*.55));
	float foam = 1.0-smoothstep(.05,.36,abs(at.z-60.36-sin(at.x*.35+TIME*.95)*.16));
	sea = mix(sea+strips*.045,vec3(.78,.94,.91),foam*.55);
	ALBEDO = mix(sea,vec3(.65,.81,.84),smoothstep(97.,192.,at.z));
}
"""
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	water.position = Vector3(0,-.16,194.75)

func _build_trees() -> void:
	for at in [
		Vector3(-75,0,-47),Vector3(-60,0,-46),Vector3(-48,0,-48),Vector3(-28,0,-49),
		Vector3(-17,0,-44),Vector3(13,0,-47),Vector3(24,0,-46),Vector3(51,0,-49),
		Vector3(63,0,-46),Vector3(74,0,-49),Vector3(77,0,-20),Vector3(76,0,6),
		Vector3(77,0,27),Vector3(-77,0,-21),Vector3(-77,0,8),Vector3(-77,0,31),
		Vector3(-65,0,48),Vector3(-43,0,48),Vector3(-33,0,50),Vector3(-25,0,55),
		Vector3(-21,0,59),Vector3(-11,0,59),Vector3(2,0,58.3),Vector3(7,0,54.5),
		Vector3(17,0,53),Vector3(37,0,54),Vector3(53,0,56),Vector3(64,0,55),
		Vector3(13,0,-29.2),PARK_BENCH_TREE_START,Vector3(25,0,-27),
		Vector3(23,0,22),Vector3(-22.8,0,25),Vector3(-22,0,-26),HOUSE_2_TREE_START,
	]:
		var large: bool = int(absf(at.x + at.z)) % 2 == 0
		# Keep the original tree art and yaw, but move their trunks and collision out of door/stage routes.
		var tree_at: Vector3 = at
		if at == Vector3(-17,0,-44):
			tree_at = Vector3(-11.5,0,-49.6)
		elif at == Vector3(51,0,-49):
			tree_at = Vector3(66,0,-54)
		elif at == PARK_BENCH_TREE_START:
			tree_at = PARK_BENCH_TREE_SIDE
		elif at == HOUSE_2_TREE_START:
			tree_at = HOUSE_2_TREE_SIDE
		_fit_width(SUBURBAN + ("tree-large" if large else "tree-small") + ".glb",tree_at,4.1 if large else 3.0,at.x)
		_collider(tree_at + Vector3.UP * 1.2,Vector3(0.6,2.4,0.6))

func _build_nursery_and_garden() -> void:
	const NATURE := ROOT + "kenney-nature/"
	_box(Vector3(-23,0.08,50),Vector3(11,0.17,10),SAND).name = "LittleNursery"
	_box(Vector3(-23,0.062,43.5),Vector3(3,0.12,5),SAND)
	_box(Vector3(-23,0.92,54),Vector3(6.5,0.24,1.3),Color("#a47c54"),true)
	for x: float in [-26.5,-19.5]:
		for z: float in [51.8,55]:
			_box(Vector3(x,1.6,z),Vector3(0.22,3.2,0.22),Color("#94724c"),true)
	for i in range(8):
		_box(Vector3(-26.5+i,3.3,53.4),Vector3(0.18,0.18,3.6),Color("#b99b71"))
	for z: float in [51.8,55]:
		_box(Vector3(-23,3.15,z),Vector3(7.4,0.2,0.2),Color("#94724c"))
	_sign("LITTLE NURSERY",Vector3(-23,3.15,51.662),4.25,0.55,PI,Color("#846b48"))
	_sign("SEEDS & FLOWERS",Vector3(-23,0.92,53.31),3.1,0.40,PI,Color("#846b48"))
	var seedlings := ["flower_redA.glb","flower_purpleA.glb","plant_bushSmall.glb"]
	for x: float in [-27,-19]:
		for row in range(3):
			_fit_width(NATURE + "pot_large.glb",Vector3(x,0.16,47+3*row),1.2,0.0)
			_fit_width(NATURE + seedlings[row],Vector3(x,0.55,47+3*row),1.0,0.0)
			_collider(Vector3(x,0.35,47+3*row),Vector3(0.85,0.7,0.85))
	for x: float in [-25,-23,-21]:
		_fit_width(NATURE + "pot_small.glb",Vector3(x,1.04,53.9),0.65,0.0)
		_fit_width(NATURE + "flower_yellowA.glb",Vector3(x,1.39,53.9),0.68,0.0)
	_box(Vector3(20,0.03,49),Vector3(11,0.06,9),Color("#c5bb87")).name = "CommunityGarden"
	_box(Vector3(20,0.05,43.5),Vector3(2.8,0.08,4.5),SAND)
	if OS.has_feature("web") and get_node_or_null("/root/WillowbrookBrowserSession") != null and get_node("/root/WillowbrookBrowserSession").has_method("tend_garden"):
		_posted_sign("COMMUNITY GARDEN",Vector3(17.2,0,44.7),4.4,PI)
		var garden_marker := Label3D.new()
		garden_marker.name = "GardenWateringMarker"
		garden_marker.position = Vector3(20,1.15,47.4)
		garden_marker.text = "WATER HERE"
		garden_marker.font_size = 46
		garden_marker.pixel_size = 0.008
		garden_marker.modulate = Color("#f6f5aa")
		garden_marker.outline_size = 10
		garden_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(garden_marker)
	var plantings := [
		["crops_leafsStageB.glb","flower_redA.glb","crops_wheatStageA.glb"],
		["flower_purpleA.glb","crops_leafsStageB.glb","flower_yellowA.glb"],
	]
	for col in range(2):
		var x := 17.0 + 6*col
		# The raised rim is solid; the wide center aisle and both ends remain usable.
		_box(Vector3(x,0.19,49),Vector3(2.2,0.38,5.2),Color("#98714e"),true).name = "RaisedGardenBed_%d" % col
		for row in range(3):
			_fit_width(NATURE + String(plantings[col][row]),Vector3(x,0.40,47+2*row),1.25,row*PI/5)
	for p: Vector3 in [Vector3(8,0.05,-29),Vector3(24,0.05,-29),Vector3(8,0.05,-19),
			Vector3(24,0.05,-19),Vector3(-19,0.05,54),Vector3(-8,0.05,54)]:
		_fit_width(NATURE + "flower_yellowA.glb",p,0.8,0.0)

func _build_recreation() -> void:
	var playground := Vector3(48,0,50)
	var skate := Vector3(-49,0,50)
	_box(playground + Vector3.UP*0.05,Vector3(21,0.10,16),Color("#d7c895")).name = "Playground"
	_box(skate + Vector3.UP*0.04,Vector3(21,0.08,16),Color("#b9bebc")).name = "SkateCorner"
	_posted_sign("PLAYGROUND",Vector3(40,0,43.5),3.2,PI)
	_posted_sign("SKATE CORNER",Vector3(-57,0,43.5),3.4,PI)
	for x in [-49,48]:
		_box(Vector3(x,0.069,43.5),Vector3(3,0.12,3),SAND)
	var park_pack := ROOT + "tiny-playground/"
	for p in [
		["slide_A.gltf",Vector3(43,0.12,48.5),5.0,Vector3(2.5,1.8,4.8),"PlaygroundSlide"],
		["swing_A_small.gltf",Vector3(51,0.12,47),4.5,Vector3(4.1,1.1,3.1),"PlaygroundSwing"],
		["seesaw_small.gltf",Vector3(44,0.12,55),3.5,Vector3(1.1,0.8,3.0),"PlaygroundSeesaw"],
		["sandbox_round_decorated.gltf",Vector3(53,0.12,54),3.6,Vector3.ZERO,"PlaygroundSandbox"],
		["picnic_table.gltf",Vector3(57,0.12,48),2.5,Vector3(2.3,0.9,2.3),"PlaygroundPicnic"],
	]:
		var model := _fit_width(park_pack + String(p[0]),p[1],p[2],0.0)
		model.name = p[4]
		var size: Vector3 = p[3]
		if size != Vector3.ZERO:
			var at: Vector3 = p[1]
			_collider(at + Vector3.UP*size.y/2.0,size)
	var skate_pack := ROOT + "kenney-skate/"
	for p in [
		["half-pipe-low.glb",Vector3(-47,0.085,48),6.0,PI/2.0,Vector3(5.1,0.8,3.1)],
		["ramp.glb",Vector3(-55,0.085,50),4.0,0.0,Vector3(3.2,0.75,3.2)],
		["rail-low.glb",Vector3(-46,0.085,55),3.0,0.0,Vector3(2.8,0.55,0.36)],
	]:
		_fit_width(skate_pack + String(p[0]),p[1],p[2],p[3])
		var at: Vector3 = p[1]
		var size: Vector3 = p[4]
		_collider(at + Vector3.UP*size.y*0.5,size)

func _build_concert() -> void:
	var pack := ROOT + "ipoly-concert/"
	var canopy := _fit_width(pack + "canopy.glb",Vector3(54,0.05,-49),12.0,0.0)
	canopy.name = "StarlightStage"
	_fit_width(pack + "platform.glb",Vector3(54,-0.30,-49),10.0,0.0)
	_fit_width(pack + "backdrop.glb",Vector3(54,0.05,-52.9),10.0,0.0)
	_fit_height(pack + "microphone.glb",Vector3(54,0.05,-51),1.9,PI)
	for x: float in [49.2,58.8]:
		_fit_height(pack + "speaker.glb",Vector3(x,0.05,-50),2.0,0.0)
		_collider(Vector3(x,0.8,-50),Vector3(0.9,1.6,0.9))
	for x: float in [50.5,57.5]:
		_fit_height(pack + "spotlight.glb",Vector3(x,0.05,-52),0.9,PI/5 if x < 54 else -PI/5)
	for x: float in [48.28,59.72]:
		for z: float in [-52.73,-45.27]:
			_collider(Vector3(x,1.85,z),Vector3(0.5,3.7,0.5))
	_collider(Vector3(54,1.8,-52.90),Vector3(9.6,3.6,0.24))
	_box(Vector3(54,0.065,-43.5),Vector3(3,0.12,3),SAND)
	_box(Vector3(54,3.95,-45.25),Vector3(11.6,0.20,0.23),Color("#5a5669"))
	_sign("STARLIGHT STAGE",Vector3(54,3.95,-45.095),5.0,0.64,0.0,Color("#59537c"))

func _posted_sign(title: String, at: Vector3, width: float, yaw: float) -> void:
	var board := _sign(title,at + Vector3.UP*1.63,width,.62,yaw,Color("#41685e"))
	var wood := Color("#735437")
	# Two grounded legs carry the wide plaque. Mount behind the front face.
	for side: float in [-1.,1.]:
		var post := _box(Vector3.ZERO,Vector3(.19,1.92,.20),wood)
		post.name = "PlaquePostLeft" if side < 0.0 else "PlaquePostRight"
		post.reparent(board,false)
		post.position = Vector3(side*width*.36,-.69,-.103)
		var cap := _box(Vector3.ZERO,Vector3(.235,.14,.235),Color("#a58159"))
		cap.name = "PostCap"
		cap.reparent(post,false)
		cap.position = Vector3(0,.93,0)
	var upper := _box(Vector3.ZERO,Vector3(width+.06,.065,.135),wood)
	upper.name = "CrownRail"
	upper.reparent(board,false)
	upper.position = Vector3(0,.315,-.012)
	var lower := _box(Vector3.ZERO,Vector3(width+.06,.065,.135),wood)
	lower.name = "BottomRail"
	lower.reparent(board,false)
	lower.position = Vector3(0,-.315,-.012)

func _build_street_landmarks() -> void:
	_posted_sign("WILLOW NEIGHBORHOOD",Vector3(-43.5,0,-42.9),4.2,0.0)
	for at: Vector3 in [Vector3(-5.2,0.02,6.8),Vector3(5.2,0.02,17.2)]:
		_street_post(at)
	var jobs := _fitted(ROOT + "3dassets-notice-board/notice-board-godot.glb",Vector3(10,0.02,4),1.5,0.0)
	jobs.name = "HiringNoticeBoard"
	var inserted := jobs.get_child(0) as Node3D
	SIGN_ART.add_notice_face(inserted,"NOW HIRING","Read the job board",Color("#32594e"))
	SIGN_ART.add_notice_face(inserted,"NOW HIRING","Read the job board",Color("#32594e"),true)
	_collider(Vector3(10,0.8,4),Vector3(2.7,1.6,0.45))

func _build_bays() -> void:
	_box(Vector3(-20,0.034,3),Vector3(10,0.062,5),Color("#b8c3b1")).name = "ScooterBay"
	_box(Vector3(-20,0.032,6.0),Vector3(6,0.060,4),STONE)
	for x: float in [-22,-20,-18]:
		_box(Vector3(x-0.82,0.075,3.5),Vector3(0.07,0.02,2.8),Color("#fff1cd"))
	var rack := _fit_width(ROOT + "scooter-rack/rack-godot.glb",Vector3(-20,0.06,1.35),5.8,0.0)
	rack.name = "ScooterRack"
	_collider(Vector3(-20,0.38,1.35),Vector3(5.7,0.75,0.38))
	_posted_sign("SCOOTER PARKING",Vector3(-23.5,0,5.18),3.0,0.0)
	_box(Vector3(22.9,0.026,1.85),Vector3(13.8,0.05,7.7),Color("#c6c6bb")).name = "WillowWheels"
	_box(Vector3(19,0.035,5.85),Vector3(3,0.05,0.30),STONE)
	for x: float in [24,28.2]:
		_box(Vector3(x,0.066,2.3),Vector3(3,0.04,5.8),STONE)
		_box(Vector3(x,0.102,5),Vector3(2.7,0.08,0.15),Color("#eee9d4"))
	_fit_width(ROOT+"kenney-cars/sedan.glb",Vector3(24,0.088,2.3),4.5,0.0)
	_fit_width(ROOT+"kenney-cars/sedan-sports.glb",Vector3(28.2,0.088,2.3),4.5,0.0)
	for x: float in [24,28.2]:
		_collider(Vector3(x,0.56,2.3),Vector3(2.25,1.1,4.3))
	_fit_width(ROOT+"kenney-furniture/desk.glb",Vector3(19,0.05,0.7),2.6,PI)
	_collider(Vector3(19,0.65,0.7),Vector3(2.6,1.3,1))
	_box(Vector3(19,3.6,-0.1),Vector3(5,0.18,3.4),Color("#508b83"))
	for x: float in [16.7,21.3]:
		_box(Vector3(x,1.8,-1.5),Vector3(0.12,3.6,0.12),Color("#58746c"),true)
	_sign("WILLOW WHEELS",Vector3(19,3.6,1.66),4.4,0.54,0.0,Color("#446864"))

func _build_hills() -> void:
	for i in range(16):
		var angle := float(i)*TAU/16.0
		var x := cos(angle)*125.0
		var z := sin(angle)*110.0
		if z > 85.0 and absf(x) < 65.0:
			continue
		var hill := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 13.0
		mesh.height = 10.0 + float(i%3)*3.0
		mesh.radial_segments = 7
		hill.mesh = mesh
		hill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hill.material_override = _material(Color("#91b9a0"))
		add_child(hill)
		hill.position = Vector3(x,2.0,z)

func _instance(file: String) -> Node3D:
	if not scenes.has(file):
		scenes[file] = load(file)
	var result := (scenes[file] as PackedScene).instantiate() as Node3D
	add_child(result)
	if file.get_file().begins_with("flower_") or file.get_file().begins_with("crops_") or file.get_file().begins_with("plant_bushSmall") or file.get_file().begins_with("lily_"):
		_disable_shadow(result)
	return result


func _disable_shadow(node: Node3D) -> void:
	if node is GeometryInstance3D:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child: GeometryInstance3D in node.find_children("*","GeometryInstance3D",true,false):
		child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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

func _asset_bounds(file: String, model: Node3D) -> AABB:
	if not dimensions.has(file):
		dimensions[file] = _measure(model)
	return dimensions[file]

func _fit_height(file: String, at: Vector3, height: float, yaw: float) -> Node3D:
	var model := _instance(file)
	var raw := _asset_bounds(file,model)
	return _place(model,raw,at,height/maxf(0.001,raw.size.y),yaw)

func _fitted(file: String, at: Vector3, ratio: float, yaw: float) -> Node3D:
	var model := _instance(file)
	if not dimensions.has(file):
		dimensions[file] = _measure(model)
	return _place(model,dimensions[file],at,ratio,yaw)

func _fit_width(file: String, at: Vector3, width: float, yaw: float) -> Node3D:
	var model := _instance(file)
	if not dimensions.has(file):
		dimensions[file] = _measure(model)
	var raw: AABB = dimensions[file]
	return _place(model,raw,at,width/maxf(0.0001,maxf(raw.size.x,raw.size.z)),yaw)

func _place(model: Node3D, bounds: AABB, at: Vector3, ratio: float, yaw: float) -> Node3D:
	var wrapper := Node3D.new()
	add_child(wrapper)
	model.reparent(wrapper,false)
	var turned := Basis(Vector3.UP,yaw)
	var raw_anchor := bounds.get_center()
	raw_anchor.y = bounds.position.y
	wrapper.transform = Transform3D(turned.scaled(Vector3.ONE*ratio),at - turned*raw_anchor*ratio)
	var rotated := Transform3D(turned,Vector3.ZERO) * bounds
	wrapper.set_meta("layout_size",rotated.size*ratio)
	wrapper.set_meta("layout_anchor",at)
	return wrapper

func _footprint(building: Node3D, x_ratio: float, z_ratio: float) -> void:
	var size: Vector3 = building.get_meta("layout_size")
	var at: Vector3 = building.get_meta("layout_anchor")
	var height := minf(3.2,size.y)
	_collider(at + Vector3.UP * height * 0.5,Vector3(size.x*x_ratio,height,size.z*z_ratio))
func _material(color: Color) -> StandardMaterial3D:
	if not materials.has(color):
		var fresh := StandardMaterial3D.new()
		fresh.albedo_color = color
		fresh.roughness = 1.0
		materials[color] = fresh
	return materials[color] as StandardMaterial3D

func _box(at: Vector3,size: Vector3,color: Color,solid := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var model := MeshInstance3D.new()
	model.mesh = mesh
	model.material_override = _material(color)
	add_child(model)
	model.position = at
	if size.y <= .16:
		model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if solid:
		_collider(at,size)
	return model

func _disk(at: Vector3, radius: Vector2, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.02
	mesh.radial_segments = 32
	mesh.rings = 0
	var model := MeshInstance3D.new()
	model.mesh = mesh
	model.material_override = _material(color)
	add_child(model)
	model.position = at
	model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.scale = Vector3(radius.x,1,radius.y)

func _collider(at: Vector3,size: Vector3) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.position = at
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)

func _street_post(at: Vector3) -> void:
	var post := _box(at + Vector3.UP * 1.58,Vector3(.11,3.16,.11),Color("#697d79"))
	post.name = "StreetSignPost"
	var street := _sign("MARKET STREET",at+Vector3(-.81,2.54,0),1.86,.32,0.,Color("#345f5a"))
	var lane := _sign("WILLOW LANE",at+Vector3(0,2.92,.81),1.86,.32,PI/2.0,Color("#345f5a"))
	var cap := _box(at+Vector3.UP*3.16,Vector3(.165,.083,.165),Color("#405c53"))
	cap.name = "StreetPostCap"
	for board in [street,lane]:
		board.reparent(post,true)
		var front := board.get_child(0) as Label3D
		var rear := front.duplicate() as Label3D
		board.add_child(rear)
		rear.position.z = -.054
		rear.rotation.y = PI


func _mount_board(board: MeshInstance3D, offsets: Vector2, depths: Vector2) -> void:
	for i in range(2):
		var reach := depths[i]
		var plate := _box(Vector3.ZERO,Vector3(.18,.18,reach),Color("#584a40"))
		plate.name = "FacadeBracket"
		plate.reparent(board,false)
		plate.position = Vector3(offsets[i],0.,-.033-reach*.5)


func _sign(title: String, at: Vector3, width: float, height: float, yaw: float, color: Color) -> MeshInstance3D:
	var sign := _box(at,Vector3(width,height,0.1),color)
	sign.name = "Sign_" + title.to_pascal_case()
	sign.rotation.y = yaw
	var label := Label3D.new()
	label.text = title
	label.font_size = 58
	label.outline_size = 4
	var font: Font = ThemeDB.fallback_font
	var glyph_width := font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,label.font_size).x
	var glyph_height := font.get_height(label.font_size)
	label.pixel_size = minf(width*.9/(glyph_width+8.),height*.73/(glyph_height+8.))
	label.modulate = Color("#fff2ca")
	sign.add_child(label)
	label.position.z = 0.054
	return sign
