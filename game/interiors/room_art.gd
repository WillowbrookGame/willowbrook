extends Node3D

const ART := "res://game/interiors/art/"
const DATA := preload("res://game/interiors/room_data.json")
const HOUSING_PLACEMENT := preload("res://game/interiors/housing_placement.gd")
const PALETTE := {"salon":"f3e2ec"}
const ROOM_FLOORS := ["e3c6a1","e1d4b5","d5d6bd"]
const ROOM_WALLS := ["f1e6d5","e0ebe4","e8e2ef"]
var materials: Dictionary = {}
var decor: Node3D
var placement_ghost: Node3D
var _ghost_kind := ""
var _ghost_material: StandardMaterial3D
var public_seats: Array[Dictionary] = []

func build(id: String, profile: Dictionary) -> void:
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color("#dbe9ee")
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color("#fff3dd")
	world.environment.ambient_light_energy = 0.78
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-61,-35,0)
	sun.light_color = Color("#fff3dc")
	sun.light_energy = 0.53
	add_child(sun)
	if id == "home":
		_home(maxi(1,int(DATA.data.homeVariants.get(profile.get("home",{}).get("variant","starter"),{}).get("rooms",1))))
		redraw_decor(profile)
		return
	room_shell(9.0,7.0,_room_tint(id))
	if DATA.data.shopLayouts.has(id):
		for spec: Dictionary in DATA.data.shopLayouts[id]:
			var at := Vector3(spec.x,0.03,spec.z)
			var dimensions := Vector3(spec.w,spec.h,spec.d)
			var holder := piece(spec.file,at,dimensions,float(spec.rotation),true)
			_register_shop_piece(spec,holder,dimensions)
	_build_room_details(id)
	label_3d("Town  →",Vector3(0,2.75,6.82),42,false)

func _register_shop_piece(_spec: Dictionary, _holder: Node3D, _dimensions: Vector3) -> void:
	pass

func _room_tint(id: String) -> Color:
	return Color(PALETTE.get(id,"e5e9ed"))

func _build_room_details(id: String) -> void:
	match id:
		"salon":
			npc("female-b","Stylist",Vector3(0,0,-5.7))
			for x: float in [-5.0,5.0]:
				piece("rugRectangle",Vector3(x,.018,3),Vector3(2.8,.025,3))
				piece("lampRoundFloor",Vector3(x+signf(x)*1.5,0,3.8),Vector3(.55,1.9,.55),0,true)
func room_shell(hw: float, hd: float, tint: Color) -> void:
	box("Floor",Vector3(0,-.12,0),Vector3(hw*2+.4,.24,hd*2+.35),Color("#e1c9a4"),true)
	box("BackWall",Vector3(0,2,-hd-.1),Vector3(hw*2+.4,4,.22),tint,true,3)
	for side: float in [-1.0,1.0]:
		box("SideWall",Vector3(side*(hw+.1),2,0),Vector3(.22,4,hd*2),tint,true,3)
		box("FrontWall",Vector3(side*(hw+1.5)*.5,2,hd+.1),Vector3(hw-1.5,4,.22),tint,true,3)
	box("DoorLintel",Vector3(0,3.6,hd+.1),Vector3(3,.8,.22),tint,true,3)
	window_at(0,-hd+.05)
	exit_mat(hd-.6)

func _public_furniture() -> void:
	for z: float in [1,3.5]:
		_register_public_seat(piece("chairCushion",Vector3(-6,0,z),Vector3(1.2,1.18,1.15),PI/2,true),1.18)
	for x: float in [-5.5,5.5]:
		piece("bookcaseClosedWide",Vector3(x,0,-5.8),Vector3(2.5,2.7,.9),0,true)
	for x: float in [-7.5,7.5]:
		piece("pottedPlant",Vector3(x,0,5.2),Vector3(1,1.65,1),0,true)

func _register_public_seat(holder: Node3D, height: float) -> void:
	# chairCushion's back is on -Z; the seat top is ~0.24 of its .46 m model.
	public_seats.append({"chair":holder,"surface":Vector3(0,height*.522,-.02)})


