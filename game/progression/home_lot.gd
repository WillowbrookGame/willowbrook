extends Node3D
## Collect purchased furniture at your own mailbox/front path, as in the web game.
## The teller owns home acquisition; this node never grants or changes ownership.
const PICKUP_RADIUS := 4.0
const YARD_VISUALS = preload("res://game/progression/yard_visuals.gd")
var _yard_visuals: Node3D
var _host: Node3D
var _yard_panel: PanelContainer
var _yard_fields: VBoxContainer
var _yard_sign: Label3D
var _yard_message := ""

var _profile: RefCounted
var _account: Node
var _player: CharacterBody3D
var _doors: Array
var _packet: Node3D
var _packet_label: Label3D
var _notice: Label
var _notice_seconds := 0.0
var _plot := -1
var _first_delivery: Dictionary = {}


func setup(host: Node3D, player: CharacterBody3D, hud: CanvasLayer, doors: Array) -> void:
	_profile = host.profile
	_host = host
	_player = player
	_doors = doors.duplicate()
	_create_packet()
	_notice = Label.new()
	_notice.position = Vector2(18,148)
	_notice.modulate = Color("#fac557")
	_notice.add_theme_constant_override("outline_size",4)
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_notice)
	_profile.changed.connect(_refresh)
	if OS.has_feature("web"):
		_account = get_node_or_null("/root/WillowbrookBrowserSession")
	if _account != null and _account.has_signal("furniture_snapshot_changed"):
		_account.furniture_snapshot_changed.connect(_refresh)
		_account.furniture_result.connect(_account_result)
		_account.pet_snapshot_changed.connect(_refresh)
	if _account != null and _account.has_signal("yard_public_changed"):
		_yard_visuals = YARD_VISUALS.new()
		add_child(_yard_visuals)
		_yard_visuals.configure(_doors)
		_account.yard_public_changed.connect(_refresh_yard_visuals)
		_account.yard_result.connect(_yard_reply)
		_create_yard_menu(hud)
		_refresh_yard_visuals()
	_refresh()


func interaction_prompt() -> String:
	if _first_delivery.is_empty() or not _near(_plot):
		return "Improve your yard" if _near_yard() else ""
	return "Pick up %d × %s" % [_first_delivery.quantity,str(_first_delivery.kind).capitalize()]


func interact() -> bool:
	if (_first_delivery.is_empty() or not _near(_plot)) and _near_yard():
		_yard_panel.show()
		_yard_message = ""
		_render_yard_menu()
		_host.set_zone_modal(true)
		return true
	if _account != null and _account.has_method("furniture_deliveries"):
		if _first_delivery.is_empty() or not _near(_plot):
			return false
		if _account.furniture_waiting():
			_message("Waiting for the last package pickup.")
		elif _account.furniture_command("pickup",{"deliveryId":str(_first_delivery.id)}):
			_message("Collecting your saved delivery.")
		else:
			_message("Could not reach the server. Your package is still waiting.")
		return true
	var state: Dictionary = _profile.snapshot()
	var plot := _own_plot(state)
	var next := _delivery_index(state,plot)
	if next < 0 or not _near(plot):
		return false
	var parcel: Dictionary = state.deliveries[next]
	var kind := str(parcel.kind)
	var stack: Dictionary = {}
	for item in state.furniture:
		if item is Dictionary and item.get("kind") == kind and not item.has("x"):
			stack = item
			break
	var previous: int = int(stack.get("quantity",0))
	if previous < 0 or previous > 9007199254740991-int(parcel.quantity):
		_message("Your furniture inventory is full.")
		return true
	if stack.is_empty():
		state.furniture.append({"kind":kind,"quantity":parcel.quantity})
	else:
		stack.quantity = previous + int(parcel.quantity)
	state.deliveries.remove_at(next)
	if _profile.commit(state):
		_message("%d × %s added to your furniture inventory." % [parcel.quantity,kind.capitalize()])
	else:
		_message("Couldn't save your delivery. The package is still waiting.")
	return true


func tick(delta: float) -> void:
	if _notice_seconds > 0.0:
		_notice_seconds = maxf(0.0,_notice_seconds-delta)
		if _notice_seconds == 0.0:
			_notice.text = ""


func _message(text: String) -> void:
	_notice.text = text
	_notice_seconds = 4.0


func _own_plot(state: Dictionary) -> int:
	var home: Variant = state.get("home")
	if not home is Dictionary:
		return -1
	var plot: Variant = home.get("plot")
	return int(plot) if (plot is int or plot is float) and int(plot) >= 0 and int(plot) < _doors.size() else -1


func _near(plot: int) -> bool:
	if plot < 0:
		return false
	var p: Vector3 = _player.position
	var door: Vector3 = _doors[plot]
	return absf(p.y) < 2.0 and Vector2(p.x-door.x,p.z-door.z).length() <= PICKUP_RADIUS


func _delivery_index(state: Dictionary, plot: int) -> int:
	if plot < 0:
		return -1
	for i in state.deliveries.size():
		var parcel: Variant = state.deliveries[i]
		if _valid_delivery(parcel,plot):
			return i
	return -1


