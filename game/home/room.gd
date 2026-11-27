extends "res://game/interiors/room.gd"

const HOME_ART := preload("res://game/home/room_art.gd")

const EDIT_CAMERA := preload("res://game/interiors/home_decorator_camera.gd")
var _decorator: EDIT_CAMERA
var _editor_key := ""
var _edit_room := 0
var _edit_rooms := 1
var _edit_pieces: Array = []
var _edit_indices: Array[int] = []
var _edit_supports: Array[Dictionary] = []
var _edit_choices: OptionButton
var _edit_surfaces: OptionButton
var _edit_hint: Label
var _edit_apply: Button
var _edit_pack: Button
var _edit_turn := 0
var _edit_at := Vector2.ZERO
var _edit_orbit := false
var _drag_orbit := false
var _drag_offset := Vector2.ZERO
var _drag_height := 0.0
var _edit_pointer := -1
var _edit_mouse_button := MOUSE_BUTTON_LEFT



func _new_room_art() -> ART:
	return HOME_ART.new()

func spawn_position() -> Vector3:
	return Vector3(0,.04,3.5)

func bounds() -> Vector2:
	# All home floors end at z = 5. Keep the player inside that edge, within exit range.
	return Vector2(30,4.8)

func _near_exit() -> bool:
	return absf(player.position.x)<1.25 and player.position.z>=4.0

func _build_furniture_editor(p: Dictionary) -> void:
	var old_key := _editor_key
	var old_at := _edit_at
	var old_turn := _edit_turn
	var preserve := not _editor_key.is_empty()
	_edit_pieces = p.get("furniture",[])
	_edit_rooms = HOUSING_PLACEMENT.room_count(p)
	var local_player := art.to_local(player.global_position)
	_edit_room = clampi(floori((local_player.x + HOUSING_PLACEMENT.ROOM_STRIDE * .5) / HOUSING_PLACEMENT.ROOM_STRIDE), 0, _edit_rooms - 1)
	_edit_indices.clear()
	_edit_choices = OptionButton.new()
	_edit_choices.name = "FurnitureChoice"
	_edit_choices.fit_to_longest_item = false
	_edit_choices.get_popup().add_theme_constant_override("v_separation", 18)
	_edit_choices.custom_minimum_size.y = 68
	for i in range(_edit_pieces.size()):
		var piece: Dictionary = _edit_pieces[i]
		var kind := str(piece.get("kind", ""))
		var spec: Dictionary = DATA.data.furnitureCatalog.get(kind, {})
		if spec.is_empty(): continue
		if piece.has("x") and int(piece.get("room", -1)) != _edit_room: continue
		_edit_indices.append(i)
		_edit_choices.add_item(("Placed: %s" % spec.name) if piece.has("x") else ("Packed: %s x %d" % [spec.name, int(piece.get("quantity", 1))]))
	_label("Room %d of %d. Walk into another room to decorate it." % [_edit_room + 1, _edit_rooms])
	var tools := HFlowContainer.new()
	fields.add_child(tools)
	_editor_button(tools, "View left", func(): _decorator.turn(PI / 4.0))
	_editor_button(tools, "View right", func(): _decorator.turn(-PI / 4.0))
	_editor_button(tools, "Zoom in", func(): _decorator.zoom_by(.88))
	_editor_button(tools, "Zoom out", func(): _decorator.zoom_by(1.0 / .88))
	var camera_mode := _editor_button(tools, "Drag to orbit", func(): pass)
	camera_mode.toggle_mode = true
	camera_mode.set_pressed_no_signal(_edit_orbit)
	camera_mode.toggled.connect(func(on: bool): _edit_orbit = on)
	if _edit_indices.is_empty():
		_edit_choices.free()
		_edit_choices = null
		_editor_key = ""
		_label("No furniture in this room or in storage. The Town Store sells furnishings.")
		return
	fields.add_child(_edit_choices)
	_edit_surfaces = OptionButton.new()
	_edit_surfaces.name = "FurnitureSurface"
	_edit_surfaces.fit_to_longest_item = false
	_edit_surfaces.get_popup().add_theme_constant_override("v_separation", 18)
	_edit_surfaces.custom_minimum_size.y = 68
	fields.add_child(_edit_surfaces)
	_editor_button(tools, "Rotate item", func():
		_edit_turn = posmod(_edit_turn + 1, 4)
		_refresh_furniture_preview()
	)
	_edit_hint = _label("")
	_edit_hint.name = "PlacementPreviewStatus"
	_edit_apply = _editor_button(_edit_commands, "Place furniture", _apply_furniture_edit)
	_edit_apply.name = "ConfirmFurniturePlacement"
	_edit_pack = _editor_button(_edit_commands, "Pack away", func(): _pack_furniture(_edit_indices[_edit_choices.selected]))
	_edit_choices.item_selected.connect(func(option: int): _choose_furniture(option))
	_edit_surfaces.item_selected.connect(func(_option: int):
		var support := _edit_support()
		if not support.is_empty():
			var base: Dictionary = _edit_pieces[support.index]
			var surface: Dictionary = support.surface
			var turn := int(base.rotation)
			var at := Vector2(float(surface.x), float(surface.z)).rotated(-turn * PI / 2.0)
			_edit_turn = turn
			_edit_at = Vector2(float(base.x), float(base.z)) + at
			_edit_at = _edit_at.snapped(Vector2(.25, .25))
		_refresh_furniture_preview()
	)
	var kept := -1
	var first_packed := -1
	for option in range(_edit_indices.size()):
		var row: Dictionary = _edit_pieces[_edit_indices[option]]
		if not row.has("x") and first_packed < 0: first_packed = option
		if _furniture_key(row) == old_key: kept = option
	var option := kept if kept >= 0 else maxi(0, first_packed)
	_choose_furniture(option, preserve and kept >= 0, old_at, old_turn)


