extends Node3D

const HUD_FIT := preload("res://game/hud_fit.gd")
const LAYOUT := preload("res://game/scuba/shop_layout.tscn")
const TRIP := preload("res://game/scuba/departure.gd")
const PHOTO_BOOK := preload("res://game/photo_book_ui.gd")
const REEF_PHOTOS := preload("res://game/scuba/reef_photos.gd")
const FISHING := preload("res://game/fishing_game.gd")
const DOOR := Vector3(2.20,0,1.90)

var _host: Node3D
var _player: CharacterBody3D
var _hud: CanvasLayer
var _panel: Control
var _trip: Control
var _book: Control
var _actor: Node3D

func setup(_id: String, host: Node3D, player: CharacterBody3D, hud: CanvasLayer) -> void:
	if get_tree().has_meta("scuba_shop_return"):
		get_tree().remove_meta("scuba_shop_return")
	_host=host
	_player=player
	_hud=hud
	var layout := LAYOUT.instantiate() as Node3D
	add_child(layout)
	_actor = layout.get_node("DiveMaster")
	for item in _actor.find_children("*","AnimationPlayer",true,false):
		var animation := item as AnimationPlayer
		if animation.has_animation("idle"):
			animation.play("idle")
			break


func spawn_yaw() -> float:
	return .65


func camera_profile() -> Dictionary:
	return {"tight_enter": 2.25, "tight_leave": 2.68, "collision_mask": 5}


func spawn_position() -> Vector3:
	return Vector3(2.11,.04,.54)

func bounds() -> Vector2:
	return Vector2(5,4.2)

func interaction_prompt() -> String:
	if is_modal_open(): return ""
	var p := _player.position
	if p.z > 1.09 and p.distance_to(DOOR) < 1.48:
		return "Exit to beach"
	if p.z > -1.60 and p.z < 1.5 and is_instance_valid(_actor) and _player.global_position.distance_to(_actor.global_position) < 3.55:
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
	return is_instance_valid(_panel) or is_instance_valid(_trip) or (is_instance_valid(_book) and _book.visible)

func close_modal() -> void:
	if is_instance_valid(_trip):
		_trip.cancel()
		return
	if is_instance_valid(_book):
		_book.queue_free()
		_book=null
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
	var book_btn := Button.new()
	book_btn.text="Photo Book"
	book_btn.custom_minimum_size.y=44
	book_btn.pressed.connect(open_photo_book)
	box.add_child(book_btn)
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
		for button: Button in [start,book_btn,back]:
			button.custom_minimum_size.y=44.0*factor
			button.add_theme_font_size_override("font_size",roundi(15*factor))
	resize_dialogue.call()
	viewport.size_changed.connect(resize_dialogue)
	_panel.tree_exited.connect(func():
		if is_instance_valid(viewport) and viewport.size_changed.is_connected(resize_dialogue):
			viewport.size_changed.disconnect(resize_dialogue),CONNECT_ONE_SHOT)
	start.grab_focus()

func open_photo_book() -> void:
	if is_instance_valid(_panel):
		_panel.queue_free()
		_panel=null
	if is_instance_valid(_book):
		_book.queue_free()
	var profile := REEF_PHOTOS.resolve_profile(get_tree())
	var caught: Array = profile.snapshot().get("fish_discovered",[]) if profile!=null else []
	var reef_found: Array[String] = REEF_PHOTOS.load_discovered(profile)
	_book = PHOTO_BOOK.new()
	_hud.add_child(_book)
	_book.closed.connect(close_modal)
	var tabs: Array[Dictionary]=[
		FISHING.book_tab(caught),
		REEF_PHOTOS.book_tab(reef_found),
	]
	_book.configure_tabs(tabs)
	_book.open("reef")

func _start_trip() -> void:
	if is_instance_valid(_trip): return
	_panel.queue_free()
	_panel=null
	_trip=TRIP.new()
	_hud.add_child(_trip)
	_trip.cancelled.connect(func():
		_trip=null
		_host.set_zone_modal(false))
