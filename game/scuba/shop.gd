extends Node3D

const SHOP := "res://game/beach_art/beach-shops/dive-shop.glb"
const GEAR := "res://game/town_assets/scuba-starter/"
const HUD_FIT := preload("res://game/hud_fit.gd")
const ART := preload("res://game/interiors/room_art.gd")
const TRIP := preload("res://game/scuba/departure.gd")
const DOOR := Vector3(2.20,0,1.90)
const MASTER := Vector3(-1.84,0,-2.46)

var _host: Node3D
var _player: CharacterBody3D
var _hud: CanvasLayer
var _panel: Control
var _trip: Control
var _actor: Node3D

func setup(_id: String, host: Node3D, player: CharacterBody3D, hud: CanvasLayer) -> void:
	if get_tree().has_meta("scuba_shop_return"):
		get_tree().remove_meta("scuba_shop_return")
	_host=host
	_player=player
	_hud=hud
	var helper := ART.new()
	add_child(helper)
	var original := load(SHOP) as PackedScene
	if original != null:
		var shack := original.instantiate() as Node3D
		add_child(shack)
		shack.scale=Vector3(.49,.39,.56)
		shack.position=Vector3(0,-.77,-.33)
		var retail_rack := Node3D.new()
		retail_rack.name="WetsuitDisplay"
		add_child(retail_rack)
		retail_rack.position=Vector3(3.49,0,.02)
		retail_rack.rotation.y=-PI*.5
		retail_rack.scale=Vector3.ONE*.36
		var old_rack_origin:=Vector3(13.2,.7,7.0)
		for piece_name in ["WetsuitRack","Wetsuit_1","Wetsuit_2"]:
			var piece := shack.find_child(piece_name,true,false) as Node3D
			if piece!=null:
				var original_position:=piece.position
				piece.reparent(retail_rack,false)
				piece.position=original_position-old_rack_origin
		for piece_name in ["Roof","Door","Shutter","Hangers","SurfRack","Surfboard_1","Surfboard_2","Surfboard_3","Surfboard_4","Surfboard_5","Wetsuit_3"]:
			var piece := shack.find_child(piece_name,true,false) as Node3D
			if piece != null: piece.hide()
	# Invisible collision follows the authored room footprint and open doorway.
	helper.body_box(self,Vector3(0,-.15,-.27),Vector3(10.1,.3,8.15),3)
	helper.body_box(self,Vector3(-3.90,1.7,-.53),Vector3(.22,3.4,7.86),3)
	helper.body_box(self,Vector3(3.90,1.7,-.53),Vector3(.22,3.4,7.86),3)
	helper.body_box(self,Vector3(0,1.7,-3.33),Vector3(10.1,3.4,.22),3)
	helper.body_box(self,Vector3(-1.34,1.7,1.93),Vector3(5.18,3.4,.18),3)
	helper.body_box(self,Vector3(3.53,1.7,1.93),Vector3(.74,3.4,.18),3)
	helper.body_box(self,Vector3(0,1.7,3.65),Vector3(10.1,3.4,.18),3)
	helper.body_box(self,Vector3(0,1.7,1.46),Vector3(10.1,3.4,.12),4)
	# The aisle between reception and equipment is straight, with no props
	# placed in the entry lane or the normal talk/exit patches.
	_room_piece(helper,"rugRectangle",Vector3(.48,.055,.19),Vector3(2.15,.025,1.47))
	_room_piece(helper,"desk",Vector3(-1.83,0,-1.63),Vector3(2.35,1.03,.83),0,true)
	_room_piece(helper,"books",Vector3(-2.42,1.04,-1.58),Vector3(.34,.12,.31))
	_room_piece(helper,"pottedPlant",Vector3(-3.44,0,-2.88),Vector3(.58,1.32,.58))
	_room_piece(helper,"chairCushion",Vector3(-3.43,0,.28),Vector3(.77,.96,.78),PI*.5,true)
	_room_piece(helper,"chairCushion",Vector3(-3.43,0,-.77),Vector3(.77,.96,.78),PI*.5,true)
	helper.label_3d("DIVE TRIPS",Vector3(-1.83,2.68,-3.23),28,false)
	helper.label_3d("GEAR CHECK",Vector3(2.30,2.27,-3.23),26,false)
	_actor=helper.npc("male-a","Dive Master",MASTER)
	helper.body_box(self,MASTER+Vector3.UP*.72,Vector3(.56,1.44,.5),3)
	_place_gear("diver-equipment-bench",Vector3(2.30,0,-2.68),2.50)
	helper.body_box(self,Vector3(2.30,.70,-2.68),Vector3(2.50,1.4,1.13),3)
	_place_gear("twin-scuba-tank-rig",Vector3(3.46,0,-1.75),.64)
	_place_gear("dive-mask",Vector3(2.39,1.364,-2.46),.36)
	_place_gear("dive-fin-left",Vector3(1.48,1.364,-2.46),.48)
	_place_gear("dive-fin-right",Vector3(1.73,1.364,-2.46),.48)
	_place_gear("underwater-camera-housing",Vector3(3.06,1.364,-2.46),.48)
	helper.body_box(self,Vector3(3.53,1.10,.03),Vector3(.65,2.2,1.84),3)
	var fill:=OmniLight3D.new()
	fill.position=Vector3(.38,3.20,-.55)
	fill.light_color=Color("#d9efff")
	fill.light_energy=.52
	fill.omni_range=7.4
	fill.shadow_enabled=false
	add_child(fill)