func _editor_button(parent: Control, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(68, 68)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _furniture_key(piece: Dictionary) -> String:
	return "placed:" + str(piece.id) if piece.has("x") else "packed:" + str(piece.kind)


func _edit_piece() -> Dictionary:
	if not is_instance_valid(_edit_choices) or _edit_choices.selected < 0: return {}
	return _edit_pieces[_edit_indices[_edit_choices.selected]]


func _choose_furniture(option: int, preserve := false, at := Vector2.ZERO, turns := 0) -> void:
	_edit_choices.select(option)
	var piece := _edit_piece()
	_editor_key = _furniture_key(piece)
	var moving := piece.has("x")
	_edit_turn = int(piece.get("rotation",0)) if moving or not preserve else turns
	_edit_at = Vector2(float(piece.x),float(piece.z)) if moving else (at if preserve else Vector2(1.75,-1.75))
	_edit_surfaces.clear()
	_edit_surfaces.add_item("On the floor")
	_edit_supports = [{}]
	if DATA.data.furnitureCatalog[piece.kind].get("surfacePlaceable",false):
		for i in range(_edit_pieces.size()):
			var base: Dictionary = _edit_pieces[i]
			if not base.has("x") or not base.has("id") or base.get("supportId") != null or base.get("id") == piece.get("id", "") or int(base.room) != _edit_room: continue
			for surface: Dictionary in DATA.data.furnitureSurfaces.get(base.kind,[]):
				_edit_supports.append({"index":i,"surface":surface})
				_edit_surfaces.add_item("%s / %s" % [DATA.data.furnitureCatalog[base.kind].name,surface.label])
				if moving and piece.get("supportId") == base.id and piece.get("surfaceId") == surface.id:
					_edit_surfaces.select(_edit_supports.size()-1)
	_edit_surfaces.visible = _edit_supports.size() > 1
	_edit_pack.visible = moving
	_edit_apply.text = "Save move" if moving else "Place furniture"
	if not moving and not str(_edit_candidate(_edit_at).error).is_empty():
		# Prefer the last working spot, then a nearby clear square. Do not save until confirmed.
		var offsets := [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2(1,1),Vector2(1,-1),Vector2(-1,1),Vector2(-1,-1)]
		var found := false
		for step in range(1, 21):
			for delta: Vector2 in offsets:
				var next := _edit_at + delta * step * .25
				if str(_edit_candidate(next).error).is_empty():
					_edit_at = next
					found = true
					break
			if found: break
	_refresh_furniture_preview()


func _edit_support() -> Dictionary:
	return _edit_supports[_edit_surfaces.selected] if is_instance_valid(_edit_surfaces) and _edit_surfaces.selected >= 0 else {}


func _edit_candidate(at: Vector2) -> Dictionary:
	var piece := _edit_piece()
	var moving := piece.has("x")
	var item := {"kind":piece.kind,"room":_edit_room,"x":at.x,"z":at.y,"rotation":_edit_turn}
	var others: Array = _edit_pieces
	if moving:
		others = _edit_pieces.filter(func(other: Dictionary): return other.get("id") != piece.id)
		for other: Dictionary in others:
			if other.get("supportId") == piece.id:
				return {"item":item,"error":"Move or pack the decorations on this furniture first."}
	var support := _edit_support()
	var base: Dictionary = {} if support.is_empty() else _edit_pieces[int(support.index)]
	var surface: Dictionary = support.get("surface",{})
	if not base.is_empty():
		item.supportId = base.id
		item.surfaceId = surface.id
		item.y = float(surface.y)
	var err := HOUSING_PLACEMENT.placement_error(item,others,_edit_rooms,art.to_local(player.global_position),_placement_player_radius(),base,surface,_account()!=null)
	return {"item":item,"error":err}


func _refresh_furniture_preview() -> void:
	if not is_instance_valid(_edit_apply) or _edit_piece().is_empty(): return
	var result := _edit_candidate(_edit_at)
	var ready: bool = str(result.error).is_empty()
	_edit_apply.disabled = not ready
	_edit_hint.text = "Green preview: ready to save." if ready else str(result.error)
	art.show_placement_ghost(result.item,ready)


func _apply_furniture_edit() -> void:
	var piece := _edit_piece()
	if piece.is_empty() or _visiting(): return
	var result := _edit_candidate(_edit_at)
	if not str(result.error).is_empty():
		feedback(result.error)
		return
	var index := _edit_indices[_edit_choices.selected]
	if not piece.has("x"):
		_place_furniture(index,_edit_room,_edit_at.x,_edit_at.y,_edit_turn,_edit_support())
		return
	var item: Dictionary = result.item
	var account := _account()
	if account != null:
		item.erase("y")
		item.id = str(piece.id)
		item.expectedRevision = int(piece.get("revision",0))
		_send_furniture("move",item)
		return
	var p := _snapshot()
	if index >= p.furniture.size() or p.furniture[index].get("id") != piece.id: return
	item.id = piece.id
	item.revision = int(piece.get("revision",0))+1
	p.furniture[index] = item
	if _commit(p,"Furniture position saved."):
		art.redraw_decor(p)
		_home_menu(false)


func _setup_home_editor(profile: Dictionary) -> void:
	if not is_instance_valid(_decorator):
		_decorator = EDIT_CAMERA.new()
		art.add_child(_decorator)
	_decorator.start(get_viewport())
	_build_furniture_editor(profile)
	_layout_room_panel()


func _close_home_editor() -> void:
	_editor_key = ""
	_edit_pointer = -1
	_edit_orbit = false
	if is_instance_valid(_decorator):
		_decorator.stop()
		_decorator.yaw = 0.0
		_decorator.zoom = 1.0


func _layout_home_editor(viewport_size: Vector2) -> void:
	if not is_instance_valid(_decorator): return
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edit_pointer = -1
	var landscape := viewport_size.x >= viewport_size.y * 1.18
	var clear := Rect2(Vector2.ZERO,viewport_size)
	if landscape:
		var left := minf(viewport_size.x * .48,maxf(360.0,viewport_size.x * .34))
		panel.offset_right = left - viewport_size.x
		_room_scroll.custom_minimum_size = Vector2(left - 58.0,clampf(viewport_size.y * .53,150.0,460.0))
		clear.position.x = left
		clear.size.x -= left
	else:
		var top := viewport_size.y * .51
		panel.offset_top = top
		_room_scroll.custom_minimum_size = Vector2(minf(560.0,viewport_size.x - 58.0),clampf(viewport_size.y * .19,126.0,300.0))
		clear.size.y = top
	_decorator.frame_room(_edit_room,viewport_size,clear)


func _input(event: InputEvent) -> void:
	# Once a drag starts, finish it even if the pointer travels over the menu.
	if not _editing_furniture() or _edit_pointer == -1: return
	if event is InputEventScreenDrag and event.index == _edit_pointer:
		_drag_in_room(event.position, event.relative)
	elif event is InputEventScreenTouch and event.index == _edit_pointer:
		if not event.pressed or event.canceled: _edit_pointer = -1
	elif event is InputEventMouseMotion and _edit_pointer == -2 and event.device != -1:
		_drag_in_room(event.position, event.relative)
	elif event is InputEventMouseButton and _edit_pointer == -2 and event.device != -1 and event.button_index == _edit_mouse_button:
		if not event.pressed: _edit_pointer = -1
	else: return
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _editing_furniture() or _edit_pointer != -1: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_modal()
	elif event is InputEventScreenTouch and event.pressed and not event.canceled:
		if not _start_room_drag(event.position,event.index,_edit_orbit): return
	elif event is InputEventMouseButton and event.pressed and event.device != -1:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _room_window.get_global_rect().has_point(event.position): return
			_decorator.zoom_by(.90 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/.90)
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
			_edit_mouse_button = event.button_index
			if not _start_room_drag(event.position,-2,_edit_orbit or event.button_index == MOUSE_BUTTON_RIGHT): return
		else: return
	else: return
	get_viewport().set_input_as_handled()


func _editing_furniture() -> bool:
	return active_panel == "home" and is_modal_open() and is_instance_valid(_decorator) and not _visiting()


func _start_room_drag(at: Vector2, finger: int, orbit: bool) -> bool:
	if _room_window.get_global_rect().has_point(at): return false
	var hit := ""
	var preview_hit := false
	if not orbit and not _edit_piece().is_empty():
		# A press on a placed object picks it up. A press on empty space moves
		# the current preview. Neither action writes to the save.
		var item := _edit_piece()
		hit = _decorator.pick_item(at,_edit_pieces)
		var preview: Dictionary = _edit_candidate(_edit_at).item
		var point := _decorator.point_at(at,float(preview.get("y",0.0)) + HOUSING_PLACEMENT.height(str(item.kind)))
		if point.is_finite():
			preview_hit = HOUSING_PLACEMENT.footprint(preview,preview.has("supportId")).grow(.15).has_point(Vector2(point.x,point.z))
		if not hit.is_empty() and not preview_hit:
			for option in range(_edit_indices.size()):
				if _edit_pieces[_edit_indices[option]].get("id") == hit:
					_choose_furniture(option)
					break
	_drag_orbit = orbit
	_edit_pointer = finger
	_drag_offset = Vector2.ZERO
	_drag_height = 0.0
	if not orbit and not _edit_piece().is_empty():
		if preview_hit or not hit.is_empty():
			_drag_height = HOUSING_PLACEMENT.height(str(_edit_piece().kind))
			var point := _decorator.point_at(at,float(_edit_support().get("surface",{}).get("y",0.0)) + _drag_height)
			if point.is_finite(): _drag_offset = _edit_at - Vector2(point.x,point.z)
		else:
			_drag_in_room(at,Vector2.ZERO)
	return true


func _drag_in_room(at: Vector2, motion: Vector2) -> void:
	if _drag_orbit:
		_decorator.turn(-motion.x * .009)
		return
	if _edit_piece().is_empty() or _room_window.get_global_rect().has_point(at): return
	var selected_surface := _surface_under_pointer(at)
	var surface: Dictionary = _edit_supports[selected_surface].get("surface",{})
	var projected := _decorator.point_at(at,float(surface.get("y",0.0)) + _drag_height)
	if not projected.is_finite(): return
	var next := (Vector2(projected.x,projected.z) + _drag_offset).snapped(Vector2(.25,.25))
	if not HOUSING_PLACEMENT.USABLE_FLOOR.grow(.25).has_point(next): return
	if next != _edit_at or selected_surface != _edit_surfaces.selected:
		_edit_surfaces.select(selected_surface)
		_edit_at = next
		_refresh_furniture_preview()


func _surface_under_pointer(at: Vector2) -> int:
	# Only server-supported surfaces are offered. Prefer the upper surface
	# if shelves overlap on screen; the chooser can select a lower shelf.
	var hit := 0
	var highest := -1.0
	for option in range(1,_edit_supports.size()):
		var support := _edit_supports[option]
		var row: Dictionary = _edit_pieces[int(support.index)]
		var surface: Dictionary = support.surface
		var height := float(surface.y)
		if height < highest: continue
		var point := _decorator.point_at(at,height + _drag_height)
		if not point.is_finite(): continue
		var offset := Vector2(point.x-float(row.x),point.z-float(row.z)).rotated(int(row.rotation)*PI/2.0)
		var size := Vector2(float(surface.width),float(surface.depth))
		var centered := Vector2(float(surface.x),float(surface.z))-size*.5
		if Rect2(centered,size).grow(.045).has_point(offset):
			hit = option
			highest = height
	return hit


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_edit_pointer = -1
