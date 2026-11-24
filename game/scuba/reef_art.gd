extends Node3D
const ASSETS:="res://game/town_assets/scuba-starter/"
const FLOOR:=preload("res://game/arcade/kenney-mini-arcade/floor.glb")
const SAND:=preload("res://game/beach_art/beach-nature/sand-color.png")
const ROCK:="res://game/town_assets/kenney-nature/rock_smallA.glb"
const FISH:="res://game/fish_art/"
var _fish: Array[Dictionary]=[]
var _elapsed:=0.0
var _fish_tick:=0.0
# Main1 sits toward each authored fish face; Main6 grows down the rear (-Z).
# The fixed orbit tangent is aligned to the imported models' local +Z.
const HEAD_AXIS:=Vector3.BACK
const BW:=.76

func _ready() -> void:
	_terrain()
	_landmarks()
	# Authored nearby landmarks frame the schools; their lanes are in open water.
	_school("Clownfish",Vector3(-6,-3.35,13),5,3.5,.23,.33)
	_school("BlueTang",Vector3(6.5,-3.45,12),4,4.1,.22,.31)
	_school("ButterflyFish",Vector3(-6,-5.3,1.0),5,3.7,.24,.29)
	_school("CoralGrouper",Vector3(7.5,-6.0,0),3,4.1,.28,.31)
	_school("ParrotFish",Vector3(-11,-10.8,-14.5),4,4.5,.29,.26)
	_school("Tuna",Vector3(11,-9.8,-19),3,5.2,.36,.26)
	_update_fish()

func floor_at(at: Vector3) -> float:
	return -6.4 - clampf((8.0-at.z)/22.0,0.0,1.0)*11.0

func landmark(at: Vector3) -> String:
	if at.z>=7.0:return "Sunbeam Shallows"
	if at.z>=-5.5:return "Fan Garden"
	if at.z>=-13.5:return "Coral Gate"
	return "Bluewater Wreck" if at.x > -5.0 else "Bluewater Overhang"

func _tile(at: Vector3, span: float, pitch: float, sand: StandardMaterial3D) -> void:
	# Actual authored floor asset, rematerialized with the existing beach sand.
	var model:=FLOOR.instantiate() as Node3D
	model.position=at
	model.rotation.x=pitch
	model.scale=Vector3(62,.1,span)
	for m: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		m.material_override=sand
		m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(model)

func _terrain() -> void:
	var sand:=StandardMaterial3D.new()
	sand.albedo_color=Color("#d1baa1")
	sand.albedo_texture=SAND
	sand.uv1_scale=Vector3(12,7,1)
	sand.roughness=1.0
	_tile(Vector3(0,-6.4,18.0),20.0,0.0,sand)
	_tile(Vector3(0,-11.9,-3.0),sqrt(22.0*22.0+11.0*11.0),-atan(.5),sand)
	_tile(Vector3(0,-17.4,-21.0),14.0,0.0,sand)

func _asset(path: String, at: Vector3, size: float, angle: float) -> Node3D:
	var packed:=load(path) as PackedScene
	if packed==null:return null
	var node:=packed.instantiate() as Node3D
	if node==null:return null
	node.position=at
	node.set_meta("art_source",path.get_file())
	node.rotation.y=angle
	node.scale=Vector3.ONE*size
	for m: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		m.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _plant(asset: String, x: float, z: float, size: float, angle: float) -> void:
	var at:=Vector3(x,0,z)
	at.y=floor_at(at)
	_asset(ASSETS+asset+".glb",at,size,angle)

func _collider(at: Vector3, size: Vector3, yaw: float=0.0) -> void:
	var body:=StaticBody3D.new()
	body.position=at
	body.rotation.y=yaw
	var obstacle:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=size
	obstacle.shape=shape
	body.add_child(obstacle)
	add_child(body)

