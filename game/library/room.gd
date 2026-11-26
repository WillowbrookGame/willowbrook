extends "res://game/interiors/room.gd"

const LIBRARY_LAYOUT := preload("res://game/library/room_layout.tscn")
const CLERK_PROMPT := "Talk to the librarian"
var _class_request_until := 0
var course_index := 0

func setup(room_id: String, room_host: Node3D, body_player: CharacterBody3D, room_hud: CanvasLayer) -> void:
	super.setup(room_id,room_host,body_player,room_hud)
	var account := _account()
	if account!=null and not _visiting() and account.has_signal("class_result"):
		account.class_result.connect(_on_class_result)

func _room_title(key: String) -> String:
	return "Willowbrook Library" if key == "library" else ""

func _new_room_art() -> ART:
	return LIBRARY_LAYOUT.instantiate() as ART

func _welcomes_visitors() -> bool:
	return true

func _publishes_sitting() -> bool:
	return true

func _clerk_prompt() -> String:
	return CLERK_PROMPT

func _interact_room_specific(prompt: String) -> bool:
	if prompt != CLERK_PROMPT: return false
	_library_menu()
	return true

func _refresh_hire_menu() -> void:
	if active_panel == "library": _library_menu(false)
	else: super._refresh_hire_menu()

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(host): return
	if _class_request_until>0 and Time.get_ticks_msec()>_class_request_until:
		_class_request_until=0
		if is_modal_open() and active_panel=="library":
			feedback("No confirmation yet. Retry the same payment without paying twice.")
			_library_menu(false)
	super._process(delta)

func _library_menu(reset := true) -> void:
	var p := _snapshot()
	_open_panel("library","Willowbrook Library · Classes","Study any job, even before you get hired. Classes raise only that job's pay from 3 stars to 5, 8, then 10.",reset)
	_hire_button("library")
	var account := _account()
	if account!=null and (not account.has_method("classes_available") or not account.classes_available()):
		_label("Saved-star classes are unavailable on this server.")
		return
	var pending: Dictionary = account.pending_class_payment() if account!=null else {}
	if not pending.is_empty():
		if _class_request_until>0:
			_label("Saving your tuition payment…")
		else:
			_button("Retry same payment",_pay_class.bind(str(pending.course),int(pending.amount)))
		return
	var course := OptionButton.new()
	for job in JOBS: course.add_item(job.capitalize())
	course.select(course_index)
	fields.add_child(course)
	course.item_selected.connect(func(index: int):
		course_index = index
		_library_menu()
	)
	var job: String = JOBS[course_index]
	var classes: Dictionary = account.class_state() if account!=null else p.get("classes",{})
	var state: Dictionary = classes.get(job,{})
	var tier: int = state.get("tier",0)
	var paid: int = state.get("paid",0)
	if tier>=3:
		_label("All three tiers complete. This job earns 10 stars.")
		return
	var cost: int = [50,120,200][tier]
	var remain := maxi(1,cost-paid)
	var stars: int = account.saved_stars() if account!=null else p.get("stars",0)
	if account!=null: _label("Saved Stars: %d" % stars)
	_label("Current pay: %d stars. Tier %d tuition: %d stars. Paid %d; %d to go." % [[3,5,8,10][tier],tier+1,cost,paid,remain])
	_button("Pay 1 star",_pay_class.bind(job,1)).disabled = stars<1
	_button("Pay remaining %d stars" % remain,_pay_class.bind(job,remain)).disabled = stars<remain
	var spin := _spinner("Partial tuition",1,remain,mini(10,remain))
	_button("Make partial payment",func(): _pay_class(job,int(spin.value))).disabled = stars<1

func _pay_class(job: String, amount: int) -> void:
	var account := _account()
	if account!=null:
		if _class_request_until>0: return
		if account.has_method("class_command") and account.class_command(job,amount):
			_class_request_until=Time.get_ticks_msec()+8000
			_library_menu(false)
		else: feedback("Couldn't send tuition. Reconnect and check your balance.")
		return
	var service := _service()
	if service != null and service.has_method("take_class"):
		_show_result(service.take_class(job,amount))
		_library_menu(false)

func _on_class_result(_ok: bool,text: String) -> void:
	_class_request_until=0
	if not is_modal_open() or active_panel!="library": return
	feedback(text)
	_library_menu(false)
