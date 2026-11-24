extends Node3D
## Original town job board, HUD, and next-step marker. All state lives in Profile.
const BOARD := Vector3(10,0,4)
const BOARD_RADIUS := 4.5
const TASK_COLOR := Color("#fac557")
const FIT = preload("res://game/hud_fit.gd")
const PARK_ART = preload("res://game/progression/park_cleanup_art.gd")

var _host: Node3D
var _player: CharacterBody3D
var _profile: RefCounted
var _overlay: CenterContainer
var _offline_stars: Label
var _activity_ui: JavaScriptObject
var _activity_open_cb: JavaScriptObject
var _activity_layout_cb: JavaScriptObject
var _activity_bottom := 56.0
var _activity_flags := ""
var _neighbor_board: Button
var _notice: Label
var _board_status: Label
var _heading: Label
var _guide: Label
var _jobs: OptionButton
var _cancel: Button
var _checklist_button: Button
var _switch: Button
var _checking_starters := false
var _scroll: ScrollContainer
var _marker: Node3D
var _marker_label: Label3D
var _marker_ring: MeshInstance3D
var _park_props := {}
var _park_prop_kind := ""
var _time_left := 0.0
var _checklist_refresh := 0.0
var _fit_board: Callable
var _neighbors: Node3D


func setup(host: Node3D, player: CharacterBody3D, hud: CanvasLayer) -> void:
	_host = host
	_player = player
	_profile = host.profile
	_neighbors = host.get_node_or_null("TownLayout/TownNpcs")
	_create_hud(hud)
	_create_marker()
	_sync_marker()


func _account() -> Node:
	var node := get_node_or_null("/root/WillowbrookBrowserSession")
	return node if OS.has_feature("web") and node != null and node.has_method("job_offer") else null

func interaction_prompt() -> String:
	if is_modal_open():
		return ""
	var account := _account()
	var offer: Dictionary = account.job_offer(false) if account != null else {}
	var task: String = String(offer.get("label","")) if account != null else _profile.prompt("town",_player.position,true)
	if not task.is_empty():
		return task
	var distance := Vector2(_player.position.x-BOARD.x,_player.position.z-BOARD.z).length()
	if distance <= BOARD_RADIUS:
		return "Read the job board"
	return ""


func interact() -> bool:
	var prompt := interaction_prompt()
	if prompt.is_empty():
		return false
	if prompt == "Read the job board":
		_open_board(false)
	elif _account() != null:
		_account().interact_job(_account().job_offer(false))
	else:
		_show_result(_profile.perform("town",_player.position,-1.0,true))
		_sync_marker()
	return true


func conversation_id() -> String:
	return _neighbors.nearby(_player.global_position) if is_instance_valid(_neighbors) else ""

func conversation_prompt() -> String:
	var id := conversation_id()
	return _neighbors.prompt_for(id) if not id.is_empty() else ""

func talk() -> bool:
	var id := conversation_id()
	if id.is_empty():
		return false
	if id == "car_lot":
		_host.vehicles._open_purchase()
		return true
	var account := _account()
	var can_hire: bool = _neighbors.hire_in_reach(id,_player.global_position)
	if account != null:
		account.interact_job({"kind":"hire","job":id,"label":_neighbors.prompt_for(id),"hire_in_reach":can_hire})
	elif _profile.memberships().has(id):
		var guide: Dictionary = _profile.job_guide(id)
		_show_result({"text":"You're already hired. Start at: " + String(guide.get("station","the marked station")) + "."})
	elif can_hire:
		_show_result(_profile.hire(id,"town",_player.position))
	else:
		_show_result({"text":"Come closer to the front if you'd like to get hired."})
	return true

func _open_board(starters: bool) -> void:
	_checking_starters = starters
	_refresh_board()
	_overlay.show()
	(_switch if starters else _jobs).grab_focus()
	_host.set_zone_modal(true)


func tick(delta: float) -> void:
	if _account() == null:
		_show_result(_profile.advance("town",_player.position))
	if _time_left > 0.0:
		_time_left -= delta
		if _time_left <= 0.0:
			_notice.text = ""
	_sync_marker()
	if is_modal_open() and _checking_starters:
		_checklist_refresh -= delta
		if _checklist_refresh <= 0.0:
			_checklist_refresh = 1.0
			_refresh_board()


func is_modal_open() -> bool:
	return is_instance_valid(_overlay) and _overlay.visible


func close_modal() -> void:
	if is_modal_open():
		_overlay.hide()
		_host.set_zone_modal(false)


func _show_result(result: Dictionary) -> void:
	if not result.is_empty():
		_notice.text = str(result.get("text",""))
		_time_left = 4.0


