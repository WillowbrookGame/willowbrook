extends Control

const DISPLAY = preload("res://game/arcade/screen.gd")
const HELP := {
	"basketball": "Hold Left or Right to move. Adjust the arc with Up and Down. Hold Shoot, then release. You have 60 seconds.",
	"memory": "Find all six pairs. Tap a card, or select one with the arrow keys and press Space.",
	"claw": "Hold Right and release to set the claw's position. Hold Up and release to drop it. Collect the toy from the chute with Space.",
	"air-hockey": "Offline practice against the computer. Drag or use the arrows to move your paddle. First to five wins a round. Play on ice, sea, and desert.",
	"road-hop": "Hop with the arrows or WASD. Watch out for traffic and trees.",
	"maze-chase": "Turn with Left and Right. Up thrusts; Space fires. Clear rocks and wrap around the screen.",
	"brick-breaker": "Use Left and Right or drag to move the paddle. Press Space to launch and clear the bricks.",
	"survivors": "Arrows or WASD move. Your character fires automatically. Tap an upgrade directly, or choose it with the arrows and tap Action."
}
const ACTIONS := {"basketball":"Shoot", "memory":"Flip", "claw":"Collect", "maze-chase":"Fire", "brick-breaker":"Launch","air-hockey":"Next round"}

var host: Node3D
var display: Control
var title: Label
var instruction: Label
var status: Label
var controls: HFlowContainer
var controls_by_action: Dictionary = {}
var start: Button
var online: Button
var restart: Button
var how: Button
var close: Button
var id := ""
var game_title := ""
var running := false
var built := false
var paused := false

func setup(owner_map: Node3D) -> void:
	host = owner_map
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color("#122343bb")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["top","bottom","left","right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var center := CenterContainer.new()
	margin.add_child(center)
	# Upper width/height limits keep everything readable on a 640px display.
	var panel := PanelContainer.new()
	center.add_child(panel)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#213453")
	bg.set_corner_radius_all(12)
	bg.content_margin_top = 12
	bg.content_margin_bottom = 12
	bg.content_margin_left = 12
	bg.content_margin_right = 12
	panel.add_theme_stylebox_override("panel", bg)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 5)
	panel.add_child(list)
	title = Label.new()
	title.add_theme_font_size_override("font_size",24)
	list.add_child(title)
	instruction = Label.new()
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(instruction)
	display = DISPLAY.new()
	list.add_child(display)
	display.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 22
	list.add_child(status)
	controls = HFlowContainer.new()
	list.add_child(controls)
	for a: String in ["left","up","down","right","action"]:
		var b := _button(a.capitalize(),controls)
		controls_by_action[a] = b
		b.button_down.connect(_touch_input.bind(a,true))
		b.button_up.connect(_touch_input.bind(a,false))
	var footer := HBoxContainer.new()
	list.add_child(footer)
	start = _button("Play",footer)
	start.pressed.connect(play)
	online = _button("Play with a Friend",footer)
	online.pressed.connect(_play_online)
	restart = _button("Play Again",footer)
	restart.pressed.connect(_begin)
	how = _button("How to Play",footer)
	how.pressed.connect(_show_help)
	close = _button("Done",footer)
	close.pressed.connect(dismiss)
	get_viewport().size_changed.connect(_resize_display)
	_resize_display()
	hide()

func _resize_display() -> void:
	var available := get_viewport_rect().size
	var w := clampf(minf(available.x - 50,(available.y-212)*4.0/3.0),212,480)
	display.custom_minimum_size = Vector2(w,w*.75)

func _button(caption: String, holder: Control) -> Button:
	var b := Button.new()
	b.text = caption
	b.custom_minimum_size = Vector2(48,44)
	b.focus_mode = Control.FOCUS_NONE
	holder.add_child(b)
	return b

func open_cabinet(cabinet: String, caption: String) -> void:
	id = cabinet
	game_title = caption
	built = false
	paused = false
	show()
	host.set_zone_modal(true)
	_show_help()
	for a: String in controls_by_action:
		var b: Button = controls_by_action[a]
		b.text = String(ACTIONS.get(id,"Action")) if a == "action" else ("Thrust" if a == "up" and id == "maze-chase" else a.capitalize())
		b.visible = not (id == "maze-chase" and a == "down" or id == "claw" and a in ["left","down"] or id == "brick-breaker" and a in ["up","down"] or id in ["road-hop","survivors"] and a == "action")

func _show_help() -> void:
	running = false
	display.clear_inputs()
	instruction.text = String(HELP.get(id,""))
	if id == "air-hockey":
		instruction.text = "Drag or use the arrows to move your paddle. First to five wins a round; play on ice, sea, and desert. Play solo against the computer, or join a friend at this cabinet in a LAN session."
	start.text = "Resume" if built else "Play"
	title.text = "How to play: " + game_title
	instruction.show()
	start.show()
	var session := get_node_or_null("/root/WillowbrookSession")
	online.visible = id == "air-hockey" and not built and session != null and bool(session.get("admitted"))
	display.hide()
	status.hide()
	controls.hide()
	restart.hide()
	how.hide()

func play() -> void:
	if not built:
		display.begin(id)
		built = true
	paused = false
	running = true
	title.text = game_title
	instruction.hide()
	start.hide()
	online.hide()
	display.show()
	status.show()
	controls.show()
	restart.show()
	restart.disabled = false
	restart.text = "Rematch" if display.session != null else "Play Again"
	how.show()
	status.text = display.message()

func _play_online() -> void:
	var session := get_node_or_null("/root/WillowbrookSession")
	if session == null or not bool(session.get("admitted")):
		return
	display.begin(id)
	display.bind_hockey(session)
	built = true
	play()


func _begin() -> void:
	if display.session != null:
		display.session.hockey_rematch()
		return
	built = false
	play()

func dismiss() -> void:
	if not visible:
		return
	running = false
	built = false
	display.clear_inputs()
	display.leave_hockey()
	hide()
	host.set_zone_modal(false)

func _process(delta: float) -> void:
	if running and not paused and visible:
		display.step(minf(delta,.05))
		status.text = display.message()
		if id == "survivors":
			controls_by_action["action"].visible = display.wants_survivor_action()
		restart.disabled = display.session != null and not display.hockey.get("phase","") == "finished"

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and display != null:
		display.clear_inputs()

func _touch_input(a: String, down: bool) -> void:
	if running and not paused:
		display.play_input(a,down)

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	var action := ""
	match key.physical_keycode:
		KEY_ESCAPE:
			if key.pressed and not key.echo:
				dismiss()
		KEY_A, KEY_LEFT:
			action = "left"
		KEY_D, KEY_RIGHT:
			action = "right"
		KEY_W, KEY_UP:
			action = "up"
		KEY_S, KEY_DOWN:
			action = "down"
		KEY_SPACE, KEY_ENTER:
			action = "action"
			if not running and key.pressed and not key.echo:
				play()
				action = ""
		KEY_P:
			if running and key.pressed and not key.echo:
				paused = not paused
				display.clear_inputs()
				status.text = "Paused. Press P to resume." if paused else display.message()
		_:
			return
	if not action.is_empty() and running and not paused and not key.echo:
		display.play_input(action,key.pressed)
	get_viewport().set_input_as_handled()