func _home(count: int) -> void:
	for i in range(count):
		var x := float(i)*12.0
		var tint := Color(ROOM_WALLS[i])
		box("HomeFloor",Vector3(x,-.12,0),Vector3(12,.24,10),Color(ROOM_FLOORS[i]),true)
		box("HomeBackWall",Vector3(x,2,-5),Vector3(12,4,.18),tint,true,3)
		window_at(x,-4.87)
		if i == 0:
			for side: float in [-1.0,1.0]:
				box("HomeDoorWall",Vector3(side*3.75,2,5),Vector3(4.5,4,.18),tint,true,3)
			box("HomeLintel",Vector3(0,3.65,5),Vector3(3,.7,.18),tint,true,3)
			box("HomeLeftWall",Vector3(-6,2,0),Vector3(.18,4,10),tint,true,3)
		else:
			box("HomeFrontWall",Vector3(x,2,5),Vector3(12,4,.18),tint,true,3)
		if i == count-1:
			box("HomeSideWall",Vector3(x+6,2,0),Vector3(.18,4,10),tint,true,3)
		else:
			for side: float in [-1.0,1.0]:
				box("Partition",Vector3(x+6,2,side*3.25),Vector3(.18,4,3.5),tint,true,3)
			box("PartitionLintel",Vector3(x+6,3.65,0),Vector3(.18,.7,3),tint,true,3)
	exit_mat(4.35)
	decor = Node3D.new()
	decor.name = "Furniture"
	add_child(decor)

func furniture_height(kind: String) -> float:
	return HOUSING_PLACEMENT.height(kind)

func redraw_decor(profile: Dictionary) -> void:
	if not is_instance_valid(decor): return
	for child in decor.get_children():
		decor.remove_child(child)
		child.queue_free()
	var by_id: Dictionary = {}
	for item: Dictionary in profile.get("furniture",[]):
		if item.has("x") and item.has("id"):
			by_id[item.id] = item
	for item: Dictionary in profile.get("furniture",[]):
		if not item.has("x") or not item.has("z"): continue
		var def: Dictionary = DATA.data.furnitureCatalog.get(item.get("kind",""),{})
		if def.is_empty(): continue
		var kind: String = item.kind
		var h := furniture_height(kind)
		var at := Vector3(float(item.get("room",0))*HOUSING_PLACEMENT.ROOM_STRIDE+float(item.x),HOUSING_PLACEMENT.base_height(item,by_id),float(item.z))
		var placed := piece(def.file,at,Vector3(def.width,h,def.depth),int(item.get("rotation",0))*PI/2,kind!="rug" and not item.has("supportId"),decor)
		placed.set_meta("furniture_id",item.get("id",""))


func clear_placement_ghost() -> void:
	if is_instance_valid(placement_ghost):
		placement_ghost.hide()


func show_placement_ghost(item: Dictionary,valid: bool) -> void:
	var kind := String(item.get("kind",""))
	var def: Dictionary = DATA.data.furnitureCatalog.get(kind,{})
	if def.is_empty():
		clear_placement_ghost()
		return
	if not is_instance_valid(placement_ghost) or _ghost_kind!=kind:
		if is_instance_valid(placement_ghost):
			placement_ghost.hide()
			placement_ghost.queue_free()
		placement_ghost = piece(def.file,Vector3.ZERO,Vector3(def.width,furniture_height(kind),def.depth))
		placement_ghost.name = "PlacementGhost"
		_ghost_kind = kind
		_ghost_material = StandardMaterial3D.new()
		_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ghost_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		for part: MeshInstance3D in placement_ghost.find_children("*","MeshInstance3D",true,false):
			part.material_override = _ghost_material
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	placement_ghost.position = Vector3(float(item.room)*HOUSING_PLACEMENT.ROOM_STRIDE+float(item.x),float(item.get("y",.002))+.002,float(item.z))
	placement_ghost.rotation.y = int(item.rotation)*PI/2.0
	_ghost_material.albedo_color = Color("#7ce6a89c") if valid else Color("#f17a789c")
	placement_ghost.show()


func exit_mat(z: float) -> void:
	box("ExitMat",Vector3(0,.017,z),Vector3(2.4,.03,.75),Color("#8dc4b0"))
	box("ExitArrow",Vector3(0,.04,z-.12),Vector3(.13,.02,.38),Color.WHITE)
	var arrow := box("ExitArrowTip",Vector3(0,.042,z+.17),Vector3(.32,.02,.32),Color.WHITE)
	arrow.rotation.y = PI/4

func window_at(x: float,z: float) -> void:
	box("Glass",Vector3(x,2.36,z),Vector3(3.4,1.7,.05),Color("#a7d0df"))
	box("WindowCross",Vector3(x,2.36,z+.03),Vector3(.08,1.7,.04),Color("#fffaf0"))
	box("WindowCross",Vector3(x,2.36,z+.03),Vector3(3.4,.08,.04),Color("#fffaf0"))