func _sync_marker() -> void:
	_offline_stars.text = "%d Stars" % _profile.get_stars()
	var status: String = _profile.status_text()
	if _time_left <= 0.0 and _account() == null:
		_notice.text=status
	var marker: Dictionary = _profile.current_marker("town")
	var online := _account()
	if online != null:
		var active_markers: Array = online.job_markers(true)
		marker = active_markers[0] if not active_markers.is_empty() else {}
	var has_tasks := not _onboarding_complete(online)
	var no_modal: bool = not is_modal_open() and _host.get("zone_modal")!=true
	if _activity_ui != null:
		_checklist_button.hide()
		var flags := [no_modal and (online==null or not online.has_method("activity_hud_allowed") or online.activity_hud_allowed()),has_tasks,online!=null and online.has_method("neighbor_quests_completed") and not online.neighbor_quests_completed()]
		var fingerprint := str(flags)
		if fingerprint!=_activity_flags:
			_activity_flags=fingerprint
			_activity_ui.setTown(str(get_instance_id()),flags[0],flags[1],flags[2])
	else:
		_checklist_button.visible = no_modal and has_tasks
	var account := get_node_or_null("/root/WillowbrookBrowserSession")
	if OS.has_feature("web") and account != null and account.has_method("garden_approach") and account.garden_approach():
		_marker.hide()
		return
	# The original gives the destination name, not an arrow, for parcel shifts.
	if marker.is_empty() and not status.begins_with("Deliver to "):
		var radius := 9.0
		for candidate: Dictionary in (online.job_markers() if online != null else _profile.available_markers("town")):
			if candidate.get("kind") == "hire":
				continue
			var distance: float = _player.position.distance_to(candidate.position)
			if distance < radius:
				radius = distance
				marker = candidate
	_marker.visible = not marker.is_empty() and not status.begins_with("Deliver to ")
	if _marker.visible:
		_marker.position = marker.position + Vector3.UP * 0.12
		_marker_label.text = marker.label
		_show_park_prop(marker)


func _create_marker() -> void:
	_marker = Node3D.new()
	_marker.name = "JobTaskMarker"
	add_child(_marker)
	var ring := MeshInstance3D.new()
	var shape := TorusMesh.new()
	shape.inner_radius = 0.52
	shape.outer_radius = 0.61
	shape.rings = 16
	shape.ring_segments = 8
	ring.mesh = shape
	var material := StandardMaterial3D.new()
	material.albedo_color = TASK_COLOR
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = material
	_marker.add_child(ring)
	_marker_ring = ring
	_marker_label = Label3D.new()
	_marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_marker_label.font_size = 32
	_marker_label.outline_size = 7
	_marker_label.pixel_size = 0.0055
	_marker_label.modulate = TASK_COLOR
	_marker_label.position = Vector3.UP * 1.3
	_marker.add_child(_marker_label)



func _show_park_prop(marker: Dictionary) -> void:
	var kind: String = PARK_ART.prop_for(marker)
	if kind == _park_prop_kind:
		return
	if _park_props.has(_park_prop_kind):
		_park_props[_park_prop_kind].hide()
	_park_prop_kind = kind
	_marker_ring.visible = kind.is_empty()
	if kind.is_empty():
		return
	if not _park_props.has(kind):
		_park_props[kind] = PARK_ART.make_prop(kind)
		_marker.add_child(_park_props[kind])
	_park_props[kind].show()