func _valid_delivery(parcel: Variant, plot: int) -> bool:
	return parcel is Dictionary and parcel.get("homeId",parcel.get("plot",plot)) == plot and parcel.get("kind") is String and not parcel.kind.is_empty() and parcel.get("quantity") is int and parcel.quantity >= 1 and parcel.quantity <= 10


func _account_result(_ok: bool,message: String) -> void:
	_refresh()
	_message(message)

func _refresh() -> void:
	var state: Dictionary = _profile.snapshot()
	if _account != null and _account.has_method("furniture_deliveries"):
		state.home = _account.saved_home()
		state.deliveries = _account.furniture_deliveries()
	var plot := _own_plot(state)
	_plot = plot
	var first := _delivery_index(state,plot)
	_first_delivery = state.deliveries[first] if first >= 0 else {}
	var count := 0
	if plot >= 0:
		for parcel in state.deliveries:
			if _valid_delivery(parcel,plot):
				count += int(parcel.quantity)
	if is_instance_valid(_yard_sign):
		_yard_sign.visible = plot>=0 and _account.yard_eligible()
		if _yard_sign.visible:
			_yard_sign.position = _yard_anchor() + Vector3.UP
	_packet.visible = count > 0
	if _packet.visible:
		_packet.position = _doors[plot] + Vector3(1.35,0.03,1.15)
		_packet_label.text = "Delivery (%d)" % count


func _refresh_yard_visuals() -> void:
	if is_instance_valid(_yard_visuals):
		_yard_visuals.update_rows(_account.yard_exterior())

func _yard_anchor() -> Vector3:
	return _doors[_plot] + Vector3(4.2,0,2.5)

func _near_yard() -> bool:
	if not is_instance_valid(_yard_panel) or _yard_panel.visible or _plot<0 or not _account.yard_eligible():
		return false
	var here := _player.position
	var at := _yard_anchor()
	return absf(here.y)<1.25 and Vector2(here.x-at.x,here.z-at.z).length()<=1.5

func _create_yard_menu(hud: CanvasLayer) -> void:
	_yard_sign = Label3D.new()
	_yard_sign.text = "Yard improvements"
	_yard_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_yard_sign.outline_size = 5
	_yard_sign.pixel_size = .0045
	_yard_sign.hide()
	add_child(_yard_sign)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_yard_panel = PanelContainer.new()
	center.add_child(_yard_panel)
	_yard_panel.hide()
	_yard_fields = VBoxContainer.new()
	_yard_fields.add_theme_constant_override("separation",8)
	_yard_panel.add_child(_yard_fields)

func _render_yard_menu() -> void:
	for child in _yard_fields.get_children():
		_yard_fields.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.text = "Yard improvements - saved stars: %d" % _account.saved_stars()
	_yard_fields.add_child(title)
	for row: Array in [["fence","Yard fence",30],["trees","Yard trees",20],["decor","Yard decorations",15]]:
		var kind: String = row[0]
		var cost: int = row[2]
		var installed := bool(_account.yard_flags().get(kind,false))
		var b := Button.new()
		b.text = "%s: %s" % [row[1],"Installed" if installed else "Buy for %d stars" % cost]
		b.custom_minimum_size.y = 42
		b.disabled = installed or _account.saved_stars() < cost
		b.pressed.connect(func():
			_yard_message = "Saving your improvement." if _account.buy_yard(kind) else ("Waiting for the last purchase." if _account.yard_waiting() else "Could not reach the server.")
			_render_yard_menu()
		)
		_yard_fields.add_child(b)
	if not _yard_message.is_empty():
		var status := Label.new()
		status.text = _yard_message
		_yard_fields.add_child(status)
	var done := Button.new()
	done.text = "Done"
	done.custom_minimum_size.y = 42
	done.pressed.connect(_close_yard_menu)
	_yard_fields.add_child(done)

func _close_yard_menu() -> void:
	if not is_instance_valid(_yard_panel) or not _yard_panel.visible:
		return
	_yard_panel.hide()
	_host.set_zone_modal(false)

func _input(event: InputEvent) -> void:
	if is_instance_valid(_yard_panel) and _yard_panel.visible and event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		_close_yard_menu()
		get_viewport().set_input_as_handled()

func _yard_reply(_ok: bool,message: String) -> void:
	if is_instance_valid(_yard_panel) and _yard_panel.visible:
		_yard_message = message
		_render_yard_menu()
	else:
		_message(message)

func _create_packet() -> void:
	_packet = Node3D.new()
	_packet.name = "HomeDeliveryPackage"
	add_child(_packet)
	_crate_box(Vector3(0,0.23,0),Vector3(0.60,0.46,0.46),Color("#a8723f"))
	_crate_box(Vector3(0,0.467,0),Vector3(0.13,0.014,0.475),Color("#dfb66c"))
	_crate_box(Vector3(0,0.24,0.233),Vector3(0.13,0.44,0.014),Color("#dfb66c"))
	_packet_label = Label3D.new()
	_packet_label.position = Vector3(0,0.88,0)
	_packet_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_packet_label.modulate = Color("#f6d081")
	_packet_label.font_size = 28
	_packet_label.outline_size = 5
	_packet_label.pixel_size = 0.005
	_packet.add_child(_packet_label)


func _crate_box(at: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var box := MeshInstance3D.new()
	box.position = at
	box.mesh = mesh
	_packet.add_child(box)