func _room_piece(helper: Node, asset: String, at: Vector3, desired: Vector3, yaw := 0.0, solid := false) -> void:
	if ResourceLoader.exists("res://game/interiors/art/kenney-furniture/"+asset+".glb"):
		helper.piece(asset,at,desired,yaw,solid)

func _place_gear(asset: String, at: Vector3, width: float) -> void:
	var path := GEAR+asset+".glb"
	if not ResourceLoader.exists(path): return
	var scene := load(path) as PackedScene
	if scene == null: return
	var root := scene.instantiate() as Node3D
	add_child(root)
	var aabb := AABB()
	var valid := false
	var meshes := root.find_children("*","MeshInstance3D",true,false)
	if root is MeshInstance3D: meshes.push_front(root)
	for m in meshes:
		if m.mesh == null: continue
		var b: AABB = root.global_transform.affine_inverse()*m.global_transform*m.get_aabb()
		aabb=b if not valid else aabb.merge(b)
		valid=true
	if not valid:
		root.queue_free()
		return
	var factor := width / maxf(.001,maxf(aabb.size.x,aabb.size.z))
	root.scale *= factor
	var midpoint := aabb.get_center()
	midpoint.y=aabb.position.y
	root.position=at-midpoint*factor

func spawn_position() -> Vector3:
	return Vector3(2.11,.04,.54)

func bounds() -> Vector2:
	return Vector2(5,4.2)

func interaction_prompt() -> String:
	if is_modal_open(): return ""
	var p := _player.position
	if p.z > 1.09 and p.distance_to(DOOR) < 1.48:
		return "Exit to beach"
	if p.z > -1.60 and p.z < 1.5 and p.distance_to(MASTER) < 3.55:
		return "Talk to Dive Master"
	return ""

func interact() -> bool:
	match interaction_prompt():
		"Exit to beach":
			_host.go_to_town()
			return true
		"Talk to Dive Master":
			_open_dialogue()
			return true
	return false

func is_modal_open() -> bool:
	return is_instance_valid(_panel) or is_instance_valid(_trip)

func close_modal() -> void:
	if is_instance_valid(_trip):
		_trip.cancel()
		return
	if is_instance_valid(_panel):
		_panel.queue_free()
		_panel=null
	_host.set_zone_modal(false)

func _open_dialogue() -> void:
	if is_instance_valid(_actor):
		var target := _player.global_position
		target.y = _actor.global_position.y
		if target.distance_squared_to(_actor.global_position)>.01:
			_actor.look_at(target,Vector3.UP,true)
	_host.set_zone_modal(true)
	_panel=Control.new()
	_hud.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var veil := ColorRect.new()
	veil.color=Color(.08,.22,.31,.58)
	_panel.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	_panel.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card := PanelContainer.new()
	center.add_child(card)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x=295
	box.add_theme_constant_override("separation",12)
	card.add_child(box)
	var talk := Label.new()
	talk.text="Dive Master\nReady to explore the reef?"
	talk.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	talk.add_theme_font_size_override("font_size",22)
	box.add_child(talk)
	var start := Button.new()
	start.text="Go on a dive trip"
	start.custom_minimum_size.y=50
	start.pressed.connect(_start_trip)
	box.add_child(start)
	var back := Button.new()
	back.text="Not now"
	back.custom_minimum_size.y=44
	back.pressed.connect(close_modal)
	box.add_child(back)
	var viewport := _panel.get_viewport()
	var resize_dialogue := func():
		var factor := HUD_FIT.touch_scale(viewport)
		var width := viewport.get_visible_rect().size.x / factor
		box.custom_minimum_size.x = minf(298.0,maxf(160.0,width - 30.0))*factor
		box.add_theme_constant_override("separation",roundi(8*factor))
		talk.add_theme_font_size_override("font_size",roundi(16*factor))
		for button: Button in [start,back]:
			button.custom_minimum_size.y=44.0*factor
			button.add_theme_font_size_override("font_size",roundi(15*factor))
	resize_dialogue.call()
	viewport.size_changed.connect(resize_dialogue)
	_panel.tree_exited.connect(func():
		if is_instance_valid(viewport) and viewport.size_changed.is_connected(resize_dialogue):
			viewport.size_changed.disconnect(resize_dialogue),CONNECT_ONE_SHOT)
	start.grab_focus()

func _start_trip() -> void:
	if is_instance_valid(_trip): return
	_panel.queue_free()
	_panel=null
	_trip=TRIP.new()
	_hud.add_child(_trip)
	_trip.cancelled.connect(func():
		_trip=null
		_host.set_zone_modal(false))