func _label(text: String, font_size: int = 17) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_constant_override("outline_size",4)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _create_hud(hud: CanvasLayer) -> void:
	_offline_stars = _label("")
	_offline_stars.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	hud.add_child(_offline_stars)
	_offline_stars.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var account := get_node_or_null("/root/WillowbrookBrowserSession")
	if OS.has_feature("web") and account != null and account.has_method("tend_garden"):
		_offline_stars.hide()
	_notice = _label("")
	_notice.position = Vector2(18,120)
	_notice.modulate = TASK_COLOR
	hud.add_child(_notice)
	_checklist_button = Button.new()
	_checklist_button.text = "Getting Started"
	_checklist_button.position = Vector2(18,156)
	_checklist_button.custom_minimum_size = Vector2(125,44)
	_checklist_button.focus_mode = Control.FOCUS_NONE
	_checklist_button.pressed.connect(_open_board.bind(true))
	hud.add_child(_checklist_button)
	_overlay = CenterContainer.new()
	_overlay.name = "JobBoardPanel"
	hud.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	var backdrop := StyleBoxFlat.new()
	backdrop.bg_color = Color("#152334f5")
	backdrop.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel",backdrop)
	_overlay.add_child(panel)
	var padding := MarginContainer.new()
	panel.add_child(padding)
	for side in ["left","top","right","bottom"]:
		padding.add_theme_constant_override("margin_"+side,16)
	var column := VBoxContainer.new()
	padding.add_child(column)
	column.custom_minimum_size.x = 330.0
	column.add_theme_constant_override("separation",8)
	_heading = _label("Willowbrook Job Board",24)
	column.add_child(_heading)
	_board_status = _label("")
	column.add_child(_board_status)
	_jobs = OptionButton.new()
	_jobs.custom_minimum_size.y = 42
	column.add_child(_jobs)
	var names: Array = _profile.job_names()
	for id: String in names:
		_jobs.add_item("Stage" if id == "singing" else id.capitalize())
		_jobs.set_item_metadata(_jobs.item_count-1,id)
	_jobs.item_selected.connect(func(_index: int): _refresh_board())
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size.y = 150
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_guide = _label("")
	_guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_guide)
	_switch = Button.new()
	_switch.custom_minimum_size.y = 38
	_switch.pressed.connect(func():
		_checking_starters = not _checking_starters
		_scroll.scroll_vertical = 0
		_refresh_board()
	)
	column.add_child(_switch)
	_cancel = Button.new()
	_cancel.text = "Cancel Current Activity"
	_cancel.custom_minimum_size.y = 44
	_cancel.pressed.connect(func(): 
		if _account() != null:
			_account().job_action("cancel")
			close_modal()
		else:
			_show_result(_profile.cancel())
		_refresh_board()
	)
	column.add_child(_cancel)
	_neighbor_board=Button.new()
	_neighbor_board.text="Neighbor Quests"
	_neighbor_board.hide()
	_neighbor_board.pressed.connect(func():
		var current := _account()
		if current!=null and current.has_method("neighbor_quests_supported") and current.neighbor_quests_supported():
			close_modal()
			current.open_neighbor_quests()
	)
	column.add_child(_neighbor_board)
	var close := Button.new()
	close.text = "Back to Town"
	close.custom_minimum_size.y = 44
	close.pressed.connect(close_modal)
	column.add_child(close)
	_overlay.hide()
	_fit_board = func(s: float,width: float,height: float) -> void:
		column.custom_minimum_size.x = minf(410.0,width-52.0)*s
		for edge in ["left","right","top","bottom"]:
			padding.add_theme_constant_override("margin_"+edge,roundi(12.0*s))
		column.add_theme_constant_override("separation",roundi(6.0*s))
		_heading.add_theme_font_size_override("font_size",roundi(21.0*s))
		for label: Label in [_board_status,_guide]:
			label.add_theme_font_size_override("font_size",roundi(15.0*s))
		for button: Button in [_jobs,_cancel,_switch,_neighbor_board,close]:
			button.custom_minimum_size.y = (38.0 if height<430.0 else 44.0)*s
			button.add_theme_font_size_override("font_size",roundi(15.0*s))
		_scroll.custom_minimum_size.y = clampf(height*.27,74.0,155.0)*s
	get_viewport().size_changed.connect(_fit_town_hud)
	_fit_town_hud()
	if OS.has_feature("web"):
		var window := JavaScriptBridge.get_interface("window")
		_activity_ui = window.WillowbrookActivityLaunchers if window!=null else null
		if _activity_ui!=null:
			_activity_open_cb=JavaScriptBridge.create_callback(_open_activity)
			_activity_layout_cb=JavaScriptBridge.create_callback(_activity_layout)
			_activity_ui.bindTown(str(get_instance_id()),_activity_open_cb,_activity_layout_cb)

func _open_activity(args: Array) -> void:
	if args.size()!=1 or is_modal_open() or _host.get("zone_modal")==true:return
	if args[0]=="getting-started": _open_board(true)
	elif args[0]=="neighbor-quests":
		var account:=_account()
		if account!=null and account.has_method("open_neighbor_quests"):account.open_neighbor_quests()

func _activity_layout(args: Array) -> void:
	if args.size()==1 and (args[0] is float or args[0] is int) and is_finite(float(args[0])):
		var bottom:=clampf(float(args[0]),0.0,1200.0)
		if not is_equal_approx(_activity_bottom,bottom):
			_activity_bottom=bottom
			_fit_town_hud()

func _exit_tree() -> void:
	if _activity_ui!=null: _activity_ui.clearTown(str(get_instance_id()))