func mark_task(at: Vector3, title: String, kind := "blue") -> Node3D:
	var root := Node3D.new()
	root.name = "JobMarker"
	add_child(root)
	root.position = at
	var c := Color({"blue":"7db4d0","gold":"ffcb68","green":"82ccb3"}.get(kind,"7db4d0"))
	box("StationMat",Vector3(0,.015,0),Vector3(.85,.028,.75),c,false,1,root)
	var sign := label_3d(title,Vector3(0,.68,0),25,true,root)
	sign.modulate = Color("#ffffef")
	return root

var conversation_actor: Node3D

func npc(character: String, title: String, at: Vector3) -> Node3D:
	var model := piece("character-"+character,at,Vector3(0,1.63,0),0,false)
	conversation_actor = model
	label_3d(title,at+Vector3.UP*1.92,34,true)
	if model != null:
		var players := model.find_children("*","AnimationPlayer",true,false)
		if not players.is_empty():
			var anim := players[0] as AnimationPlayer
			if anim.has_animation("idle"): anim.play("idle")
	return model

func label_3d(caption: String, at: Vector3, size: int, billboard: bool, target: Node3D = null) -> Label3D:
	var tag := Label3D.new()
	tag.text = caption
	tag.font_size = size
	tag.outline_size = 5
	tag.pixel_size = .005
	tag.no_depth_test = false
	if billboard: tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	(target if is_instance_valid(target) else self).add_child(tag)
	tag.position = at
	return tag

func piece(file: String, at: Vector3, desired: Vector3, yaw := 0.0, solid := false, target: Node3D = null) -> Node3D:
	var asset_path := ART+"kenney-furniture/"+file+".glb"
	if file.begins_with("shop/"): asset_path = ART+"kenney-mini-shop/"+file.trim_prefix("shop/")+".glb"
	if file.begins_with("salon/"): asset_path = ART+"shuriken-salon/"+file.trim_prefix("salon/")+".glb"
	if file.begins_with("food/"): asset_path = ART+"kenney-food/"+file.trim_prefix("food/")+".glb"
	if file.begins_with("character-"): asset_path = ART+"kenney-mini/"+file+".glb"
	if file.begins_with("animal-"): asset_path = ART+"kenney-pets/"+file+".glb"
	if file=="../scavenger/trophy": asset_path = ART+"scavenger/trophy.glb"
	var parent := target if is_instance_valid(target) else self
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = at
	holder.rotation.y = yaw
	var scene := load(asset_path) as PackedScene if ResourceLoader.exists(asset_path) else null
	if scene == null:
		var fallback := Vector3(maxf(.45,desired.x),maxf(.65,desired.y),maxf(.45,desired.z))
		box("Furniture",Vector3.UP*fallback.y*.5,fallback,Color("#b4a492"),solid,3,holder)
		return holder
	var model := scene.instantiate() as Node3D
	holder.add_child(model)
	var minmax := AABB()
	var any := false
	for node in model.find_children("*","MeshInstance3D",true,false):
		var mesh := node as MeshInstance3D
		var relative := holder.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		minmax = minmax.merge(relative) if any else relative
		any = true
	if any and minmax.size.length_squared()>.0001:
		var natural := minmax.size
		var scalar := desired.y / maxf(natural.y,.01) if desired.x<=0 else 1.0
		var scale_vec := Vector3(desired.x/maxf(.01,natural.x),desired.y/maxf(.01,natural.y),desired.z/maxf(.01,natural.z)) if desired.x > 0 else Vector3.ONE*scalar
		model.scale *= scale_vec
		var pivot := minmax.get_center()
		pivot.y = minmax.position.y
		model.position -= pivot*scale_vec
		if solid:
			body_box(holder,Vector3.UP*desired.y*.5,desired,3)
	return holder

func box(name_: String, at: Vector3, size: Vector3, tint: Color, solid := false, mask := 1, target: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	var geometry := BoxMesh.new()
	geometry.size = size
	node.mesh = geometry
	if not materials.has(tint):
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.roughness = .94
		materials[tint] = material
	node.material_override = materials[tint]
	var parent := target if is_instance_valid(target) else self
	parent.add_child(node)
	node.position = at
	if solid: body_box(parent,at,size,mask)
	return node

func body_box(parent: Node3D, at: Vector3, size: Vector3, mask: int) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = mask
	body.collision_mask = 0
	parent.add_child(body)
	body.position = at
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	body.add_child(shape)
