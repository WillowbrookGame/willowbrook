extends Node3D
## Client-only scavenger visuals. Item positions and awards are owned by the local account server.
const PICKUPS := "res://paintball_prototype/scavenger/pickups/"
const ACTIVE_IDS := ["coin","gem","ruby","heart","star","key","scroll","medallion"]
const NAMES := {"coin":"Coin","gem":"Gem","ruby":"Ruby","heart":"Heart","star":"Star","key":"Key","scroll":"Scroll","medallion":"Medallion"}

var session: Node
var host: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var zone: String
var state: Dictionary = {}
var rows: Array = []
var visuals := {}
var _signature := ""
var _clock_delta := 0.0
var _champion: Label3D
var _board_scroll: ScrollContainer
var _opened_at_board := false
const CHAMPIONS_BOARD := Vector3(28,.02,-20)
const CHAMPIONS_INTERACT := Vector2(28,-18)
const SIGN_ART = preload("res://paintball_prototype/landmark_sign_art.gd")
const BOARD_MODEL = preload("res://paintball_prototype/town_assets/3dassets-notice-board/notice-board-godot.glb")
const TOWN_HUD_FIT = preload("res://paintball_prototype/hud_fit.gd")
var _overlay: CenterContainer
var _menu: VBoxContainer
var _time: Label
var _hint_open := {}
var _opened_at_mayor := false
var _time_last := -1
var _cool_until := 0

func setup(net: Node, map: Node3D, body: CharacterBody3D, canvas: CanvasLayer, area: String) -> void:
	session = net
	host = map
	player = body
	hud = canvas
	zone = area
	_make_hud()
	if zone == "town":
		_make_champions_sign()

func update_state(snapshot: Dictionary, leaderboard: Array, server_time: Variant = null) -> void:
	var old := state.duplicate(true)
	state = snapshot.duplicate(true)
	rows = leaderboard.duplicate(true)
	if server_time is float or server_time is int:
		_clock_delta = float(server_time) - Time.get_unix_time_from_system()*1000.0
	if old.get("runId") != state.get("runId"):
		_hint_open.clear()
	var found: Array = state.get("collected",[])
	var sig := JSON.stringify([state.get("runId"),found,state.get("completedAt")])
	if sig != _signature:
		_signature = sig
		_sync_visuals()
	_sync_champion()
	if is_open():
		_build_menu()

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec()
	for obj: Variant in visuals.values():
		if is_instance_valid(obj):
			obj.position.y = 0.18 + sin(t/600.0+obj.position.x)*0.06
	_update_clock()

func _active() -> bool:
	return state.get("startedAt") != null and state.get("completedAt") == null

func _nearest() -> Dictionary:
	if not session.admitted or not _active() or not is_instance_valid(player):
		return {}
	var p := player.global_position
	var best: Dictionary = {}
	var dist := INF
	for item: Dictionary in state.get("placements",[]):
		if item.get("zone") != zone or state.get("collected",[]).has(item.get("id")):
			continue
		var d := Vector2(p.x-float(item.x),p.z-float(item.z)).length()
		if d < dist and d <= float(item.get("radius",2.2)) and absf(p.y)<1.35:
			dist = d
			best = item
	return best

func prompt() -> String:
	var item := _nearest()
	return ("Read Hunt Champions" if _near_champions() else "") if item.is_empty() else "Collect %s" % String(item.get("label","treasure"))

func interact() -> bool:
	var item := _nearest()
	if item.is_empty():
		if _near_champions():
			open_menu(false,true)
			return is_open()
		return false
	if Time.get_ticks_msec() >= _cool_until:
		_cool_until = Time.get_ticks_msec()+500
		session.hunt_action("collect",String(item.id))
	return true