func _fit_town_hud() -> void:
	var view := get_viewport().get_visible_rect().size
	var s: float = FIT.touch_scale(get_viewport()) if _activity_ui!=null else FIT.physical_scale(get_viewport())
	var whole_width := maxf(1.0,view.x-24.0*s)
	var weather_y:=maxf(62.0,_activity_bottom+6.0)
	if _host.has_method("fit_town_activity_weather"): _host.fit_town_activity_weather(weather_y,s)
	_offline_stars.add_theme_font_size_override("font_size",roundi(15*s))
	_offline_stars.offset_right=-12.0*s
	_offline_stars.offset_left=-110.0*s
	_offline_stars.offset_top=12.0*s
	_notice.add_theme_font_size_override("font_size",roundi(15*s))
	_notice.position = Vector2(12,weather_y+23.0)*s
	_notice.size.x = whole_width
	_notice.set_deferred("size",Vector2(whole_width,64*s))
	_checklist_button.position = Vector2(12,12)*s
	_checklist_button.custom_minimum_size = Vector2(124,44)*s
	_checklist_button.size = _checklist_button.custom_minimum_size
	_checklist_button.add_theme_font_size_override("font_size",roundi(14*s))
	if _fit_board.is_valid():
		_fit_board.call(s,view.x/s,view.y/s)


func _onboarding_complete(account: Node) -> bool:
	if account == null:
		# Native/offline opens its four local tasks; the account-only Hunt cannot be completed there.
		return _profile.starter_eligible()
	var jobs: Dictionary = account.job_state()
	return bool(jobs.get("eligible",false)) and account.hunt_first_completed()


func _refresh_board() -> void:
	var state: Dictionary = _profile.snapshot()
	var recorded: Dictionary = state.starter.completed
	var account := _account()
	var jobs: Dictionary = account.job_state() if account != null else {}
	if account != null:
		recorded = {}
		for id: Variant in jobs.get("completed",[]):
			recorded[String(id)] = true
	var completed: Array[String] = []
	for id in ["cafe","store","park","garden"]:
		completed.append("%s %s" % ["Complete:" if recorded.has(id) else "To do:",id.capitalize()])
	_board_status.text = "You're eligible for town jobs." if bool(jobs.get("eligible",false) if account != null else _profile.starter_eligible()) else "Finish the four starter activities to get hired."
	_board_status.text += "\n" + "   ".join(completed)
	var current: Variant = jobs.get("current")
	if current is Dictionary:
		var activity: String = String(current.get("job","")).capitalize()
		var zone_name: String = String(current.get("zone","town"))
		var location: String = {"town":"outside in town","cafe":"inside Sunny Cafe","store":"inside the Town Store","library":"inside the Library","salon":"inside the Salon"}.get(zone_name,"inside " + zone_name.capitalize())
		_board_status.text += "\nIn progress: %s. %s %s." % [activity,String(current.get("label","Follow the marker")),location]
		if _checking_starters:
			_board_status.text += "\nFinish it or choose Cancel Current Activity to start another. Completed activities and stars stay saved."
	_cancel.visible = jobs.get("current") is Dictionary if account != null else _profile.active()
	_heading.text = "Getting Started" if _checking_starters else "Willowbrook Job Board"
	_neighbor_board.visible=not _checking_starters and account!=null and account.has_method("neighbor_quests_supported") and account.neighbor_quests_supported()
	_jobs.visible = not _checking_starters
	_switch.text = "Show Job Board" if _checking_starters else "Show Starter Checklist"
	if _checking_starters:
		var rows := PackedStringArray()
		for item: Dictionary in _profile.starter_checklist():
			var cooldown: int = account.job_starter_wait(String(item.id)) if account != null else item.wait
			var value := "%d %s" % [item.reward,"star" if item.reward == 1 else "stars"]
			if cooldown < 0:
				value = "Waiting for server reward timer"
			elif cooldown > 0:
				value = "%s ready in %d:%02d" % [value,floori(cooldown/60.0),cooldown%60]
			rows.append("%s %s  (%s)\n%s" % ["Done:" if (recorded.has(str(item.get("id",""))) if account != null else item.done) else "To do:",item.label,value,item.hint])
		if account != null:
			rows.append("%s Treasure Hunt" % ("Done:" if account.hunt_first_completed() else "To do:"))
			rows.append("Talk to the Mayor in the park and find all eight treasures. Read the Hunt Champions sign for times.")
		_guide.text = "\n\n".join(rows)
		return
	var id: String = _jobs.get_item_metadata(_jobs.selected)
	var guide: Dictionary = _profile.job_guide(id)
	var hired: bool = account.job_memberships().has(id) if account != null else _profile.memberships().has(id)
	var lines := PackedStringArray(["%d stars per shift" % guide.reward,"Already hired" if hired else "Ask: %s" % guide.employer,"Start: %s" % guide.station])
	if id == "delivery":
		lines.append("Deliver the parcel to the named door or front path.")
	for task: Dictionary in guide.tasks:
		lines.append("â€¢ " + task.label)
	_guide.text = "\n".join(lines)

