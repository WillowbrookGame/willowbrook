extends Node3D
const LAYOUT := preload("res://game/scuba/reef_layout.tscn")
const FISH:="res://game/fish_art/"
var _fish: Array[Dictionary]=[]
var _elapsed:=0.0
var _fish_tick:=0.0
# Main1 sits toward each authored fish face; Main6 grows down the rear (-Z).
# The fixed orbit tangent is aligned to the imported models' local +Z.
const HEAD_AXIS:=Vector3.BACK
const BW:=.76

func _ready() -> void:
	var layout := LAYOUT.instantiate() as Node3D
	add_child(layout)
	_disable_shadows(layout)
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

func _disable_shadows(node: Node3D) -> void:
	for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _asset(path: String, at: Vector3, size: float, angle: float) -> Node3D:
	var packed:=load(path) as PackedScene
	if packed==null:return null
	var node:=packed.instantiate() as Node3D
	if node==null:return null
	node.position=at
	node.set_meta("art_source",path.get_file())
	node.rotation.y=angle
	node.scale=Vector3.ONE*size
	_disable_shadows(node)
	add_child(node)
	return node

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