func _landmarks() -> void:
	# Low, distinct islands of coral leave space in the swimming route.
	for p: Array in [[-13,13,1.15,.40],[16,12,1.25,-.65],[-16,4,1.28,-.6],[15,-2,1.25,-.8]]:
		_plant("reef-spur",p[0],p[1],p[2],p[3])
	for p: Array in [[-8,5,1.02,1.05],[7,6,1.08,-.44],[-10,-2,.96,.54],[10,-6,.82,-.75]]:
		_plant("sea-fan",p[0],p[1],p[2],p[3])
	for p: Array in [[-7,17,.88,.4],[8,17,1.12,.8],[-4,0,.92,-.3],[5,-4,1.18,.4],[-9,-21,1.3,.4]]:
		_plant("barrel-sponge",p[0],p[1],p[2],p[3])
	var gate:=Vector3(0,-11.0,-5.7)
	_asset(ASSETS+"swim-through-arch.glb",gate,2.05,0.0)
	# Open arch: two supports and a lintel, not a single solid hull.
	_collider(gate+Vector3(-3.36,2.0,0),Vector3(1.15,3.7,1.7))
	_collider(gate+Vector3(3.36,2.0,0),Vector3(1.15,3.7,1.7))
	_collider(gate+Vector3(0,5.5,0),Vector3(4.4,1.05,1.5))
	for p: Array in [[-20,-9,1.45,1.15],[15,-11,1.7,-.98],[22,-23,1.55,-.66]]:
		_plant("reef-wall-straight",p[0],p[1],p[2],p[3])
		var at:=Vector3(p[0],0,p[1])
		at.y=floor_at(at)+float(p[2])
		_collider(at,Vector3(3.5,1.7,1.1)*float(p[2]),float(p[3]))
	_plant("reef-wall-corner",-17,-22,1.55,.45)
	_plant("reef-wall-overhang",-25,-22,1.35,-.48)
	_plant("reef-wall-overhang",12,-24,1.30,.9)
	var cockpit:=Vector3(4,-17.35,-20)
	_asset(ASSETS+"wreck-cockpit-section.glb",cockpit,1.53,.56)
	_asset(ASSETS+"torn-wing-section.glb",Vector3(-3,-17.25,-24),1.45,-.78)
	_collider(cockpit+Vector3(0,1.2,0),Vector3(3.5,2.35,4.1),.56)
	for p: Array in [[-18,16,1.1,.43],[21,8,.95,.72],[-8,-12,1.4,-.58],[10,-15,1.25,.8]]:
		var at:=Vector3(p[0],0,p[1])
		at.y=floor_at(at)
		_asset(ROCK,at,p[2],p[3])

func _school(species: String, origin: Vector3, count: int, radius: float, ratio: float, rate: float) -> void:
	for i in count:
		var n:=_asset(FISH+species+".glb",origin,ratio*(.94+.05*float(i%3)),0.0)
		if n==null:continue
		n.set_meta("reef_fish",true)
		# Equal phase separation and shared angular speed prevent school members passing through one another.
		_fish.append({"node":n,"origin":origin,"radius":radius,"phase":float(i)*TAU/count,"rate":rate})

func _update_fish() -> void:
	for a: Dictionary in _fish:
		var n:Node3D=a.node
		var theta:float=_elapsed*a.rate+a.phase
		var wiggle:float=.11*sin(4.2*_elapsed+a.phase*4.0)
		var baseline:Vector3=a.origin
		var tangent:=Vector3(-sin(theta),0,cos(theta)*BW)
		n.position=baseline+Vector3(cos(theta)*a.radius,.21*sin(theta*2.0+a.phase),sin(theta)*a.radius*BW)
		n.rotation.y=atan2(tangent.x,tangent.z)+wiggle

func _process(delta:float) -> void:
	_elapsed+=delta
	_fish_tick+=delta
	if _fish_tick<.06:return
	_fish_tick=0.0
	_update_fish()
