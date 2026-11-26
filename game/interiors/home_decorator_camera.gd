extends Node3D
## Edit camera and ray projection. No save or input authority lives here.
const PLACEMENT := preload("res://game/interiors/housing_placement.gd")
var camera: Camera3D
var previous: Camera3D
var room := 0
var yaw := 0.0
var zoom := 1.0
var canvas_size := Vector2.ZERO
var clear_rect := Rect2()


func start(view: Viewport) -> void:
	if is_instance_valid(camera): return
	previous = view.get_camera_3d()
	camera = Camera3D.new()
	camera.name = "FurnitureEditCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	add_child(camera)
	camera.make_current()


func stop() -> void:
	if not is_instance_valid(camera): return
	if camera.is_current() and is_instance_valid(previous): previous.make_current()
	camera.queue_free()
	camera = null
	previous = null


func frame_room(index: int, viewport_size: Vector2, visible_area: Rect2) -> void:
	room = index
	canvas_size = viewport_size
	clear_rect = visible_area
	_update()


func turn(radians: float) -> void:
	yaw = wrapf(yaw + radians, -PI, PI)
	_update()


func zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, .65, 1.45)
	_update()


func _update() -> void:
	if not is_instance_valid(camera) or clear_rect.size.x < 1.0 or clear_rect.size.y < 1.0: return
	var at := Vector3(room * PLACEMENT.ROOM_STRIDE, .4, 0.0)
	camera.position = at + Vector3(0, 13.5, 7.8).rotated(Vector3.UP, yaw)
	camera.look_at(to_global(at))
	camera.size = maxf(15.0 * canvas_size.y / clear_rect.size.x, 13.0 * canvas_size.y / clear_rect.size.y) * zoom
	var shift := (clear_rect.get_center() - canvas_size * .5) * camera.size / canvas_size.y
	camera.h_offset = -shift.x
	camera.v_offset = shift.y


func point_at(screen: Vector2, height: float) -> Vector3:
	if not is_instance_valid(camera): return Vector3.INF
	var origin := to_local(camera.project_ray_origin(screen))
	var ray := global_basis.inverse() * camera.project_ray_normal(screen)
	if absf(ray.y) < .001: return Vector3.INF
	var distance := (height - origin.y) / ray.y
	if distance < 0.0: return Vector3.INF
	var at := origin + ray * distance
	at.x -= room * PLACEMENT.ROOM_STRIDE
	return at


func pick_item(screen: Vector2, pieces: Array) -> String:
	var selected := ""
	var highest := -1.0
	for item: Dictionary in pieces:
		if not item.has("id") or not item.has("x") or int(item.get("room", -1)) != room: continue
		var raised := item.get("supportId") != null
		var height := float(item.get("y", 0.0)) + PLACEMENT.height(str(item.kind))
		var at := point_at(screen, height)
		if at.is_finite() and height > highest and PLACEMENT.footprint(item, raised).grow(.12).has_point(Vector2(at.x, at.z)):
			selected = str(item.id)
			highest = height
	return selected