func _sync_visuals() -> void:
	for obj: Variant in visuals.values():
		if is_instance_valid(obj):
			obj.queue_free()
	visuals.clear()
	if not _active():
		return
	for item: Dictionary in state.get("placements",[]):
		var id := String(item.get("id",""))
		if item.get("zone") != zone or id not in ACTIVE_IDS or state.get("collected",[]).has(id):
			continue
		var target := Node3D.new()
		target.name = "HuntPickup_" + id
		target.position = Vector3(float(item.x),0.18,float(item.z))
		add_child(target)
		visuals[id] = target
		var scene := load(PICKUPS+id+".glb") as PackedScene
		if scene == null:
			continue
		var model := scene.instantiate() as Node3D
		target.add_child(model)
		var box := AABB()
		var found := false
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			var local_transform: Transform3D = target.global_transform.affine_inverse() * mesh.global_transform
			var bounds: AABB = local_transform * mesh.get_aabb()
			box = box.merge(bounds) if found else bounds
			found = true
		if found:
			var factor := .72 / maxf(maxf(box.size.x,box.size.y),maxf(.001,box.size.z))
			var center := box.get_center()
			model.scale = Vector3.ONE * factor
			model.position = Vector3(-center.x,-box.position.y,-center.z)*factor

func open_menu(at_mayor := false, at_board := false) -> void:
	if not session.admitted or not is_instance_valid(host):
		return
	if not at_mayor and host.has_method("can_open_network_menu") and not host.can_open_network_menu():
		return
	_opened_at_mayor = at_mayor
	_opened_at_board = at_board
	_overlay.show()
	host.set_zone_modal(true)
	_build_menu()

func is_open() -> bool:
	return is_instance_valid(_overlay) and _overlay.visible

func close_menu() -> void:
	if not is_open():
		return
	_overlay.hide()
	if is_instance_valid(host):
		host.set_zone_modal(false)

func _make_hud() -> void:
	_overlay = CenterContainer.new()
	hud.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	_overlay.add_child(panel)
	var margin := MarginContainer.new()
	panel.add_child(margin)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,16)
	var scroll := ScrollContainer.new()
	_board_scroll = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_menu = VBoxContainer.new()
	_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu.add_theme_constant_override("separation",8)
	scroll.add_child(_menu)
	get_viewport().size_changed.connect(_fit_champions_menu)
	_fit_champions_menu()
	_overlay.hide()

func _label(text: String, size := 16) -> Label:
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",size)
	label.text = text
	_menu.add_child(label)
	return label

func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.pressed.connect(action)
	_menu.add_child(button)

func _build_menu() -> void:
	for child in _menu.get_children():
		_menu.remove_child(child)
		child.queue_free()
	if _opened_at_board:
		_label("Hunt Champions",23)
		_add_rankings()
		_button("Back to game",close_menu)
		_time = null
		return
	_label("Town treasure hunt",23)
	var count: int = state.get("collected",[]).size()
	_label("Found %d / 8" % count)
	_time = _label("")
	_time_last = -1
	_label("Find eight treasures on foot. Press E or tap Collect. Hints are optional, and progress saves automatically.")
	if state.get("rewardClaimed") == true:
		_label("Trophy earned! Place it from Decorate your home.")
	elif state.get("trophyInventoryPending") == true:
		_label("Your trophy is earned but not yet saved to the furniture bag. Sign in again to retry.")
	elif not _active():
		_label("Your first finish earns one trophy. No stars are needed.")
	if not _active() and _opened_at_mayor:
		_button("Play treasure hunt again" if state.get("completedAt") != null else "Start treasure hunt",func(): close_menu();session.hunt_action("start"))
	elif not _active():
		_label("Visit the Mayor in the park to start a round.")
	if not rows.is_empty():
		_add_rankings()
	if not state.get("placements",[]).is_empty():
		for id in ACTIVE_IDS:
			var is_found: bool = state.get("collected",[]).has(id)
			_label(("[Found] " if is_found else "[ ] ") + NAMES[id])
			if not is_found:
				var my_id: String = id
				_button("Hide hint" if _hint_open.has(id) else "Show hint",func():
					if _hint_open.has(my_id): _hint_open.erase(my_id)
					else: _hint_open[my_id] = true
					_build_menu())
				if _hint_open.has(id):
					for p: Dictionary in state.get("placements",[]):
						if p.get("id") == id: _label(String(p.get("hint","Look around town.")))
	_button("Back to game",close_menu)
	_update_clock()

