extends SceneTree

const PROFILE := preload("res://game/progression/profile.gd")
const TOWN := preload("res://game/town_layout.gd")

func _initialize() -> void:
	run.call_deferred()

func expect(ok: bool, detail: String) -> bool:
	if not ok:
		push_error(detail)
		quit(1)
	return ok

func mouse(button: MouseButton, pressed: bool, at: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = pressed
	ev.position = at
	root.push_input(ev,true)

func drag_mouse(from: Vector2, to: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	mouse(button,true,from)
	var ev := InputEventMouseMotion.new()
	ev.position = to
	ev.relative = to - from
	root.push_input(ev,true)
	mouse(button,false,to)

func drag_touch(from: Vector2, to: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 1
	down.position = from
	down.pressed = true
	root.push_input(down,true)
	var move := InputEventScreenDrag.new()
	move.index = 1
	move.position = to
	move.relative = to - from
	root.push_input(move,true)
	var up := InputEventScreenTouch.new()
	up.index = 1
	up.position = to
	root.push_input(up,true)

func projected(room: Node3D, x: float, z: float, height := 0.0) -> Vector2:
	return room._decorator.camera.unproject_position(room.art.to_global(Vector3(x,height,z)))

func step_frame() -> void:
	await process_frame
	await process_frame
	await process_frame

func run() -> void:
	set_meta("willowbrook_save_override","")
	set_meta("fishing_save_override","")
	root.size = Vector2i(1366,768)
	var profile := PROFILE.new("")
	set_meta("willowbrook_profile",profile)
	change_scene_to_file("res://game/town.tscn")
	await scene_changed
	var next: Dictionary = profile.snapshot()
	next.home = {"plot":0,"variant":"starter"}
	next.furniture = [{"kind":"chair","quantity":3},{"kind":"books","quantity":2},{"kind":"table","id":"fixture-table","room":0,"x":2.0,"z":1.75,"rotation":0}]
	if not expect(profile.commit(next),"Fixture rejected"): return
	var town := current_scene
	town.player.position = TOWN.HOME_DOORS[0] + Vector3(0,.04,1.3)
	town._interact()
	await scene_changed
	var map := current_scene
	var room: Node3D = map.room
	room._home_menu()
	await step_frame()
	if not expect(room._decorator.camera.is_current() and map.zone_modal,"editor camera and modal did not open"): return
	var floor_point := projected(room,-2.0,-1.0)
	var point: Vector3 = room._decorator.point_at(floor_point,0.0)
	if not expect(point.distance_to(Vector3(-2.0,0,-1.0)) < .02,"projection did not round trip: %s" % str(point)): return
	var from := projected(room,room._edit_at.x,room._edit_at.y,1.15)
	var to := from + (projected(room,-2.0,-1.0) - projected(room,room._edit_at.x,room._edit_at.y))
	drag_mouse(from,to)
	if not expect(room._edit_at.is_equal_approx(Vector2(-2,-1)),"mouse failed to drag packed preview: %s" % str(room._edit_at)): return
	if not expect(profile.snapshot().furniture.size()==3,"drag wrote before confirmation"): return
	var confirm_at: Vector2 = room._edit_apply.get_global_rect().get_center()
	mouse(MOUSE_BUTTON_LEFT,true,confirm_at)
	mouse(MOUSE_BUTTON_LEFT,false,confirm_at)
	await step_frame()
	if not expect(room.art.decor.get_child_count()==2 and not room._edit_at.is_equal_approx(Vector2(-2,-1)) and not room._edit_apply.disabled,"second placement did not get a clear preview"): return
	root.size=Vector2i(820,1180)
	await step_frame()
	if not expect(room.panel.offset_top > 0.0 and room._room_window.get_global_rect().end.y <= root.get_visible_rect().end.y + 1.0,"portrait control dock overflowed"): return
	var touch_at := projected(room,2,-1)
	drag_touch(touch_at,projected(room,2.5,-1.5))
	if not expect(room._edit_at.is_equal_approx(Vector2(2.5,-1.5)),"touch failed to drag packed preview: %s" % str(room._edit_at)): return
	room._edit_apply.pressed.emit()
	await step_frame()
	if not expect(room.art.decor.get_child_count()==3,"second confirmed placement not saved"): return
	var placed_at := projected(room,-2,-1,1.15)
	drag_touch(placed_at,placed_at + (projected(room,-2.5,-2.5) - projected(room,-2,-1)))
	if not expect(room._edit_piece().has("id") and room._edit_at.is_equal_approx(Vector2(-2.5,-2.5)),"world picking or dragging placed chair failed: %s" % str(room._edit_at)): return
	room._edit_apply.pressed.emit()
	await step_frame()
	var moved: Array = profile.snapshot().furniture.filter(func(item: Dictionary): return item.get("x") == -2.5 and item.get("z") == -2.5)
	if not expect(moved.size()==1,"placed chair move did not persist"): return
	var books := -1
	for option in range(room._edit_indices.size()):
		if room._edit_pieces[room._edit_indices[option]].get("kind") == "books":
			books = option
			break
	if not expect(books >= 0,"packed books missing"): return
	room._choose_furniture(books)
	var origin := projected(room,room._edit_at.x,room._edit_at.y,.27625)
	drag_touch(origin,projected(room,2.0,1.75,.698906+.27625))
	if not expect(not room._edit_apply.disabled and room._edit_support().get("surface",{}).get("id") == "top","touch did not snap books onto the table: %s" % room._edit_hint.text): return
	room._edit_apply.pressed.emit()
	await step_frame()
	var stacked: Array = profile.snapshot().furniture.filter(func(item: Dictionary): return item.get("supportId") == "fixture-table" and item.get("surfaceId") == "top")
	if not expect(stacked.size() == 1 and float(stacked[0].y) > .69,"stacked books did not persist"): return
	var table_screen := projected(room,2.6,1.75,.698906)
	var table_choice: String = room._decorator.pick_item(table_screen,room._edit_pieces)
	if not expect(table_choice == "fixture-table","stack must still allow selection of its support"): return
	var table_option := -1
	for option in range(room._edit_indices.size()):
		if room._edit_pieces[room._edit_indices[option]].get("id") == "fixture-table":
			table_option = option
			break
	if not expect(table_option >= 0,"placed table missing"): return
	room._choose_furniture(table_option)
	if not expect(room._edit_apply.disabled,"table with books accepted unsafe move"): return
	var turn_before: float = room._decorator.yaw
	drag_mouse(projected(room,0,-2),projected(room,0,-2)+Vector2(35,0),MOUSE_BUTTON_RIGHT)
	if not expect(not is_equal_approx(room._decorator.yaw,turn_before),"camera drag failed"): return
	room.close_modal()
	await step_frame()
	if not expect(not map.zone_modal and map.camera.is_current() and not room.art.placement_ghost.visible,"close did not restore world camera/input or clear preview"): return
	print("PASS: home editor mouse and touch placement, repeat placement, selecting and moving saved item, portrait layout, stacking, orbit, and camera restore.")
	quit(0)