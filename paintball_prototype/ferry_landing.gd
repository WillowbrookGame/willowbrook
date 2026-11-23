extends Node3D
## Willowbrook's shared pier, folding gangway and fitted Innerscene passenger ferry.
const DARK := Color("#214d60")
const TEAL := Color("#2b8490")
const CREAM := Color("#fff0cb")
const RED := Color("#e2684a")
const TIMBER := Color("#9c6749")
const REEF := Color("#246b87")

var _boat: Node3D
var _at := Vector3.ZERO
var _sail := 0.0
var _gangway: Node3D
var _boat_gate: Node3D
const STAGING := Vector3(0,.07,.65)
const RAMP_START := Vector3(2.18,.12,4.97)
const RAMP_END := Vector3(3.18,.57,4.97)
const DECK := Vector3(-.95,.56,-5.0)
var _materials := {}


func build(dock_name: String, destination: String) -> void:
	_block(self, Vector3(0,-.14,2.65), Vector3(5.7,.24,7.5), DARK)
	for row in range(12):
		_block(self, Vector3(0,.008,-.78+float(row)*.62), Vector3(5.6,.145,.60),
			Color("#d5a376") if row % 3 == 0 else Color("#c08c63"))
	for side: float in [-1.0,1.0]:
		var x := 2.65*side
		for z: float in ([1.15,3.52,5.77,6.0] if side > 0 else [1.15,3.58,6.0]):
			_block(self, Vector3(x,.14,z), Vector3(.30,1.95,.30), TIMBER)
			_block(self, Vector3(x,1.13,z), Vector3(.34,.1,.34), CREAM)
		if side > 0:
			for rail: Vector2 in [Vector2(2.36,2.43),Vector2(5.94,.44)]:
				_block(self, Vector3(x,.83,rail.x), Vector3(.13,.14,rail.y), DARK)
				_block(self, Vector3(x,.54,rail.x), Vector3(.095,.085,rail.y), TIMBER)
		else:
			_block(self, Vector3(x,.83,3.58), Vector3(.13,.14,5.10), DARK)
			_block(self, Vector3(x,.54,3.58), Vector3(.095,.085,5.10), TIMBER)
		_block(self, Vector3(x,.12,6.33), Vector3(.32,.11,.57), CREAM)
	# A wayfinder off the walkway, facing the player approaching the water.
	var sign_x := -3.65
	for dx: float in [-1.36,1.36]:
		_block(self, Vector3(sign_x+dx,.85,.95), Vector3(.14,1.7,.18), TIMBER)
	_block(self, Vector3(sign_x,1.79,.92), Vector3(3.3,1.07,.17), DARK)
	_block(self, Vector3(sign_x,2.345,.92), Vector3(3.44,.12,.24), TEAL)
	_label(sign_x,2.01,.80,dock_name,42,CREAM)
	_label(sign_x,1.64,.80,destination,30,Color("#ceeff3"))
	_block(self, Vector3(0,.104,.63), Vector3(1.65,.03,.13), CREAM)
	_block(self, Vector3(0,.104,.31), Vector3(1.25,.03,.13), CREAM)
	_boat = Node3D.new()
	_boat.name = "WillowbrookShuttle"
	add_child(_boat)
	_at = Vector3(4.65,.02,9.969)
	_boat.position = _at
	_boat.rotation.y = 0.0
	# The source models +X as the bow; gameplay sails along +Z. Set the
	# measured main-deck top (2.93 m on source) at deck feet, .56 m local.
	var ferry := preload("res://paintball_prototype/ferry_art/innerscene-passenger-ferry.glb").instantiate() as Node3D
	ferry.name = "InnerscenePassengerFerry"
	ferry.rotation.y = -PI/2.0
	ferry.scale = Vector3.ONE * .52
	ferry.position.y = .56 - 2.93*.52
	_boat.add_child(ferry)
	_boat_gate = ferry.find_child("PortGate",true,false) as Node3D
	if _boat_gate != null:
		_boat_gate.rotation.x = PI/2.0
	_build_gangway()


func _build_gangway() -> void:
	_gangway = Node3D.new()
	_gangway.name = "BoardingGangway"
	add_child(_gangway)
	_gangway.position = RAMP_START
	_gangway.rotation.z = atan2(RAMP_END.y - RAMP_START.y,RAMP_END.x - RAMP_START.x)
	var span := RAMP_START.distance_to(RAMP_END)
	for step in range(7):
		var x := float(step) * span / 6.0
		_block(_gangway,Vector3(x,-.055,0),Vector3(.18,.11,1.20),Color("#bd8a60") if step % 2 == 0 else Color("#d5a376"))
	for side: float in [-1.0,1.0]:
		_block(_gangway,Vector3(span*.5,-.14,.55*side),Vector3(span+.2,.11,.10),DARK)
		_block(_gangway,Vector3(span*.5,.535,.56*side),Vector3(span+.12,.08,.08),DARK)
		for x: float in [0.0,span]:
			_block(_gangway,Vector3(x,.26,.56*side),Vector3(.09,.56,.09),TIMBER)


func boarding_points() -> Array[Vector3]:
	return [to_global(STAGING),to_global(Vector3(0,.12,RAMP_START.z)),to_global(RAMP_START),to_global(RAMP_END),deck_position()]


func deck_position() -> Vector3:
	return _boat.to_global(DECK)


func sail(progress: float) -> void:
	var eased := progress * progress * (3.0 - 2.0 * progress)
	_sail = 8.6 * eased
	var fold := minf(1.0,progress*3.7)
	_gangway.rotation.z = lerpf(atan2(RAMP_END.y-RAMP_START.y,RAMP_END.x-RAMP_START.x),1.54,fold)
	if _boat_gate != null:
		_boat_gate.rotation.x = lerpf(PI/2.0,0.0,fold)
	_update_boat()


func _update_boat() -> void:
	var time := Time.get_ticks_msec()*.001
	_boat.position = _at + Vector3(.72 * _sail / 8.6,sin(time*1.24)*.035,_sail)
	_boat.rotation.z = sin(time*1.16)*.009


func _process(_delta: float) -> void:
	if _boat != null:
		_update_boat()


func _mat(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = .88
		_materials[color] = material
	return _materials[color]


func _block(parent: Node3D, at: Vector3, size: Vector3, color: Color) -> void:
	var item := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = _mat(color)
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	item.position = at


func _label(x: float, y: float, z: float, caption: String, font: int, color: Color) -> void:
	var sign := Label3D.new()
	sign.text = caption
	sign.font_size = font
	sign.pixel_size = .0081
	sign.outline_size = 0
	sign.modulate = color
	add_child(sign)
	sign.position = Vector3(x,y,z)
	sign.rotation.y = PI


static func sailing_card(parent: Node, destination: String) -> ColorRect:
	var screen := ColorRect.new()
	screen.name = "FerryCrossing"
	screen.color = Color("#123646ee")
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 10)
	center.add_child(words)
	for row in [["WILLOWBROOK FERRY",18,Color("#fbd499")],["Sailing to "+destination,32,Color.WHITE],["Across the bay",18,Color("#b9e6eb")]]:
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.text = row[0]
		label.add_theme_font_size_override("font_size",row[1])
		label.add_theme_color_override("font_color",row[2])
		words.add_child(label)
	screen.modulate.a = 0.0
	var reveal := screen.create_tween()
	reveal.tween_interval(.21)
	reveal.tween_property(screen,"modulate:a",1.0,.28)
	return screen