func _fmt(ms: float) -> String:
	var sec := floori(maxf(0.0,ms) / 1000.0)
	return "%d:%02d" % [floori(sec/60.0),sec%60]

func _update_clock() -> void:
	if not is_open() or not is_instance_valid(_time):
		return
	var start: Variant = state.get("startedAt")
	if start == null:
		_time.text = "The clock starts when you begin."
		return
	var now := Time.get_unix_time_from_system()*1000.0 + _clock_delta
	var elapsed: float = float(state.get("elapsedMs",0)) if not _active() else now-float(start)
	var sec := floori(elapsed/1000.0)
	if sec == _time_last:
		return
	_time_last = sec
	var best: Variant = state.get("bestMs")
	_time.text = ("Time: " if _active() else "Finished: ") + _fmt(elapsed) + (" | Best: "+_fmt(float(best)) if best != null else "")

func _fit_champions_menu() -> void:
	if not is_instance_valid(_board_scroll):
		return
	var view := get_viewport().get_visible_rect().size
	var scale := TOWN_HUD_FIT.physical_scale(get_viewport())
	_board_scroll.custom_minimum_size = Vector2(minf(320*scale, maxf(160,view.x-52)),minf(340*scale,maxf(130,view.y-58)))

func _near_champions() -> bool:
	if zone != "town" or not session.admitted or state.is_empty() or not is_instance_valid(player):
		return false
	var pos := player.global_position
	return absf(pos.y)<1.35 and Vector2(pos.x,pos.z).distance_to(CHAMPIONS_INTERACT)<=2.3 and pos.z > CHAMPIONS_BOARD.z+.3

func _add_rankings() -> void:
	_label("Fastest times",18)
	if rows.is_empty():
		_label("No times yet. Visit the Mayor to start a hunt.")
	for row: Dictionary in rows:
		_label("%d. %s  %s" % [int(row.get("rank",0)),String(row.get("displayName","Player")),_fmt(float(row.get("durationMs",0)))])

func _make_champions_sign() -> void:
	var board := Node3D.new()
	board.name = "HuntChampions"
	board.position = CHAMPIONS_BOARD
	add_child(board)
	var model := BOARD_MODEL.instantiate() as Node3D
	board.add_child(model)
	var bounds := AABB()
	var has_bounds := false
	for mesh: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var local := board.global_transform.affine_inverse() * mesh.global_transform
		var part := local * mesh.get_aabb()
		bounds = bounds.merge(part) if has_bounds else part
		has_bounds = true
	var sign_z := .18
	if has_bounds:
		var factor := minf(2.7/maxf(.01,bounds.size.x),2.6/maxf(.01,bounds.size.y))
		var center := bounds.get_center()
		model.scale = Vector3.ONE * factor
		model.position = Vector3(-center.x,-bounds.position.y,-center.z)*factor
		sign_z = bounds.size.z * factor * .5 + .025
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.8,2.2,maxf(.55,sign_z*2))
	shape.shape = box
	shape.position.y = 1.1
	body.add_child(shape)
	board.add_child(body)
	_champion = SIGN_ART.add_notice_face(model,"HUNT CHAMPIONS","View the leaderboard",Color("#32594e"))

func _sync_champion() -> void:
	if not is_instance_valid(_champion):
		return
	if rows.is_empty():
		_champion.text = "View the leaderboard"
	else:
		var leader: Dictionary = rows[0]
		_champion.text = "%s\n%s" % [String(leader.get("displayName","Player")).left(24),_fmt(float(leader.get("durationMs",0)))]
	SIGN_ART.fit_text(_champion,Vector2(1.16,.245))


